//
//  NotificationManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreLocation
import Foundation
import UIKit
import UserNotifications

enum NotificationError: Error {
    case permissionDenied
    case notificationFailed
    case invalidConfiguration
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "通知の許可が必要です"
        case .notificationFailed:
            return "通知の送信に失敗しました"
        case .invalidConfiguration:
            return "通知設定が無効です"
        }
    }
}

enum NotificationCategory: String, CaseIterable {
    case trainAlert = "TRAIN_ALERT"
    case snoozeAlert = "SNOOZE_ALERT"
    
    var identifier: String {
        self.rawValue
    }
}

enum NotificationAction: String {
    case snooze = "SNOOZE_ACTION"
    case dismiss = "DISMISS_ACTION"
    case openApp = "OPEN_APP_ACTION"
    
    var identifier: String {
        self.rawValue
    }
}


struct NotificationContent {
    let title: String
    let body: String
    let sound: UNNotificationSound
    let categoryIdentifier: String
    let userInfo: [String: Any]
}

struct NotificationSettings {
    let defaultAdvanceTime: TimeInterval
    let defaultAdvanceDistance: Double
    let snoozeInterval: TimeInterval
    let maxSnoozeCount: Int
    let characterStyle: CharacterStyle
    let soundName: String
    let vibrationEnabled: Bool
    let previewEnabled: Bool
    
    init(
        defaultAdvanceTime: TimeInterval = 5 * 60,
        defaultAdvanceDistance: Double = 500,
        snoozeInterval: TimeInterval = 1 * 60,
        maxSnoozeCount: Int = 5,
        characterStyle: CharacterStyle = .healing,
        soundName: String = "default",
        vibrationEnabled: Bool = true,
        previewEnabled: Bool = true
    ) {
        self.defaultAdvanceTime = defaultAdvanceTime
        self.defaultAdvanceDistance = defaultAdvanceDistance
        self.snoozeInterval = snoozeInterval
        self.maxSnoozeCount = maxSnoozeCount
        self.characterStyle = characterStyle
        self.soundName = soundName
        self.vibrationEnabled = vibrationEnabled
        self.previewEnabled = previewEnabled
    }
}

@MainActor
class NotificationManager: NSObject, ObservableObject {
    // MARK: - Properties
    
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isPermissionGranted: Bool = false
    @Published var lastError: NotificationError?
    @Published var settings = NotificationSettings()
    
    internal let center = UNUserNotificationCenter.current()
    private let openAIClient = OpenAIClient.shared
    private let historyManager = NotificationHistoryManager.shared
    private var pendingNotifications: Set<String> = []
    private var snoozeCounters: [String: Int] = [:]
    private var settingsObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
        loadSettings()
        observeSettingsChanges()
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        let characterStyleRaw = defaults.string(forKey: "selectedCharacterStyle") ?? CharacterStyle.healing.rawValue
        let characterStyle = CharacterStyle(rawValue: characterStyleRaw) ?? .healing
        
        settings = NotificationSettings(
            defaultAdvanceTime: TimeInterval(defaults.integer(forKey: "defaultNotificationTime")) * 60,
            defaultAdvanceDistance: Double(defaults.integer(forKey: "defaultNotificationDistance")),
            snoozeInterval: TimeInterval(defaults.integer(forKey: "defaultSnoozeInterval")) * 60,
            maxSnoozeCount: 5,
            characterStyle: characterStyle,
            soundName: defaults.string(forKey: "selectedNotificationSound") ?? "default",
            vibrationEnabled: defaults.bool(forKey: "vibrationEnabled"),
            previewEnabled: defaults.bool(forKey: "notificationPreviewEnabled")
        )
    }
    
    private func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSettings()
        }
    }
    
    // MARK: - Authorization
    
    /// Request notification permissions
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        
        do {
            let granted = try await center.requestAuthorization(options: options)
            await MainActor.run {
                isPermissionGranted = granted
                if !granted {
                    lastError = .permissionDenied
                }
            }
            await checkAuthorizationStatus()
        } catch {
            await MainActor.run {
                lastError = .permissionDenied
            }
            throw NotificationError.permissionDenied
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        await MainActor.run {
            authorizationStatus = settings.authorizationStatus
            isPermissionGranted = settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule a train alert notification
    func scheduleTrainAlert(
        for stationName: String,
        arrivalTime: Date,
        currentLocation: CLLocation?,
        targetLocation: CLLocation,
        characterStyle: CharacterStyle = .healing,
        alertId: String? = nil
    ) async throws {
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        let notificationTime = arrivalTime.addingTimeInterval(-settings.defaultAdvanceTime)
        let identifier = "train_alert_\(stationName)_\(Int(arrivalTime.timeIntervalSince1970))"
        
        // Cancel existing notification with same identifier
        cancelNotification(identifier: identifier)
        
        let content = await createTrainAlertContent(
            stationName: stationName,
            arrivalTime: arrivalTime,
            currentLocation: currentLocation,
            targetLocation: targetLocation,
            characterStyle: characterStyle,
            alertId: alertId
        )
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, notificationTime.timeIntervalSinceNow),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
        pendingNotifications.insert(identifier)
        
        // 📱 Scheduled train alert for station at notification time
    }
    
    /// Schedule a location-based notification
    func scheduleLocationBasedAlert(
        for stationName: String,
        targetLocation: CLLocation,
        radius: CLLocationDistance = 500,
        alertId: String? = nil
    ) async throws {
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        let identifier = "location_alert_\(stationName)"
        
        // Cancel existing location notification
        cancelNotification(identifier: identifier)
        
        let content = await createLocationAlertContent(stationName: stationName, characterStyle: settings.characterStyle, alertId: alertId)
        
        let region = CLCircularRegion(
            center: targetLocation.coordinate,
            radius: radius,
            identifier: identifier
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        
        let trigger = UNLocationNotificationTrigger(
            region: region,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
        pendingNotifications.insert(identifier)
        
        // 📍 Scheduled location-based alert for station
    }
    
    /// Schedule a snooze notification
    func scheduleSnoozeNotification(for originalIdentifier: String, stationName: String) async throws {
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        // Check snooze limit
        let currentCount = snoozeCounters[originalIdentifier, default: 0]
        guard currentCount < settings.maxSnoozeCount else {
            // ⏰ Maximum snooze count reached
            return
        }
        
        let snoozeIdentifier = "\(originalIdentifier)_snooze_\(currentCount + 1)"
        snoozeCounters[originalIdentifier] = currentCount + 1
        
        let content = await createSnoozeAlertContent(
            stationName: stationName,
            snoozeCount: currentCount + 1,
            characterStyle: settings.characterStyle
        )
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: settings.snoozeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: snoozeIdentifier,
            content: content,
            trigger: trigger
        )
        
        try await center.add(request)
        pendingNotifications.insert(snoozeIdentifier)
        
        // 😴 Scheduled snooze notification
    }
    
    /// Schedule a route-based notification for timetable alerts
    func scheduleRouteNotification(
        routeAlert: RouteAlert,
        at notificationTime: Date
    ) async {
        guard isPermissionGranted else {
            print("通知の許可がありません")
            return
        }
        
        guard let departureStation = routeAlert.departureStation,
              let arrivalStation = routeAlert.arrivalStation else {
            return
        }
        
        let identifier = "route_alert_\(routeAlert.routeId?.uuidString ?? UUID().uuidString)"
        
        // Cancel existing notification
        cancelNotification(identifier: identifier)
        
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = getNotificationSound()
        
        // Generate message using character style
        // Note: RouteAlertにはcharacterStyleがないため、UserDefaultsから取得
        let savedStyle = UserDefaults.standard.string(forKey: "defaultCharacterStyle") ?? CharacterStyle.healing.rawValue
        let characterStyle = CharacterStyle(rawValue: savedStyle) ?? .healing
        let arrivalTimeString = routeAlert.arrivalTimeString
        
        // Generate message using OpenAI or fallback
        let message: String
        if openAIClient.hasAPIKey() {
            do {
                message = try await openAIClient.generateNotificationMessage(
                    for: arrivalStation,
                    arrivalTime: arrivalTimeString,
                    characterStyle: characterStyle
                )
            } catch {
                // Fallback to default message
                message = characterStyle.generateDefaultMessage(for: arrivalStation)
            }
        } else {
            message = characterStyle.generateDefaultMessage(for: arrivalStation)
        }
        
        content.title = "🚃 もうすぐ到着駅です"
        content.body = message
        content.subtitle = "\(arrivalStation)駅に到着予定"
        
        // Add user info
        content.userInfo = [
            "stationName": arrivalStation,
            "departureStation": departureStation,
            "routeAlertId": routeAlert.routeId?.uuidString ?? "",
            "type": "route"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, notificationTime.timeIntervalSinceNow),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            pendingNotifications.insert(identifier)
            print("🚆 時刻表ベースの通知をスケジュールしました: \(arrivalStation)駅")
        } catch {
            print("通知のスケジュールに失敗しました: \(error)")
        }
    }
    
    /// Schedule a repeating notification with calendar-based trigger
    func scheduleRepeatingNotification(
        for stationName: String,
        departureStation: String?,
        arrivalTime: Date,
        pattern: RepeatPattern,
        customDays: [Int] = [],
        characterStyle: CharacterStyle = .healing,
        notificationMinutes: Int = 5,
        alertId: String
    ) async throws {
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        // 繰り返しパターンに基づいて曜日を取得
        let days = pattern == .custom ? customDays : pattern.getDays()
        guard !days.isEmpty else { return }
        
        // 通知内容を作成
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = getNotificationSound()
        
        // 基準となる時刻から通知時刻を計算
        let notificationTime = arrivalTime.addingTimeInterval(TimeInterval(-notificationMinutes * 60))
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: notificationTime)
        
        // メッセージ生成
        let message: String
        if openAIClient.hasAPIKey() {
            do {
                message = try await openAIClient.generateNotificationMessage(
                    for: stationName,
                    arrivalTime: "\(notificationMinutes)分後",
                    characterStyle: characterStyle
                )
            } catch {
                message = characterStyle.generateDefaultMessage(for: stationName)
            }
        } else {
            message = characterStyle.generateDefaultMessage(for: stationName)
        }
        
        content.title = "🚃 もうすぐ\(stationName)駅です！"
        content.body = message
        
        if let departureStation = departureStation {
            content.subtitle = "\(departureStation) → \(stationName)"
        }
        
        content.userInfo = [
            "stationName": stationName,
            "departureStation": departureStation ?? "",
            "alertId": alertId,
            "type": "repeating",
            "pattern": pattern.rawValue
        ]
        
        content.badge = NSNumber(value: 1)
        
        // iOSの制限により、最大64個の通知をスケジュール
        // 各曜日に対して通知を作成
        for day in days {
            var dateComponents = DateComponents()
            dateComponents.weekday = day
            dateComponents.hour = components.hour
            dateComponents.minute = components.minute
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let identifier = "repeat_\(alertId)_day\(day)"
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            try await center.add(request)
            pendingNotifications.insert(identifier)
        }
        
        print("🔄 繰り返し通知をスケジュールしました: \(stationName)駅 (\(pattern.displayName))")
    }
    
    /// Cancel all repeating notifications for a specific alert
    func cancelRepeatingNotifications(alertId: String) {
        // 全ての曜日の通知識別子を作成
        var identifiers: [String] = []
        for day in 1...7 {
            identifiers.append("repeat_\(alertId)_day\(day)")
        }
        
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        identifiers.forEach { pendingNotifications.remove($0) }
        
        print("🚫 繰り返し通知をキャンセルしました: \(alertId)")
    }
    
    // MARK: - Notification Content Creation
    
    private func createTrainAlertContent(
        stationName: String,
        arrivalTime: Date,
        currentLocation: CLLocation?,
        targetLocation: CLLocation,
        characterStyle: CharacterStyle,
        alertId: String? = nil
    ) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = getNotificationSound()
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        
        let timeString = formatter.string(from: arrivalTime)
        let minutesUntilArrival = Int(arrivalTime.timeIntervalSinceNow / 60)
        let arrivalTimeString = minutesUntilArrival > 0 ? "\(minutesUntilArrival)分後" : "まもなく"
        
        // Try to generate message using OpenAI API
        var generatedMessage: String?
        do {
            generatedMessage = try await OpenAIClient.shared.generateNotificationMessage(
                for: stationName,
                arrivalTime: arrivalTimeString,
                characterStyle: characterStyle
            )
        } catch {
            // ❌ OpenAI API error occurred
        }
        
        // Use generated message or fallback to preset
        if let message = generatedMessage {
            content.title = "🚃 \(stationName)駅だよ！"
            content.body = message
        } else {
            // Fallback to preset messages
            let messages = getCharacterMessages(for: characterStyle, stationName: stationName)
            content.title = messages.title
            content.body = messages.body
        }
        
        content.body += "\n到着予定時刻: \(timeString)"
        
        // Add distance info if available
        if let currentLocation = currentLocation {
            let distance = currentLocation.distance(from: targetLocation)
            let distanceText = distance > 1_000 ? 
                String(format: "%.1fkm", distance / 1_000) : 
                String(format: "%.0fm", distance)
            content.body += "\n距離: \(distanceText)"
        }
        
        var userInfo: [String: Any] = [
            "stationName": stationName,
            "arrivalTime": arrivalTime.timeIntervalSince1970,
            "notificationType": "trainAlert"
        ]
        
        if let alertId = alertId {
            userInfo["alertId"] = alertId
        }
        
        content.userInfo = userInfo
        
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    private func createLocationAlertContent(stationName: String, characterStyle: CharacterStyle, alertId: String? = nil) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = getNotificationSound()
        
        // Try to generate message using OpenAI API
        var generatedMessage: String?
        do {
            generatedMessage = try await OpenAIClient.shared.generateNotificationMessage(
                for: stationName,
                arrivalTime: "まもなく",
                characterStyle: characterStyle
            )
        } catch {
            // ❌ OpenAI API error occurred
        }
        
        if let message = generatedMessage {
            content.title = "📍 \(stationName)駅に到着！"
            content.body = message
        } else {
            let messages = getLocationBasedMessages(for: characterStyle, stationName: stationName)
            content.title = messages.title
            content.body = messages.body
        }
        
        var userInfo: [String: Any] = [
            "stationName": stationName,
            "notificationType": "locationAlert"
        ]
        
        if let alertId = alertId {
            userInfo["alertId"] = alertId
        }
        
        content.userInfo = userInfo
        
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    private func createSnoozeAlertContent(
        stationName: String,
        snoozeCount: Int,
        characterStyle: CharacterStyle
    ) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.snoozeAlert.identifier
        content.sound = getNotificationSound()
        
        // Try to generate message using OpenAI API for snooze
        var generatedMessage: String?
        do {
            // Add snooze context to prompt
            let snoozeContext = "（スヌーズ\(snoozeCount)回目）"
            generatedMessage = try await OpenAIClient.shared.generateNotificationMessage(
                for: "\(stationName)\(snoozeContext)",
                arrivalTime: "もうすぐ",
                characterStyle: characterStyle
            )
        } catch {
            // ❌ OpenAI API error occurred
        }
        
        if let message = generatedMessage {
            content.title = "😴 スヌーズ\(snoozeCount)回目"
            content.body = message
        } else {
            let messages = getSnoozeMessages(for: characterStyle, stationName: stationName, count: snoozeCount)
            content.title = messages.title
            content.body = messages.body
        }
        
        content.userInfo = [
            "stationName": stationName,
            "snoozeCount": snoozeCount,
            "notificationType": "snoozeAlert"
        ]
        
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    // MARK: - Sound Configuration
    
    private func getNotificationSound() -> UNNotificationSound {
        switch settings.soundName {
        case "default":
            return .defaultCritical
        case "chime":
            return UNNotificationSound(named: UNNotificationSoundName("chime.caf"))
        case "bell":
            return UNNotificationSound(named: UNNotificationSoundName("bell.caf"))
        case "gentle":
            return UNNotificationSound(named: UNNotificationSoundName("gentle.caf"))
        case "urgent":
            return UNNotificationSound(named: UNNotificationSoundName("urgent.caf"))
        default:
            return .defaultCritical
        }
    }
    
    // MARK: - Character Messages
    
    private func getCharacterMessages(for style: CharacterStyle, stationName: String) -> (title: String, body: String) {
        let messages = style.fallbackMessages
        return (
            title: messages.trainAlert.title,
            body: messages.trainAlert.body.replacingOccurrences(of: "{station}", with: stationName)
        )
    }
    
    private func getLocationBasedMessages(for style: CharacterStyle, stationName: String) -> (title: String, body: String) {
        let messages = style.fallbackMessages
        return (
            title: messages.locationAlert.title,
            body: messages.locationAlert.body.replacingOccurrences(of: "{station}", with: stationName)
        )
    }
    
    private func getSnoozeMessages(for style: CharacterStyle, stationName: String, count: Int) -> (title: String, body: String) {
        let messages = style.fallbackMessages
        return (
            title: messages.snoozeAlert.title,
            body: messages.snoozeAlert.body
                .replacingOccurrences(of: "{station}", with: stationName)
                .replacingOccurrences(of: "{count}", with: "\(count)")
        )
    }
    
    // MARK: - Notification Management
    
    /// Cancel specific notification
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        pendingNotifications.remove(identifier)
        snoozeCounters.removeValue(forKey: identifier)
    }
    
    /// Cancel all notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        pendingNotifications.removeAll()
        snoozeCounters.removeAll()
        
        // Reset badge count
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    /// Get pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
    
    // MARK: - Settings
    
    /// Update character style
    func updateCharacterStyle(_ style: CharacterStyle) {
        settings = NotificationSettings(
            defaultAdvanceTime: settings.defaultAdvanceTime,
            snoozeInterval: settings.snoozeInterval,
            maxSnoozeCount: settings.maxSnoozeCount,
            characterStyle: style
        )
    }
    
    /// Update advance time
    func updateAdvanceTime(_ time: TimeInterval) {
        settings = NotificationSettings(
            defaultAdvanceTime: time,
            snoozeInterval: settings.snoozeInterval,
            maxSnoozeCount: settings.maxSnoozeCount,
            characterStyle: settings.characterStyle
        )
    }
    
    /// Update snooze interval
    func updateSnoozeInterval(_ interval: TimeInterval) {
        settings = NotificationSettings(
            defaultAdvanceTime: settings.defaultAdvanceTime,
            snoozeInterval: interval,
            maxSnoozeCount: settings.maxSnoozeCount,
            characterStyle: settings.characterStyle
        )
    }
    
    // MARK: - Haptic Feedback
    
    /// Generate haptic feedback
    func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
        guard settings.vibrationEnabled else { return }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    /// Generate notification haptic pattern
    func generateNotificationHapticPattern() {
        guard settings.vibrationEnabled else { return }
        
        // Custom haptic pattern for train alerts
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - Private Setup
    
    private func setupNotificationCategories() {
        // Train Alert Category
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.identifier,
            title: "スヌーズ",
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.identifier,
            title: "OK",
            options: []
        )
        
        let trainAlertCategory = UNNotificationCategory(
            identifier: NotificationCategory.trainAlert.identifier,
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Snooze Alert Category
        let snoozeAlertCategory = UNNotificationCategory(
            identifier: NotificationCategory.snoozeAlert.identifier,
            actions: [snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        center.setNotificationCategories([trainAlertCategory, snoozeAlertCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 通知が表示される際に履歴を保存
        let userInfo = notification.request.content.userInfo
        let notificationType = userInfo["notificationType"] as? String ?? userInfo["type"] as? String ?? "unknown"
        let message = notification.request.content.body
        
        Task { @MainActor in
            // 履歴を保存（willPresentは常に表示時なのでisUserInteraction=false）
            historyManager.saveNotificationHistory(
                userInfo: userInfo,
                notificationType: notificationType,
                message: message,
                isUserInteraction: false
            )
            
            // ハプティックフィードバック
            generateNotificationHapticPattern()
        }
        
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier
        let notificationType = userInfo["notificationType"] as? String ?? userInfo["type"] as? String ?? "unknown"
        let message = response.notification.request.content.body
        
        // ユーザーが通知をタップまたはアクションを実行した際に履歴を保存
        // （willPresentで既に保存されている場合もあるが、バックグラウンドから
        // 直接タップされた場合のために、ここでも保存する）
        Task { @MainActor in
            // 履歴を保存（ユーザーインタラクションなのでisUserInteraction=true）
            historyManager.saveNotificationHistory(
                userInfo: userInfo,
                notificationType: notificationType,
                message: message,
                isUserInteraction: true
            )
        }
        
        switch response.actionIdentifier {
        case NotificationAction.snooze.identifier:
            Task { @MainActor in
                handleSnoozeAction(identifier: identifier, userInfo: userInfo)
            }
            
        case NotificationAction.dismiss.identifier, UNNotificationDefaultActionIdentifier:
            Task { @MainActor in
                handleDismissAction(identifier: identifier, userInfo: userInfo)
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleSnoozeAction(identifier: String, userInfo: [AnyHashable: Any]) {
        Task {
            if let stationName = userInfo["stationName"] as? String {
                try? await scheduleSnoozeNotification(for: identifier, stationName: stationName)
            }
        }
    }
    
    private func handleDismissAction(identifier: String, userInfo: [AnyHashable: Any]) {
        // Clean up snooze counters
        snoozeCounters.removeValue(forKey: identifier)
        
        // Reset badge if no more notifications
        Task {
            let pending = await getPendingNotifications()
            if pending.isEmpty {
                await MainActor.run {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }
        }
    }
}

