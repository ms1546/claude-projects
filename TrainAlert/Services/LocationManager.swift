//
//  LocationManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation
import Combine
import BackgroundTasks

enum LocationError: Error {
    case authorizationDenied
    case locationUnavailable
    case backgroundUpdatesFailed
    
    var localizedDescription: String {
        switch self {
        case .authorizationDenied:
            return "位置情報の利用が許可されていません"
        case .locationUnavailable:
            return "位置情報を取得できません"
        case .backgroundUpdatesFailed:
            return "バックグラウンドでの位置情報更新に失敗しました"
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    private var targetStation: CLLocation?
    private var updateTimer: Timer?
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isUpdatingLocation = false
    @Published var lastError: LocationError?
    
    // Location update frequency based on distance to target station
    private var currentUpdateInterval: TimeInterval = 60.0
    
    // MARK: - Initialization
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        
        // Background location updates configuration will be set after authorization
    }
    
    // MARK: - Public Methods
    
    /// Request location authorization with enhanced handling
    func requestAuthorization() {
        switch authorizationStatus {
        case .notDetermined:
            // First request when in use, then ask for always
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Upgrade to always authorization for background updates
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            lastError = .authorizationDenied
        case .authorizedAlways:
            // Already have full permission
            break
        @unknown default:
            break
        }
    }
    
    /// Start location updates with dynamic accuracy adjustment
    func startUpdatingLocation(targetStation: CLLocation? = nil) {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            lastError = .authorizationDenied
            return
        }
        
        self.targetStation = targetStation
        isUpdatingLocation = true
        
        // Update accuracy based on initial distance
        adjustAccuracyForCurrentLocation()
        
        locationManager.startUpdatingLocation()
        
        // Enable background updates if we have always authorization
        if authorizationStatus == .authorizedAlways {
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                locationManager.allowsBackgroundLocationUpdates = true
                locationManager.pausesLocationUpdatesAutomatically = true
            }
            startBackgroundLocationUpdates()
        }
        
        // Start timer for dynamic updates
        startUpdateTimer()
    }
    
    /// Stop all location updates
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Alias for stopSignificantLocationChanges - for compatibility
    func stopSignificantLocationUpdates() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    /// Alias for startMonitoringSignificantLocationChanges - for compatibility  
    func startSignificantLocationUpdates() {
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    /// Calculate distance between two locations
    func distance(from location1: CLLocation, to location2: CLLocation) -> CLLocationDistance {
        return location1.distance(from: location2)
    }
    
    /// Get distance to target station if set
    func distanceToTargetStation() -> CLLocationDistance? {
        guard let currentLocation = location,
              let target = targetStation else {
            return nil
        }
        return distance(from: currentLocation, to: target)
    }
    
    // MARK: - Private Methods
    
    private func startBackgroundLocationUpdates() {
        guard authorizationStatus == .authorizedAlways else {
            return
        }
        
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: currentUpdateInterval, repeats: true) { [weak self] _ in
            self?.adjustAccuracyForCurrentLocation()
        }
    }
    
    /// Dynamically adjust location accuracy based on distance to target station
    private func adjustAccuracyForCurrentLocation() {
        guard let targetStation = targetStation,
              let currentLocation = location else {
            // Default settings for normal operation
            setLocationAccuracy(accuracy: kCLLocationAccuracyHundredMeters, 
                              distanceFilter: 100,
                              updateInterval: 60.0)
            return
        }
        
        let distanceToStation = distance(from: currentLocation, to: targetStation)
        
        // Adjust based on technical specification table
        if distanceToStation <= 2000 { // Within 2km
            setLocationAccuracy(accuracy: kCLLocationAccuracyBest,
                              distanceFilter: 10,
                              updateInterval: 15.0)
        } else if distanceToStation <= 5000 { // Within 5km
            setLocationAccuracy(accuracy: kCLLocationAccuracyNearestTenMeters,
                              distanceFilter: 30,
                              updateInterval: 30.0)
        } else { // Normal operation
            setLocationAccuracy(accuracy: kCLLocationAccuracyHundredMeters,
                              distanceFilter: 100,
                              updateInterval: 60.0)
        }
    }
    
    private func setLocationAccuracy(accuracy: CLLocationAccuracy, 
                                   distanceFilter: CLLocationDistance,
                                   updateInterval: TimeInterval) {
        locationManager.desiredAccuracy = accuracy
        locationManager.distanceFilter = distanceFilter
        
        // Update timer interval if changed
        if currentUpdateInterval != updateInterval {
            currentUpdateInterval = updateInterval
            startUpdateTimer()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch authorizationStatus {
        case .authorizedWhenInUse:
            // Automatically request always authorization for background updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.locationManager.requestAlwaysAuthorization()
            }
        case .authorizedAlways:
            // Enable background location updates
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                locationManager.allowsBackgroundLocationUpdates = true
                locationManager.pausesLocationUpdatesAutomatically = true
            }
            if isUpdatingLocation {
                startBackgroundLocationUpdates()
            }
        case .denied, .restricted:
            lastError = .authorizationDenied
            stopUpdatingLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let locationAge = -newLocation.timestamp.timeIntervalSinceNow
        guard locationAge < 15.0 && newLocation.horizontalAccuracy < 100 else {
            return
        }
        
        location = newLocation
        lastError = nil
        
        // Adjust accuracy based on new location
        adjustAccuracyForCurrentLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = .locationUnavailable
        
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                lastError = .authorizationDenied
            case .locationUnknown:
                // Continue trying to get location
                break
            case .network:
                lastError = .locationUnavailable
            default:
                lastError = .locationUnavailable
            }
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        // Location updates paused (iOS power management)
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        // Location updates resumed
    }
}
