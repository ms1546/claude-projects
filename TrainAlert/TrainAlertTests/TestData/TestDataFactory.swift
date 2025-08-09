//
//  TestDataFactory.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation
@testable import TrainAlert

/// Factory class for creating test data objects
class TestDataFactory {
    
    // MARK: - Station Test Data
    
    static func createTestStations() -> [Station] {
        return [
            Station(
                id: "test_tokyo_station",
                name: "東京",
                latitude: 35.6812,
                longitude: 139.7673,
                lines: ["JR山手線", "JR東海道本線", "JR中央線"]
            ),
            Station(
                id: "test_shibuya_station",
                name: "渋谷",
                latitude: 35.6580,
                longitude: 139.7016,
                lines: ["JR山手線", "東急東横線", "京王井の頭線"]
            ),
            Station(
                id: "test_shinjuku_station",
                name: "新宿",
                latitude: 35.6896,
                longitude: 139.7006,
                lines: ["JR山手線", "JR中央線", "小田急小田原線"]
            ),
            Station(
                id: "test_shinagawa_station",
                name: "品川",
                latitude: 35.6762,
                longitude: 139.6503,
                lines: ["JR山手線", "JR東海道本線", "京急本線"]
            ),
            Station(
                id: "test_ikebukuro_station",
                name: "池袋",
                latitude: 35.7090,
                longitude: 139.7319,
                lines: ["JR山手線", "JR埼京線", "西武池袋線"]
            ),
            Station(
                id: "test_harajuku_station",
                name: "原宿",
                latitude: 35.6702,
                longitude: 139.7027,
                lines: ["JR山手線"]
            ),
            Station(
                id: "test_akihabara_station",
                name: "秋葉原",
                latitude: 35.6984,
                longitude: 139.7731,
                lines: ["JR山手線", "JR京浜東北線", "つくばエクスプレス"]
            ),
            Station(
                id: "test_ueno_station",
                name: "上野",
                latitude: 35.7140,
                longitude: 139.7774,
                lines: ["JR山手線", "JR東北本線", "東京メトロ銀座線"]
            )
        ]
    }
    
    static func createTestStation(
        id: String = "test_station",
        name: String = "テスト駅",
        latitude: Double = 35.6812,
        longitude: Double = 139.7673,
        lines: [String] = ["テスト線"]
    ) -> Station {
        return Station(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            lines: lines
        )
    }
    
    // MARK: - Alert Setup Data
    
    static func createTestAlertSetupData() -> AlertSetupData {
        var setupData = AlertSetupData()
        setupData.selectedStation = createTestStation()
        setupData.notificationTime = 5
        setupData.notificationDistance = 500
        setupData.snoozeInterval = 3
        setupData.characterStyle = .gyaru
        return setupData
    }
    
    static func createInvalidAlertSetupData() -> AlertSetupData {
        var setupData = AlertSetupData()
        // Invalid data - no station selected
        setupData.notificationTime = -1 // Invalid time
        setupData.notificationDistance = -100 // Invalid distance
        setupData.snoozeInterval = 0 // Invalid snooze
        return setupData
    }
    
    // MARK: - Character Style Test Data
    
    static func getAllCharacterStyles() -> [CharacterStyle] {
        return CharacterStyle.allCases
    }
    
    static func createTestCharacterMessages() -> [(CharacterStyle, String)] {
        return [
            (.gyaru, "もうすぐ東京駅だよ〜！起きなきゃダメじゃん！"),
            (.butler, "東京駅にまもなく到着いたします。お支度はいかがでしょうか。"),
            (.kansai, "東京駅着くで〜！寝とったらあかんで〜"),
            (.tsundere, "べ、別にアンタのために起こしてあげるんじゃないからね！東京駅よ！"),
            (.sporty, "よし！東京駅到着だ！気合い入れて降りるぞ！"),
            (.healing, "東京駅ですね。ゆっくり起きて、お気をつけてお降りください。")
        ]
    }
    
    // MARK: - Location Test Data
    
    static func createTestLocations() -> [CLLocation] {
        let stations = createTestStations()
        return stations.map { station in
            CLLocation(latitude: station.latitude, longitude: station.longitude)
        }
    }
    
    static func createTestLocationCoordinates() -> [CLLocationCoordinate2D] {
        let stations = createTestStations()
        return stations.map { station in
            CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
        }
    }
    
    static func createTestRoute() -> [CLLocation] {
        // Route from Shibuya to Tokyo Station with intermediate points
        return [
            CLLocation(latitude: 35.6580, longitude: 139.7016), // Shibuya
            CLLocation(latitude: 35.6625, longitude: 139.7200), // Intermediate point 1
            CLLocation(latitude: 35.6695, longitude: 139.7380), // Intermediate point 2
            CLLocation(latitude: 35.6750, longitude: 139.7550), // Intermediate point 3
            CLLocation(latitude: 35.6812, longitude: 139.7673)  // Tokyo
        ]
    }
    
    // MARK: - API Response Test Data
    
    static func createMockStationAPIResponse() -> Data {
        let json = """
        {
            "response": {
                "station": [
                    {
                        "name": "東京",
                        "prefecture": "東京都",
                        "line": "JR山手線",
                        "x": "139.7673",
                        "y": "35.6812",
                        "distance": "0"
                    },
                    {
                        "name": "有楽町",
                        "prefecture": "東京都",
                        "line": "JR山手線",
                        "x": "139.7630",
                        "y": "35.6751",
                        "distance": "500"
                    },
                    {
                        "name": "新橋",
                        "prefecture": "東京都",
                        "line": "JR山手線",
                        "x": "139.7587",
                        "y": "35.6677",
                        "distance": "1200"
                    }
                ]
            }
        }
        """
        return json.data(using: .utf8)!
    }
    
    static func createMockLineAPIResponse() -> Data {
        let json = """
        {
            "response": {
                "line": [
                    {
                        "name": "JR山手線",
                        "company_name": "JR東日本"
                    },
                    {
                        "name": "JR京浜東北線",
                        "company_name": "JR東日本"
                    },
                    {
                        "name": "JR東海道本線",
                        "company_name": "JR東日本"
                    }
                ]
            }
        }
        """
        return json.data(using: .utf8)!
    }
    
    static func createEmptyStationAPIResponse() -> Data {
        let json = """
        {
            "response": {
                "station": null
            }
        }
        """
        return json.data(using: .utf8)!
    }
    
    // MARK: - OpenAI Response Test Data
    
    static func createMockOpenAIResponse() -> Data {
        let json = """
        {
            "id": "chatcmpl-test123",
            "object": "chat.completion",
            "created": 1677652288,
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "もうすぐ東京駅だよ〜！起きなきゃダメじゃん！"
                    },
                    "finish_reason": "stop"
                }
            ],
            "usage": {
                "prompt_tokens": 56,
                "completion_tokens": 31,
                "total_tokens": 87
            }
        }
        """
        return json.data(using: .utf8)!
    }
    
    static func createMockOpenAIErrorResponse(statusCode: Int = 401) -> Data {
        let json = """
        {
            "error": {
                "message": "Invalid API key provided",
                "type": "invalid_request_error",
                "code": "invalid_api_key"
            }
        }
        """
        return json.data(using: .utf8)!
    }
    
    // MARK: - Notification Test Data
    
    static func createTestNotificationContent() -> [NotificationContent] {
        return [
            NotificationContent(
                title: "🚃 東京駅到着",
                body: "もうすぐ東京駅だよ〜！起きなきゃダメじゃん！",
                sound: .defaultCritical,
                categoryIdentifier: "TRAIN_ALERT",
                userInfo: [
                    "stationName": "東京",
                    "characterStyle": "gyaru",
                    "notificationType": "trainAlert"
                ]
            ),
            NotificationContent(
                title: "📍 渋谷駅接近",
                body: "渋谷駅にまもなく到着いたします。お支度はいかがでしょうか。",
                sound: .defaultCritical,
                categoryIdentifier: "TRAIN_ALERT",
                userInfo: [
                    "stationName": "渋谷",
                    "characterStyle": "butler",
                    "notificationType": "locationAlert"
                ]
            ),
            NotificationContent(
                title: "😴 スヌーズ通知",
                body: "新宿駅やで〜！今度こそ起きいや〜（3回目）",
                sound: .defaultCritical,
                categoryIdentifier: "SNOOZE_ALERT",
                userInfo: [
                    "stationName": "新宿",
                    "characterStyle": "kansai",
                    "snoozeCount": 3,
                    "notificationType": "snoozeAlert"
                ]
            )
        ]
    }
    
    // MARK: - Core Data Test Data
    
    static func createMockHistory() -> [TestHistoryEntry] {
        let now = Date()
        return [
            TestHistoryEntry(
                id: UUID(),
                stationName: "東京",
                message: "もうすぐ東京駅だよ〜！起きなきゃダメじゃん！",
                characterStyle: "gyaru",
                notifiedAt: now.addingTimeInterval(-3600) // 1 hour ago
            ),
            TestHistoryEntry(
                id: UUID(),
                stationName: "渋谷",
                message: "渋谷駅にまもなく到着いたします。",
                characterStyle: "butler",
                notifiedAt: now.addingTimeInterval(-7200) // 2 hours ago
            ),
            TestHistoryEntry(
                id: UUID(),
                stationName: "新宿",
                message: "新宿駅着くで〜！",
                characterStyle: "kansai",
                notifiedAt: now.addingTimeInterval(-86400) // 1 day ago
            ),
            TestHistoryEntry(
                id: UUID(),
                stationName: "品川",
                message: "べ、別に心配してるんじゃないからね！品川駅よ！",
                characterStyle: "tsundere",
                notifiedAt: now.addingTimeInterval(-172800) // 2 days ago
            ),
            TestHistoryEntry(
                id: UUID(),
                stationName: "池袋",
                message: "よし！池袋駅到着だ！",
                characterStyle: "sporty",
                notifiedAt: now.addingTimeInterval(-259200) // 3 days ago
            )
        ]
    }
    
    // MARK: - Settings Test Data
    
    static func createTestSettingsData() -> [String: Any] {
        return [
            "defaultNotificationTime": 5,
            "defaultNotificationDistance": 500,
            "defaultSnoozeInterval": 3,
            "selectedNotificationSound": "chime",
            "vibrationIntensity": 0.8,
            "selectedCharacterStyle": "gyaru",
            "useAIGeneratedMessages": true,
            "openAIAPIKey": "test-api-key-for-testing-1234567890abcdef",
            "selectedLanguage": "ja",
            "distanceUnit": "metric",
            "use24HourFormat": true,
            "dataCollectionEnabled": true,
            "crashReportsEnabled": true,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": "1.0.0"
        ]
    }
    
    static func createInvalidSettingsData() -> [String: Any] {
        return [
            "defaultNotificationTime": "invalid",
            "defaultNotificationDistance": -100,
            "unknownSetting": "should_be_ignored",
            "exportDate": "invalid_date",
            "appVersion": 123 // Should be string
        ]
    }
    
    // MARK: - Performance Test Data
    
    static func createLargeDataset(count: Int = 1000) -> [Station] {
        return (0..<count).map { index in
            Station(
                id: "perf_test_station_\(index)",
                name: "パフォーマンステスト駅\(index)",
                latitude: 35.6000 + Double(index) * 0.001,
                longitude: 139.7000 + Double(index) * 0.001,
                lines: ["テスト線\(index % 10)"]
            )
        }
    }
    
    static func createComplexRoute(pointCount: Int = 100) -> [CLLocation] {
        let startLat = 35.6580 // Shibuya
        let startLon = 139.7016
        let endLat = 35.6812   // Tokyo
        let endLon = 139.7673
        
        return (0..<pointCount).map { index in
            let progress = Double(index) / Double(pointCount - 1)
            let lat = startLat + (endLat - startLat) * progress
            let lon = startLon + (endLon - startLon) * progress
            
            // Add some random variation to simulate realistic GPS data
            let latNoise = Double.random(in: -0.0001...0.0001)
            let lonNoise = Double.random(in: -0.0001...0.0001)
            
            return CLLocation(latitude: lat + latNoise, longitude: lon + lonNoise)
        }
    }
    
    // MARK: - Error Test Data
    
    static func createTestErrors() -> [Error] {
        return [
            StationAPIError.networkError(NSError(domain: "TestDomain", code: 1, userInfo: nil)),
            StationAPIError.invalidURL,
            StationAPIError.noData,
            StationAPIError.noStationsFound,
            StationAPIError.requestTimeout,
            StationAPIError.serverError(500),
            OpenAIError.missingAPIKey,
            OpenAIError.invalidAPIKey,
            OpenAIError.rateLimitExceeded,
            OpenAIError.networkUnavailable,
            NotificationError.permissionDenied,
            NotificationError.notificationFailed,
            NotificationError.invalidConfiguration,
            LocationError.authorizationDenied,
            LocationError.locationUnavailable,
            LocationError.backgroundUpdatesFailed
        ]
    }
    
    // MARK: - Accessibility Test Data
    
    static func createAccessibilityTestCases() -> [AccessibilityTestCase] {
        return [
            AccessibilityTestCase(
                elementType: "Button",
                label: "アラートを追加",
                hint: "新しいアラートを作成します",
                trait: "Button"
            ),
            AccessibilityTestCase(
                elementType: "SearchField",
                label: "駅名を入力",
                hint: "検索したい駅名を入力してください",
                trait: "SearchField"
            ),
            AccessibilityTestCase(
                elementType: "Slider",
                label: "通知タイミング",
                hint: "通知を受け取るタイミングを調整します",
                trait: "Adjustable"
            ),
            AccessibilityTestCase(
                elementType: "Switch",
                label: "AI生成メッセージを使用",
                hint: "AIによる個性的なメッセージを有効にします",
                trait: "Button"
            )
        ]
    }
}

// MARK: - Supporting Data Structures

struct TestHistoryEntry {
    let id: UUID
    let stationName: String
    let message: String
    let characterStyle: String
    let notifiedAt: Date
}

struct AccessibilityTestCase {
    let elementType: String
    let label: String
    let hint: String
    let trait: String
}

// MARK: - Test Data Validation

extension TestDataFactory {
    
    /// Validates that test stations have valid coordinates
    static func validateTestStations() -> Bool {
        let stations = createTestStations()
        
        for station in stations {
            // Check if coordinates are within Japan's approximate bounds
            let validLatRange = 24.0...46.0  // Japan's latitude range
            let validLonRange = 123.0...146.0 // Japan's longitude range
            
            guard validLatRange.contains(station.latitude) &&
                  validLonRange.contains(station.longitude) else {
                print("Invalid coordinates for station: \(station.name)")
                return false
            }
            
            guard !station.name.isEmpty && !station.lines.isEmpty else {
                print("Invalid station data for: \(station.id)")
                return false
            }
        }
        
        return true
    }
    
    /// Validates that test character messages are appropriate
    static func validateCharacterMessages() -> Bool {
        let messages = createTestCharacterMessages()
        
        for (style, message) in messages {
            guard !message.isEmpty else {
                print("Empty message for style: \(style)")
                return false
            }
            
            guard message.count >= 10 && message.count <= 100 else {
                print("Invalid message length for style: \(style)")
                return false
            }
            
            // Check for appropriate character-specific patterns
            switch style {
            case .gyaru:
                guard message.contains("だよ") || message.contains("じゃん") else {
                    print("Missing gyaru-style expressions in: \(message)")
                    return false
                }
            case .butler:
                guard message.contains("いたします") || message.contains("ございます") else {
                    print("Missing butler-style expressions in: \(message)")
                    return false
                }
            case .kansai:
                guard message.contains("やで") || message.contains("あかん") else {
                    print("Missing Kansai-style expressions in: \(message)")
                    return false
                }
            default:
                break // Other styles are less strict
            }
        }
        
        return true
    }
}
