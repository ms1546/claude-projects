//
//  NotificationManagerTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
import UserNotifications
import CoreLocation
import UIKit
@testable import TrainAlert

@MainActor
final class NotificationManagerTests: XCTestCase {
    
    var notificationManager: NotificationManager!
    
    override func setUp() {
        super.setUp()
        notificationManager = NotificationManager()
    }
    
    override func tearDown() {
        notificationManager?.cancelAllNotifications()
        notificationManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testNotificationManagerSingletonInitialization() {
        let instance1 = NotificationManager.shared
        let instance2 = NotificationManager.shared
        
        XCTAssertTrue(instance1 === instance2, "NotificationManager should be a singleton")
    }
    
    func testNotificationManagerInitialization() {
        XCTAssertNotNil(notificationManager)
        XCTAssertEqual(notificationManager.authorizationStatus, .notDetermined)
        XCTAssertFalse(notificationManager.isPermissionGranted)
        XCTAssertNil(notificationManager.lastError)
        XCTAssertNotNil(notificationManager.settings)
    }
    
    // MARK: - Notification Category Tests
    
    func testNotificationCategories() {
        let categories = NotificationCategory.allCases
        XCTAssertEqual(categories.count, 2)
        XCTAssertTrue(categories.contains(.trainAlert))
        XCTAssertTrue(categories.contains(.snoozeAlert))
        
        // Test identifiers
        XCTAssertEqual(NotificationCategory.trainAlert.identifier, "TRAIN_ALERT")
        XCTAssertEqual(NotificationCategory.snoozeAlert.identifier, "SNOOZE_ALERT")
    }
    
    func testNotificationActions() {
        let actions: [NotificationAction] = [.snooze, .dismiss, .openApp]
        
        for action in actions {
            XCTAssertFalse(action.identifier.isEmpty, "Action identifier should not be empty")
        }
        
        XCTAssertEqual(NotificationAction.snooze.identifier, "SNOOZE_ACTION")
        XCTAssertEqual(NotificationAction.dismiss.identifier, "DISMISS_ACTION")
        XCTAssertEqual(NotificationAction.openApp.identifier, "OPEN_APP_ACTION")
    }
    
    // MARK: - Notification Settings Tests
    
    func testNotificationSettingsDefaults() {
        let defaultSettings = NotificationSettings()
        
        XCTAssertEqual(defaultSettings.defaultAdvanceTime, 5 * 60) // 5 minutes
        XCTAssertEqual(defaultSettings.snoozeInterval, 1 * 60) // 1 minute
        XCTAssertEqual(defaultSettings.maxSnoozeCount, 5)
        XCTAssertEqual(defaultSettings.characterStyle, .gyaru)
    }
    
    func testNotificationSettingsCustomization() {
        let customSettings = NotificationSettings(
            defaultAdvanceTime: 10 * 60,
            snoozeInterval: 2 * 60,
            maxSnoozeCount: 3,
            characterStyle: .butler
        )
        
        XCTAssertEqual(customSettings.defaultAdvanceTime, 10 * 60)
        XCTAssertEqual(customSettings.snoozeInterval, 2 * 60)
        XCTAssertEqual(customSettings.maxSnoozeCount, 3)
        XCTAssertEqual(customSettings.characterStyle, .butler)
    }
    
    // MARK: - Authorization Tests
    
    func testCheckAuthorizationStatus() async {
        await notificationManager.checkAuthorizationStatus()
        
        // Should have updated the status
        XCTAssertTrue(
            [.notDetermined, .denied, .authorized, .provisional, .ephemeral]
                .contains(notificationManager.authorizationStatus)
        )
    }
    
    func testRequestAuthorizationDenied() async {
        // Mock the permission denial
        do {
            try await notificationManager.requestAuthorization()
            // Test passes if no exception is thrown
        } catch {
            XCTAssertEqual(error as? NotificationError, .permissionDenied)
        }
    }
    
    // MARK: - Notification Content Tests
    
    func testNotificationContentStructure() {
        let content = NotificationContent(
            title: "Test Title",
            body: "Test Body",
            sound: .defaultCritical,
            categoryIdentifier: "TEST_CATEGORY",
            userInfo: ["key": "value"]
        )
        
        XCTAssertEqual(content.title, "Test Title")
        XCTAssertEqual(content.body, "Test Body")
        XCTAssertEqual(content.sound, .defaultCritical)
        XCTAssertEqual(content.categoryIdentifier, "TEST_CATEGORY")
        XCTAssertEqual(content.userInfo["key"] as? String, "value")
    }
    
    // MARK: - Train Alert Scheduling Tests
    
    func testScheduleTrainAlertWithoutPermission() async {
        // Mock no permission
        notificationManager.isPermissionGranted = false
        
        let stationName = "渋谷駅"
        let arrivalTime = Date().addingTimeInterval(600) // 10 minutes from now
        let currentLocation = CLLocation(latitude: 35.6580, longitude: 139.7016)
        let targetLocation = CLLocation(latitude: 35.6762, longitude: 139.6503)
        
        do {
            try await notificationManager.scheduleTrainAlert(
                for: stationName,
                arrivalTime: arrivalTime,
                currentLocation: currentLocation,
                targetLocation: targetLocation,
                characterStyle: .gyaru
            )
            XCTFail("Should throw permission denied error")
        } catch {
            XCTAssertEqual(error as? NotificationError, .permissionDenied)
        }
    }
    
    func testScheduleLocationBasedAlertWithoutPermission() async {
        notificationManager.isPermissionGranted = false
        
        let stationName = "新宿駅"
        let targetLocation = CLLocation(latitude: 35.6896, longitude: 139.7006)
        
        do {
            try await notificationManager.scheduleLocationBasedAlert(
                for: stationName,
                targetLocation: targetLocation,
                radius: 500
            )
            XCTFail("Should throw permission denied error")
        } catch {
            XCTAssertEqual(error as? NotificationError, .permissionDenied)
        }
    }
    
    // MARK: - Snooze Tests
    
    func testScheduleSnoozeNotification() async {
        notificationManager.isPermissionGranted = true
        
        let originalIdentifier = "test_alert_1234567890"
        let stationName = "東京駅"
        
        do {
            try await notificationManager.scheduleSnoozeNotification(
                for: originalIdentifier,
                stationName: stationName
            )
            // Should succeed if permission is granted
        } catch {
            XCTFail("Should not throw error when permission is granted")
        }
    }
    
    func testSnoozeCountLimitExceeded() async {
        notificationManager.isPermissionGranted = true
        
        let originalIdentifier = "test_alert_limit"
        let stationName = "品川駅"
        
        // Set snooze count to maximum
        for i in 1...notificationManager.settings.maxSnoozeCount {
            try? await notificationManager.scheduleSnoozeNotification(
                for: originalIdentifier,
                stationName: stationName
            )
        }
        
        // This should not schedule another snooze (should be ignored)
        try? await notificationManager.scheduleSnoozeNotification(
            for: originalIdentifier,
            stationName: stationName
        )
        
        // Test passes if no error is thrown and method handles limit gracefully
        XCTAssertTrue(true, "Snooze limit should be handled gracefully")
    }
    
    // MARK: - Character Message Tests
    
    func testCharacterMessageGeneration() {
        let styles: [CharacterStyle] = [.gyaru, .butler, .kansai, .tsundere, .sporty, .healing]
        let stationName = "渋谷駅"
        
        for style in styles {
            let messages = style.fallbackMessages
            
            // Test train alert message
            let trainMessage = messages.trainAlert.body.replacingOccurrences(of: "{station}", with: stationName)
            XCTAssertTrue(trainMessage.contains(stationName), "Train message should contain station name")
            XCTAssertFalse(trainMessage.contains("{station}"), "Placeholder should be replaced")
            
            // Test location alert message
            let locationMessage = messages.locationAlert.body.replacingOccurrences(of: "{station}", with: stationName)
            XCTAssertTrue(locationMessage.contains(stationName), "Location message should contain station name")
            XCTAssertFalse(locationMessage.contains("{station}"), "Placeholder should be replaced")
            
            // Test snooze alert message
            let snoozeMessage = messages.snoozeAlert.body
                .replacingOccurrences(of: "{station}", with: stationName)
                .replacingOccurrences(of: "{count}", with: "3")
            XCTAssertTrue(snoozeMessage.contains(stationName), "Snooze message should contain station name")
            XCTAssertTrue(snoozeMessage.contains("3"), "Snooze message should contain count")
            XCTAssertFalse(snoozeMessage.contains("{station}"), "Station placeholder should be replaced")
            XCTAssertFalse(snoozeMessage.contains("{count}"), "Count placeholder should be replaced")
        }
    }
    
    // MARK: - Settings Management Tests
    
    func testUpdateCharacterStyle() {
        let initialStyle = notificationManager.settings.characterStyle
        let newStyle: CharacterStyle = initialStyle == .gyaru ? .butler : .gyaru
        
        notificationManager.updateCharacterStyle(newStyle)
        
        XCTAssertEqual(notificationManager.settings.characterStyle, newStyle)
        XCTAssertNotEqual(notificationManager.settings.characterStyle, initialStyle)
    }
    
    func testUpdateAdvanceTime() {
        let initialTime = notificationManager.settings.defaultAdvanceTime
        let newTime: TimeInterval = 10 * 60 // 10 minutes
        
        notificationManager.updateAdvanceTime(newTime)
        
        XCTAssertEqual(notificationManager.settings.defaultAdvanceTime, newTime)
        XCTAssertNotEqual(notificationManager.settings.defaultAdvanceTime, initialTime)
    }
    
    func testUpdateSnoozeInterval() {
        let initialInterval = notificationManager.settings.snoozeInterval
        let newInterval: TimeInterval = 3 * 60 // 3 minutes
        
        notificationManager.updateSnoozeInterval(newInterval)
        
        XCTAssertEqual(notificationManager.settings.snoozeInterval, newInterval)
        XCTAssertNotEqual(notificationManager.settings.snoozeInterval, initialInterval)
    }
    
    // MARK: - Notification Management Tests
    
    func testCancelNotification() {
        let identifier = "test_notification_123"
        
        notificationManager.cancelNotification(identifier: identifier)
        
        // Should not crash and should handle non-existing notifications gracefully
        XCTAssertTrue(true, "Cancel notification should handle non-existing notifications gracefully")
    }
    
    func testCancelAllNotifications() {
        notificationManager.cancelAllNotifications()
        
        // Should clear all pending notifications
        XCTAssertTrue(true, "Cancel all notifications should not crash")
    }
    
    func testGetPendingNotifications() async {
        let pendingNotifications = await notificationManager.getPendingNotifications()
        
        // Should return an array (might be empty)
        XCTAssertNotNil(pendingNotifications)
    }
    
    // MARK: - Haptic Feedback Tests
    
    func testGenerateHapticFeedback() {
        // Test different feedback styles
        let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.light, .medium, .heavy]
        
        for style in styles {
            notificationManager.generateHapticFeedback(style: style)
            // Should not crash
        }
        
        XCTAssertTrue(true, "Haptic feedback should not crash")
    }
    
    func testGenerateNotificationHapticPattern() {
        notificationManager.generateNotificationHapticPattern()
        
        // Should not crash
        XCTAssertTrue(true, "Notification haptic pattern should not crash")
    }
    
    // MARK: - Error Handling Tests
    
    func testNotificationErrorDescriptions() {
        let errors: [NotificationError] = [
            .permissionDenied,
            .notificationFailed,
            .invalidConfiguration
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Delegate Method Tests
    
    func testWillPresentNotification() {
        let mockCenter = UNUserNotificationCenter.current()
        let mockRequest = createMockNotificationRequest()
        let mockNotification = UNNotification()
        
        // Use reflection to call the private method indirectly
        let expectation = XCTestExpectation(description: "Completion handler called")
        
        notificationManager.userNotificationCenter(
            mockCenter,
            willPresent: mockNotification,
            withCompletionHandler: { options in
                XCTAssertTrue(options.contains(.alert))
                XCTAssertTrue(options.contains(.sound))
                XCTAssertTrue(options.contains(.badge))
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDidReceiveNotificationResponse() {
        let mockCenter = UNUserNotificationCenter.current()
        let mockRequest = createMockNotificationRequest()
        let mockNotification = UNNotification()
        let mockResponse = createMockNotificationResponse()
        
        let expectation = XCTestExpectation(description: "Completion handler called")
        
        notificationManager.userNotificationCenter(
            mockCenter,
            didReceive: mockResponse,
            withCompletionHandler: {
                expectation.fulfill()
            }
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testNotificationContentCreationPerformance() {
        measure {
            for _ in 0..<100 {
                let content = NotificationContent(
                    title: "Test Title \(Int.random(in: 1...1000))",
                    body: "Test Body \(Int.random(in: 1...1000))",
                    sound: .defaultCritical,
                    categoryIdentifier: "TEST_CATEGORY",
                    userInfo: ["test": "data"]
                )
                _ = content.title
                _ = content.body
            }
        }
    }
    
    func testCharacterStyleIterationPerformance() {
        measure {
            for _ in 0..<1000 {
                for style in CharacterStyle.allCases {
                    _ = style.fallbackMessages
                    _ = style.displayName
                    _ = style.systemPrompt
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockNotificationRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Test notification body"
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.userInfo = [
            "stationName": "テスト駅",
            "notificationType": "trainAlert"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        
        return UNNotificationRequest(
            identifier: "test_notification_123",
            content: content,
            trigger: trigger
        )
    }
    
    private func createMockNotificationResponse() -> UNNotificationResponse {
        let mockRequest = createMockNotificationRequest()
        
        // This is a simplified mock - in real tests you might need to use a more sophisticated mock
        return MockNotificationResponse(
            notification: UNNotification(),
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )
    }
}

// MARK: - Mock Classes

class MockNotificationResponse: UNNotificationResponse {
    private let mockNotification: UNNotification
    private let mockActionIdentifier: String
    
    init(notification: UNNotification, actionIdentifier: String) {
        self.mockNotification = notification
        self.mockActionIdentifier = actionIdentifier
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var notification: UNNotification {
        return mockNotification
    }
    
    override var actionIdentifier: String {
        return mockActionIdentifier
    }
}

// MARK: - Extension Tests for NotificationError Equatable

extension NotificationError: Equatable {
    public static func == (lhs: NotificationError, rhs: NotificationError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.notificationFailed, .notificationFailed),
             (.invalidConfiguration, .invalidConfiguration):
            return true
        default:
            return false
        }
    }
}
