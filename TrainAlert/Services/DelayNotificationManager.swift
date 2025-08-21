//
//  DelayNotificationManager.swift
//  TrainAlert
//
//  遅延情報の管理と通知時刻の調整
//

import BackgroundTasks
import Combine
import Foundation
import UserNotifications

/// 遅延情報管理マネージャー
@MainActor
final class DelayNotificationManager: ObservableObject {
    static let shared = DelayNotificationManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var delayInfos: [String: TrainDelayInfo] = [:] // trainNumber: delayInfo
    @Published var isEnabled: Bool = true
    @Published var notificationThreshold: Int = 10 // 遅延通知の閾値（分）
    
    // MARK: - Private Properties
    
    private let apiClient = ODPTAPIClient.shared
    private let notificationManager = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 300 // 5分間隔
    
    // キャッシュの有効期限（5分）
    private let cacheExpiration: TimeInterval = 300
    
    // MARK: - Initialization
    
    private init() {
        setupBackgroundTask()
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// 特定の列車の遅延情報を取得
    func getDelayInfo(for trainNumber: String, railwayId: String) async throws -> TrainDelayInfo? {
        // キャッシュをチェック
        if let cachedInfo = delayInfos[trainNumber],
           Date().timeIntervalSince(cachedInfo.lastUpdated) < cacheExpiration {
            return cachedInfo
        }
        
        // APIから最新情報を取得
        return try await fetchDelayInfo(trainNumber: trainNumber, railwayId: railwayId)
    }
    
    /// 遅延情報の定期更新を開始
    func startPeriodicUpdates(for alerts: [RouteAlert]) {
        stopPeriodicUpdates()
        
        guard isEnabled else { return }
        
        // タイマーで定期更新
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateDelayInfos(for: alerts)
            }
        }
        
        // 初回更新
        Task {
            await updateDelayInfos(for: alerts)
        }
    }
    
    /// 定期更新を停止
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// 通知時刻を遅延に応じて調整
    func adjustNotificationTime(
        for alert: RouteAlert,
        originalTime: Date,
        delayMinutes: Int
    ) async throws {
        guard isEnabled else { return }
        
        // 新しい通知時刻を計算
        let adjustedTime = originalTime.addingTimeInterval(TimeInterval(delayMinutes * 60))
        
        // 既存の通知をキャンセル
        if let identifier = alert.routeId?.uuidString {
            notificationManager.cancelNotification(identifier: identifier)
        }
        
        // 新しい通知をスケジュール
        if adjustedTime > Date() {
            // 通知内容を生成
            let content = createDelayNotificationContent(
                for: alert,
                delayMinutes: delayMinutes,
                adjustedTime: adjustedTime
            )
            
            // 通知をスケジュール
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: adjustedTime.timeIntervalSinceNow,
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: alert.routeId?.uuidString ?? UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            try await UNUserNotificationCenter.current().add(request)
            
            print("Notification adjusted for delay: \(delayMinutes) minutes, new time: \(adjustedTime)")
        }
    }
    
    /// 大幅遅延時の特別通知
    func sendMajorDelayNotification(
        for alert: RouteAlert,
        delayMinutes: Int
    ) async throws {
        guard isEnabled && delayMinutes >= 30 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ 大幅遅延発生"
        content.body = "\(alert.departureStation ?? "")〜\(alert.arrivalStation ?? "")間で約\(delayMinutes)分の遅延が発生しています"
        content.sound = .defaultCritical
        content.categoryIdentifier = "MAJOR_DELAY"
        
        let request = UNNotificationRequest(
            identifier: "major_delay_\(alert.routeId?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: nil // 即座に通知
        )
        
        try await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Private Methods
    
    private func fetchDelayInfo(trainNumber: String, railwayId: String) async throws -> TrainDelayInfo? {
        do {
            let trains = try await apiClient.getTrainInfo(railwayId: railwayId)
            
            // 指定された列車番号の情報を探す
            if let train = trains.first(where: { $0.trainNumber == trainNumber }) {
                let delayInfo = TrainDelayInfo(
                    trainNumber: trainNumber,
                    railwayId: railwayId,
                    delayMinutes: (train.delay ?? 0) / 60, // 秒を分に変換
                    fromStation: train.fromStation,
                    toStation: train.toStation,
                    lastUpdated: Date()
                )
                
                // キャッシュに保存
                delayInfos[trainNumber] = delayInfo
                
                return delayInfo
            }
            
            return nil
        } catch {
            print("Failed to fetch delay info: \(error)")
            throw error
        }
    }
    
    private func updateDelayInfos(for alerts: [RouteAlert]) async {
        for alert in alerts {
            guard let trainNumber = alert.trainNumber,
                  let railwayId = alert.railway else { continue }
            
            do {
                if let delayInfo = try await getDelayInfo(for: trainNumber, railwayId: railwayId) {
                    // 遅延が閾値を超えた場合
                    if delayInfo.delayMinutes >= notificationThreshold {
                        // 通知時刻を調整
                        if let originalTime = alert.notificationTime {
                            try await adjustNotificationTime(
                                for: alert,
                                originalTime: originalTime,
                                delayMinutes: delayInfo.delayMinutes
                            )
                        }
                        
                        // 大幅遅延の場合は特別通知
                        if delayInfo.delayMinutes >= 30 {
                            try await sendMajorDelayNotification(
                                for: alert,
                                delayMinutes: delayInfo.delayMinutes
                            )
                        }
                    }
                }
            } catch {
                print("Failed to update delay info for train \(trainNumber): \(error)")
            }
        }
    }
    
    private func createDelayNotificationContent(
        for alert: RouteAlert,
        delayMinutes: Int,
        adjustedTime: Date
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        content.title = "🚆 遅延情報あり"
        content.body = """
        \(alert.trainNumber ?? "列車")が約\(delayMinutes)分遅延しています。
        到着予定時刻: \(adjustedTime.formatted(date: .omitted, time: .shortened))
        """
        
        content.sound = .default
        content.categoryIdentifier = "DELAY_NOTIFICATION"
        content.userInfo = [
            "alertId": alert.routeId?.uuidString ?? "",
            "delayMinutes": delayMinutes
        ]
        
        return content
    }
    
    // MARK: - Background Task
    
    private func setupBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainAlert.delayCheck",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleBackgroundDelayCheck(task: refreshTask)
        }
    }
    
    private func handleBackgroundDelayCheck(task: BGAppRefreshTask) {
        task.expirationHandler = {
            self.stopPeriodicUpdates()
        }
        
        Task { @MainActor in
            do {
                // アクティブなアラートを取得
                let context = CoreDataManager.shared.viewContext
                let activeAlerts = try context.fetch(RouteAlert.fetchRequest())
                    .filter { $0.isActive }
                
                // 遅延情報を更新
                await updateDelayInfos(for: activeAlerts)
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            
            // 次回のタスクをスケジュール
            scheduleBackgroundDelayCheck()
        }
    }
    
    private func scheduleBackgroundDelayCheck() {
        let request = BGAppRefreshTaskRequest(identifier: "com.trainAlert.delayCheck")
        request.earliestBeginDate = Date(timeIntervalSinceNow: updateInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background delay check: \(error)")
        }
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        // UserDefaultsから設定を読み込み
        isEnabled = UserDefaults.standard.bool(forKey: "delayNotificationEnabled")
        notificationThreshold = UserDefaults.standard.integer(forKey: "delayNotificationThreshold")
        
        if notificationThreshold == 0 {
            notificationThreshold = 10 // デフォルト値
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "delayNotificationEnabled")
        UserDefaults.standard.set(notificationThreshold, forKey: "delayNotificationThreshold")
    }
}

// MARK: - Supporting Types

/// 列車遅延情報
struct TrainDelayInfo {
    let trainNumber: String
    let railwayId: String
    let delayMinutes: Int
    let fromStation: String?
    let toStation: String?
    let lastUpdated: Date
    
    var isDelayed: Bool {
        delayMinutes > 0
    }
    
    var delayDescription: String {
        if delayMinutes == 0 {
            return "定刻通り"
        } else if delayMinutes < 60 {
            return "約\(delayMinutes)分遅延"
        } else {
            let hours = delayMinutes / 60
            let minutes = delayMinutes % 60
            if minutes == 0 {
                return "約\(hours)時間遅延"
            } else {
                return "約\(hours)時間\(minutes)分遅延"
            }
        }
    }
}
