//
//  GPSFallbackHandler.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/24.
//

import Combine
import CoreLocation
import Foundation
import OSLog
import SwiftUI

/// GPS不調時のフォールバック処理
@MainActor
final class GPSFallbackHandler: ObservableObject {
    // MARK: - Types
    
    /// フォールバック戦略
    enum FallbackStrategy: String, CaseIterable {
        case timetableOnly = "timetable_only"
        case lastKnownLocation = "last_known"
        case stationSequence = "station_sequence"
        case manualConfirmation = "manual"
        case hybrid = "hybrid"
        
        var displayName: String {
            switch self {
            case .timetableOnly:
                return "時刻表のみ"
            case .lastKnownLocation:
                return "最後の既知位置"
            case .stationSequence:
                return "駅順序推定"
            case .manualConfirmation:
                return "手動確認"
            case .hybrid:
                return "複合戦略"
            }
        }
        
        var description: String {
            switch self {
            case .timetableOnly:
                return "時刻表データのみで通知"
            case .lastKnownLocation:
                return "最後に取得した位置情報を使用"
            case .stationSequence:
                return "通過駅の順序から推定"
            case .manualConfirmation:
                return "ユーザーに現在地を確認"
            case .hybrid:
                return "複数の方法を組み合わせ"
            }
        }
    }
    
    /// フォールバック状態
    struct FallbackState {
        let isActive: Bool
        let strategy: FallbackStrategy
        let confidence: Double
        let reason: String
        let lastGoodLocation: CLLocation?
        let lastGoodLocationAge: TimeInterval?
        let estimatedLocation: CLLocation?
        
        var displayText: String {
            if !isActive {
                return "GPS正常"
            }
            return "\(strategy.displayName) (信頼度: \(Int(confidence * 100))%)"
        }
    }
    
    /// 駅通過記録
    struct StationPassRecord {
        let stationId: String
        let stationName: String
        let timestamp: Date
        let location: CLLocation?
        let confidence: Double
    }
    
    // MARK: - Properties
    
    static let shared = GPSFallbackHandler()
    
    @Published private(set) var currentState: FallbackState
    @Published private(set) var isInFallbackMode = false
    @Published private(set) var stationPassHistory: [StationPassRecord] = []
    @Published private(set) var lastGoodLocation: CLLocation?
    @Published private(set) var gpsOutageDuration: TimeInterval = 0
    
    @Published var preferredStrategy: FallbackStrategy = .hybrid
    @Published var fallbackThreshold: TimeInterval = 30.0 // GPS途絶から何秒でフォールバック開始
    @Published var autoRecoveryEnabled = true
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "GPSFallbackHandler")
    private var cancellables = Set<AnyCancellable>()
    private var fallbackTimer: Timer?
    private var gpsOutageStartTime: Date?
    private var currentRouteAlert: RouteAlert?
    
    // MARK: - Initialization
    
    private init() {
        currentState = FallbackState(
            isActive: false,
            strategy: .hybrid,
            confidence: 1.0,
            reason: "GPS正常動作中",
            lastGoodLocation: nil,
            lastGoodLocationAge: nil,
            estimatedLocation: nil
        )
        
        loadSettings()
        setupBindings()
    }
    
    private func loadSettings() {
        if let strategyString = UserDefaults.standard.string(forKey: "preferredFallbackStrategy"),
           let strategy = FallbackStrategy(rawValue: strategyString) {
            preferredStrategy = strategy
        }
        fallbackThreshold = UserDefaults.standard.object(forKey: "fallbackThreshold") as? TimeInterval ?? 30.0
        autoRecoveryEnabled = UserDefaults.standard.object(forKey: "autoRecoveryEnabled") as? Bool ?? true
    }
    
    private func setupBindings() {
        $preferredStrategy
            .dropFirst()
            .sink { strategy in
                UserDefaults.standard.set(strategy.rawValue, forKey: "preferredFallbackStrategy")
            }
            .store(in: &cancellables)
        
        $fallbackThreshold
            .dropFirst()
            .sink { threshold in
                UserDefaults.standard.set(threshold, forKey: "fallbackThreshold")
            }
            .store(in: &cancellables)
        
        $autoRecoveryEnabled
            .dropFirst()
            .sink { enabled in
                UserDefaults.standard.set(enabled, forKey: "autoRecoveryEnabled")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// GPS状態を監視開始
    func startMonitoring(locationManager: LocationManager, routeAlert: RouteAlert) {
        currentRouteAlert = routeAlert
        
        // 位置情報の更新を監視
        locationManager.$location
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
        
        // 定期的なチェック
        fallbackTimer?.invalidate()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkFallbackConditions()
        }
        
        logger.info("Started GPS fallback monitoring")
    }
    
    /// 監視を停止
    func stopMonitoring() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        cancellables.removeAll()
        currentRouteAlert = nil
        resetFallbackState()
        logger.info("Stopped GPS fallback monitoring")
    }
    
    /// 駅通過を記録
    func recordStationPass(stationId: String, stationName: String, location: CLLocation?, confidence: Double = 1.0) {
        let record = StationPassRecord(
            stationId: stationId,
            stationName: stationName,
            timestamp: Date(),
            location: location,
            confidence: confidence
        )
        
        stationPassHistory.append(record)
        
        // 古い記録を削除（最新20件のみ保持）
        if stationPassHistory.count > 20 {
            stationPassHistory.removeFirst()
        }
        
        logger.info("Recorded station pass: \(stationName)")
    }
    
    /// 現在位置を推定
    func estimateCurrentLocation() -> CLLocation? {
        guard isInFallbackMode else {
            return lastGoodLocation
        }
        
        switch currentState.strategy {
        case .lastKnownLocation:
            return estimateFromLastKnownLocation()
            
        case .stationSequence:
            return estimateFromStationSequence()
            
        case .hybrid:
            // 複数の推定方法を組み合わせ
            if let lastKnown = estimateFromLastKnownLocation(),
               let stationBased = estimateFromStationSequence() {
                // 両方の推定値の中間を取る（簡易実装）
                let avgLat = (lastKnown.coordinate.latitude + stationBased.coordinate.latitude) / 2
                let avgLon = (lastKnown.coordinate.longitude + stationBased.coordinate.longitude) / 2
                return CLLocation(latitude: avgLat, longitude: avgLon)
            }
            return estimateFromLastKnownLocation() ?? estimateFromStationSequence()
            
        default:
            return nil
        }
    }
    
    /// 手動で位置を確認
    func confirmManualLocation(nearStation: String) {
        guard let routeAlert = currentRouteAlert else { return }
        
        // 指定された駅の位置を取得して記録
        // TODO: 実際の駅情報を取得する実装が必要
        // 現在は仮実装として駅名のみを記録
        recordStationPass(stationId: nearStation, stationName: nearStation, location: nil, confidence: 0.8)
            
        
        // フォールバック状態を更新
        updateFallbackState(
            isActive: true,
            strategy: .manualConfirmation,
            confidence: 0.8,
            reason: "ユーザーが現在地を確認",
            estimatedLocation: nil
        )
    }
    
    // MARK: - Private Methods
    
    /// 位置情報更新を処理
    private func handleLocationUpdate(_ location: CLLocation?) {
        if let location = location, location.horizontalAccuracy > 0 && location.horizontalAccuracy < 100 {
            // 有効な位置情報を取得
            lastGoodLocation = location
            gpsOutageStartTime = nil
            
            if isInFallbackMode && autoRecoveryEnabled {
                // フォールバックモードから復帰
                recoverFromFallback()
            }
        } else {
            // GPS不調
            if gpsOutageStartTime == nil {
                gpsOutageStartTime = Date()
            }
        }
    }
    
    /// フォールバック条件をチェック
    private func checkFallbackConditions() {
        guard let outageStart = gpsOutageStartTime else {
            gpsOutageDuration = 0
            return
        }
        
        gpsOutageDuration = Date().timeIntervalSince(outageStart)
        
        if gpsOutageDuration >= fallbackThreshold && !isInFallbackMode {
            // フォールバックモードに移行
            enterFallbackMode()
        }
    }
    
    /// フォールバックモードに入る
    private func enterFallbackMode() {
        isInFallbackMode = true
        
        let strategy = determineOptimalStrategy()
        let confidence = calculateFallbackConfidence(strategy: strategy)
        
        updateFallbackState(
            isActive: true,
            strategy: strategy,
            confidence: confidence,
            reason: "GPS信号が\(Int(gpsOutageDuration))秒間途絶",
            estimatedLocation: nil
        )
        
        logger.warning("Entered fallback mode with strategy: \(strategy.rawValue)")
        
        // 通知を送信
        sendFallbackNotification()
    }
    
    /// フォールバックモードから復帰
    private func recoverFromFallback() {
        isInFallbackMode = false
        gpsOutageStartTime = nil
        gpsOutageDuration = 0
        
        updateFallbackState(
            isActive: false,
            strategy: preferredStrategy,
            confidence: 1.0,
            reason: "GPS信号回復",
            estimatedLocation: nil
        )
        
        logger.info("Recovered from fallback mode")
    }
    
    /// 最適な戦略を決定
    private func determineOptimalStrategy() -> FallbackStrategy {
        // ユーザー設定を優先
        if preferredStrategy != .hybrid {
            return preferredStrategy
        }
        
        // 状況に応じて最適な戦略を選択
        if let lastLocation = lastGoodLocation,
           Date().timeIntervalSince(lastLocation.timestamp) < 60 {
            // 最後の位置情報が新しい
            return .lastKnownLocation
        } else if !stationPassHistory.isEmpty {
            // 駅通過履歴がある
            return .stationSequence
        } else {
            // 時刻表のみ
            return .timetableOnly
        }
    }
    
    /// フォールバック信頼度を計算
    private func calculateFallbackConfidence(strategy: FallbackStrategy) -> Double {
        switch strategy {
        case .timetableOnly:
            return 0.6
            
        case .lastKnownLocation:
            guard let lastLocation = lastGoodLocation else { return 0.3 }
            let age = Date().timeIntervalSince(lastLocation.timestamp)
            if age < 30 {
                return 0.8
            } else if age < 60 {
                return 0.6
            } else if age < 180 {
                return 0.4
            } else {
                return 0.2
            }
            
        case .stationSequence:
            let recentPasses = stationPassHistory.suffix(3)
            if recentPasses.count >= 3 {
                return 0.7
            } else if recentPasses.count >= 2 {
                return 0.5
            } else {
                return 0.3
            }
            
        case .manualConfirmation:
            return 0.8
            
        case .hybrid:
            // 各戦略の信頼度を組み合わせ
            var totalConfidence = 0.0
            var count = 0
            
            if lastGoodLocation != nil {
                totalConfidence += calculateFallbackConfidence(strategy: .lastKnownLocation)
                count += 1
            }
            
            if !stationPassHistory.isEmpty {
                totalConfidence += calculateFallbackConfidence(strategy: .stationSequence)
                count += 1
            }
            
            return count > 0 ? totalConfidence / Double(count) : 0.5
        }
    }
    
    /// 最後の既知位置から推定
    private func estimateFromLastKnownLocation() -> CLLocation? {
        guard let lastLocation = lastGoodLocation else { return nil }
        
        // 時間経過に基づいて位置を推定（簡易実装）
        let timeSinceLastUpdate = Date().timeIntervalSince(lastLocation.timestamp)
        
        // 電車の平均速度を仮定（60km/h = 16.67m/s）
        let estimatedDistance = timeSinceLastUpdate * 16.67
        
        // 進行方向は不明なので、最後の位置をそのまま返す
        // 実際のアプリでは路線の方向を考慮する必要がある
        return lastLocation
    }
    
    /// 駅順序から推定
    private func estimateFromStationSequence() -> CLLocation? {
        guard let routeAlert = currentRouteAlert,
              !stationPassHistory.isEmpty else { return nil }
        
        // 最後に通過した駅を取得
        let lastPass = stationPassHistory.last!
        
        // TODO: 実際の駅順序情報を使用した推定の実装が必要
        // 現在は最後の位置をそのまま返す簡易実装
        
        return lastPass.location
    }
    
    /// フォールバック状態を更新
    private func updateFallbackState(
        isActive: Bool,
        strategy: FallbackStrategy,
        confidence: Double,
        reason: String,
        estimatedLocation: CLLocation?
    ) {
        currentState = FallbackState(
            isActive: isActive,
            strategy: strategy,
            confidence: confidence,
            reason: reason,
            lastGoodLocation: lastGoodLocation,
            lastGoodLocationAge: lastGoodLocation != nil ? Date().timeIntervalSince(lastGoodLocation!.timestamp) : nil,
            estimatedLocation: estimatedLocation
        )
    }
    
    /// フォールバック状態をリセット
    private func resetFallbackState() {
        updateFallbackState(
            isActive: false,
            strategy: preferredStrategy,
            confidence: 1.0,
            reason: "監視停止",
            estimatedLocation: nil
        )
        
        isInFallbackMode = false
        gpsOutageStartTime = nil
        gpsOutageDuration = 0
        stationPassHistory.removeAll()
    }
    
    /// フォールバック通知を送信
    private func sendFallbackNotification() {
        // 実装は省略（NotificationManagerを使用）
        logger.info("Would send fallback notification to user")
    }
}

// MARK: - Debug Extensions

extension GPSFallbackHandler {
    /// デバッグ情報を取得
    func getDebugInfo() -> String {
        var info = "=== GPS Fallback Debug Info ===\n"
        info += "Fallback Active: \(isInFallbackMode)\n"
        info += "Current Strategy: \(currentState.strategy.displayName)\n"
        info += "Confidence: \(Int(currentState.confidence * 100))%\n"
        info += "GPS Outage Duration: \(Int(gpsOutageDuration))s\n"
        
        if let lastGood = lastGoodLocation {
            let age = Date().timeIntervalSince(lastGood.timestamp)
            info += "Last Good Location Age: \(Int(age))s\n"
        }
        
        info += "\nStation Pass History:\n"
        for pass in stationPassHistory.suffix(5) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            info += "  \(formatter.string(from: pass.timestamp)): \(pass.stationName)\n"
        }
        
        return info
    }
}
