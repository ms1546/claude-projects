//
//  LocationManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import BackgroundTasks
import Combine
import CoreLocation
import Foundation

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
    
    static var shared: LocationManager?
    
    private let locationManager = CLLocationManager()
    private var targetStation: CLLocation?
    private var updateTimer: Timer?
    private var settingsObserver: NSObjectProtocol?
    
    @Published var location: CLLocation?
    
    // currentLocationプロパティを追加（互換性のため）
    var currentLocation: CLLocation? {
        location
    }
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isUpdatingLocation = false
    @Published var lastError: LocationError?
    
    // Location update frequency based on distance to target station
    private var currentUpdateInterval: TimeInterval = 60.0
    
    // Settings
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyNearestTenMeters {
        didSet {
            locationManager.desiredAccuracy = desiredAccuracy
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        self.authorizationStatus = CLLocationManager.authorizationStatus()
        super.init()
        
        setupLocationManager()
        loadSettings()
        observeSettingsChanges()
        
        // Set shared instance for hybrid notification
        LocationManager.shared = self
    }
    
    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = 100
        
        // Background location updates configuration will be set after authorization
    }
    
    private func loadSettings() {
        let accuracy = UserDefaults.standard.string(forKey: "locationAccuracy") ?? "balanced"
        updateAccuracyFromSettings(accuracy)
    }
    
    private func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSettings()
        }
    }
    
    private func updateAccuracyFromSettings(_ accuracy: String) {
        switch accuracy {
        case "high":
            desiredAccuracy = kCLLocationAccuracyBest
        case "balanced":
            desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        case "battery":
            desiredAccuracy = kCLLocationAccuracyHundredMeters
        default:
            desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location authorization with enhanced handling
    func requestAuthorization() {
        // 最新の権限状態を取得
        let currentStatus = CLLocationManager.authorizationStatus()
        authorizationStatus = currentStatus
        
        switch authorizationStatus {
        case .notDetermined:
            // First request when in use, then ask for always
            DispatchQueue.main.async {
                self.locationManager.requestWhenInUseAuthorization()
            }
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
    
    /// Force update authorization status
    func updateAuthorizationStatus() {
        let newStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus != newStatus {
            authorizationStatus = newStatus
        }
    }
    
    /// Start location updates with dynamic accuracy adjustment
    func startUpdatingLocation(targetStation: CLLocation? = nil) {
        // 最新の権限状態を確認
        let currentStatus = CLLocationManager.authorizationStatus()
        if currentStatus != authorizationStatus {
            authorizationStatus = currentStatus
        }
        
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
    
    /// Start monitoring significant location changes for background updates
    func startMonitoringSignificantLocationChanges() {
        guard authorizationStatus == .authorizedAlways else {
            return
        }
        
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    /// Stop monitoring significant location changes
    func stopMonitoringSignificantLocationChanges() {
        locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    /// Alias for stopSignificantLocationChanges - for compatibility
    func stopSignificantLocationUpdates() {
        stopMonitoringSignificantLocationChanges()
    }
    
    /// Alias for startMonitoringSignificantLocationChanges - for compatibility  
    func startSignificantLocationUpdates() {
        startMonitoringSignificantLocationChanges()
    }
    
    /// Calculate distance between two locations
    func distance(from location1: CLLocation, to location2: CLLocation) -> CLLocationDistance {
        location1.distance(from: location2)
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
            // Use settings-based accuracy for normal operation
            locationManager.desiredAccuracy = desiredAccuracy
            locationManager.distanceFilter = 100
            currentUpdateInterval = 60.0
            return
        }
        
        let distanceToStation = distance(from: currentLocation, to: targetStation)
        
        // Only adjust accuracy dynamically if high accuracy mode is enabled
        let accuracySetting = UserDefaults.standard.string(forKey: "locationAccuracy") ?? "balanced"
        
        if accuracySetting == "high" {
            // Adjust based on technical specification table
            if distanceToStation <= 2_000 { // Within 2km
                setLocationAccuracy(accuracy: kCLLocationAccuracyBest,
                                  distanceFilter: 10,
                                  updateInterval: 15.0)
            } else if distanceToStation <= 5_000 { // Within 5km
                setLocationAccuracy(accuracy: kCLLocationAccuracyNearestTenMeters,
                                  distanceFilter: 30,
                                  updateInterval: 30.0)
            } else { // Normal operation
                setLocationAccuracy(accuracy: desiredAccuracy,
                                  distanceFilter: 100,
                                  updateInterval: 60.0)
            }
        } else {
            // Use fixed accuracy based on settings
            locationManager.desiredAccuracy = desiredAccuracy
            locationManager.distanceFilter = accuracySetting == "battery" ? 200 : 100
            currentUpdateInterval = accuracySetting == "battery" ? 120.0 : 60.0
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
