//
//  LocationManagerEnhanced.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation
import Combine
import BackgroundTasks

/// Enhanced LocationManager with geofencing and battery optimization
class LocationManagerEnhanced: NSObject, ObservableObject, CLLocationManagerDelegate, LocationManagerProtocol {
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    private let powerManager = PowerManager.shared
    private let backgroundLogger = BackgroundLogger.shared
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isUpdatingLocation = false
    @Published var lastError: LocationError?
    
    // Geofencing
    private var monitoredRegions: Set<CLCircularRegion> = []
    private let geofenceRadii = [2000.0, 1000.0, 500.0, 100.0] // meters
    
    // Battery optimization
    private var currentAccuracyLevel: AccuracyLevel = .balanced
    private var significantLocationChangesEnabled = false
    
    // MARK: - AccuracyLevel
    
    enum AccuracyLevel {
        case highAccuracy      // < 500m from station
        case balanced          // 500m - 2km
        case powerSaving       // 2km - 5km
        case minimal           // > 5km
        
        var desiredAccuracy: CLLocationAccuracy {
            switch self {
            case .highAccuracy:
                return kCLLocationAccuracyBest
            case .balanced:
                return kCLLocationAccuracyNearestTenMeters
            case .powerSaving:
                return kCLLocationAccuracyHundredMeters
            case .minimal:
                return kCLLocationAccuracyKilometer
            }
        }
        
        var distanceFilter: CLLocationDistance {
            switch self {
            case .highAccuracy:
                return 10
            case .balanced:
                return 50
            case .powerSaving:
                return 100
            case .minimal:
                return 500
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        setupLocationManager()
        observePowerStateChanges()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.activityType = .automotiveNavigation
        
        // Set initial accuracy
        updateLocationAccuracy(for: .balanced)
    }
    
    private func observePowerStateChanges() {
        NotificationCenter.default.publisher(for: .powerStateChanged)
            .sink { [weak self] _ in
                self?.adjustForPowerState()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Location Authorization
    
    func requestAuthorization() {
        backgroundLogger.log("Requesting location authorization", category: .location)
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Location Updates
    
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            lastError = .authorizationDenied
            return
        }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
        
        // Enable significant location changes for background
        if authorizationStatus == .authorizedAlways {
            enableSignificantLocationChanges()
        }
        
        backgroundLogger.log("Started location updates", category: .location)
    }
    
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        disableSignificantLocationChanges()
        clearGeofences()
        
        backgroundLogger.log("Stopped location updates", category: .location)
    }
    
    // MARK: - Significant Location Changes
    
    private func enableSignificantLocationChanges() {
        guard !significantLocationChangesEnabled else { return }
        
        locationManager.startMonitoringSignificantLocationChanges()
        significantLocationChangesEnabled = true
        
        backgroundLogger.log("Enabled significant location changes", category: .location)
    }
    
    private func disableSignificantLocationChanges() {
        guard significantLocationChangesEnabled else { return }
        
        locationManager.stopMonitoringSignificantLocationChanges()
        significantLocationChangesEnabled = false
        
        backgroundLogger.log("Disabled significant location changes", category: .location)
    }
    
    // MARK: - Geofencing
    
    func setupGeofencing(for targetLocation: CLLocation) {
        clearGeofences()
        
        // Create multiple geofences at different distances
        for (index, radius) in geofenceRadii.enumerated() {
            let identifier = "station_fence_\(index)"
            let region = CLCircularRegion(
                center: targetLocation.coordinate,
                radius: radius,
                identifier: identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            locationManager.startMonitoring(for: region)
            monitoredRegions.insert(region)
        }
        
        backgroundLogger.log("Setup \(geofenceRadii.count) geofences around target station", category: .location)
    }
    
    private func clearGeofences() {
        for region in monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredRegions.removeAll()
    }
    
    // MARK: - Battery Optimization
    
    func updateDistanceToTarget(_ distance: CLLocationDistance) {
        let newLevel: AccuracyLevel
        
        switch distance {
        case 0..<500:
            newLevel = .highAccuracy
        case 500..<2000:
            newLevel = .balanced
        case 2000..<5000:
            newLevel = .powerSaving
        default:
            newLevel = .minimal
        }
        
        if newLevel != currentAccuracyLevel {
            updateLocationAccuracy(for: newLevel)
        }
    }
    
    private func updateLocationAccuracy(for level: AccuracyLevel) {
        currentAccuracyLevel = level
        locationManager.desiredAccuracy = level.desiredAccuracy
        locationManager.distanceFilter = level.distanceFilter
        
        backgroundLogger.log("Updated accuracy level to: \(level)", category: .location)
    }
    
    private func adjustForPowerState() {
        let powerState = powerManager.currentPowerState
        
        switch powerState {
        case .normal:
            // Use configured accuracy level
            updateLocationAccuracy(for: currentAccuracyLevel)
        case .lowPowerMode:
            // Reduce accuracy by one level
            switch currentAccuracyLevel {
            case .highAccuracy:
                updateLocationAccuracy(for: .balanced)
            case .balanced:
                updateLocationAccuracy(for: .powerSaving)
            default:
                updateLocationAccuracy(for: .minimal)
            }
        case .criticalBattery:
            // Use minimal accuracy
            updateLocationAccuracy(for: .minimal)
        case .charging:
            // Can use higher accuracy if needed
            break
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let age = -newLocation.timestamp.timeIntervalSinceNow
        if age > 5.0 || newLocation.horizontalAccuracy < 0 {
            return
        }
        
        location = newLocation
        
        backgroundLogger.log(
            "Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)",
            category: .location
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        backgroundLogger.log(
            "Entered geofence: \(region.identifier) (radius: \(circularRegion.radius)m)",
            category: .location
        )
        
        // Increase accuracy when approaching station
        if circularRegion.radius <= 1000 {
            updateLocationAccuracy(for: .highAccuracy)
        }
        
        // Notify about proximity
        NotificationCenter.default.post(
            name: .approachingStation,
            object: nil,
            userInfo: ["radius": circularRegion.radius]
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                lastError = .authorizationDenied
            case .locationUnknown:
                lastError = .locationUnavailable
            default:
                lastError = .locationUnavailable
            }
        }
        
        backgroundLogger.log("Location error: \(error.localizedDescription)", category: .location, level: .error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        backgroundLogger.log(
            "Authorization changed to: \(authorizationStatus.rawValue)",
            category: .location
        )
        
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startUpdatingLocation()
        } else {
            stopUpdatingLocation()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let approachingStation = Notification.Name("approachingStation")
    static let powerStateChanged = Notification.Name("powerStateChanged")
}
