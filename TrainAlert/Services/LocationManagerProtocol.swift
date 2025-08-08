//
//  LocationManagerProtocol.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation
import Combine

/// Protocol defining location management capabilities
protocol LocationManagerProtocol: ObservableObject {
    // MARK: - Published Properties
    var location: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isUpdatingLocation: Bool { get }
    var lastError: LocationError? { get }
    var isInPowerSaveMode: Bool { get }
    var batteryLevel: Float { get }
    
    // MARK: - Methods
    
    /// Request location permission
    func requestLocationPermission()
    
    /// Start location updates with specified accuracy
    /// - Parameter accuracy: Desired location accuracy
    func startLocationUpdates(accuracy: CLLocationAccuracy)
    
    /// Stop location updates
    func stopLocationUpdates()
    
    /// Setup geofence around target station
    /// - Parameters:
    ///   - location: Station location
    ///   - radius: Geofence radius in meters
    ///   - identifier: Unique identifier for the geofence
    func setupGeofence(location: CLLocation, radius: CLLocationDistance, identifier: String)
    
    /// Remove geofence
    /// - Parameter identifier: Geofence identifier to remove
    func removeGeofence(identifier: String)
    
    /// Start monitoring significant location changes
    func startSignificantLocationChanges()
    
    /// Stop monitoring significant location changes
    func stopSignificantLocationChanges()
    
    /// Calculate distance to target station
    /// - Parameter station: Target station location
    /// - Returns: Distance in meters, nil if current location unavailable
    func distanceToStation(_ station: CLLocation) -> CLLocationDistance?
    
    /// Adjust location accuracy based on battery level and distance
    /// - Parameters:
    ///   - distance: Distance to target station
    ///   - batteryLevel: Current battery level (0.0-1.0)
    func adjustAccuracyForDistance(_ distance: CLLocationDistance, batteryLevel: Float)
    
    /// Enable background location updates
    func enableBackgroundLocationUpdates() throws
    
    /// Disable background location updates
    func disableBackgroundLocationUpdates()
}

/// Extended protocol for enhanced location features
protocol LocationManagerEnhancedProtocol: LocationManagerProtocol {
    // MARK: - Advanced Properties
    var geofenceRegions: [CLRegion] { get }
    var isMonitoringSignificantChanges: Bool { get }
    var currentAccuracy: CLLocationAccuracy { get }
    var locationUpdateCount: Int { get }
    var averageAccuracy: CLLocationAccuracy { get }
    
    // MARK: - Advanced Methods
    
    /// Get location history for analysis
    /// - Parameter limit: Maximum number of locations to return
    /// - Returns: Array of recent locations
    func getLocationHistory(limit: Int) -> [CLLocation]
    
    /// Calculate optimal update interval based on movement pattern
    /// - Returns: Recommended update interval in seconds
    func calculateOptimalUpdateInterval() -> TimeInterval
    
    /// Determine if device is stationary
    /// - Returns: True if device hasn't moved significantly
    func isDeviceStationary() -> Bool
    
    /// Get movement speed estimate
    /// - Returns: Speed in meters per second, nil if insufficient data
    func getMovementSpeed() -> CLLocationSpeed?
    
    /// Setup adaptive monitoring based on context
    /// - Parameters:
    ///   - targetStation: Destination station
    ///   - departureTime: Expected departure time
    ///   - travelDuration: Expected travel time
    func setupAdaptiveMonitoring(
        targetStation: CLLocation,
        departureTime: Date,
        travelDuration: TimeInterval
    )
    
    /// Handle low power mode changes
    /// - Parameter isEnabled: True if low power mode is enabled
    func handleLowPowerModeChange(isEnabled: Bool)
    
    /// Get current location accuracy tier
    /// - Returns: Accuracy tier for optimization
    func getCurrentAccuracyTier() -> LocationAccuracyTier
}

/// Location accuracy tiers for battery optimization
enum LocationAccuracyTier: CaseIterable {
    case maximum      // Best accuracy, high battery usage
    case high         // Good accuracy, moderate battery usage  
    case balanced     // Balanced accuracy and battery usage
    case low          // Lower accuracy, minimal battery usage
    case minimal      // Significant changes only
    
    var accuracy: CLLocationAccuracy {
        switch self {
        case .maximum:
            return kCLLocationAccuracyBest
        case .high:
            return kCLLocationAccuracyNearestTenMeters
        case .balanced:
            return kCLLocationAccuracyHundredMeters
        case .low:
            return kCLLocationAccuracyKilometer
        case .minimal:
            return kCLLocationAccuracyThreeKilometers
        }
    }
    
    var updateInterval: TimeInterval {
        switch self {
        case .maximum:
            return 15.0   // 15 seconds
        case .high:
            return 30.0   // 30 seconds
        case .balanced:
            return 60.0   // 1 minute
        case .low:
            return 180.0  // 3 minutes
        case .minimal:
            return 300.0  // 5 minutes
        }
    }
    
    var description: String {
        switch self {
        case .maximum:
            return "Maximum accuracy (High battery usage)"
        case .high:
            return "High accuracy (Moderate battery usage)"
        case .balanced:
            return "Balanced accuracy and battery"
        case .low:
            return "Low accuracy (Minimal battery usage)"
        case .minimal:
            return "Significant changes only"
        }
    }
}
