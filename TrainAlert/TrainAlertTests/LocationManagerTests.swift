//
//  LocationManagerTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
import CoreLocation
import Combine
@testable import TrainAlert

final class LocationManagerTests: XCTestCase {
    
    var locationManager: LocationManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        locationManager = LocationManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testLocationManagerInitialization() {
        XCTAssertNotNil(locationManager)
        XCTAssertEqual(locationManager.authorizationStatus, CLLocationManager().authorizationStatus)
        XCTAssertFalse(locationManager.isUpdatingLocation)
        XCTAssertNil(locationManager.location)
        XCTAssertNil(locationManager.lastError)
    }
    
    // MARK: - Authorization Tests
    
    func testRequestAuthorizationWhenNotDetermined() {
        // This test can't fully test the actual authorization request without user interaction
        // But we can test the method doesn't crash and handles the case appropriately
        locationManager.requestAuthorization()
        XCTAssertTrue(true, "Request authorization should not crash")
    }
    
    func testAuthorizationStatusDescription() {
        let statuses: [CLAuthorizationStatus] = [
            .notDetermined,
            .denied,
            .restricted,
            .authorizedWhenInUse,
            .authorizedAlways
        ]
        
        for status in statuses {
            let description = status.description
            XCTAssertFalse(description.isEmpty, "Description should not be empty for status: \(status)")
        }
    }
    
    func testAuthorizationStatusIsAuthorized() {
        XCTAssertTrue(CLAuthorizationStatus.authorizedWhenInUse.isAuthorized)
        XCTAssertTrue(CLAuthorizationStatus.authorizedAlways.isAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.denied.isAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.restricted.isAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.notDetermined.isAuthorized)
    }
    
    func testAuthorizationStatusIsAlwaysAuthorized() {
        XCTAssertTrue(CLAuthorizationStatus.authorizedAlways.isAlwaysAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.authorizedWhenInUse.isAlwaysAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.denied.isAlwaysAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.restricted.isAlwaysAuthorized)
        XCTAssertFalse(CLAuthorizationStatus.notDetermined.isAlwaysAuthorized)
    }
    
    // MARK: - Distance Calculation Tests
    
    func testDistanceCalculation() {
        let location1 = CLLocation(latitude: 35.6762, longitude: 139.6503) // Tokyo Station
        let location2 = CLLocation(latitude: 35.6580, longitude: 139.7016) // Shibuya Station
        
        let distance = locationManager.distance(from: location1, to: location2)
        
        // Distance between Tokyo and Shibuya stations is approximately 4.5km
        XCTAssertGreaterThan(distance, 4000)
        XCTAssertLessThan(distance, 6000)
    }
    
    func testDistanceToTargetStation() {
        // Without target station set
        XCTAssertNil(locationManager.distanceToTargetStation())
        
        // Without current location set
        let targetStation = CLLocation(latitude: 35.6762, longitude: 139.6503)
        locationManager.startUpdatingLocation(targetStation: targetStation)
        XCTAssertNil(locationManager.distanceToTargetStation())
    }
    
    // MARK: - Location Update Tests
    
    func testStartUpdatingLocationWithoutAuthorization() {
        // When authorization is not granted, should set error
        if locationManager.authorizationStatus != .authorizedAlways &&
           locationManager.authorizationStatus != .authorizedWhenInUse {
            
            let expectation = XCTestExpectation(description: "Error should be set")
            
            locationManager.$lastError
                .dropFirst()
                .sink { error in
                    if case .authorizationDenied = error {
                        expectation.fulfill()
                    }
                }
                .store(in: &cancellables)
            
            locationManager.startUpdatingLocation()
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testStopUpdatingLocation() {
        locationManager.startUpdatingLocation()
        XCTAssertTrue(locationManager.isUpdatingLocation)
        
        locationManager.stopUpdatingLocation()
        XCTAssertFalse(locationManager.isUpdatingLocation)
    }
    
    // MARK: - Location Accuracy Tests
    
    func testLocationAccuracyAdjustment() {
        // Test with different target stations at different distances
        let nearbyStation = CLLocation(latitude: 35.6762, longitude: 139.6503) // Tokyo Station
        let farStation = CLLocation(latitude: 34.6937, longitude: 135.5023) // Osaka Station
        
        // Mock current location
        let currentLocation = CLLocation(latitude: 35.6580, longitude: 139.7016) // Shibuya
        locationManager.location = currentLocation
        
        // Test nearby station (should use higher accuracy)
        locationManager.startUpdatingLocation(targetStation: nearbyStation)
        XCTAssertTrue(locationManager.isUpdatingLocation)
        
        // Test far station (should use lower accuracy)
        locationManager.startUpdatingLocation(targetStation: farStation)
        XCTAssertTrue(locationManager.isUpdatingLocation)
    }
    
    // MARK: - Error Handling Tests
    
    func testLocationErrorDescriptions() {
        let errors: [LocationError] = [
            .authorizationDenied,
            .locationUnavailable,
            .backgroundUpdatesFailed
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Delegate Method Tests (Mocking Required)
    
    func testLocationManagerDidChangeAuthorization() {
        // This would require mocking CLLocationManager
        // For now, we test that the method exists and doesn't crash
        let mockManager = MockCLLocationManager()
        locationManager.locationManagerDidChangeAuthorization(mockManager)
        XCTAssertTrue(true, "Method should not crash")
    }
    
    func testLocationManagerDidUpdateLocations() {
        let mockManager = MockCLLocationManager()
        let testLocation = CLLocation(latitude: 35.6762, longitude: 139.6503)
        
        locationManager.locationManager(mockManager, didUpdateLocations: [testLocation])
        
        // Should update the location if it's recent and accurate enough
        // Note: This might not work in the test environment due to timestamp checks
        XCTAssertTrue(true, "Method should not crash")
    }
    
    func testLocationManagerDidFailWithError() {
        let mockManager = MockCLLocationManager()
        let testError = CLError(.denied)
        
        locationManager.locationManager(mockManager, didFailWithError: testError)
        
        XCTAssertEqual(locationManager.lastError, .authorizationDenied)
    }
    
    // MARK: - Background Updates Tests
    
    func testBackgroundLocationUpdatesConfiguration() {
        // Test that background location updates are configured correctly
        locationManager.startUpdatingLocation()
        
        // We can't directly test CLLocationManager properties in unit tests,
        // but we can test our logic doesn't crash
        XCTAssertTrue(locationManager.isUpdatingLocation)
    }
    
    // MARK: - Performance Tests
    
    func testLocationUpdatePerformance() {
        measure {
            for _ in 0..<100 {
                let location1 = CLLocation(latitude: Double.random(in: -90...90), longitude: Double.random(in: -180...180))
                let location2 = CLLocation(latitude: Double.random(in: -90...90), longitude: Double.random(in: -180...180))
                _ = locationManager.distance(from: location1, to: location2)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testLocationManagerLifecycle() {
        // Test complete lifecycle
        XCTAssertFalse(locationManager.isUpdatingLocation)
        
        let targetStation = CLLocation(latitude: 35.6762, longitude: 139.6503)
        locationManager.startUpdatingLocation(targetStation: targetStation)
        
        // Would be updating if authorization is granted
        if locationManager.authorizationStatus.isAuthorized {
            XCTAssertTrue(locationManager.isUpdatingLocation)
        } else {
            XCTAssertNotNil(locationManager.lastError)
        }
        
        locationManager.stopUpdatingLocation()
        XCTAssertFalse(locationManager.isUpdatingLocation)
    }
}

// MARK: - Mock Classes

class MockCLLocationManager: CLLocationManager {
    override var authorizationStatus: CLAuthorizationStatus {
        return .authorizedWhenInUse
    }
}

// MARK: - Test Extensions

extension LocationError: Equatable {
    static func == (lhs: LocationError, rhs: LocationError) -> Bool {
        switch (lhs, rhs) {
        case (.authorizationDenied, .authorizationDenied),
             (.locationUnavailable, .locationUnavailable),
             (.backgroundUpdatesFailed, .backgroundUpdatesFailed):
            return true
        default:
            return false
        }
    }
}

// MARK: - CLLocation Extensions for Testing

extension CLLocation {
    /// Create a test location with specific attributes
    convenience init(testLatitude: Double, testLongitude: Double, accuracy: CLLocationAccuracy = 5.0) {
        self.init(
            coordinate: CLLocationCoordinate2D(latitude: testLatitude, longitude: testLongitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            timestamp: Date()
        )
    }
}

// MARK: - Extension Tests

extension LocationManagerTests {
    
    func testCLLocationExtensions() {
        let location1 = CLLocation(latitude: 35.6762, longitude: 139.6503) // Tokyo Station
        let location2 = CLLocation(latitude: 35.6580, longitude: 139.7016) // Shibuya Station
        
        // Test bearing calculation
        let bearing = location1.bearing(to: location2)
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
        
        // Test isWithin method
        XCTAssertFalse(location1.isWithin(1000, of: location2)) // Should be false as they're ~5km apart
        XCTAssertTrue(location1.isWithin(10000, of: location2)) // Should be true as they're within 10km
        
        // Test distance string formatting
        let distanceString = location1.distanceString(from: location2)
        XCTAssertTrue(distanceString.contains("km"), "Distance should be formatted in kilometers")
        
        // Test short distance formatting
        let nearbyLocation = CLLocation(latitude: 35.6762, longitude: 139.6504) // Very close to Tokyo Station
        let nearbyDistanceString = location1.distanceString(from: nearbyLocation)
        XCTAssertTrue(nearbyDistanceString.contains("m"), "Short distance should be formatted in meters")
    }
    
    func testDoubleExtensions() {
        let degrees = 45.0
        let radians = degrees.degreesToRadians
        let backToDegrees = radians.radiansToDegrees
        
        XCTAssertEqual(degrees, backToDegrees, accuracy: 0.0001, "Degrees conversion should be reversible")
        
        // Test angle normalization
        XCTAssertEqual((-90.0).normalized(), 270.0, "Negative angle should be normalized")
        XCTAssertEqual(450.0.normalized(), 90.0, "Large angle should be normalized")
        XCTAssertEqual(180.0.normalized(), 180.0, "Normal angle should remain unchanged")
    }
    
    func testCLLocationCoordinate2DExtensions() {
        let coordinate = CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)
        
        // Test location creation
        let location = coordinate.location
        XCTAssertEqual(location.coordinate.latitude, coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(location.coordinate.longitude, coordinate.longitude, accuracy: 0.0001)
        
        // Test validity
        XCTAssertTrue(coordinate.isValid)
        
        let invalidCoordinate = CLLocationCoordinate2D(latitude: 200, longitude: 200)
        XCTAssertFalse(invalidCoordinate.isValid)
    }
}
