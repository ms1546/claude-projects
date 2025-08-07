//
//  SettingsViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import Foundation
import UserNotifications

@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Notification Settings
    
    @AppStorage("defaultNotificationTime") var defaultNotificationTime: Int = 5
    @AppStorage("defaultNotificationDistance") var defaultNotificationDistance: Int = 500
    @AppStorage("defaultSnoozeInterval") var defaultSnoozeInterval: Int = 2
    @AppStorage("selectedNotificationSound") var selectedNotificationSound: String = "default"
    @AppStorage("vibrationIntensity") var vibrationIntensity: Double = 0.8
    
    // MARK: - AI Settings
    
    @AppStorage("selectedCharacterStyle") var selectedCharacterStyle: String = CharacterStyle.healing.rawValue
    @AppStorage("useAIGeneratedMessages") var useAIGeneratedMessages: Bool = true
    @AppStorage("openAIAPIKey") var openAIAPIKey: String = ""
    
    // MARK: - App Settings
    
    @AppStorage("selectedLanguage") var selectedLanguage: String = "ja"
    @AppStorage("distanceUnit") var distanceUnit: String = "metric"
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = true
    
    // MARK: - Privacy Settings
    
    @AppStorage("dataCollectionEnabled") var dataCollectionEnabled: Bool = true
    @AppStorage("crashReportsEnabled") var crashReportsEnabled: Bool = true
    
    // MARK: - State Properties
    
    @Published var errorMessage: String?
    @Published var isAPIKeyValid: Bool = false
    @Published var isTestingAPIKey: Bool = false
    @Published var showingResetConfirmation: Bool = false
    @Published var showingExportShare: Bool = false
    @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    // MARK: - Computed Properties
    
    var selectedCharacterStyleEnum: CharacterStyle {
        CharacterStyle(rawValue: selectedCharacterStyle) ?? .healing
    }
    
    var availableNotificationTimes: [Int] {
        [1, 2, 3, 5, 10, 15, 20, 30]
    }
    
    var availableNotificationDistances: [Int] {
        [100, 200, 300, 500, 800, 1000, 1500, 2000]
    }
    
    var availableSnoozeIntervals: [Int] {
        [1, 2, 3, 5, 10, 15]
    }
    
    var availableNotificationSounds: [String] {
        ["default", "chime", "bell", "gentle", "urgent"]
    }
    
    var notificationTimeDisplayString: String {
        "\(defaultNotificationTime)分前"
    }
    
    var notificationDistanceDisplayString: String {
        if defaultNotificationDistance < 1000 {
            return "\(defaultNotificationDistance)m"
        } else {
            return String(format: "%.1fkm", Double(defaultNotificationDistance) / 1000)
        }
    }
    
    var snoozeIntervalDisplayString: String {
        "\(defaultSnoozeInterval)分間隔"
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "TrainAlert"
    }
    
    // MARK: - Initialization
    
    init() {
        checkAPIKeyValidity()
        checkNotificationPermissions()
    }
    
    // MARK: - API Key Management
    
    func validateAPIKey() async {
        guard !openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                isAPIKeyValid = false
                errorMessage = "APIキーを入力してください"
            }
            return
        }
        
        await MainActor.run {
            isTestingAPIKey = true
            errorMessage = nil
        }
        
        // Simple validation - check if it starts with "sk-" and has reasonable length
        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValidFormat = trimmedKey.hasPrefix("sk-") && trimmedKey.count > 20
        
        await MainActor.run {
            isTestingAPIKey = false
            isAPIKeyValid = isValidFormat
            
            if !isValidFormat {
                errorMessage = "無効なAPIキー形式です"
            }
        }
    }
    
    private func checkAPIKeyValidity() {
        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isAPIKeyValid = trimmedKey.hasPrefix("sk-") && trimmedKey.count > 20
    }
    
    func clearAPIKey() {
        openAIAPIKey = ""
        isAPIKeyValid = false
    }
    
    // MARK: - Notification Permissions
    
    func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    func requestNotificationPermissions() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert]
            )
            
            await MainActor.run {
                notificationPermissionStatus = granted ? .authorized : .denied
            }
        } catch {
            await MainActor.run {
                errorMessage = "通知許可の取得に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Settings Management
    
    func resetAllSettings() {
        // Reset notification settings
        defaultNotificationTime = 5
        defaultNotificationDistance = 500
        defaultSnoozeInterval = 2
        selectedNotificationSound = "default"
        vibrationIntensity = 0.8
        
        // Reset AI settings
        selectedCharacterStyle = CharacterStyle.healing.rawValue
        useAIGeneratedMessages = true
        
        // Reset app settings
        selectedLanguage = "ja"
        distanceUnit = "metric"
        use24HourFormat = true
        
        // Reset privacy settings
        dataCollectionEnabled = true
        crashReportsEnabled = true
        
        // Don't reset API key as it's sensitive data
        errorMessage = nil
    }
    
    func exportSettings() -> [String: Any] {
        return [
            "defaultNotificationTime": defaultNotificationTime,
            "defaultNotificationDistance": defaultNotificationDistance,
            "defaultSnoozeInterval": defaultSnoozeInterval,
            "selectedNotificationSound": selectedNotificationSound,
            "vibrationIntensity": vibrationIntensity,
            "selectedCharacterStyle": selectedCharacterStyle,
            "useAIGeneratedMessages": useAIGeneratedMessages,
            "selectedLanguage": selectedLanguage,
            "distanceUnit": distanceUnit,
            "use24HourFormat": use24HourFormat,
            "dataCollectionEnabled": dataCollectionEnabled,
            "crashReportsEnabled": crashReportsEnabled,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": appVersion
        ]
    }
    
    func importSettings(from data: [String: Any]) -> Bool {
        guard let exportDate = data["exportDate"] as? String,
              let _ = ISO8601DateFormatter().date(from: exportDate) else {
            errorMessage = "無効な設定ファイルです"
            return false
        }
        
        // Import settings with validation
        if let time = data["defaultNotificationTime"] as? Int,
           availableNotificationTimes.contains(time) {
            defaultNotificationTime = time
        }
        
        if let distance = data["defaultNotificationDistance"] as? Int,
           availableNotificationDistances.contains(distance) {
            defaultNotificationDistance = distance
        }
        
        if let interval = data["defaultSnoozeInterval"] as? Int,
           availableSnoozeIntervals.contains(interval) {
            defaultSnoozeInterval = interval
        }
        
        if let sound = data["selectedNotificationSound"] as? String,
           availableNotificationSounds.contains(sound) {
            selectedNotificationSound = sound
        }
        
        if let intensity = data["vibrationIntensity"] as? Double,
           (0.0...1.0).contains(intensity) {
            vibrationIntensity = intensity
        }
        
        if let character = data["selectedCharacterStyle"] as? String,
           CharacterStyle(rawValue: character) != nil {
            selectedCharacterStyle = character
        }
        
        if let useAI = data["useAIGeneratedMessages"] as? Bool {
            useAIGeneratedMessages = useAI
        }
        
        if let language = data["selectedLanguage"] as? String {
            selectedLanguage = language
        }
        
        if let unit = data["distanceUnit"] as? String {
            distanceUnit = unit
        }
        
        if let format = data["use24HourFormat"] as? Bool {
            use24HourFormat = format
        }
        
        if let dataCollection = data["dataCollectionEnabled"] as? Bool {
            dataCollectionEnabled = dataCollection
        }
        
        if let crashReports = data["crashReportsEnabled"] as? Bool {
            crashReportsEnabled = crashReports
        }
        
        return true
    }
    
    // MARK: - Helper Methods
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func getNotificationSoundDisplayName(_ sound: String) -> String {
        switch sound {
        case "default":
            return "デフォルト"
        case "chime":
            return "チャイム"
        case "bell":
            return "ベル"
        case "gentle":
            return "やさしい"
        case "urgent":
            return "緊急"
        default:
            return sound.capitalized
        }
    }
    
    func getDistanceUnitDisplayName(_ unit: String) -> String {
        switch unit {
        case "metric":
            return "メートル法 (km/m)"
        case "imperial":
            return "ヤード・ポンド法 (mi/ft)"
        default:
            return unit.capitalized
        }
    }
    
    func getLanguageDisplayName(_ language: String) -> String {
        switch language {
        case "ja":
            return "日本語"
        case "en":
            return "English"
        default:
            return language
        }
    }
}
