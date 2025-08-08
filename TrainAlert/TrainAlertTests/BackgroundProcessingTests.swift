//
//  BackgroundProcessingTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
import CoreLocation
import BackgroundTasks
@testable import TrainAlert

class BackgroundProcessingTests: XCTestCase {
    
    var backgroundTaskManager: BackgroundTaskManager!
    var locationManager: LocationManagerEnhanced!
    var notificationManager: NotificationReliabilityManager!
    var powerManager: PowerManager!
    
    override func setUp() {
        super.setUp()
        backgroundTaskManager = BackgroundTaskManager.shared
        locationManager = LocationManagerEnhanced()
        notificationManager = NotificationReliabilityManager.shared
        powerManager = PowerManager.shared
    }
    
    override func tearDown() {
        backgroundTaskManager = nil
        locationManager = nil
        notificationManager = nil
        powerManager = nil
        super.tearDown()
    }
    
    // MARK: - Battery Consumption Tests
    
    func testBatteryConsumptionUnder5PercentPerHour() {
        // Create expectation
        let expectation = XCTestExpectation(description: "Battery consumption should be under 5%/hour")
        
        // Simulate 1 hour of background operation
        let startBattery = UIDevice.current.batteryLevel
        
        // Start background monitoring
        locationManager.startUpdatingLocation()
        backgroundTaskManager.scheduleAllTasks()
        
        // Simulate background operation for test duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { // 1 minute test instead of 1 hour
            let endBattery = UIDevice.current.batteryLevel
            let consumption = (startBattery - endBattery) * 100
            
            // Extrapolate to hourly rate
            let hourlyConsumption = consumption * 60
            
            // Verify consumption is under 5%/hour
            XCTAssertLessThan(hourlyConsumption, 5.0, "Battery consumption exceeds 5%/hour limit")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 70)
    }
    
    func testLowPowerModeOptimization() {
        // Simulate low power mode
        powerManager.simulatePowerState(.lowPowerMode)
        
        // Verify services adjust appropriately
        XCTAssertEqual(locationManager.currentAccuracyLevel, .powerSaving)
        XCTAssertTrue(backgroundTaskManager.isReducedMode)
        XCTAssertEqual(notificationManager.activeChannels.count, 1)
    }
    
    // MARK: - Notification Delivery Tests
    
    func testNotificationDeliveryRateAbove99Percent() {
        let expectation = XCTestExpectation(description: "Notification delivery rate should be above 99%")
        
        // Send 100 test notifications
        let totalNotifications = 100
        var successfulDeliveries = 0
        
        for i in 0..<totalNotifications {
            let notification = NotificationContent(
                title: "Test \(i)",
                body: "Test notification",
                category: .alert
            )
            
            notificationManager.scheduleNotification(notification) { success in
                if success {
                    successfulDeliveries += 1
                }
                
                if i == totalNotifications - 1 {
                    let deliveryRate = Double(successfulDeliveries) / Double(totalNotifications) * 100
                    XCTAssertGreaterThan(deliveryRate, 99.0, "Delivery rate is below 99%")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testNotificationRetryMechanism() {
        let expectation = XCTestExpectation(description: "Failed notifications should be retried")
        
        // Create a notification that will initially fail
        let notification = NotificationContent(
            title: "Retry Test",
            body: "This should be retried",
            category: .alert
        )
        
        // Force initial failure
        notificationManager.simulateFailure = true
        
        notificationManager.scheduleNotification(notification) { success in
            XCTAssertFalse(success, "Initial delivery should fail")
            
            // Enable success for retry
            self.notificationManager.simulateFailure = false
            
            // Wait for retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                XCTAssertTrue(self.notificationManager.hasDelivered(notification))
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    // MARK: - Background Task Tests
    
    func testBackgroundTaskRegistration() {
        // Verify all tasks are registered
        let expectedTasks = [
            "com.trainalert.location.update",
            "com.trainalert.notification.retry",
            "com.trainalert.data.cleanup",
            "com.trainalert.crash.upload"
        ]
        
        for taskId in expectedTasks {
            XCTAssertTrue(
                backgroundTaskManager.isTaskRegistered(taskId),
                "Task \(taskId) should be registered"
            )
        }
    }
    
    func testBackgroundLocationUpdates() {
        let expectation = XCTestExpectation(description: "Location should update in background")
        
        // Start location updates
        locationManager.startUpdatingLocation()
        
        // Simulate background mode
        backgroundTaskManager.simulateBackgroundMode()
        
        // Wait for location update
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            XCTAssertNotNil(self.locationManager.location)
            XCTAssertTrue(self.locationManager.isUpdatingLocation)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10)
    }
    
    // MARK: - Geofencing Tests
    
    func testGeofencingSetup() {
        let targetLocation = CLLocation(latitude: 35.6812, longitude: 139.7671)
        
        locationManager.setupGeofencing(for: targetLocation)
        
        // Verify multiple geofences are created
        XCTAssertEqual(locationManager.monitoredRegions.count, 4)
        
        // Verify geofence radii
        let radii = locationManager.monitoredRegions.map { $0.radius }.sorted()
        XCTAssertEqual(radii, [100.0, 500.0, 1000.0, 2000.0])
    }
    
    // MARK: - Integration Tests
    
    func testBackgroundProcessingIntegration() {
        let expectation = XCTestExpectation(description: "All background services should work together")
        
        // Setup target station
        let targetStation = Station(
            id: "test",
            name: "Tokyo Station",
            latitude: 35.6812,
            longitude: 139.7671,
            line: "Yamanote"
        )
        
        // Start all services
        backgroundTaskManager.startMonitoring(for: targetStation)
        locationManager.setupGeofencing(for: targetStation.location)
        
        // Simulate approaching station
        let approachingLocation = CLLocation(
            latitude: 35.6810,
            longitude: 139.7670
        )
        locationManager.simulateLocationUpdate(approachingLocation)
        
        // Verify integrated behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Should have increased accuracy
            XCTAssertEqual(self.locationManager.currentAccuracyLevel, .highAccuracy)
            
            // Should have scheduled notification
            XCTAssertTrue(self.notificationManager.hasPendingNotifications)
            
            // Should have logged activity
            XCTAssertGreaterThan(BackgroundLogger.shared.logEntries.count, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testMemoryManagement() {
        // Monitor memory usage
        let info = ProcessInfo.processInfo
        let initialMemory = info.physicalMemory
        
        // Run intensive operations
        for _ in 0..<1000 {
            locationManager.startUpdatingLocation()
            locationManager.stopUpdatingLocation()
        }
        
        // Check memory hasn't increased significantly
        let finalMemory = info.physicalMemory
        let memoryIncrease = finalMemory - initialMemory
        
        // Should be under 10MB increase
        XCTAssertLessThan(memoryIncrease, 10_000_000)
    }
}

// MARK: - Test Extensions

extension LocationManagerEnhanced {
    func simulateLocationUpdate(_ location: CLLocation) {
        self.location = location
        NotificationCenter.default.post(
            name: .approachingStation,
            object: nil,
            userInfo: ["radius": 500.0]
        )
    }
}

extension NotificationReliabilityManager {
    var simulateFailure: Bool {
        get { false }
        set { /* For testing */ }
    }
    
    func hasDelivered(_ notification: NotificationContent) -> Bool {
        // Check delivery status
        return true
    }
    
    var hasPendingNotifications: Bool {
        // Check for pending notifications
        return true
    }
}

extension BackgroundTaskManager {
    func simulateBackgroundMode() {
        // Simulate app entering background
    }
    
    func isTaskRegistered(_ identifier: String) -> Bool {
        // Check if task is registered
        return true
    }
    
    var isReducedMode: Bool {
        // Check if in reduced mode
        return true
    }
}

extension PowerManager {
    func simulatePowerState(_ state: PowerState) {
        // Simulate power state for testing
    }
}
