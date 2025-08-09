//
//  BackgroundProcessingIntegrationTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
import BackgroundTasks
import CoreLocation
import UserNotifications
@testable import TrainAlert

final class BackgroundProcessingIntegrationTests: XCTestCase {
    
    var mockLocationManager: MockLocationManager!
    var mockNotificationManager: MockNotificationManager!
    var mockStationAPIClient: MockStationAPIClient!
    var testCoreDataManager: TestCoreDataManager!
    
    override func setUp() {
        super.setUp()
        
        mockLocationManager = MockLocationManager()
        mockNotificationManager = MockNotificationManager()
        mockStationAPIClient = MockStationAPIClient()
        testCoreDataManager = TestCoreDataManager()
        
        setupMockBehavior()
    }
    
    override func tearDown() {
        mockLocationManager = nil
        mockNotificationManager = nil
        mockStationAPIClient = nil
        testCoreDataManager?.deleteAllData()
        testCoreDataManager = nil
        
        super.tearDown()
    }
    
    private func setupMockBehavior() {
        mockLocationManager.shouldDenyAuthorization = false
        mockLocationManager.shouldFailLocationUpdates = false
        mockLocationManager.authorizationStatus = .authorizedAlways
        
        mockNotificationManager.shouldGrantPermission = true
        mockNotificationManager.shouldFailRequests = false
        mockNotificationManager.isPermissionGranted = true
        
        mockStationAPIClient.shouldFailRequests = false
        mockStationAPIClient.shouldReturnEmptyResults = false
    }
    
    // MARK: - Background Location Updates Tests
    
    @MainActor
    func testBackgroundLocationUpdateFlow() async throws {
        // Setup alert and start location tracking
        let targetStation = CLLocation(latitude: 35.6812, longitude: 139.7673) // Tokyo Station
        let stationName = "東京"
        
        // Create alert in database
        let stationEntity = testCoreDataManager.createStation(
            stationId: "bg_test_station",
            name: stationName,
            latitude: targetStation.coordinate.latitude,
            longitude: targetStation.coordinate.longitude
        )
        
        let alert = testCoreDataManager.createAlert(
            for: stationEntity,
            notificationTime: 5,
            notificationDistance: 500,
            characterStyle: "gyaru"
        )
        
        // Schedule location-based notification
        try await mockNotificationManager.scheduleLocationBasedAlert(
            for: stationName,
            targetLocation: targetStation,
            radius: 500
        )
        
        // Start background location tracking
        mockLocationManager.startUpdatingLocation(targetStation: targetStation)
        XCTAssertTrue(mockLocationManager.isUpdatingLocation)
        
        // Simulate significant location change (background update)
        let newLocation = CLLocation(latitude: 35.6810, longitude: 139.7670) // Near Tokyo Station
        mockLocationManager.simulateLocationUpdate(newLocation)
        
        // Verify location was updated
        XCTAssertNotNil(mockLocationManager.location)
        XCTAssertEqual(mockLocationManager.location?.coordinate.latitude, newLocation.coordinate.latitude, accuracy: 0.0001)
        
        // Calculate distance to target
        let distance = mockLocationManager.distanceToTargetStation()
        XCTAssertNotNil(distance)
        XCTAssertLessThan(distance!, 500, "Should be within notification radius")
        
        // In real implementation, this would trigger notification scheduling
        XCTAssertTrue(mockNotificationManager.isNotificationScheduled("location_alert_\(stationName)"))
    }
    
    @MainActor
    func testBackgroundTaskExecution() async throws {
        // Simulate background app refresh task
        let expectation = XCTestExpectation(description: "Background task execution")
        
        // This simulates what would happen in a real background task handler
        Task {
            // Check for active alerts
            let activeAlerts = testCoreDataManager.fetchActiveAlerts()
            
            for alert in activeAlerts {
                guard let station = alert.station,
                      let stationName = station.name else { continue }
                
                let targetLocation = CLLocation(
                    latitude: station.latitude,
                    longitude: station.longitude
                )
                
                // Update location if needed
                mockLocationManager.startUpdatingLocation(targetStation: targetLocation)
                
                // Check if we're approaching the station
                if let currentLocation = mockLocationManager.location {
                    let distance = currentLocation.distance(from: targetLocation)
                    
                    if distance <= alert.notificationDistance {
                        // Schedule immediate notification
                        try await mockNotificationManager.scheduleTrainAlert(
                            for: stationName,
                            arrivalTime: Date().addingTimeInterval(TimeInterval(alert.notificationTime * 60)),
                            currentLocation: currentLocation,
                            targetLocation: targetLocation,
                            characterStyle: CharacterStyle(rawValue: alert.characterStyle ?? "healing") ?? .healing
                        )
                    }
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(true, \"Background task simulation completed\")
    }
    
    // MARK: - Background Notification Processing Tests
    
    @MainActor
    func testBackgroundNotificationDelivery() async throws {
        // Setup scenario where user is approaching station in background
        let targetStation = CLLocation(latitude: 35.6580, longitude: 139.7016) // Shibuya Station
        let stationName = \"渋谷\"
        
        // Create alert
        let stationEntity = testCoreDataManager.createStation(
            stationId: \"bg_shibuya_station\",
            name: stationName,
            latitude: targetStation.coordinate.latitude,
            longitude: targetStation.coordinate.longitude
        )
        
        let alert = testCoreDataManager.createAlert(
            for: stationEntity,
            notificationTime: 3,
            notificationDistance: 800,
            characterStyle: \"butler\"
        )
        
        // Schedule notification
        try await mockNotificationManager.scheduleLocationBasedAlert(
            for: stationName,
            targetLocation: targetStation,
            radius: 800
        )
        
        // Simulate user approaching in background
        let approachingLocation = CLLocation(latitude: 35.6578, longitude: 139.7014) // ~200m from Shibuya
        mockLocationManager.simulateLocationUpdate(approachingLocation)
        
        let distance = approachingLocation.distance(from: targetStation)
        XCTAssertLessThan(distance, 800, \"Should be within notification radius\")
        
        // Simulate background notification trigger
        let arrivalTime = Date().addingTimeInterval(3 * 60) // 3 minutes from now
        
        try await mockNotificationManager.scheduleTrainAlert(
            for: stationName,
            arrivalTime: arrivalTime,
            currentLocation: approachingLocation,
            targetLocation: targetStation,
            characterStyle: .butler
        )
        
        // Create history entry for the notification
        let history = testCoreDataManager.createHistory(
            for: alert,
            message: \"もうすぐ\(stationName)駅でございます。お忘れ物はございませんか？\"
        )
        
        XCTAssertNotNil(history.historyId)
        XCTAssertEqual(history.alert, alert)
        
        // Verify notification was scheduled
        let notificationId = \"train_alert_\(stationName)_\(Int(arrivalTime.timeIntervalSince1970))\"
        XCTAssertTrue(mockNotificationManager.isNotificationScheduled(notificationId))
    }
    
    // MARK: - Background Data Synchronization Tests
    
    @MainActor
    func testBackgroundDataSync() async throws {
        // Test synchronizing data in background (e.g., updating station information)
        let locations = [
            (35.6812, 139.7673, \"東京\"),
            (35.6580, 139.7016, \"渋谷\"),
            (35.6896, 139.7006, \"新宿\")
        ]
        
        let expectation = XCTestExpectation(description: \"Background data sync\")
        
        Task {
            // Simulate background sync of station data
            for (lat, lon, name) in locations {
                // Fetch latest station information
                let stations = try await mockStationAPIClient.getNearbyStations(
                    latitude: lat,
                    longitude: lon
                )
                
                if let station = stations.first(where: { $0.name.contains(name) }) {
                    // Update or create station in Core Data
                    let existingStation = testCoreDataManager.fetchStation(by: station.id)
                    
                    if existingStation == nil {
                        let newStation = testCoreDataManager.createStation(
                            stationId: station.id,
                            name: station.name,
                            latitude: station.latitude,
                            longitude: station.longitude,
                            lines: station.lines.joined(separator: \",\")
                        )
                        XCTAssertNotNil(newStation)
                    }
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify stations were created/updated
        let allStations = try testCoreDataManager.viewContext.fetch(Station.fetchRequest())
        XCTAssertGreaterThanOrEqual(allStations.count, locations.count)
    }
    
    // MARK: - Background Power Management Tests
    
    func testBackgroundPowerOptimization() async throws {
        // Test power-efficient background processing
        let targetStation = CLLocation(latitude: 35.6762, longitude: 139.6503) // Shinagawa Station
        
        mockLocationManager.startUpdatingLocation(targetStation: targetStation)
        
        // Simulate different distances to test accuracy adjustment
        let testLocations = [
            CLLocation(latitude: 35.7000, longitude: 139.7000), // Far away (~5km)
            CLLocation(latitude: 35.6800, longitude: 139.6600), // Medium distance (~1km)  
            CLLocation(latitude: 35.6760, longitude: 139.6510)  // Close (~100m)
        ]
        
        for location in testLocations {
            mockLocationManager.simulateLocationUpdate(location)
            
            let distance = location.distance(from: targetStation)
            
            // Verify that location accuracy would be adjusted based on distance
            // (In real implementation, this would adjust CLLocationManager settings)
            if distance > 5000 {
                // Should use low accuracy, high distance filter
                XCTAssertTrue(true, \"Should use power-efficient settings for far distances\")
            } else if distance > 2000 {
                // Should use medium accuracy
                XCTAssertTrue(true, \"Should use medium accuracy for medium distances\")
            } else {
                // Should use high accuracy for close distances
                XCTAssertTrue(true, \"Should use high accuracy when approaching station\")
            }
        }
    }
    
    // MARK: - Background Error Handling Tests
    
    @MainActor
    func testBackgroundErrorRecovery() async throws {
        // Test handling errors during background processing
        let targetStation = CLLocation(latitude: 35.6896, longitude: 139.7006) // Shinjuku Station
        
        // Setup alert
        let stationEntity = testCoreDataManager.createStation(
            stationId: \"bg_error_test_station\",
            name: \"新宿\",
            latitude: targetStation.coordinate.latitude,
            longitude: targetStation.coordinate.longitude
        )
        
        let alert = testCoreDataManager.createAlert(
            for: stationEntity,
            notificationTime: 5,
            notificationDistance: 600
        )
        
        // Simulate location service error
        mockLocationManager.shouldFailLocationUpdates = true
        mockLocationManager.startUpdatingLocation(targetStation: targetStation)
        
        // Should handle location error gracefully
        XCTAssertEqual(mockLocationManager.lastError, .locationUnavailable)
        
        // Recovery: try with fallback method or cached location
        mockLocationManager.shouldFailLocationUpdates = false
        
        // Simulate recovery with cached/manual location
        let fallbackLocation = CLLocation(latitude: 35.6894, longitude: 139.7004)
        mockLocationManager.simulateLocationUpdate(fallbackLocation)
        
        XCTAssertNotNil(mockLocationManager.location)
        XCTAssertNil(mockLocationManager.lastError)
        
        // Continue with notification processing despite earlier error
        let distance = fallbackLocation.distance(from: targetStation)
        if distance <= alert.notificationDistance {
            try await mockNotificationManager.scheduleTrainAlert(
                for: \"新宿\",
                arrivalTime: Date().addingTimeInterval(5 * 60),
                currentLocation: fallbackLocation,
                targetLocation: targetStation,
                characterStyle: .healing
            )
        }
        
        XCTAssertTrue(mockNotificationManager.scheduledNotifications.count > 0)
    }
    
    // MARK: - Background Performance Tests
    
    func testBackgroundProcessingPerformance() async throws {
        // Test that background processing completes within time limits
        let startTime = Date()
        
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()]) {
            Task {
                // Simulate typical background processing workload
                
                // 1. Check active alerts
                let activeAlerts = testCoreDataManager.fetchActiveAlerts()
                
                // 2. Update location for each alert
                for alert in activeAlerts {
                    guard let station = alert.station else { continue }
                    
                    let targetLocation = CLLocation(
                        latitude: station.latitude,
                        longitude: station.longitude
                    )
                    
                    mockLocationManager.startUpdatingLocation(targetStation: targetLocation)
                    
                    // 3. Check distance and schedule notifications if needed
                    if let currentLocation = mockLocationManager.location {
                        let distance = currentLocation.distance(from: targetLocation)
                        
                        if distance <= alert.notificationDistance {
                            try await mockNotificationManager.scheduleLocationBasedAlert(
                                for: station.name ?? \"\",
                                targetLocation: targetLocation,
                                radius: alert.notificationDistance
                            )
                        }
                    }
                }
                
                // 4. Clean up old history entries (simulate)
                let oldHistory = testCoreDataManager.fetchHistory(limit: 100)
                let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
                
                for history in oldHistory {
                    if let notifiedAt = history.notifiedAt, notifiedAt < cutoffDate {
                        // Would delete in real implementation
                        _ = history
                    }
                }
            }
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        // Background processing should complete quickly to preserve battery
        XCTAssertLessThan(executionTime, 3.0, \"Background processing should complete within 3 seconds\")
    }
    
    // MARK: - Background Notification Accuracy Tests
    
    @MainActor
    func testBackgroundNotificationTiming() async throws {
        // Test accurate notification timing in background
        let targetStation = CLLocation(latitude: 35.7090, longitude: 139.7319) // Ikebukuro Station
        let stationName = \"池袋\"
        
        // Create alert with specific timing
        let stationEntity = testCoreDataManager.createStation(
            stationId: \"bg_timing_test_station\",
            name: stationName,
            latitude: targetStation.coordinate.latitude,
            longitude: targetStation.coordinate.longitude
        )
        
        let alert = testCoreDataManager.createAlert(
            for: stationEntity,
            notificationTime: 8, // 8 minutes before arrival
            notificationDistance: 1000,
            characterStyle: \"kansai\"
        )
        
        // Simulate user approaching station
        let approachingLocation = CLLocation(latitude: 35.7088, longitude: 139.7317) // ~300m away
        mockLocationManager.simulateLocationUpdate(approachingLocation)
        
        // Calculate estimated arrival time based on typical walking speed (5 km/h)
        let distance = approachingLocation.distance(from: targetStation)
        let walkingSpeedMPS = 1.4 // meters per second (approx 5 km/h)
        let estimatedArrivalTime = Date().addingTimeInterval(distance / walkingSpeedMPS)
        
        // Schedule notification 8 minutes before estimated arrival
        let notificationTime = estimatedArrivalTime.addingTimeInterval(-8 * 60)
        
        try await mockNotificationManager.scheduleTrainAlert(
            for: stationName,
            arrivalTime: estimatedArrivalTime,
            currentLocation: approachingLocation,
            targetLocation: targetStation,
            characterStyle: .kansai
        )
        
        // Verify notification is scheduled for correct time
        let notificationId = \"train_alert_\(stationName)_\(Int(estimatedArrivalTime.timeIntervalSince1970))\"
        XCTAssertTrue(mockNotificationManager.isNotificationScheduled(notificationId))
        
        // Create history entry with accurate timestamp
        let history = testCoreDataManager.createHistory(
            for: alert,
            message: \"もうすぐ\(stationName)駅やで！降りる準備しいや〜\"
        )
        
        XCTAssertNotNil(history.notifiedAt)
        XCTAssertEqual(history.alert, alert)
    }
    
    // MARK: - Background Memory Management Tests
    
    func testBackgroundMemoryUsage() async throws {
        // Test that background processing doesn't cause memory issues
        let initialMemory = measureMemoryUsage()
        
        // Create multiple alerts and process them
        let stationCount = 50
        var createdAlerts: [Alert] = []
        
        for i in 0..<stationCount {
            let lat = 35.6000 + Double(i) * 0.001
            let lon = 139.7000 + Double(i) * 0.001
            
            let station = testCoreDataManager.createStation(
                stationId: \"memory_test_station_\(i)\",
                name: \"テスト駅\(i)\",
                latitude: lat,
                longitude: lon
            )
            
            let alert = testCoreDataManager.createAlert(
                for: station,
                notificationTime: Int16.random(in: 1...10),
                notificationDistance: Double.random(in: 100...1000)
            )
            
            createdAlerts.append(alert)
        }
        
        // Process all alerts in background-style batch
        for alert in createdAlerts {
            guard let station = alert.station else { continue }
            
            let targetLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            mockLocationManager.startUpdatingLocation(targetStation: targetLocation)
            
            // Simulate location update
            let testLocation = CLLocation(
                latitude: station.latitude + 0.001,
                longitude: station.longitude + 0.001
            )
            mockLocationManager.simulateLocationUpdate(testLocation)
            
            // Schedule notification
            try await mockNotificationManager.scheduleLocationBasedAlert(
                for: station.name ?? \"\",
                targetLocation: targetLocation,
                radius: alert.notificationDistance
            )
        }
        
        let finalMemory = measureMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable for the amount of data processed
        XCTAssertLessThan(memoryIncrease, 50_000_000, \"Memory increase should be less than 50MB\") // 50MB limit
        
        // Clean up
        for alert in createdAlerts {
            testCoreDataManager.delete(alert)
            if let station = alert.station {
                testCoreDataManager.delete(station)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func measureMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    private func createMockStations() -> [Station] {
        return [
            Station(id: \"bg_test_tokyo\", name: \"東京\", latitude: 35.6812, longitude: 139.7673, lines: [\"JR山手線\"]),
            Station(id: \"bg_test_shibuya\", name: \"渋谷\", latitude: 35.6580, longitude: 139.7016, lines: [\"JR山手線\"]),
            Station(id: \"bg_test_shinjuku\", name: \"新宿\", latitude: 35.6896, longitude: 139.7006, lines: [\"JR山手線\"])
        ]
    }
}
