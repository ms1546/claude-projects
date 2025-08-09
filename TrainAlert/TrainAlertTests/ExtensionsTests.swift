//
//  ExtensionsTests.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import XCTest
import SwiftUI
import CoreLocation
@testable import TrainAlert

final class ExtensionsTests: XCTestCase {
    
    // MARK: - Color Extension Tests
    
    func testColorFromHex3Digits() {
        let color = Color(hex: "#F00") // Red
        XCTAssertNotNil(color)
        
        // Test without # prefix
        let colorWithoutHash = Color(hex: "00F") // Blue
        XCTAssertNotNil(colorWithoutHash)
    }
    
    func testColorFromHex6Digits() {
        let color = Color(hex: "#FF0000") // Red
        XCTAssertNotNil(color)
        
        // Test without # prefix
        let colorWithoutHash = Color(hex: "00FF00") // Green
        XCTAssertNotNil(colorWithoutHash)
    }
    
    func testColorFromHex8Digits() {
        let color = Color(hex: "#FF0000FF") // Red with full alpha
        XCTAssertNotNil(color)
        
        let colorWithAlpha = Color(hex: "FF000080") // Red with 50% alpha
        XCTAssertNotNil(colorWithAlpha)
    }
    
    func testColorFromInvalidHex() {
        let color = Color(hex: "invalid")
        XCTAssertNotNil(color) // Should still create a color (default values)
        
        let emptyColor = Color(hex: "")
        XCTAssertNotNil(emptyColor)
    }
    
    func testPredefinedColors() {
        // Test that predefined colors exist and are not nil
        XCTAssertNotNil(Color.darkNavy)
        XCTAssertNotNil(Color.charcoalGray)
        XCTAssertNotNil(Color.softBlue)
        XCTAssertNotNil(Color.warmOrange)
        XCTAssertNotNil(Color.mintGreen)
        XCTAssertNotNil(Color.lightGray)
        XCTAssertNotNil(Color.mediumGray)
    }
    
    // MARK: - CLLocation Extension Tests
    
    func testLocationBearing() {
        let tokyoStation = CLLocation(latitude: 35.6812, longitude: 139.7673)
        let shibuyaStation = CLLocation(latitude: 35.6580, longitude: 139.7016)
        
        let bearing = tokyoStation.bearing(to: shibuyaStation)
        
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
        
        // Bearing from Tokyo to Shibuya should be roughly southwest
        XCTAssertGreaterThan(bearing, 180)
        XCTAssertLessThan(bearing, 270)
    }
    
    func testLocationIsWithinRadius() {
        let centerLocation = CLLocation(latitude: 35.6812, longitude: 139.7673) // Tokyo Station
        let nearbyLocation = CLLocation(latitude: 35.6751, longitude: 139.7630) // Yurakucho (very close)
        let farLocation = CLLocation(latitude: 35.6580, longitude: 139.7016) // Shibuya (about 5km away)
        
        XCTAssertTrue(centerLocation.isWithin(1000, of: nearbyLocation)) // Within 1km
        XCTAssertFalse(centerLocation.isWithin(1000, of: farLocation)) // More than 1km away
        XCTAssertTrue(centerLocation.isWithin(10000, of: farLocation)) // Within 10km
    }
    
    func testLocationDistanceString() {
        let location1 = CLLocation(latitude: 35.6812, longitude: 139.7673)
        let location2 = CLLocation(latitude: 35.6580, longitude: 139.7016)
        
        let distanceString = location1.distanceString(from: location2)
        
        // Should be formatted in kilometers since it's > 1km
        XCTAssertTrue(distanceString.contains("km"))
        
        // Test short distance
        let nearbyLocation = CLLocation(latitude: 35.6810, longitude: 139.7670) // Very close
        let shortDistanceString = location1.distanceString(from: nearbyLocation)
        
        // Should be formatted in meters
        XCTAssertTrue(shortDistanceString.contains("m"))
        XCTAssertFalse(shortDistanceString.contains("km"))
    }
    
    // MARK: - Double Extension Tests
    
    func testDegreesToRadiansConversion() {
        let degrees = 180.0
        let radians = degrees.degreesToRadians
        
        XCTAssertEqual(radians, Double.pi, accuracy: 0.0001)
        
        let degrees90 = 90.0
        let radians90 = degrees90.degreesToRadians
        
        XCTAssertEqual(radians90, Double.pi / 2, accuracy: 0.0001)
    }
    
    func testRadiansToDegreesConversion() {
        let radians = Double.pi
        let degrees = radians.radiansToDegrees
        
        XCTAssertEqual(degrees, 180.0, accuracy: 0.0001)
        
        let radiansPiHalf = Double.pi / 2
        let degrees90 = radiansPiHalf.radiansToDegrees
        
        XCTAssertEqual(degrees90, 90.0, accuracy: 0.0001)
    }
    
    func testAngleNormalization() {
        // Test positive overflow
        let angle450 = 450.0.normalized()
        XCTAssertEqual(angle450, 90.0, accuracy: 0.0001)
        
        // Test negative angle
        let angleMinus90 = (-90.0).normalized()
        XCTAssertEqual(angleMinus90, 270.0, accuracy: 0.0001)
        
        // Test normal angle (should remain unchanged)
        let angle180 = 180.0.normalized()
        XCTAssertEqual(angle180, 180.0, accuracy: 0.0001)
        
        // Test zero
        let angle0 = 0.0.normalized()
        XCTAssertEqual(angle0, 0.0, accuracy: 0.0001)
        
        // Test 360 (should become 0)
        let angle360 = 360.0.normalized()
        XCTAssertEqual(angle360, 0.0, accuracy: 0.0001)
    }
    
    // MARK: - CLLocationCoordinate2D Extension Tests
    
    func testCoordinateLocation() {
        let coordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7673)
        let location = coordinate.location
        
        XCTAssertEqual(location.coordinate.latitude, coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(location.coordinate.longitude, coordinate.longitude, accuracy: 0.0001)
    }
    
    func testCoordinateIsValid() {
        // Valid coordinates
        let validCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7673)
        XCTAssertTrue(validCoordinate.isValid)
        
        // Invalid coordinates (out of range)
        let invalidLatitude = CLLocationCoordinate2D(latitude: 200.0, longitude: 139.7673)
        XCTAssertFalse(invalidLatitude.isValid)
        
        let invalidLongitude = CLLocationCoordinate2D(latitude: 35.6812, longitude: 200.0)
        XCTAssertFalse(invalidLongitude.isValid)
        
        // Edge cases
        let edgeCoordinate = CLLocationCoordinate2D(latitude: 90.0, longitude: 180.0)
        XCTAssertTrue(edgeCoordinate.isValid)
    }
    
    // MARK: - CLAuthorizationStatus Extension Tests
    
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
            XCTAssertTrue(description.contains("位置情報"), "Description should mention location services in Japanese")
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
    
    // MARK: - Date Extension Tests
    
    func testDateTimeString() {
        let date = Date()
        let timeString = date.timeString
        
        XCTAssertFalse(timeString.isEmpty)
        // Should contain time indicators (could be AM/PM or 24-hour format)
        XCTAssertTrue(timeString.count >= 4) // At least "HH:MM" format
    }
    
    func testDateIsWithinLastMinutes() {
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-5 * 60)
        let tenMinutesAgo = now.addingTimeInterval(-10 * 60)
        
        XCTAssertTrue(fiveMinutesAgo.isWithinLast(minutes: 10))
        XCTAssertFalse(tenMinutesAgo.isWithinLast(minutes: 5))
        XCTAssertTrue(now.isWithinLast(minutes: 1))
    }
    
    // MARK: - String Extension Tests
    
    func testStringTruncated() {
        let longString = "これは非常に長い文字列のテストです。文字数制限のテストを行います。"
        let shortString = "短い文字列"
        
        let truncated = longString.truncated(to: 10)
        XCTAssertEqual(truncated.count, 13) // 10 characters + "..."
        XCTAssertTrue(truncated.hasSuffix("..."))
        
        let notTruncated = shortString.truncated(to: 20)
        XCTAssertEqual(notTruncated, shortString)
        XCTAssertFalse(notTruncated.hasSuffix("..."))
        
        // Edge case: empty string
        let emptyTruncated = "".truncated(to: 5)
        XCTAssertEqual(emptyTruncated, "")
        
        // Edge case: exactly at limit
        let exactLengthString = "12345"
        let exactTruncated = exactLengthString.truncated(to: 5)
        XCTAssertEqual(exactTruncated, exactLengthString)
    }
    
    // MARK: - Performance Tests
    
    func testColorCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let hexValue = String(format: "#%06X", i % 0xFFFFFF)
                _ = Color(hex: hexValue)
            }
        }
    }
    
    func testLocationDistanceCalculationPerformance() {
        let locations = (0..<1000).map { i in
            CLLocation(
                latitude: 35.0 + Double(i) * 0.001,
                longitude: 139.0 + Double(i) * 0.001
            )
        }
        
        let referenceLocation = CLLocation(latitude: 35.6812, longitude: 139.7673)
        
        measure {
            for location in locations {
                _ = referenceLocation.bearing(to: location)
                _ = referenceLocation.distanceString(from: location)
                _ = referenceLocation.isWithin(1000, of: location)
            }
        }
    }
    
    func testAngleConversionPerformance() {
        let angles = (0..<10000).map { Double($0) * 0.1 }
        
        measure {
            for angle in angles {
                _ = angle.degreesToRadians
                _ = angle.radiansToDegrees
                _ = angle.normalized()
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testBearingWithSameLocation() {
        let location = CLLocation(latitude: 35.6812, longitude: 139.7673)
        let bearing = location.bearing(to: location)
        
        // Bearing to the same location should be 0 or handle gracefully
        XCTAssertGreaterThanOrEqual(bearing, 0)
        XCTAssertLessThan(bearing, 360)
    }
    
    func testDistanceStringWithZeroDistance() {
        let location = CLLocation(latitude: 35.6812, longitude: 139.7673)
        let distanceString = location.distanceString(from: location)
        
        XCTAssertTrue(distanceString.contains("0") || distanceString.contains("1"))
        XCTAssertTrue(distanceString.contains("m"))
    }
    
    func testNormalizationWithExtremeValues() {
        let extremePositive = 3600.0.normalized() // 10 full rotations
        XCTAssertEqual(extremePositive, 0.0, accuracy: 0.0001)
        
        let extremeNegative = (-720.0).normalized() // -2 full rotations
        XCTAssertEqual(extremeNegative, 0.0, accuracy: 0.0001)
        
        let largeAngle = 1234567.0.normalized()
        XCTAssertGreaterThanOrEqual(largeAngle, 0.0)
        XCTAssertLessThan(largeAngle, 360.0)
    }
    
    // MARK: - Boundary Value Tests
    
    func testLocationWithBoundaryCoordinates() {
        // Test with extreme valid coordinates
        let northPole = CLLocation(latitude: 90.0, longitude: 0.0)
        let southPole = CLLocation(latitude: -90.0, longitude: 0.0)
        let eastBoundary = CLLocation(latitude: 0.0, longitude: 180.0)
        let westBoundary = CLLocation(latitude: 0.0, longitude: -180.0)
        
        let bearing1 = northPole.bearing(to: southPole)
        let bearing2 = eastBoundary.bearing(to: westBoundary)
        
        XCTAssertGreaterThanOrEqual(bearing1, 0)
        XCTAssertLessThan(bearing1, 360)
        XCTAssertGreaterThanOrEqual(bearing2, 0)
        XCTAssertLessThan(bearing2, 360)
        
        let distance = northPole.distanceString(from: southPole)
        XCTAssertFalse(distance.isEmpty)
    }
    
    func testStringTruncationBoundaries() {
        let testString = "1234567890"
        
        // Truncate to 0 (edge case)
        let truncated0 = testString.truncated(to: 0)
        XCTAssertEqual(truncated0, "...")
        
        // Truncate to 1
        let truncated1 = testString.truncated(to: 1)
        XCTAssertEqual(truncated1, "1...")
        
        // Truncate to exact length
        let truncated10 = testString.truncated(to: 10)
        XCTAssertEqual(truncated10, testString)
        
        // Truncate to more than length
        let truncated20 = testString.truncated(to: 20)
        XCTAssertEqual(truncated20, testString)
    }
}
