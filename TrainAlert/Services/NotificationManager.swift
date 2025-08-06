//
//  NotificationManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import UserNotifications
import UIKit
import CoreLocation

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
        return self.rawValue
    }
}

enum NotificationAction: String {
    case snooze = "SNOOZE_ACTION"
    case dismiss = "DISMISS_ACTION"
    case openApp = "OPEN_APP_ACTION"
    
    var identifier: String {
        return self.rawValue
    }
}

enum CharacterStyle: String, CaseIterable {
    case friendly = "friendly"
    case energetic = "energetic"
    case gentle = "gentle"
    case formal = "formal"
    
    var displayName: String {
        switch self {
        case .friendly:
            return "フレンドリー"
        case .energetic:
            return "元気"
        case .gentle:
            return "優しい"
        case .formal:
            return "丁寧"
        }
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
    let defaultAdvanceTime: TimeInterval = 5 * 60 // 5 minutes
    let snoozeInterval: TimeInterval = 1 * 60 // 1 minute
    let maxSnoozeCount: Int = 5
    let characterStyle: CharacterStyle = .friendly
}

@MainActor
class NotificationManager: NSObject, ObservableObject {
    // MARK: - Properties
    
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isPermissionGranted: Bool = false
    @Published var lastError: NotificationError?
    @Published var settings = NotificationSettings()
    
    private let center = UNUserNotificationCenter.current()
    private var pendingNotifications: Set<String> = []
    private var snoozeCounters: [String: Int] = [:]
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
        checkAuthorizationStatus()
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
        let settings = await center.getNotificationSettings()
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
        characterStyle: CharacterStyle = .friendly
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
            characterStyle: characterStyle
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
        
        print("📱 Scheduled train alert for \(stationName) at \(notificationTime)")
    }
    
    /// Schedule a location-based notification
    func scheduleLocationBasedAlert(
        for stationName: String,
        targetLocation: CLLocation,
        radius: CLLocationDistance = 500
    ) async throws {
        
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        let identifier = "location_alert_\(stationName)"
        
        // Cancel existing location notification
        cancelNotification(identifier: identifier)
        
        let content = await createLocationAlertContent(stationName: stationName, characterStyle: settings.characterStyle)
        
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
        
        print("📍 Scheduled location-based alert for \(stationName)")
    }
    
    /// Schedule a snooze notification
    func scheduleSnoozeNotification(for originalIdentifier: String, stationName: String) async throws {
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        // Check snooze limit
        let currentCount = snoozeCounters[originalIdentifier, default: 0]
        guard currentCount < settings.maxSnoozeCount else {
            print("⏰ Maximum snooze count reached for \(originalIdentifier)")
            return
        }
        
        let snoozeIdentifier = "\(originalIdentifier)_snooze_\(currentCount + 1)"
        snoozeCounters[originalIdentifier] = currentCount + 1
        
        let content = await createSnoozeAlertContent(stationName: stationName, snoozeCount: currentCount + 1, characterStyle: settings.characterStyle)
        
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
        
        print("😴 Scheduled snooze notification #\(currentCount + 1) for \(stationName)")
    }
    
    // MARK: - Notification Content Creation
    
    private func createTrainAlertContent(
        stationName: String,
        arrivalTime: Date,
        currentLocation: CLLocation?,
        targetLocation: CLLocation,
        characterStyle: CharacterStyle
    ) async -> UNMutableNotificationContent {
        
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = .defaultCritical
        
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
            print("❌ OpenAI API error: \(error.localizedDescription)")
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
            let distanceText = distance > 1000 ? 
                String(format: "%.1fkm", distance / 1000) : 
                String(format: "%.0fm", distance)
            content.body += "\n距離: \(distanceText)"
        }
        
        content.userInfo = [
            "stationName": stationName,
            "arrivalTime": arrivalTime.timeIntervalSince1970,
            "notificationType": "trainAlert"
        ]
        
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    private func createLocationAlertContent(stationName: String, characterStyle: CharacterStyle) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = .defaultCritical
        
        // Try to generate message using OpenAI API
        var generatedMessage: String?
        do {
            generatedMessage = try await OpenAIClient.shared.generateNotificationMessage(
                for: stationName,
                arrivalTime: "まもなく",
                characterStyle: characterStyle
            )
        } catch {
            print("❌ OpenAI API error: \(error.localizedDescription)")
        }
        
        if let message = generatedMessage {
            content.title = "📍 \(stationName)駅に到着！"
            content.body = message
        } else {
            let messages = getLocationBasedMessages(for: characterStyle, stationName: stationName)
            content.title = messages.title
            content.body = messages.body
        }
        
        content.userInfo = [
            "stationName": stationName,
            "notificationType": "locationAlert"
        ]
        
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    private func createSnoozeAlertContent(stationName: String, snoozeCount: Int, characterStyle: CharacterStyle) async -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.snoozeAlert.identifier
        content.sound = .defaultCritical
        
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
            print("❌ OpenAI API error: \(error.localizedDescription)")
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
    
    // MARK: - Character Messages
    
    private func getCharacterMessages(for style: CharacterStyle, stationName: String) -> (title: String, body: String) {
        switch style {
        case .friendly:
            return (
                title: "🚃 もうすぐ到着だよ！",
                body: "\(stationName)駅に間もなく到着します。起きる時間だよ〜！"
            )
        case .energetic:
            return (
                title: "⚡ 起きて起きて！",
                body: "\(stationName)駅だよ！元気よく降りる準備をしよう！"
            )
        case .gentle:
            return (
                title: "🌸 そっとお知らせ",
                body: "\(stationName)駅にもうすぐ到着します。ゆっくり起きてくださいね。"
            )
        case .formal:
            return (
                title: "🔔 到着通知",
                body: "\(stationName)駅への到着をお知らせいたします。ご準備ください。"
            )
        }
    }
    
    private func getLocationBasedMessages(for style: CharacterStyle, stationName: String) -> (title: String, body: String) {
        switch style {
        case .friendly:
            return (
                title: "📍 近づいてきたよ！",
                body: "\(stationName)駅の近くまで来ました。降りる準備をしてね！"
            )
        case .energetic:
            return (
                title: "🎯 目標地点到達！",
                body: "\(stationName)駅エリアに入ったよ！降車準備開始！"
            )
        case .gentle:
            return (
                title: "🗺️ 目的地付近です",
                body: "\(stationName)駅の近くまで来ました。そろそろ準備してください。"
            )
        case .formal:
            return (
                title: "📍 位置通知",
                body: "\(stationName)駅近辺に到着いたしました。降車のご準備をお願いします。"
            )
        }
    }
    
    private func getSnoozeMessages(for style: CharacterStyle, stationName: String, count: Int) -> (title: String, body: String) {
        switch style {
        case .friendly:
            return (
                title: "😴 スヌーズ \(count)回目",
                body: "まだ寝てる？\(stationName)駅だよ〜。今度こそ起きて！"
            )
        case .energetic:
            return (
                title: "⏰ 再アラーム！",
                body: "\(stationName)駅！\(count)回目のアラームだよ！今度こそ起きよう！"
            )
        case .gentle:
            return (
                title: "🔔 再度のお知らせ",
                body: "\(stationName)駅です。もう一度お知らせします。起きてください。"
            )
        case .formal:
            return (
                title: "🚨 再通知",
                body: "\(stationName)駅到着の再通知です。速やかにご対応ください。"
            )
        }
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
        return await center.getPendingNotificationRequests()
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
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    /// Generate notification haptic pattern
    func generateNotificationHapticPattern() {
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
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        generateNotificationHapticPattern()
        completionHandler([.alert, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        
        let userInfo = response.notification.request.content.userInfo
        let identifier = response.notification.request.identifier
        
        switch response.actionIdentifier {
        case NotificationAction.snooze.identifier:
            handleSnoozeAction(identifier: identifier, userInfo: userInfo)
            
        case NotificationAction.dismiss.identifier, UNNotificationDefaultActionIdentifier:
            handleDismissAction(identifier: identifier, userInfo: userInfo)
            
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
