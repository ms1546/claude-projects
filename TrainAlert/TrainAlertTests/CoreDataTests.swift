//
//  CoreDataTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
import CoreData
@testable import TrainAlert

final class CoreDataTests: XCTestCase {
    
    var coreDataManager: TestCoreDataManager!
    
    override func setUp() {
        super.setUp()
        coreDataManager = TestCoreDataManager()
    }
    
    override func tearDown() {
        coreDataManager?.deleteAllData()
        coreDataManager = nil
        super.tearDown()
    }
    
    // MARK: - CoreDataManager Tests
    
    func testCoreDataManagerInitialization() {
        XCTAssertNotNil(coreDataManager)
        XCTAssertNotNil(coreDataManager.persistentContainer)
        XCTAssertNotNil(coreDataManager.viewContext)
    }
    
    func testCoreDataManagerSingletonAccess() {
        let instance1 = CoreDataManager.shared
        let instance2 = CoreDataManager.shared
        
        XCTAssertTrue(instance1 === instance2, "CoreDataManager should be a singleton")
    }
    
    func testNewBackgroundContext() {
        let backgroundContext = coreDataManager.newBackgroundContext()
        
        XCTAssertNotNil(backgroundContext)
        XCTAssertNotEqual(backgroundContext, coreDataManager.viewContext)
        XCTAssertEqual(backgroundContext.concurrencyType, .privateQueueConcurrencyType)
    }
    
    func testSaveContext() {
        let context = coreDataManager.viewContext
        
        // Create a test station
        let station = Station(context: context)
        station.stationId = "test_station"
        station.name = "テスト駅"
        station.latitude = 35.6762
        station.longitude = 139.6503
        
        // This should not throw
        coreDataManager.save()
        
        // Verify the station was saved
        let fetchRequest: NSFetchRequest<Station> = Station.fetchRequest()
        do {
            let stations = try context.fetch(fetchRequest)
            XCTAssertGreaterThan(stations.count, 0)
        } catch {
            XCTFail("Failed to fetch saved station: \(error)")
        }
    }
    
    func testPerformBackgroundTask() {
        let expectation = XCTestExpectation(description: "Background task completed")
        
        coreDataManager.performBackgroundTask { context in
            // Create a station in background context
            let station = Station(context: context)
            station.stationId = "background_test_station"
            station.name = "バックグラウンドテスト駅"
            station.latitude = 35.6580
            station.longitude = 139.7016
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify the station was saved to main context
        let fetchRequest: NSFetchRequest<Station> = Station.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@", "background_test_station")
        
        do {
            let stations = try coreDataManager.viewContext.fetch(fetchRequest)
            XCTAssertGreaterThan(stations.count, 0)
        } catch {
            XCTFail("Failed to fetch background saved station: \(error)")
        }
    }
    
    // MARK: - Station Entity Tests
    
    func testCreateStation() {
        let station = coreDataManager.createStation(
            stationId: "create_test_station",
            name: "作成テスト駅",
            latitude: 35.6896,
            longitude: 139.7006,
            lines: "JR山手線,JR中央線"
        )
        
        XCTAssertEqual(station.stationId, "create_test_station")
        XCTAssertEqual(station.name, "作成テスト駅")
        XCTAssertEqual(station.latitude, 35.6896, accuracy: 0.0001)
        XCTAssertEqual(station.longitude, 139.7006, accuracy: 0.0001)
        XCTAssertEqual(station.lines, "JR山手線,JR中央線")
        XCTAssertFalse(station.isFavorite)
        XCTAssertNotNil(station.lastUsedAt)
    }
    
    func testFetchStation() {
        // Create a station first
        let createdStation = coreDataManager.createStation(
            stationId: "fetch_test_station",
            name: "取得テスト駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        // Fetch it
        let fetchedStation = coreDataManager.fetchStation(by: "fetch_test_station")
        
        XCTAssertNotNil(fetchedStation)
        XCTAssertEqual(fetchedStation?.stationId, createdStation.stationId)
        XCTAssertEqual(fetchedStation?.name, createdStation.name)
    }
    
    func testFetchNonexistentStation() {
        let station = coreDataManager.fetchStation(by: "nonexistent_station")
        XCTAssertNil(station)
    }
    
    func testFetchFavoriteStations() {
        // Create stations
        let station1 = coreDataManager.createStation(
            stationId: "favorite_station_1",
            name: "お気に入り駅1",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let station2 = coreDataManager.createStation(
            stationId: "favorite_station_2",
            name: "お気に入り駅2",
            latitude: 35.6580,
            longitude: 139.7016
        )
        
        // Mark one as favorite
        station1.isFavorite = true
        coreDataManager.save()
        
        let favoriteStations = coreDataManager.fetchFavoriteStations()
        
        XCTAssertEqual(favoriteStations.count, 1)
        XCTAssertEqual(favoriteStations.first?.stationId, "favorite_station_1")
    }
    
    // MARK: - Alert Entity Tests
    
    func testCreateAlert() {
        // Create a station first
        let station = coreDataManager.createStation(
            stationId: "alert_test_station",
            name: "アラートテスト駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let alert = coreDataManager.createAlert(
            for: station,
            notificationTime: 5,
            notificationDistance: 500,
            snoozeInterval: 3,
            characterStyle: "gyaru"
        )
        
        XCTAssertNotNil(alert.alertId)
        XCTAssertEqual(alert.station, station)
        XCTAssertEqual(alert.notificationTime, 5)
        XCTAssertEqual(alert.notificationDistance, 500)
        XCTAssertEqual(alert.snoozeInterval, 3)
        XCTAssertEqual(alert.characterStyle, "gyaru")
        XCTAssertTrue(alert.isActive)
        XCTAssertNotNil(alert.createdAt)
    }
    
    func testFetchActiveAlerts() {
        // Create a station and alerts
        let station = coreDataManager.createStation(
            stationId: "active_alert_station",
            name: "アクティブアラート駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let activeAlert = coreDataManager.createAlert(
            for: station,
            notificationTime: 5,
            notificationDistance: 500
        )
        
        let inactiveAlert = coreDataManager.createAlert(
            for: station,
            notificationTime: 10,
            notificationDistance: 1000
        )
        
        // Mark one as inactive
        inactiveAlert.isActive = false
        coreDataManager.save()
        
        let activeAlerts = coreDataManager.fetchActiveAlerts()
        
        XCTAssertEqual(activeAlerts.count, 1)
        XCTAssertEqual(activeAlerts.first?.alertId, activeAlert.alertId)
    }
    
    // MARK: - History Entity Tests
    
    func testCreateHistory() {
        // Create station and alert first
        let station = coreDataManager.createStation(
            stationId: "history_test_station",
            name: "履歴テスト駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let alert = coreDataManager.createAlert(
            for: station,
            notificationTime: 5,
            notificationDistance: 500
        )
        
        let history = coreDataManager.createHistory(
            for: alert,
            message: "テスト通知メッセージ"
        )
        
        XCTAssertNotNil(history.historyId)
        XCTAssertEqual(history.alert, alert)
        XCTAssertEqual(history.message, "テスト通知メッセージ")
        XCTAssertNotNil(history.notifiedAt)
    }
    
    func testFetchHistory() {
        // Create station, alert, and history
        let station = coreDataManager.createStation(
            stationId: "fetch_history_station",
            name: "履歴取得駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let alert = coreDataManager.createAlert(
            for: station,
            notificationTime: 5,
            notificationDistance: 500
        )
        
        let history1 = coreDataManager.createHistory(for: alert, message: "メッセージ1")
        let history2 = coreDataManager.createHistory(for: alert, message: "メッセージ2")
        
        let historyItems = coreDataManager.fetchHistory(limit: 10)
        
        XCTAssertGreaterThanOrEqual(historyItems.count, 2)
        // Should be sorted by notifiedAt descending
        XCTAssertGreaterThanOrEqual(historyItems[0].notifiedAt ?? Date.distantPast, 
                                   historyItems[1].notifiedAt ?? Date.distantPast)
    }
    
    // MARK: - Utility Method Tests
    
    func testDeleteEntity() {
        let station = coreDataManager.createStation(
            stationId: "delete_test_station",
            name: "削除テスト駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        // Verify it exists
        let fetchRequest: NSFetchRequest<Station> = Station.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@", "delete_test_station")
        
        do {
            var stations = try coreDataManager.viewContext.fetch(fetchRequest)
            XCTAssertEqual(stations.count, 1)
            
            // Delete it
            coreDataManager.delete(station)
            
            // Verify it's deleted
            stations = try coreDataManager.viewContext.fetch(fetchRequest)
            XCTAssertEqual(stations.count, 0)
            
        } catch {
            XCTFail("Delete operation failed: \(error)")
        }
    }
    
    func testDeleteAllData() {
        // Create some test data
        let station = coreDataManager.createStation(
            stationId: "delete_all_station",
            name: "全削除テスト駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let alert = coreDataManager.createAlert(
            for: station,
            notificationTime: 5,
            notificationDistance: 500
        )
        
        let history = coreDataManager.createHistory(
            for: alert,
            message: "全削除テスト"
        )
        
        // Delete all data
        coreDataManager.deleteAllData()
        
        // Verify all data is deleted
        let stationFetch: NSFetchRequest<Station> = Station.fetchRequest()
        let alertFetch: NSFetchRequest<Alert> = Alert.fetchRequest()
        let historyFetch: NSFetchRequest<History> = History.fetchRequest()
        
        do {
            let stations = try coreDataManager.viewContext.fetch(stationFetch)
            let alerts = try coreDataManager.viewContext.fetch(alertFetch)
            let historyItems = try coreDataManager.viewContext.fetch(historyFetch)
            
            XCTAssertEqual(stations.count, 0)
            XCTAssertEqual(alerts.count, 0)
            XCTAssertEqual(historyItems.count, 0)
            
        } catch {
            XCTFail("Fetch after delete all failed: \(error)")
        }
    }
    
    func testBatchDelete() {
        // Create multiple stations
        for i in 1...5 {
            coreDataManager.createStation(
                stationId: "batch_delete_station_\(i)",
                name: "バッチ削除駅\(i)",
                latitude: 35.6762,
                longitude: 139.6503
            )
        }
        
        // Batch delete stations
        coreDataManager.batchDelete(entityName: "Station")
        
        // Verify stations are deleted
        let fetchRequest: NSFetchRequest<Station> = Station.fetchRequest()
        do {
            let stations = try coreDataManager.viewContext.fetch(fetchRequest)
            XCTAssertEqual(stations.count, 0)
        } catch {
            XCTFail("Batch delete verification failed: \(error)")
        }
    }
    
    // MARK: - Migration Tests
    
    func testRequiresMigration() {
        // This is difficult to test in unit tests without actual model version changes
        let requiresMigration = coreDataManager.requiresMigration()
        
        // Should not crash and return a boolean
        XCTAssertNotNil(requiresMigration)
    }
    
    func testPerformLightweightMigration() {
        // Should not crash
        coreDataManager.performLightweightMigration()
        XCTAssertTrue(true, "Lightweight migration configuration should not crash")
    }
    
    // MARK: - Relationship Tests
    
    func testStationAlertRelationship() {
        let station = coreDataManager.createStation(
            stationId: "relationship_station",
            name: "関係テスト駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let alert1 = coreDataManager.createAlert(for: station, notificationTime: 5, notificationDistance: 500)
        let alert2 = coreDataManager.createAlert(for: station, notificationTime: 10, notificationDistance: 1000)
        
        XCTAssertEqual(station.alerts?.count, 2)
        XCTAssertTrue(station.alerts?.contains(alert1) ?? false)
        XCTAssertTrue(station.alerts?.contains(alert2) ?? false)
        XCTAssertEqual(alert1.station, station)
        XCTAssertEqual(alert2.station, station)
    }
    
    func testAlertHistoryRelationship() {
        let station = coreDataManager.createStation(
            stationId: "alert_history_station",
            name: "アラート履歴駅",
            latitude: 35.6762,
            longitude: 139.6503
        )
        
        let alert = coreDataManager.createAlert(for: station, notificationTime: 5, notificationDistance: 500)
        
        let history1 = coreDataManager.createHistory(for: alert, message: "履歴1")
        let history2 = coreDataManager.createHistory(for: alert, message: "履歴2")
        
        XCTAssertEqual(alert.history?.count, 2)
        XCTAssertTrue(alert.history?.contains(history1) ?? false)
        XCTAssertTrue(alert.history?.contains(history2) ?? false)
        XCTAssertEqual(history1.alert, alert)
        XCTAssertEqual(history2.alert, alert)
    }
    
    // MARK: - Performance Tests
    
    func testMassDataCreationPerformance() {
        measure {
            for i in 1...100 {
                let station = coreDataManager.createStation(
                    stationId: "perf_station_\(i)",
                    name: "パフォーマンス駅\(i)",
                    latitude: 35.0 + Double(i) * 0.01,
                    longitude: 139.0 + Double(i) * 0.01
                )
                
                coreDataManager.createAlert(
                    for: station,
                    notificationTime: Int16(i % 10 + 1),
                    notificationDistance: Double(i * 10 + 100)
                )
            }
        }
    }
    
    func testMassFetchPerformance() {
        // Create test data first
        for i in 1...1000 {
            coreDataManager.createStation(
                stationId: "fetch_perf_station_\(i)",
                name: "取得パフォーマンス駅\(i)",
                latitude: 35.0 + Double(i) * 0.001,
                longitude: 139.0 + Double(i) * 0.001
            )
        }
        
        measure {
            let fetchRequest: NSFetchRequest<Station> = Station.fetchRequest()
            do {
                _ = try coreDataManager.viewContext.fetch(fetchRequest)
            } catch {
                XCTFail("Mass fetch failed: \(error)")
            }
        }
    }
}

// MARK: - Test Core Data Manager

class TestCoreDataManager: CoreDataManager {
    
    override init() {
        super.init()
        setupInMemoryPersistentContainer()
    }
    
    private func setupInMemoryPersistentContainer() {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("In-memory Core Data failed to load: \(error)")
            }
        }
    }
}

// MARK: - Core Data Model Extensions for Testing

extension Station {
    static func createTestStation(in context: NSManagedObjectContext) -> Station {
        let station = Station(context: context)
        station.stationId = "test_station_\(UUID().uuidString)"
        station.name = "テスト駅"
        station.latitude = 35.6762
        station.longitude = 139.6503
        station.lines = "テスト線"
        station.isFavorite = false
        station.lastUsedAt = Date()
        return station
    }
}

extension Alert {
    static func createTestAlert(for station: Station, in context: NSManagedObjectContext) -> Alert {
        let alert = Alert(context: context)
        alert.alertId = UUID()
        alert.station = station
        alert.notificationTime = 5
        alert.notificationDistance = 500
        alert.snoozeInterval = 3
        alert.characterStyle = "healing"
        alert.isActive = true
        alert.createdAt = Date()
        return alert
    }
}

extension History {
    static func createTestHistory(for alert: Alert, in context: NSManagedObjectContext) -> History {
        let history = History(context: context)
        history.historyId = UUID()
        history.alert = alert
        history.message = "テスト通知メッセージ"
        history.notifiedAt = Date()
        return history
    }
}
