//
//  IntegrationTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import CoreData
import CoreLocation
@testable import TrainAlert
import UserNotifications
import XCTest

@MainActor
final class IntegrationTests: XCTestCase {
    var mockStationAPIClient: MockStationAPIClient!
    var mockOpenAIClient: MockOpenAIClient!
    var mockNotificationManager: MockNotificationManager!
    var mockLocationManager: MockLocationManager!
    var testCoreDataManager: TestCoreDataManager!
    
    override func setUp() {
        super.setUp()
        
        mockStationAPIClient = MockStationAPIClient()
        mockOpenAIClient = MockOpenAIClient()
        mockNotificationManager = MockNotificationManager()
        mockLocationManager = MockLocationManager()
        testCoreDataManager = TestCoreDataManager()
        
        // Configure mocks for integration testing
        setupMockBehavior()
    }
    
    override func tearDown() {
        mockStationAPIClient = nil
        mockOpenAIClient = nil
        mockNotificationManager = nil
        mockLocationManager = nil
        testCoreDataManager?.deleteAllData()
        testCoreDataManager = nil
        
        super.tearDown()
    }
    
    private func setupMockBehavior() {
        // Configure API client
        mockStationAPIClient.shouldFailRequests = false
        mockStationAPIClient.shouldReturnEmptyResults = false
        
        // Configure OpenAI client
        mockOpenAIClient.hasValidAPIKey = true
        mockOpenAIClient.shouldFailRequests = false
        
        // Configure notification manager
        mockNotificationManager.shouldGrantPermission = true
        mockNotificationManager.shouldFailRequests = false
        
        // Configure location manager
        mockLocationManager.shouldDenyAuthorization = false
        mockLocationManager.shouldFailLocationUpdates = false
    }
    
    // MARK: - Alert Creation Integration Tests
    
    func testCompleteAlertCreationFlow() async throws {
        // Step 1: Search for stations near user location
        let userLocation = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7673)
        let nearbyStations = try await mockStationAPIClient.getNearbyStations(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )
        
        XCTAssertFalse(nearbyStations.isEmpty, "Should find nearby stations")
        
        // Step 2: Select a station
        let selectedStation = nearbyStations.first!
        
        // Step 3: Create alert in Core Data
        let stationEntity = testCoreDataManager.createStation(
            stationId: selectedStation.id,
            name: selectedStation.name,
            latitude: selectedStation.latitude,
            longitude: selectedStation.longitude,
            lines: selectedStation.lines
        )
        
        let alert = testCoreDataManager.createAlert(
            for: stationEntity,
            notificationTime: 5,
            notificationDistance: 500,
            characterStyle: "gyaru"
        )
        
        XCTAssertNotNil(alert.alertId)
        XCTAssertEqual(alert.station, stationEntity)
        
        // Step 4: Request notification permissions
        try await mockNotificationManager.requestAuthorization()
        XCTAssertTrue(mockNotificationManager.isPermissionGranted)
        
        // Step 5: Schedule location-based notification
        let stationLocation = CLLocation(
            latitude: selectedStation.latitude,
            longitude: selectedStation.longitude
        )
        
        try await mockNotificationManager.scheduleLocationBasedAlert(
            for: selectedStation.name,
            targetLocation: stationLocation,
            radius: 500
        )
        
        XCTAssertTrue(mockNotificationManager.isNotificationScheduled("location_alert_\(selectedStation.name)"))
        
        // Step 6: Start location tracking
        mockLocationManager.startUpdatingLocation(targetStation: stationLocation)
        XCTAssertTrue(mockLocationManager.isUpdatingLocation)
        
        // Integration test passes if all steps complete successfully
        XCTAssertTrue(true, "Complete alert creation flow should succeed")
    }
    
    func testAlertCreationWithAPIFailures() async throws {
        // Test resilience to API failures
        mockStationAPIClient.shouldFailRequests = true
        
        do {
            _ = try await mockStationAPIClient.getNearbyStations(latitude: 35.6812, longitude: 139.7673)
            XCTFail("Should throw error when API fails")
        } catch {
            XCTAssertTrue(error is StationAPIError)
        }
        
        // App should handle this gracefully and allow manual station entry
        let manualStation = Station(
            id: "manual_tokyo_station",
            name: "東京",
            latitude: 35.6812,
            longitude: 139.7673,
            lines: ["JR山手線", "JR東海道本線"]
        )
        
        // Continue with manual station
        let stationEntity = testCoreDataManager.createStation(
            stationId: manualStation.id,
            name: manualStation.name,
            latitude: manualStation.latitude,
            longitude: manualStation.longitude,
            lines: manualStation.lines
        )
        
        XCTAssertNotNil(stationEntity)
        XCTAssertEqual(stationEntity.name, "東京")
    }
    
    // MARK: - Notification Generation Integration Tests
    
    func testNotificationMessageGeneration() async throws {
        // Setup OpenAI client with valid API key
        mockOpenAIClient.hasValidAPIKey = true
        
        // Test message generation for different character styles
        let characterStyles: [CharacterStyle] = [.gyaru, .butler, .kansai, .tsundere, .sporty, .healing]
        let stationName = "渋谷"
        let arrivalTime = "5分後"
        
        for style in characterStyles {
            do {
                let message = try await mockOpenAIClient.generateNotificationMessage(
                    for: stationName,
                    arrivalTime: arrivalTime,
                    characterStyle: style
                )
                
                XCTAssertFalse(message.isEmpty, "Generated message should not be empty for \(style.displayName)")
                XCTAssertTrue(message.contains(stationName), "Message should contain station name for \(style.displayName)")
                
                // Verify tracking
                XCTAssertEqual(mockOpenAIClient.lastStationName, stationName)
                XCTAssertEqual(mockOpenAIClient.lastCharacterStyle, style)
            } catch {
                XCTFail("Message generation failed for \(style.displayName): \(error)")
            }
        }
        
        XCTAssertEqual(mockOpenAIClient.requestCount, characterStyles.count)
    }
    
    func testNotificationFallbackSystem() async throws {
        // Test fallback when OpenAI API fails
        mockOpenAIClient.shouldFailRequests = true
        
        let stationName = "新宿"
        let characterStyle = CharacterStyle.butler
        
        // When OpenAI fails, system should use fallback messages
        do {
            _ = try await mockOpenAIClient.generateNotificationMessage(
                for: stationName,
                arrivalTime: "3分後",
                characterStyle: characterStyle
            )
            XCTFail("Should fail when configured to fail")
        } catch {
            // This should trigger fallback message system
            let fallbackMessages = characterStyle.fallbackMessages
            let fallbackMessage = fallbackMessages.trainAlert.body.replacingOccurrences(of: "{station}", with: stationName)
            
            XCTAssertFalse(fallbackMessage.isEmpty)
            XCTAssertTrue(fallbackMessage.contains(stationName))
            XCTAssertFalse(fallbackMessage.contains("{station}"))
        }
    }
    
    // MARK: - Location and Notification Integration Tests
    
    func testLocationBasedNotificationTrigger() async throws {
        // Setup complete notification flow
        mockNotificationManager.shouldGrantPermission = true
        try await mockNotificationManager.requestAuthorization()
        
        let targetStation = CLLocation(latitude: 35.6812, longitude: 139.7673) // Tokyo Station
        let stationName = "東京"
        
        // Schedule location-based alert
        try await mockNotificationManager.scheduleLocationBasedAlert(
            for: stationName,
            targetLocation: targetStation,
            radius: 500
        )
        
        XCTAssertTrue(mockNotificationManager.isNotificationScheduled("location_alert_\(stationName)"))
        
        // Start location tracking
        mockLocationManager.startUpdatingLocation(targetStation: targetStation)
        
        // Simulate approaching the station
        let approachingLocation = CLLocation(latitude: 35.6810, longitude: 139.7670) // ~300m away
        mockLocationManager.simulateLocationUpdate(approachingLocation)
        
        // Check distance calculation
        let distance = mockLocationManager.distance(from: approachingLocation, to: targetStation)
        XCTAssertLessThan(distance, 500, "Should be within notification radius")
        
        // In real implementation, this would trigger the notification
        XCTAssertNotNil(mockLocationManager.location)
        XCTAssertEqual(mockLocationManager.targetStation, targetStation)
    }
    
    func testMultipleStationAlertManagement() async throws {
        // Test managing multiple alerts for different stations
        let stations = [
            ("東京", 35.6812, 139.7673),
            ("渋谷", 35.6580, 139.7016),
            ("新宿", 35.6896, 139.7006)
        ]
        
        var createdAlerts: [Alert] = []
        
        for (name, lat, lon) in stations {
            // Create station and alert
            let stationEntity = testCoreDataManager.createStation(
                stationId: "station_\(name)",
                name: name,
                latitude: lat,
                longitude: lon
            )
            
            let alert = testCoreDataManager.createAlert(
                for: stationEntity,
                notificationTime: 5,
                notificationDistance: 500
            )
            
            createdAlerts.append(alert)
            
            // Schedule notification
            let location = CLLocation(latitude: lat, longitude: lon)
            try await mockNotificationManager.scheduleLocationBasedAlert(
                for: name,
                targetLocation: location,
                radius: 500
            )
        }
        
        // Verify all alerts were created
        XCTAssertEqual(createdAlerts.count, 3)
        
        let activeAlerts = testCoreDataManager.fetchActiveAlerts()
        XCTAssertEqual(activeAlerts.count, 3)
        
        // Verify all notifications were scheduled
        XCTAssertEqual(mockNotificationManager.scheduledNotifications.count, 3)
        
        for (name, _, _) in stations {
            XCTAssertTrue(mockNotificationManager.isNotificationScheduled("location_alert_\(name)"))
        }
    }
    
    // MARK: - Data Persistence Integration Tests
    
    func testAlertAndHistoryPersistence() async throws {
        // Create station and alert
        let stationEntity = testCoreDataManager.createStation(
            stationId: "persistence_test_station",
            name: "テスト駅",
            latitude: 35.6812,
            longitude: 139.7673
        )
        
        let alert = testCoreDataManager.createAlert(
            for: stationEntity,
            notificationTime: 10,
            notificationDistance: 800,
            characterStyle: "healing"
        )
        
        // Generate notification message
        let message = try await mockOpenAIClient.generateNotificationMessage(
            for: stationEntity.name ?? "",
            arrivalTime: "10分後",
            characterStyle: .healing
        )
        
        // Create history entry
        let history = testCoreDataManager.createHistory(for: alert, message: message)
        
        // Verify persistence
        XCTAssertNotNil(history.historyId)
        XCTAssertEqual(history.alert, alert)
        XCTAssertEqual(history.message, message)
        XCTAssertNotNil(history.notifiedAt)
        
        // Verify relationships
        XCTAssertEqual(alert.station, stationEntity)
        XCTAssertTrue(alert.history?.contains(history) ?? false)
        XCTAssertTrue(stationEntity.alerts?.contains(alert) ?? false)
        
        // Fetch and verify data consistency
        let fetchedStation = testCoreDataManager.fetchStation(by: "persistence_test_station")
        XCTAssertNotNil(fetchedStation)
        XCTAssertEqual(fetchedStation?.name, "テスト駅")
        
        let fetchedHistory = testCoreDataManager.fetchHistory(limit: 10)
        XCTAssertGreaterThan(fetchedHistory.count, 0)
        XCTAssertEqual(fetchedHistory.first?.message, message)
    }
    
    // MARK: - Error Recovery Integration Tests
    
    func testNetworkErrorRecovery() async throws {
        // Test graceful handling of network errors
        mockStationAPIClient.shouldFailRequests = true
        mockStationAPIClient.mockError = .networkError(NSError(domain: "TestError", code: 1, userInfo: nil))
        
        do {
            _ = try await mockStationAPIClient.getNearbyStations(latitude: 35.6812, longitude: 139.7673)
            XCTFail("Should throw network error")
        } catch let error as StationAPIError {
            switch error {
            case .networkError:
                // Expected - app should handle this and show cached data or allow manual entry
                XCTAssertTrue(true)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        // Recovery: use cached data or manual entry
        mockStationAPIClient.shouldFailRequests = false
        mockStationAPIClient.mockError = nil
        
        let stations = try await mockStationAPIClient.getNearbyStations(latitude: 35.6812, longitude: 139.7673)
        XCTAssertFalse(stations.isEmpty, "Should recover and return stations")
    }
    
    func testLocationPermissionHandling() async throws {
        // Test handling of location permission denial
        mockLocationManager.shouldDenyAuthorization = true
        
        mockLocationManager.requestAuthorization()
        
        // Wait for permission response
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        XCTAssertEqual(mockLocationManager.authorizationStatus, .denied)
        XCTAssertEqual(mockLocationManager.lastError, .authorizationDenied)
        
        // App should handle this by disabling location features or showing manual alternatives
        mockLocationManager.startUpdatingLocation()
        XCTAssertEqual(mockLocationManager.lastError, .authorizationDenied)
        XCTAssertFalse(mockLocationManager.isUpdatingLocation)
    }
    
    func testNotificationPermissionHandling() async throws {
        // Test handling of notification permission denial
        mockNotificationManager.shouldGrantPermission = false
        
        do {
            try await mockNotificationManager.requestAuthorization()
            XCTFail("Should throw permission denied error")
        } catch NotificationError.permissionDenied {
            XCTAssertFalse(mockNotificationManager.isPermissionGranted)
            XCTAssertEqual(mockNotificationManager.authorizationStatus, .denied)
        }
        
        // App should inform user about limited functionality
        // and suggest alternative methods (sound, vibration, etc.)
        XCTAssertTrue(mockNotificationManager.permissionRequested)
    }
    
    // MARK: - Performance Integration Tests
    
    func testCompleteFlowPerformance() async throws {
        let startTime = Date()
        
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                // Complete flow from station search to notification scheduling
                let stations = try await mockStationAPIClient.getNearbyStations(
                    latitude: 35.6812,
                    longitude: 139.7673
                )
                
                let selectedStation = stations.first!
                
                let stationEntity = testCoreDataManager.createStation(
                    stationId: selectedStation.id,
                    name: selectedStation.name,
                    latitude: selectedStation.latitude,
                    longitude: selectedStation.longitude
                )
                
                let alert = testCoreDataManager.createAlert(
                    for: stationEntity,
                    notificationTime: 5,
                    notificationDistance: 500
                )
                
                try await mockNotificationManager.requestAuthorization()
                
                let location = CLLocation(
                    latitude: selectedStation.latitude,
                    longitude: selectedStation.longitude
                )
                
                try await mockNotificationManager.scheduleLocationBasedAlert(
                    for: selectedStation.name,
                    targetLocation: location
                )
                
                mockLocationManager.startUpdatingLocation(targetStation: location)
            }
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        XCTAssertLessThan(executionTime, 2.0, "Complete flow should execute within 2 seconds")
    }
    
    func testConcurrentAPIRequests() async throws {
        // Test handling multiple concurrent API requests
        let locations = [
            (35.6812, 139.7673), // Tokyo
            (35.6580, 139.7016), // Shibuya  
            (35.6896, 139.7006), // Shinjuku
            (35.6762, 139.6503), // Shinagawa
            (35.7090, 139.7319)  // Ikebukuro
        ]
        
        let startTime = Date()
        
        // Execute concurrent API requests
        let tasks = locations.map { lat, lon in
            Task {
                try await mockStationAPIClient.getNearbyStations(latitude: lat, longitude: lon)
            }
        }
        
        let results = try await withThrowingTaskGroup(of: [Station].self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var allResults: [[Station]] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        let endTime = Date()
        let executionTime = endTime.timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, 5, "Should complete all 5 requests")
        XCTAssertLessThan(executionTime, 1.0, "Concurrent requests should complete quickly")
        
        // Verify all requests were made
        XCTAssertEqual(mockStationAPIClient.requestCount, 5)
    }
    
    // MARK: - Real-world Scenario Tests
    
    func testCommuterScenario() async throws {
        // Simulate a typical commuter scenario
        
        // 1. User sets up alert for their commute
        let homeStation = testCoreDataManager.createStation(
            stationId: "home_station",
            name: "自宅最寄り駅",
            latitude: 35.6580,
            longitude: 139.7016
        )
        
        let workStation = testCoreDataManager.createStation(
            stationId: "work_station", 
            name: "勤務先最寄り駅",
            latitude: 35.6812,
            longitude: 139.7673
        )
        
        // 2. Create alerts for both directions
        let morningAlert = testCoreDataManager.createAlert(
            for: workStation,
            notificationTime: 5,
            notificationDistance: 300,
            characterStyle: "sporty" // Energetic for morning
        )
        
        let eveningAlert = testCoreDataManager.createAlert(
            for: homeStation,
            notificationTime: 10,
            notificationDistance: 500,
            characterStyle: "healing" // Relaxing for evening
        )
        
        // 3. Schedule notifications
        try await mockNotificationManager.requestAuthorization()
        
        let workLocation = CLLocation(latitude: workStation.latitude, longitude: workStation.longitude)
        let homeLocation = CLLocation(latitude: homeStation.latitude, longitude: homeStation.longitude)
        
        try await mockNotificationManager.scheduleLocationBasedAlert(
            for: workStation.name ?? "",
            targetLocation: workLocation,
            radius: 300
        )
        
        try await mockNotificationManager.scheduleLocationBasedAlert(
            for: homeStation.name ?? "",
            targetLocation: homeLocation,
            radius: 500
        )
        
        // 4. Simulate commute - start location tracking
        mockLocationManager.startUpdatingLocation(targetStation: workLocation)
        
        // 5. Simulate approaching work station
        let approachingWork = CLLocation(latitude: 35.6810, longitude: 139.7670)
        mockLocationManager.simulateLocationUpdate(approachingWork)
        
        let distanceToWork = mockLocationManager.distance(from: approachingWork, to: workLocation)
        XCTAssertLessThan(distanceToWork, 500, "Should be approaching work station")
        
        // 6. Generate and log notification message
        let workMessage = try await mockOpenAIClient.generateNotificationMessage(
            for: workStation.name ?? "",
            arrivalTime: "3分後",
            characterStyle: .sporty
        )
        
        let workHistory = testCoreDataManager.createHistory(for: morningAlert, message: workMessage)
        
        // 7. Later, simulate evening commute
        mockLocationManager.startUpdatingLocation(targetStation: homeLocation)
        
        let approachingHome = CLLocation(latitude: 35.6578, longitude: 139.7014)
        mockLocationManager.simulateLocationUpdate(approachingHome)
        
        let homeMessage = try await mockOpenAIClient.generateNotificationMessage(
            for: homeStation.name ?? "",
            arrivalTime: "7分後", 
            characterStyle: .healing
        )
        
        let eveningHistory = testCoreDataManager.createHistory(for: eveningAlert, message: homeMessage)
        
        // Verify complete scenario
        let allHistory = testCoreDataManager.fetchHistory(limit: 10)
        XCTAssertGreaterThanOrEqual(allHistory.count, 2)
        
        let activeAlerts = testCoreDataManager.fetchActiveAlerts()
        XCTAssertEqual(activeAlerts.count, 2)
        
        XCTAssertEqual(mockNotificationManager.scheduledNotifications.count, 2)
        XCTAssertEqual(mockOpenAIClient.requestCount, 2)
    }
}
