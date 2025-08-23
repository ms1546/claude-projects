//
//  LocationAccuracyManager.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/24.
//

import Combine
import CoreLocation
import Foundation
import OSLog
import SwiftUI

/// GPS精度管理とバッテリー消費最適化
@MainActor
final class LocationAccuracyManager: ObservableObject {
    // MARK: - Types
    
    /// 精度レベル
    enum AccuracyLevel: String, CaseIterable {
        case high = "high"
        case medium = "medium"
        case low = "low"
        case veryLow = "veryLow"
        case unavailable = "unavailable"
        
        var displayName: String {
            switch self {
            case .high:
                return "高精度"
            case .medium:
                return "中精度"
            case .low:
                return "低精度"
            case .veryLow:
                return "非常に低精度"
            case .unavailable:
                return "利用不可"
            }
        }
        
        var color: Color {
            switch self {
            case .high:
                return .green
            case .medium:
                return .yellow
            case .low:
                return .orange
            case .veryLow:
                return .red
            case .unavailable:
                return .gray
            }
        }
        
        var minAccuracy: CLLocationAccuracy {
            switch self {
            case .high:
                return 0
            case .medium:
                return 20
            case .low:
                return 50
            case .veryLow:
                return 100
            case .unavailable:
                return Double.greatestFiniteMagnitude
            }
        }
        
        var maxAccuracy: CLLocationAccuracy {
            switch self {
            case .high:
                return 20
            case .medium:
                return 50
            case .low:
                return 100
            case .veryLow:
                return 500
            case .unavailable:
                return Double.greatestFiniteMagnitude
            }
        }
    }
    
    /// 位置情報更新モード
    enum UpdateMode: String, CaseIterable {
        case continuous = "continuous"
        case periodic = "periodic"
        case significant = "significant"
        case manual = "manual"
        
        var displayName: String {
            switch self {
            case .continuous:
                return "連続更新"
            case .periodic:
                return "定期更新"
            case .significant:
                return "大幅移動時のみ"
            case .manual:
                return "手動更新"
            }
        }
        
        var updateInterval: TimeInterval? {
            switch self {
            case .continuous:
                return nil
            case .periodic:
                return 30.0
            case .significant:
                return nil
            case .manual:
                return nil
            }
        }
    }
    
    /// 環境タイプ
    enum EnvironmentType {
        case outdoor
        case indoor
        case underground
        case tunnel
        case unknown
        
        var displayName: String {
            switch self {
            case .outdoor:
                return "屋外"
            case .indoor:
                return "屋内"
            case .underground:
                return "地下"
            case .tunnel:
                return "トンネル"
            case .unknown:
                return "不明"
            }
        }
    }
    
    // MARK: - Properties
    
    static let shared = LocationAccuracyManager()
    
    @Published private(set) var currentAccuracy: CLLocationAccuracy = 0
    @Published private(set) var accuracyLevel: AccuracyLevel = .unavailable
    @Published private(set) var updateMode: UpdateMode = .periodic
    @Published private(set) var environment: EnvironmentType = .unknown
    @Published private(set) var isOptimizingBattery = false
    @Published private(set) var accuracyHistory: [AccuracyRecord] = []
    
    @Published var adaptiveAccuracyEnabled = true
    @Published var batteryOptimizationEnabled = true
    @Published var undergroundModeEnabled = true
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "LocationAccuracyManager")
    private var cancellables = Set<AnyCancellable>()
    private var locationManager: LocationManager?
    private var updateTimer: Timer?
    
    // 精度履歴記録
    struct AccuracyRecord {
        let timestamp: Date
        let accuracy: CLLocationAccuracy
        let level: AccuracyLevel
        let latitude: Double
        let longitude: Double
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
        setupBindings()
    }
    
    private func loadSettings() {
        adaptiveAccuracyEnabled = UserDefaults.standard.object(forKey: "adaptiveAccuracyEnabled") as? Bool ?? true
        batteryOptimizationEnabled = UserDefaults.standard.object(forKey: "batteryOptimizationEnabled") as? Bool ?? true
        undergroundModeEnabled = UserDefaults.standard.object(forKey: "undergroundModeEnabled") as? Bool ?? true
    }
    
    private func setupBindings() {
        $adaptiveAccuracyEnabled
            .dropFirst()
            .sink { enabled in
                UserDefaults.standard.set(enabled, forKey: "adaptiveAccuracyEnabled")
            }
            .store(in: &cancellables)
        
        $batteryOptimizationEnabled
            .dropFirst()
            .sink { enabled in
                UserDefaults.standard.set(enabled, forKey: "batteryOptimizationEnabled")
            }
            .store(in: &cancellables)
        
        $undergroundModeEnabled
            .dropFirst()
            .sink { enabled in
                UserDefaults.standard.set(enabled, forKey: "undergroundModeEnabled")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 精度管理を開始
    func startManaging(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        // 位置情報の変更を監視
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.updateAccuracy(from: location)
            }
            .store(in: &cancellables)
        
        // 定期的な最適化チェック
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.optimizeSettings()
        }
        
        logger.info("Started location accuracy management")
    }
    
    /// 精度管理を停止
    func stopManaging() {
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()
        logger.info("Stopped location accuracy management")
    }
    
    /// 現在の精度レベルを取得
    func getCurrentAccuracyLevel() -> AccuracyLevel {
        accuracyLevel
    }
    
    /// 推奨される精度設定を取得
    func getRecommendedAccuracy(for situation: TrackingSituation) -> CLLocationAccuracy {
        switch situation {
        case .approaching(let distance):
            if distance < 500 {
                return kCLLocationAccuracyBest
            } else if distance < 2_000 {
                return kCLLocationAccuracyNearestTenMeters
            } else {
                return kCLLocationAccuracyHundredMeters
            }
            
        case .departing:
            return kCLLocationAccuracyHundredMeters
            
        case .idle:
            return kCLLocationAccuracyKilometer
            
        case .underground:
            // 地下では精度を下げて省電力
            return kCLLocationAccuracyThreeKilometers
        }
    }
    
    /// 手動で精度を設定
    func setDesiredAccuracy(_ accuracy: CLLocationAccuracy) {
        guard let locationManager = locationManager else { return }
        
        locationManager.desiredAccuracy = accuracy
        logger.info("Manually set accuracy to \(accuracy)")
    }
    
    /// 更新モードを設定
    func setUpdateMode(_ mode: UpdateMode) {
        guard let locationManager = locationManager else { return }
        
        updateMode = mode
        
        switch mode {
        case .continuous:
            locationManager.startUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
            
        case .periodic:
            locationManager.startUpdatingLocation()
            // 定期的に停止・再開する処理を実装
            
        case .significant:
            locationManager.stopUpdatingLocation()
            locationManager.startMonitoringSignificantLocationChanges()
            
        case .manual:
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        
        logger.info("Set update mode to \(mode.rawValue)")
    }
    
    /// 環境を推定
    func detectEnvironment(from location: CLLocation, railway: String?) -> EnvironmentType {
        // 簡易的な実装（将来的に改善）
        if let railway = railway,
           railway.contains("地下鉄") || railway.contains("Subway") || railway.contains("Metro") {
            return .underground
        }
        
        // GPS精度から推定
        if location.horizontalAccuracy > 50 {
            return .indoor
        } else if location.horizontalAccuracy < 20 {
            return .outdoor
        }
        
        return .unknown
    }
    
    // MARK: - Private Methods
    
    /// 精度情報を更新
    private func updateAccuracy(from location: CLLocation) {
        currentAccuracy = location.horizontalAccuracy
        
        // 精度レベルを判定
        let level = determineAccuracyLevel(from: location.horizontalAccuracy)
        if level != accuracyLevel {
            accuracyLevel = level
            logger.info("Accuracy level changed to \(level.rawValue)")
        }
        
        // 履歴に記録
        let record = AccuracyRecord(
            timestamp: location.timestamp,
            accuracy: location.horizontalAccuracy,
            level: level,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        accuracyHistory.append(record)
        
        // 古い履歴を削除（最新100件のみ保持）
        if accuracyHistory.count > 100 {
            accuracyHistory.removeFirst()
        }
        
        // 適応的精度調整
        if adaptiveAccuracyEnabled {
            adjustAccuracyAdaptively()
        }
    }
    
    /// 精度レベルを判定
    private func determineAccuracyLevel(from accuracy: CLLocationAccuracy) -> AccuracyLevel {
        if accuracy < 0 {
            return .unavailable
        }
        
        for level in AccuracyLevel.allCases {
            if accuracy >= level.minAccuracy && accuracy < level.maxAccuracy {
                return level
            }
        }
        
        return .veryLow
    }
    
    /// 適応的に精度を調整
    private func adjustAccuracyAdaptively() {
        guard let locationManager = locationManager else { return }
        
        // 最近の精度履歴を分析
        let recentRecords = accuracyHistory.suffix(10)
        guard !recentRecords.isEmpty else { return }
        
        let averageAccuracy = recentRecords.map { $0.accuracy }.reduce(0, +) / Double(recentRecords.count)
        
        // 精度が安定して良好な場合は精度を下げて省電力
        if averageAccuracy < 20 && batteryOptimizationEnabled {
            if locationManager.desiredAccuracy == kCLLocationAccuracyBest {
                setDesiredAccuracy(kCLLocationAccuracyNearestTenMeters)
                isOptimizingBattery = true
            }
        }
        // 精度が悪化している場合は精度を上げる
        else if averageAccuracy > 50 {
            if locationManager.desiredAccuracy != kCLLocationAccuracyBest {
                setDesiredAccuracy(kCLLocationAccuracyBest)
                isOptimizingBattery = false
            }
        }
    }
    
    /// 設定を最適化
    private func optimizeSettings() {
        guard batteryOptimizationEnabled else { return }
        
        // バッテリー残量をチェック（iOS 12+）
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        // 低電力時の対応
        if batteryLevel < 0.2 && batteryLevel > 0 && batteryState != .charging {
            // 更新モードを省電力に
            if updateMode == .continuous {
                setUpdateMode(.periodic)
            }
            
            // 精度を下げる
            if let locationManager = locationManager,
               locationManager.desiredAccuracy == kCLLocationAccuracyBest {
                setDesiredAccuracy(kCLLocationAccuracyHundredMeters)
            }
            
            isOptimizingBattery = true
            logger.info("Optimizing for low battery: \(batteryLevel * 100)%")
        }
    }
    
    /// 地下鉄モードの設定
    func configureForUnderground() {
        guard undergroundModeEnabled else { return }
        
        environment = .underground
        
        // 地下では位置情報の更新頻度を下げる
        setUpdateMode(.significant)
        
        // 精度も下げる
        setDesiredAccuracy(kCLLocationAccuracyThreeKilometers)
        
        logger.info("Configured for underground mode")
    }
    
    /// 通常モードに戻す
    func configureForNormal() {
        environment = .outdoor
        
        // 通常の設定に戻す
        setUpdateMode(.periodic)
        setDesiredAccuracy(kCLLocationAccuracyBest)
        
        logger.info("Configured for normal mode")
    }
}

// MARK: - Supporting Types

/// 追跡状況
enum TrackingSituation {
    case approaching(distance: CLLocationDistance)
    case departing
    case idle
    case underground
}

// MARK: - Extensions

extension LocationAccuracyManager {
    /// デバッグ情報を取得
    func getDebugInfo() -> String {
        var info = "=== Location Accuracy Debug Info ===\n"
        info += "Current Accuracy: \(currentAccuracy)m\n"
        info += "Accuracy Level: \(accuracyLevel.displayName)\n"
        info += "Update Mode: \(updateMode.displayName)\n"
        info += "Environment: \(environment.displayName)\n"
        info += "Battery Optimizing: \(isOptimizingBattery)\n"
        info += "Adaptive Accuracy: \(adaptiveAccuracyEnabled)\n"
        
        if !accuracyHistory.isEmpty {
            let recent = accuracyHistory.suffix(5)
            info += "\nRecent Accuracy:\n"
            for record in recent {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                info += "  \(formatter.string(from: record.timestamp)): \(record.accuracy)m (\(record.level.displayName))\n"
            }
        }
        
        return info
    }
}
