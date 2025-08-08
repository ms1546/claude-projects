//
//  TestHelpers.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import XCTest
import CoreLocation
import CoreData
@testable import TrainAlert

// MARK: - Test Assertion Helpers

/// Custom assertions for testing location-based functionality
struct LocationTestAssertions {
    
    /// Assert that two coordinates are approximately equal within a tolerance
    static func XCTAssertCoordinatesEqual(
        _ coordinate1: CLLocationCoordinate2D,
        _ coordinate2: CLLocationCoordinate2D,
        accuracy: Double = 0.0001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(coordinate1.latitude, coordinate2.latitude, accuracy: accuracy, 
                      "Latitudes should be equal", file: file, line: line)
        XCTAssertEqual(coordinate1.longitude, coordinate2.longitude, accuracy: accuracy,
                      "Longitudes should be equal", file: file, line: line)
    }
    
    /// Assert that a location is within a specified distance of a target
    static func XCTAssertLocationWithinDistance(
        _ location: CLLocation,
        of target: CLLocation,
        distance: CLLocationDistance,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualDistance = location.distance(from: target)
        XCTAssertLessThanOrEqual(actualDistance, distance,
                                "Location should be within \(distance)m of target (actual: \(actualDistance)m)",
                                file: file, line: line)
    }
    
    /// Assert that a coordinate is valid
    static func XCTAssertValidCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate),
                     "Coordinate should be valid", file: file, line: line)
        
        // Check reasonable bounds for Japan
        XCTAssertTrue((24.0...46.0).contains(coordinate.latitude),
                     "Latitude should be within Japan bounds", file: file, line: line)
        XCTAssertTrue((123.0...146.0).contains(coordinate.longitude),
                     "Longitude should be within Japan bounds", file: file, line: line)
    }
}

/// Custom assertions for testing API responses
struct APITestAssertions {
    
    /// Assert that an API response contains expected station data
    static func XCTAssertValidStationResponse(
        _ stations: [Station],
        minCount: Int = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(stations.count, minCount,
                                   "Should have at least \(minCount) stations", file: file, line: line)
        
        for (index, station) in stations.enumerated() {
            XCTAssertFalse(station.id.isEmpty, "Station \(index) should have valid ID", file: file, line: line)
            XCTAssertFalse(station.name.isEmpty, "Station \(index) should have valid name", file: file, line: line)
            XCTAssertFalse(station.lines.isEmpty, "Station \(index) should have lines", file: file, line: line)
            LocationTestAssertions.XCTAssertValidCoordinate(station.coordinate, file: file, line: line)
        }
    }
    
    /// Assert that an error is of the expected API error type
    static func XCTAssertAPIError<T: Error & Equatable>(
        _ error: Error,
        equals expectedError: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actualError = error as? T else {
            XCTFail("Expected \(type(of: expectedError)) but got \(type(of: error))", file: file, line: line)
            return
        }
        XCTAssertEqual(actualError, expectedError, file: file, line: line)
    }
}

/// Custom assertions for testing notifications
struct NotificationTestAssertions {
    
    /// Assert that notification content is properly formatted
    static func XCTAssertValidNotificationContent(
        _ content: NotificationContent,
        expectedStation: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(content.title.isEmpty, "Title should not be empty", file: file, line: line)
        XCTAssertFalse(content.body.isEmpty, "Body should not be empty", file: file, line: line)
        XCTAssertTrue(content.body.count >= 10, "Body should have meaningful content", file: file, line: line)
        XCTAssertTrue(content.body.count <= 200, "Body should not be too long", file: file, line: line)
        
        if let expectedStation = expectedStation {
            XCTAssertTrue(content.body.contains(expectedStation) || content.title.contains(expectedStation),
                         "Content should mention station name", file: file, line: line)
        }
        
        XCTAssertFalse(content.categoryIdentifier.isEmpty, "Category should be set", file: file, line: line)
    }
    
    /// Assert that character-specific messages match expected style
    static func XCTAssertCharacterStyleMessage(
        _ message: String,
        matchesStyle style: CharacterStyle,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch style {
        case .gyaru:
            let hasGyaruExpressions = message.contains("だよ") || message.contains("じゃん") || message.contains("マジ")
            XCTAssertTrue(hasGyaruExpressions, "Message should contain gyaru-style expressions", file: file, line: line)
            
        case .butler:
            let hasButlerExpressions = message.contains("いたします") || message.contains("ございます") || message.contains("でございます")
            XCTAssertTrue(hasButlerExpressions, "Message should contain butler-style expressions", file: file, line: line)
            
        case .kansai:
            let hasKansaiExpressions = message.contains("やで") || message.contains("あかん") || message.contains("せん")
            XCTAssertTrue(hasKansaiExpressions, "Message should contain Kansai-style expressions", file: file, line: line)
            
        case .tsundere:
            let hasTsundereExpressions = message.contains("べつに") || message.contains("別に") || message.contains("じゃない")
            XCTAssertTrue(hasTsundereExpressions, "Message should contain tsundere-style expressions", file: file, line: line)
            
        case .sporty:
            let hasSportyExpressions = message.contains("よし") || message.contains("頑張") || message.contains("ファイト")
            XCTAssertTrue(hasSportyExpressions, "Message should contain sporty-style expressions", file: file, line: line)
            
        case .healing:
            let hasHealingExpressions = message.contains("ですね") || message.contains("でしょうか") || message.contains("ゆっくり")
            XCTAssertTrue(hasHealingExpressions, "Message should contain healing-style expressions", file: file, line: line)
        }
    }
}

// MARK: - Test Timing Helpers

/// Utilities for testing time-based functionality
struct TimeTestHelpers {
    
    /// Create a date in the future for testing
    static func futureDate(minutesFromNow minutes: Int) -> Date {
        return Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    /// Create a date in the past for testing
    static func pastDate(minutesAgo minutes: Int) -> Date {
        return Date().addingTimeInterval(-TimeInterval(minutes * 60))
    }
    
    /// Wait for async operations with timeout
    static func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withTimeout(seconds: timeout) {
            return try await operation()
        }
    }
    
    private static func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
}

struct TimeoutError: Error {}

// MARK: - Mock Data Helpers

/// Utilities for creating and managing mock data
struct MockDataHelpers {
    
    /// Setup mock API responses for testing
    static func setupMockAPIClient(_ client: MockStationAPIClient) {
        client.shouldFailRequests = false
        client.shouldReturnEmptyResults = false
        client.mockDelay = 0.1
        
        // Add comprehensive test stations
        let testStations = TestDataFactory.createTestStations()
        for station in testStations {
            client.addMockStation(station)
        }
    }
    
    /// Setup mock OpenAI client for testing  
    static func setupMockOpenAIClient(_ client: MockOpenAIClient) {
        client.hasValidAPIKey = true
        client.shouldFailRequests = false
        client.mockDelay = 0.1
        
        // Add variety of mock responses
        let responses = [
            "もうすぐ{station}だよ〜！起きなきゃ！",
            "{station}にまもなく到着いたします。",
            "{station}着くで〜！準備しいや〜",
            "べ、別に{station}よ！起きなさいよ！",
            "よし！{station}到着だ！気合い入れろ！",
            "{station}ですね。ゆっくり起きてください。"
        ]
        
        for response in responses {
            client.addMockResponse(response)
        }
    }
    
    /// Setup mock notification manager for testing
    static func setupMockNotificationManager(_ manager: MockNotificationManager) {
        manager.shouldGrantPermission = true
        manager.shouldFailRequests = false
        manager.mockDelay = 0.1
        manager.isPermissionGranted = true
        manager.authorizationStatus = .authorized
    }
    
    /// Setup mock location manager for testing
    static func setupMockLocationManager(_ manager: MockLocationManager) {
        manager.shouldDenyAuthorization = false
        manager.shouldFailLocationUpdates = false
        manager.authorizationStatus = .authorizedAlways
        manager.mockLocation = CLLocation(latitude: 35.6812, longitude: 139.7673) // Tokyo Station
    }
}

// MARK: - Core Data Test Helpers

/// Utilities for testing Core Data functionality
struct CoreDataTestHelpers {
    
    /// Create a test Core Data stack in memory
    static func createInMemoryTestStack() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "TrainAlert")
        
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to create in-memory Core Data stack: \(error)")
            }
        }
        
        return container
    }
    
    /// Populate Core Data with test data
    static func populateTestData(in context: NSManagedObjectContext) {
        let testStations = TestDataFactory.createTestStations()
        let testHistory = TestDataFactory.createMockHistory()
        
        // Create stations
        var stationEntities: [Station] = []
        for station in testStations {
            let entity = Station(context: context)
            entity.stationId = station.id
            entity.name = station.name
            entity.latitude = station.latitude
            entity.longitude = station.longitude
            entity.lines = station.lines.joined(separator: ",")
            entity.isFavorite = Bool.random()
            entity.lastUsedAt = Date()
            
            stationEntities.append(entity)
        }
        
        // Create alerts
        for (index, stationEntity) in stationEntities.enumerated() where index < 3 {
            let alert = Alert(context: context)
            alert.alertId = UUID()
            alert.station = stationEntity
            alert.notificationTime = Int16.random(in: 1...10)
            alert.notificationDistance = Double.random(in: 100...1000)
            alert.snoozeInterval = Int16.random(in: 1...10)
            alert.characterStyle = CharacterStyle.allCases.randomElement()?.rawValue
            alert.isActive = true
            alert.createdAt = Date()
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            fatalError("Failed to save test data: \(error)")
        }
    }
    
    /// Clean up Core Data context
    static func cleanupTestData(in context: NSManagedObjectContext) {
        let entityNames = ["Station", "Alert", "History"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let objects = try context.fetch(fetchRequest)
                for object in objects {
                    context.delete(object)
                }
            } catch {
                print("Failed to cleanup \(entityName): \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save cleanup: \(error)")
        }
    }
}

// MARK: - Performance Test Helpers

/// Utilities for performance testing
struct PerformanceTestHelpers {
    
    /// Measure the execution time of a block
    static func measureTime<T>(operation: () throws -> T) rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Measure async operation time
    static func measureAsyncTime<T>(operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, timeElapsed)
    }
    
    /// Create a large dataset for performance testing
    static func createLargeTestDataset(size: Int) -> [Station] {
        return TestDataFactory.createLargeDataset(count: size)
    }
    
    /// Simulate memory pressure for testing
    static func simulateMemoryPressure() {
        // Create temporary large objects to simulate memory pressure
        let _ = Array(repeating: Data(count: 1024 * 1024), count: 50) // 50MB
    }
}

// MARK: - UI Test Helpers

/// Utilities for UI testing
struct UITestHelpers {
    
    /// Wait for UI element to appear
    static func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10.0
    ) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    /// Perform scroll action until element is visible
    static func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        var attempts = 0
        let maxAttempts = 10
        
        while !element.isHittable && attempts < maxAttempts {
            scrollView.swipeUp()
            attempts += 1
        }
    }
    
    /// Clear and enter text in a text field
    static func clearAndEnterText(in textField: XCUIElement, text: String) {
        textField.tap()
        
        // Select all existing text
        textField.press(forDuration: 1.0)
        
        // Delete existing text
        if let currentValue = textField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            textField.typeText(deleteString)
        }
        
        // Enter new text
        textField.typeText(text)
    }
    
    /// Verify accessibility properties
    static func verifyAccessibility(for element: XCUIElement) -> Bool {
        guard element.isAccessibilityElement else {
            return false
        }
        
        guard let label = element.accessibilityLabel, !label.isEmpty else {
            return false
        }
        
        return true
    }
}

// MARK: - Test Configuration

/// Configuration for test environment
struct TestConfiguration {
    static let defaultTimeout: TimeInterval = 10.0
    static let networkTimeout: TimeInterval = 30.0
    static let animationTimeout: TimeInterval = 2.0
    
    /// Test data file paths
    enum TestDataPath {
        static let mockResponses = "MockResponses"
        static let testImages = "TestImages"
        static let testAudio = "TestAudio"
    }
    
    /// Test user defaults suite
    static let testUserDefaultsSuite = "com.trainAlert.tests"
    
    /// Test Core Data model name
    static let testModelName = "TrainAlertTest"
}

// MARK: - Debug Helpers

/// Utilities for debugging tests
struct DebugHelpers {
    
    /// Print detailed information about a test failure
    static func printTestFailureInfo(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        print("🚨 TEST FAILURE")
        print("File: \(URL(fileURLWithPath: file).lastPathComponent)")
        print("Function: \(function)")
        print("Line: \(line)")
        print("Message: \(message)")
        print("Timestamp: \(Date())")
        print("---")
    }
    
    /// Log test execution flow
    static func logTestStep(_ step: String) {
        print("📝 Test Step: \(step)")
    }
    
    /// Print memory usage information
    static func printMemoryUsage() {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .memory
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = formatter.string(fromByteCount: Int64(info.resident_size))
            print("💾 Memory Usage: \(memoryUsage)")
        }
    }
}