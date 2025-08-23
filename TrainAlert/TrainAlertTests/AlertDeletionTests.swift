//
//  AlertDeletionTests.swift
//  TrainAlertTests
//
//  Created by Claude Code on 2025/08/24.
//

import CoreData
@testable import TrainAlert
import XCTest

final class AlertDeletionTests: XCTestCase {
    var coreDataManager: CoreDataManager!
    var context: NSManagedObjectContext!
    var notificationManager: NotificationManager!
    var deletionManager: AlertDeletionManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // In-memory Core Data stack for testing
        coreDataManager = CoreDataManager(inMemory: true)
        context = coreDataManager.viewContext
        notificationManager = NotificationManager.shared
        deletionManager = AlertDeletionManager.shared
        
        // Clear all existing notifications
        notificationManager.cancelAllNotifications()
    }
    
    override func tearDown() async throws {
        // Clean up
        notificationManager.cancelAllNotifications()
        coreDataManager = nil
        context = nil
        
        try await super.tearDown()
    }
    
    /// テスト: 基本的なアラート削除と通知キャンセル
    func testBasicAlertDeletion() async throws {
        // Given: アラートを作成
        let alert = Alert(context: context)
        alert.alertId = UUID()
        alert.station = createTestStation()
        alert.arrivalTime = Date().addingTimeInterval(3_600) // 1時間後
        alert.isActive = true
        alert.notificationTime = 5
        alert.createdAt = Date()
        alert.updatedAt = Date()
        
        try context.save()
        
        // 通知をスケジュール
        let notificationId = alert.notificationIdentifier()
        await notificationManager.scheduleTestNotification(
            identifier: notificationId,
            title: "Test Alert",
            body: "Test notification",
            date: Date().addingTimeInterval(3_600)
        )
        
        // 通知が登録されていることを確認
        let pendingBefore = await notificationManager.center.pendingNotificationRequests()
        XCTAssertTrue(pendingBefore.contains { $0.identifier == notificationId })
        
        // When: アラートを削除
        try await deletionManager.deleteAlert(alert)
        
        // Then: 通知がキャンセルされていることを確認
        let pendingAfter = await notificationManager.center.pendingNotificationRequests()
        XCTAssertFalse(pendingAfter.contains { $0.identifier == notificationId })
        
        // Core Dataからも削除されていることを確認
        let fetchRequest = Alert.fetchRequest()
        let remainingAlerts = try context.fetch(fetchRequest)
        XCTAssertEqual(remainingAlerts.count, 0)
    }
    
    /// テスト: 繰り返し通知の削除
    func testRepeatingNotificationDeletion() async throws {
        // Given: 繰り返し設定のあるアラートを作成
        let alert = Alert(context: context)
        alert.alertId = UUID()
        alert.station = createTestStation()
        alert.arrivalTime = Date().addingTimeInterval(3_600)
        alert.isActive = true
        alert.notificationTime = 5
        alert.repeatPattern = .daily
        alert.createdAt = Date()
        alert.updatedAt = Date()
        
        try context.save()
        
        // 複数の繰り返し通知をスケジュール
        let alertIdString = alert.alertId!.uuidString
        for day in 1...7 {
            let identifier = "repeat_\(alertIdString)_day\(day)"
            await notificationManager.scheduleTestNotification(
                identifier: identifier,
                title: "Repeating Alert",
                body: "Daily notification",
                date: Date().addingTimeInterval(Double(86_400 * day))
            )
        }
        
        // When: アラートを削除
        try await deletionManager.deleteAlert(alert)
        
        // Then: すべての繰り返し通知がキャンセルされていることを確認
        let pendingAfter = await notificationManager.center.pendingNotificationRequests()
        let remainingRepeats = pendingAfter.filter { $0.identifier.contains(alertIdString) }
        XCTAssertEqual(remainingRepeats.count, 0)
    }
    
    /// テスト: 位置情報ベース通知の削除
    func testLocationBasedNotificationDeletion() async throws {
        // Given: 位置情報ベースのアラートを作成
        let alert = Alert(context: context)
        alert.alertId = UUID()
        alert.station = createTestStation()
        alert.isActive = true
        alert.notificationType = "location"
        alert.notificationDistance = 1_000
        alert.createdAt = Date()
        alert.updatedAt = Date()
        
        try context.save()
        
        // 位置情報ベースの通知をシミュレート
        let locationId = "location_\(alert.alertId!.uuidString)"
        await notificationManager.scheduleTestNotification(
            identifier: locationId,
            title: "Location Alert",
            body: "Near target station",
            date: Date().addingTimeInterval(3_600)
        )
        
        // When: アラートを削除
        try await deletionManager.deleteAlert(alert)
        
        // Then: 位置情報通知がキャンセルされていることを確認
        let pendingAfter = await notificationManager.center.pendingNotificationRequests()
        XCTAssertFalse(pendingAfter.contains { $0.identifier == locationId })
    }
    
    /// テスト: AlertMonitoringServiceからの削除
    func testRemovalFromMonitoringService() async throws {
        // Given: アラートを作成して監視サービスに追加
        let alert = Alert(context: context)
        alert.alertId = UUID()
        alert.station = createTestStation()
        alert.isActive = true
        alert.createdAt = Date()
        alert.updatedAt = Date()
        
        try context.save()
        
        // 監視サービスをリロードして、アラートが含まれることを確認
        AlertMonitoringService.shared.reloadAlerts()
        await Task.yield() // Allow time for reload
        
        let activeAlertsBefore = AlertMonitoringService.shared.activeAlerts
        XCTAssertTrue(activeAlertsBefore.contains { $0.alertId == alert.alertId })
        
        // When: アラートを削除
        try await deletionManager.deleteAlert(alert)
        
        // Then: 監視サービスから削除されていることを確認
        let activeAlertsAfter = AlertMonitoringService.shared.activeAlerts
        XCTAssertFalse(activeAlertsAfter.contains { $0.alertId == alert.alertId })
    }
    
    // MARK: - Helper Methods
    
    private func createTestStation() -> Station {
        let station = Station(context: context)
        station.stationId = "test_station_001"
        station.name = "テスト駅"
        station.latitude = 35.6812
        station.longitude = 139.7671
        station.lines = ["TestLine"]
        return station
    }
}

// MARK: - Test Extensions

extension NotificationManager {
    /// テスト用の通知をスケジュール
    func scheduleTestNotification(identifier: String, title: String, body: String, date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: date.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        try? await center.add(request)
    }
}
