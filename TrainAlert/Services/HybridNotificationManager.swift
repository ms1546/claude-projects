//
//  HybridNotificationManager.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/24.
//

import Combine
import CoreLocation
import Foundation
import OSLog
import SwiftUI
import UserNotifications

/// 時刻表と位置情報を組み合わせたハイブリッド通知管理
@MainActor
final class HybridNotificationManager: ObservableObject {
    // MARK: - Types
    
    /// 判定モード
    enum NotificationMode: String, CaseIterable {
        case timetableOnly = "timetable"
        case locationOnly = "location"
        case hybrid = "hybrid"
        case fallback = "fallback"
        
        var displayName: String {
            switch self {
            case .timetableOnly:
                return "時刻表モード"
            case .locationOnly:
                return "位置情報モード"
            case .hybrid:
                return "ハイブリッドモード"
            case .fallback:
                return "フォールバックモード"
            }
        }
        
        var icon: String {
            switch self {
            case .timetableOnly:
                return "clock.fill"
            case .locationOnly:
                return "location.fill"
            case .hybrid:
                return "link.circle.fill"
            case .fallback:
                return "exclamationmark.triangle.fill"
            }
        }
    }
    
    /// 通知判定結果
    struct NotificationDecision {
        let shouldNotify: Bool
        let mode: NotificationMode
        let confidence: Double // 0.0-1.0
        let estimatedTimeToArrival: TimeInterval?
        let distanceToTarget: CLLocationDistance?
        let reason: String
        let timestamp: Date
    }
    
    /// 位置情報と時刻表のズレ
    struct ScheduleDeviation {
        let expected: Date
        let actual: Date
        let deviationSeconds: TimeInterval
        let confidence: Double
        
        var isDelayed: Bool {
            deviationSeconds > 0
        }
        
        var displayText: String {
            let minutes = Int(abs(deviationSeconds) / 60)
            if minutes == 0 {
                return "定刻通り"
            } else if isDelayed {
                return "\(minutes)分遅れ"
            } else {
                return "\(minutes)分早着"
            }
        }
    }
    
    // MARK: - Properties
    
    static let shared = HybridNotificationManager()
    
    @Published private(set) var currentMode: NotificationMode = .hybrid
    @Published private(set) var lastDecision: NotificationDecision?
    @Published private(set) var currentDeviation: ScheduleDeviation?
    @Published private(set) var isMonitoring = false
    @Published private(set) var gpsAccuracy: CLLocationAccuracy = 0
    @Published private(set) var confidenceLevel: Double = 0.0
    
    @Published var isEnabled = true
    @Published var preferredMode: NotificationMode = .hybrid
    @Published var lowAccuracyThreshold: CLLocationAccuracy = 50.0 // meters
    @Published var deviationThreshold: TimeInterval = 180 // 3 minutes
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "HybridNotificationManager")
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var currentRouteAlert: RouteAlert?
    private var locationManager: LocationManager?
    private var notificationManager: NotificationManager?
    
    // Cache for calculations
    private var lastLocationUpdate: Date?
    private var lastTimetableCheck: Date?
    private var stationApproachHistory: [(station: String, time: Date, distance: CLLocationDistance)] = []
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
        setupBindings()
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.object(forKey: "hybridNotificationEnabled") as? Bool ?? true
        if let modeString = UserDefaults.standard.string(forKey: "preferredNotificationMode"),
           let mode = NotificationMode(rawValue: modeString) {
            preferredMode = mode
        }
        lowAccuracyThreshold = UserDefaults.standard.object(forKey: "lowAccuracyThreshold") as? CLLocationAccuracy ?? 50.0
        deviationThreshold = UserDefaults.standard.object(forKey: "deviationThreshold") as? TimeInterval ?? 180
    }
    
    private func setupBindings() {
        $isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                UserDefaults.standard.set(enabled, forKey: "hybridNotificationEnabled")
                if !enabled {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)
        
        $preferredMode
            .dropFirst()
            .sink { mode in
                UserDefaults.standard.set(mode.rawValue, forKey: "preferredNotificationMode")
            }
            .store(in: &cancellables)
        
        $lowAccuracyThreshold
            .dropFirst()
            .sink { threshold in
                UserDefaults.standard.set(threshold, forKey: "lowAccuracyThreshold")
            }
            .store(in: &cancellables)
        
        $deviationThreshold
            .dropFirst()
            .sink { threshold in
                UserDefaults.standard.set(threshold, forKey: "deviationThreshold")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 監視を開始
    func startMonitoring(for routeAlert: RouteAlert, locationManager: LocationManager, notificationManager: NotificationManager) {
        guard isEnabled else {
            logger.info("Hybrid notification is disabled")
            return
        }
        
        self.currentRouteAlert = routeAlert
        self.locationManager = locationManager
        self.notificationManager = notificationManager
        
        isMonitoring = true
        stationApproachHistory.removeAll()
        
        // 定期的な監視を開始
        monitoringTimer?.invalidate()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkNotificationConditions()
            }
        }
        
        // 位置情報の精度を監視
        locationManager.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.gpsAccuracy = location.horizontalAccuracy
                self?.lastLocationUpdate = Date()
            }
            .store(in: &cancellables)
        
        logger.info("Started hybrid monitoring for route alert")
    }
    
    /// 監視を停止
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        currentRouteAlert = nil
        cancellables.removeAll()
        logger.info("Stopped hybrid monitoring")
    }
    
    /// 通知条件をチェック
    @MainActor
    func checkNotificationConditions() async -> NotificationDecision? {
        guard let routeAlert = currentRouteAlert,
              let locationManager = locationManager else {
            return nil
        }
        
        // 現在のモードを決定
        let mode = determineCurrentMode()
        currentMode = mode
        
        // モードに応じた判定を実行
        let decision: NotificationDecision
        
        switch mode {
        case .timetableOnly:
            decision = await checkTimetableBasedNotification(routeAlert: routeAlert)
            
        case .locationOnly:
            decision = await checkLocationBasedNotification(routeAlert: routeAlert, locationManager: locationManager)
            
        case .hybrid:
            decision = await checkHybridNotification(routeAlert: routeAlert, locationManager: locationManager)
            
        case .fallback:
            decision = await checkFallbackNotification(routeAlert: routeAlert, locationManager: locationManager)
        }
        
        lastDecision = decision
        confidenceLevel = decision.confidence
        
        // 通知を送信
        if decision.shouldNotify {
            await sendNotification(decision: decision, routeAlert: routeAlert)
        }
        
        return decision
    }
    
    // MARK: - Private Methods
    
    /// 現在のモードを決定
    private func determineCurrentMode() -> NotificationMode {
        guard let locationManager = locationManager else {
            return .timetableOnly
        }
        
        // ユーザーの設定を優先
        if preferredMode == .timetableOnly {
            return .timetableOnly
        }
        
        // GPS精度をチェック
        let hasGoodGPS = locationManager.location?.horizontalAccuracy ?? Double.greatestFiniteMagnitude <= lowAccuracyThreshold
        
        // 地下鉄判定（将来的に実装）
        let isUnderground = checkIfUnderground()
        
        if !hasGoodGPS || isUnderground {
            // GPS精度が低い場合はフォールバックモード
            return preferredMode == .locationOnly ? .fallback : .timetableOnly
        }
        
        // GPS精度が良好な場合
        switch preferredMode {
        case .locationOnly:
            return .locationOnly
        case .hybrid:
            return .hybrid
        default:
            return .hybrid
        }
    }
    
    /// 地下鉄かどうかを判定（簡易実装）
    private func checkIfUnderground() -> Bool {
        // TODO: 路線情報から地下鉄かどうかを判定
        false
    }
    
    /// 時刻表ベースの通知チェック
    private func checkTimetableBasedNotification(routeAlert: RouteAlert) async -> NotificationDecision {
        guard let arrivalTime = routeAlert.arrivalTime else {
            return NotificationDecision(
                shouldNotify: false,
                mode: .timetableOnly,
                confidence: 0.0,
                estimatedTimeToArrival: nil,
                distanceToTarget: nil,
                reason: "到着時刻が設定されていません",
                timestamp: Date()
            )
        }
        
        let now = Date()
        let timeToArrival = arrivalTime.timeIntervalSince(now)
        let notificationTime = TimeInterval(routeAlert.notificationMinutes * 60)
        
        // 遅延情報を考慮
        var adjustedTimeToArrival = timeToArrival
        if let trainNumber = routeAlert.trainNumber,
           let railway = routeAlert.railway,
           let delayInfo = try? await DelayNotificationManager.shared.getDelayInfo(
            for: trainNumber,
            railwayId: railway
        ) {
            adjustedTimeToArrival += Double(delayInfo.delayMinutes * 60)
        }
        
        let shouldNotify = adjustedTimeToArrival <= notificationTime && adjustedTimeToArrival > 0
        
        return NotificationDecision(
            shouldNotify: shouldNotify,
            mode: .timetableOnly,
            confidence: 0.8, // 時刻表ベースは比較的高い信頼度
            estimatedTimeToArrival: adjustedTimeToArrival,
            distanceToTarget: nil,
            reason: shouldNotify ? "時刻表に基づく通知時刻です" : "まだ通知時刻ではありません",
            timestamp: now
        )
    }
    
    /// 位置情報ベースの通知チェック
    private func checkLocationBasedNotification(routeAlert: RouteAlert, locationManager: LocationManager) async -> NotificationDecision {
        guard let targetStationName = routeAlert.arrivalStation,
              let currentLocation = locationManager.location else {
            return NotificationDecision(
                shouldNotify: false,
                mode: .locationOnly,
                confidence: 0.0,
                estimatedTimeToArrival: nil,
                distanceToTarget: nil,
                reason: "位置情報が取得できません",
                timestamp: Date()
            )
        }
        
        // TODO: 実際の駅の座標を取得する必要がある
        // 仮の実装：距離を2000mとして仮定
        let distance = 2_000.0 // 仮の値
        let notificationDistance = 2_000.0
        
        // 駅への接近を記録
        recordStationApproach(station: targetStationName, distance: distance)
        
        // 速度を推定
        let estimatedSpeed = estimateCurrentSpeed()
        let estimatedTimeToArrival = estimatedSpeed > 0 ? distance / estimatedSpeed : nil
        
        let shouldNotify = distance <= notificationDistance
        let confidence = calculateLocationConfidence(accuracy: currentLocation.horizontalAccuracy, distance: distance)
        
        return NotificationDecision(
            shouldNotify: shouldNotify,
            mode: .locationOnly,
            confidence: confidence,
            estimatedTimeToArrival: estimatedTimeToArrival,
            distanceToTarget: distance,
            reason: shouldNotify ? "目的駅に接近しています" : "まだ目的駅から離れています",
            timestamp: Date()
        )
    }
    
    /// ハイブリッド通知チェック
    private func checkHybridNotification(routeAlert: RouteAlert, locationManager: LocationManager) async -> NotificationDecision {
        // 両方の判定を取得
        let timetableDecision = await checkTimetableBasedNotification(routeAlert: routeAlert)
        let locationDecision = await checkLocationBasedNotification(routeAlert: routeAlert, locationManager: locationManager)
        
        // ズレを計算
        if let timetableETA = timetableDecision.estimatedTimeToArrival,
           let locationETA = locationDecision.estimatedTimeToArrival {
            let deviation = timetableETA - locationETA
            let expected = Date().addingTimeInterval(timetableETA)
            let actual = Date().addingTimeInterval(locationETA)
            
            currentDeviation = ScheduleDeviation(
                expected: expected,
                actual: actual,
                deviationSeconds: deviation,
                confidence: (timetableDecision.confidence + locationDecision.confidence) / 2
            )
        }
        
        // 統合判定
        let shouldNotify: Bool
        let confidence: Double
        let reason: String
        
        if timetableDecision.confidence > 0.7 && locationDecision.confidence > 0.7 {
            // 両方の信頼度が高い場合は両方の条件を考慮
            shouldNotify = timetableDecision.shouldNotify || locationDecision.shouldNotify
            confidence = max(timetableDecision.confidence, locationDecision.confidence)
            reason = "時刻表と位置情報の両方から判定"
        } else if locationDecision.confidence > timetableDecision.confidence {
            // 位置情報の信頼度が高い
            shouldNotify = locationDecision.shouldNotify
            confidence = locationDecision.confidence
            reason = "位置情報を優先して判定"
        } else {
            // 時刻表の信頼度が高い
            shouldNotify = timetableDecision.shouldNotify
            confidence = timetableDecision.confidence
            reason = "時刻表を優先して判定"
        }
        
        return NotificationDecision(
            shouldNotify: shouldNotify,
            mode: .hybrid,
            confidence: confidence,
            estimatedTimeToArrival: locationDecision.estimatedTimeToArrival ?? timetableDecision.estimatedTimeToArrival,
            distanceToTarget: locationDecision.distanceToTarget,
            reason: reason,
            timestamp: Date()
        )
    }
    
    /// フォールバック通知チェック
    private func checkFallbackNotification(routeAlert: RouteAlert, locationManager: LocationManager) async -> NotificationDecision {
        // GPS精度が低い場合は時刻表をメインに使用
        let timetableDecision = await checkTimetableBasedNotification(routeAlert: routeAlert)
        
        // 可能な限り位置情報も参考にする
        if let location = locationManager.location,
           location.horizontalAccuracy < 100 { // 100m以内なら参考程度に使用
            let locationDecision = await checkLocationBasedNotification(routeAlert: routeAlert, locationManager: locationManager)
            
            // 位置情報は参考程度に
            let adjustedConfidence = timetableDecision.confidence * 0.8 + locationDecision.confidence * 0.2
            
            return NotificationDecision(
                shouldNotify: timetableDecision.shouldNotify,
                mode: .fallback,
                confidence: adjustedConfidence,
                estimatedTimeToArrival: timetableDecision.estimatedTimeToArrival,
                distanceToTarget: locationDecision.distanceToTarget,
                reason: "GPS精度が低いため時刻表を優先",
                timestamp: Date()
            )
        }
        
        // 位置情報が使えない場合
        return NotificationDecision(
            shouldNotify: timetableDecision.shouldNotify,
            mode: .fallback,
            confidence: timetableDecision.confidence * 0.7, // 信頼度を下げる
            estimatedTimeToArrival: timetableDecision.estimatedTimeToArrival,
            distanceToTarget: nil,
            reason: "GPS不調のため時刻表のみで判定",
            timestamp: Date()
        )
    }
    
    /// 駅への接近を記録
    private func recordStationApproach(station: String, distance: CLLocationDistance) {
        let record = (station: station, time: Date(), distance: distance)
        stationApproachHistory.append(record)
        
        // 古い記録を削除（最新10件のみ保持）
        if stationApproachHistory.count > 10 {
            stationApproachHistory.removeFirst()
        }
    }
    
    /// 現在の速度を推定
    private func estimateCurrentSpeed() -> CLLocationSpeed {
        guard stationApproachHistory.count >= 2 else {
            return 0
        }
        
        // 最新の2つの記録から速度を計算
        let recent = stationApproachHistory.suffix(2)
        let first = recent[recent.startIndex]
        let second = recent[recent.index(after: recent.startIndex)]
        
        let timeDiff = second.time.timeIntervalSince(first.time)
        let distanceDiff = abs(second.distance - first.distance)
        
        guard timeDiff > 0 else { return 0 }
        
        return distanceDiff / timeDiff
    }
    
    /// 位置情報の信頼度を計算
    private func calculateLocationConfidence(accuracy: CLLocationAccuracy, distance: CLLocationDistance) -> Double {
        guard accuracy > 0 else { return 0.0 }
        
        // 精度が距離に対して十分良好か
        let accuracyRatio = accuracy / max(distance, 100)
        
        if accuracyRatio < 0.1 {
            return 1.0 // 非常に高精度
        } else if accuracyRatio < 0.3 {
            return 0.8 // 高精度
        } else if accuracyRatio < 0.5 {
            return 0.6 // 中精度
        } else if accuracyRatio < 1.0 {
            return 0.4 // 低精度
        } else {
            return 0.2 // 非常に低精度
        }
    }
    
    /// 通知を送信
    private func sendNotification(decision: NotificationDecision, routeAlert: RouteAlert) async {
        guard let notificationManager = notificationManager else { return }
        
        var message = "もうすぐ\(routeAlert.arrivalStation ?? "目的駅")に到着します"
        
        // モードに応じてメッセージを調整
        switch decision.mode {
        case .hybrid:
            if let deviation = currentDeviation {
                message += " (\(deviation.displayText))"
            }
        case .fallback:
            message += " (GPS精度低下中)"
        default:
            break
        }
        
        // 距離情報を追加
        if let distance = decision.distanceToTarget {
            if distance < 1_000 {
                message += " - 残り\(Int(distance))m"
            } else {
                message += String(format: " - 残り%.1fkm", distance / 1_000)
            }
        }
        
        // NotificationManagerの既存メソッドを使用
        let content = UNMutableNotificationContent()
        content.title = "降車駅接近"
        content.body = message
        content.sound = .defaultCritical
        content.categoryIdentifier = "TRAIN_ARRIVAL"
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        
        logger.info("Sent hybrid notification: \(message)")
    }
}

// MARK: - UserDefaults Keys

private extension UserDefaults {
    static let hybridNotificationEnabledKey = "hybridNotificationEnabled"
    static let preferredNotificationModeKey = "preferredNotificationMode"
    static let lowAccuracyThresholdKey = "lowAccuracyThreshold"
    static let deviationThresholdKey = "deviationThreshold"
}
