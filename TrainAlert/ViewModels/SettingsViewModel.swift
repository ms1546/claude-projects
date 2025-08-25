//
//  SettingsViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreLocation
import Foundation
import SwiftUI
import UserNotifications

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    
    // MARK: - Location Settings
    
    @AppStorage("locationAccuracy") var locationAccuracy: String = "balanced"
    @AppStorage("backgroundUpdateInterval") var backgroundUpdateInterval: Int = 5
    @AppStorage("backgroundUpdateEnabled") var backgroundUpdateEnabled: Bool = true
    
    // MARK: - Notification Settings
    
    @AppStorage("defaultNotificationTime") var defaultNotificationTime: Int = 5
    @AppStorage("defaultNotificationDistance") var defaultNotificationDistance: Int = 500
    @AppStorage("defaultSnoozeInterval") var defaultSnoozeInterval: Int = 2
    @AppStorage("selectedNotificationSound") var selectedNotificationSound: String = "default"
    @AppStorage("vibrationIntensity") var vibrationIntensity: Double = 0.8
    @AppStorage("vibrationEnabled") var vibrationEnabled: Bool = true
    @AppStorage("notificationPreviewEnabled") var notificationPreviewEnabled: Bool = true
    
    // MARK: - AI Settings
    
    @AppStorage("selectedCharacterStyle") var selectedCharacterStyle: String = CharacterStyle.gyaru.rawValue
    @AppStorage("useAIGeneratedMessages") var useAIGeneratedMessages: Bool = true
    // API Key is now stored in Keychain, not in UserDefaults
    @Published var openAIAPIKey: String = ""
    
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
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Computed Properties
    
    var selectedCharacterStyleEnum: CharacterStyle {
        CharacterStyle(rawValue: selectedCharacterStyle) ?? .healing
    }
    
    var availableNotificationTimes: [Int] {
        [1, 2, 3, 5, 10, 15, 20, 30]
    }
    
    var availableNotificationDistances: [Int] {
        [100, 200, 300, 500, 800, 1_000, 1_500, 2_000]
    }
    
    var availableSnoozeIntervals: [Int] {
        [1, 2, 3, 5, 10, 15]
    }
    
    var availableNotificationSounds: [String] {
        ["default", "chime", "bell", "gentle", "urgent"]
    }
    
    var availableBackgroundUpdateIntervals: [Int] {
        [1, 3, 5, 10]
    }
    
    var locationAccuracyOptions: [(String, String)] {
        [("high", "高精度"), ("balanced", "バランス"), ("battery", "省電力")]
    }
    
    var locationAccuracyDisplayName: String {
        locationAccuracyOptions.first { $0.0 == locationAccuracy }?.1 ?? "バランス"
    }
    
    var backgroundUpdateIntervalDisplayString: String {
        "\(backgroundUpdateInterval)分間隔"
    }
    
    var notificationTimeDisplayString: String {
        "\(defaultNotificationTime)分前"
    }
    
    var notificationDistanceDisplayString: String {
        if defaultNotificationDistance < 1_000 {
            return "\(defaultNotificationDistance)m"
        } else {
            return String(format: "%.1fkm", Double(defaultNotificationDistance) / 1_000)
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
        // Load API key from Keychain
        loadAPIKeyFromKeychain()
        checkAPIKeyValidity()
        checkNotificationPermissions()
        checkLocationPermissions()
    }
    
    // MARK: - API Key Management
    
    private func loadAPIKeyFromKeychain() {
        do {
            if let apiKey = try KeychainManager.shared.getOpenAIAPIKey() {
                openAIAPIKey = apiKey
            }
        } catch {
            // Ignore error, API key will remain empty
        }
    }
    
    func saveAPIKeyToKeychain() {
        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedKey.isEmpty {
            try? KeychainManager.shared.deleteOpenAIAPIKey()
        } else {
            do {
                try KeychainManager.shared.saveOpenAIAPIKey(trimmedKey)
            } catch {
                errorMessage = "APIキーの保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
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
        
        // Simple validation - check for reasonable length
        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let isValidFormat = trimmedKey.count > 20
        
        await MainActor.run {
            isTestingAPIKey = false
            isAPIKeyValid = isValidFormat
            
            if !isValidFormat {
                errorMessage = "無効なAPIキー形式です"
            } else {
                // Save to Keychain if valid
                saveAPIKeyToKeychain()
            }
        }
    }
    
    private func checkAPIKeyValidity() {
        let trimmedKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isAPIKeyValid = trimmedKey.count > 20
    }
    
    func clearAPIKey() {
        openAIAPIKey = ""
        isAPIKeyValid = false
        // Delete from Keychain
        try? KeychainManager.shared.deleteOpenAIAPIKey()
    }
    
    // MARK: - Location Permissions
    
    func checkLocationPermissions() {
        locationPermissionStatus = CLLocationManager.authorizationStatus()
    }
    
    func requestLocationPermissions() {
        locationManager.requestWhenInUseAuthorization()
        
        // Update status after request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkLocationPermissions()
        }
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
        // Reset location settings
        locationAccuracy = "balanced"
        backgroundUpdateInterval = 5
        backgroundUpdateEnabled = true
        
        // Reset notification settings
        defaultNotificationTime = 5
        defaultNotificationDistance = 500
        defaultSnoozeInterval = 2
        selectedNotificationSound = "default"
        vibrationIntensity = 0.8
        vibrationEnabled = true
        notificationPreviewEnabled = true
        
        // Reset AI settings
        selectedCharacterStyle = CharacterStyle.gyaru.rawValue
        useAIGeneratedMessages = true
        clearAPIKey()
        
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
        [
            "locationAccuracy": locationAccuracy,
            "backgroundUpdateInterval": backgroundUpdateInterval,
            "backgroundUpdateEnabled": backgroundUpdateEnabled,
            "defaultNotificationTime": defaultNotificationTime,
            "defaultNotificationDistance": defaultNotificationDistance,
            "defaultSnoozeInterval": defaultSnoozeInterval,
            "selectedNotificationSound": selectedNotificationSound,
            "vibrationIntensity": vibrationIntensity,
            "vibrationEnabled": vibrationEnabled,
            "notificationPreviewEnabled": notificationPreviewEnabled,
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
        if let accuracy = data["locationAccuracy"] as? String,
           locationAccuracyOptions.contains(where: { $0.0 == accuracy }) {
            locationAccuracy = accuracy
        }
        
        if let interval = data["backgroundUpdateInterval"] as? Int,
           availableBackgroundUpdateIntervals.contains(interval) {
            backgroundUpdateInterval = interval
        }
        
        if let enabled = data["backgroundUpdateEnabled"] as? Bool {
            backgroundUpdateEnabled = enabled
        }
        
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
        
        if let enabled = data["vibrationEnabled"] as? Bool {
            vibrationEnabled = enabled
        }
        
        if let preview = data["notificationPreviewEnabled"] as? Bool {
            notificationPreviewEnabled = preview
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
