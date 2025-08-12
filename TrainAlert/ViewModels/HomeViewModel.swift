//
//  HomeViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import UIKit
import Combine
import CoreData
import CoreLocation
import OSLog

@MainActor
class HomeViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    private let locationManager: LocationManager
    private let notificationManager: NotificationManager
    private let performanceMonitor = PerformanceMonitor.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "HomeViewModel")
    
    // MARK: - Published Properties
    
    @Published var activeAlerts: [Alert] = []
    @Published var allAlerts: [Alert] = []
    @Published var recentStations: [StationData] = []
    @Published var currentLocation: CLLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var refreshDate = Date()
    
    // MARK: - Computed Properties
    
    var hasActiveAlerts: Bool {
        !activeAlerts.isEmpty
    }
    
    var primaryAlert: Alert? {
        activeAlerts.first
    }
    
    var locationStatus: LocationStatus {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notRequested
        @unknown default:
            return .unknown
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var dataRefreshTask: Task<Void, Never>?
    private var locationUpdateTask: Task<Void, Never>?
    
    // Weak references to prevent retain cycles
    // private weak var appState: AppState? // Temporarily disabled
    
    // MARK: - Initialization
    
    init(
        coreDataManager: CoreDataManager = CoreDataManager.shared,
        locationManager: LocationManager = LocationManager(),
        notificationManager: NotificationManager = NotificationManager.shared
    ) {
        self.coreDataManager = coreDataManager
        self.locationManager = locationManager
        self.notificationManager = notificationManager
        // self.appState = appState // Temporarily disabled
        
        setupSubscriptions()
        loadInitialDataIfNeeded()
        
        logger.info("HomeViewModel initialized")
    }
    
    deinit {
        // Cleanup handled by automatic cancellation
        logger.info("HomeViewModel deinitialized")
    }
    
    // MARK: - Public Methods
    
    /// Setup dependencies after view appears
    func setupWithDependencies(
        locationManager: LocationManager,
        notificationManager: NotificationManager,
        coreDataManager: CoreDataManager
    ) {
        // Dependencies are already set in init, just trigger initial load
        Task {
            await refresh()
        }
    }
    
    /// Refresh all data with performance monitoring
    func refresh() async {
        // Cancel any existing refresh task
        dataRefreshTask?.cancel()
        
        dataRefreshTask = Task { @MainActor in
            performanceMonitor.startTimer(for: "Home Data Refresh")
            isLoading = true
            errorMessage = nil
            
            // Use TaskGroup for concurrent operations
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.loadActiveAlerts()
                }
                
                group.addTask {
                    await self.loadRecentStations()
                }
                
                if self.locationStatus == .authorized {
                    group.addTask {
                        await self.updateLocation()
                    }
                }
            }
            
            refreshDate = Date()
            isLoading = false
            performanceMonitor.endTimer(for: "Home Data Refresh")
            performanceMonitor.logMemoryUsage(context: "Home Refresh Complete")
        }
        
        await dataRefreshTask?.value
    }
    
    /// Start location updates with performance optimization
    func startLocationUpdates() {
        guard locationUpdateTask == nil else { return }
        
        locationUpdateTask = Task {
            performanceMonitor.startTimer(for: "Location Updates Start")
            
            locationManager.requestAuthorization()
            
            // Only start location updates if we have active alerts
            if !self.activeAlerts.isEmpty {
                locationManager.startUpdatingLocation()
                logger.info("Location updates started with \(self.activeAlerts.count) active alerts")
            } else {
                logger.info("Skipped location updates - no active alerts")
            }
            
            performanceMonitor.endTimer(for: "Location Updates Start")
        }
    }
    
    /// Stop location updates and cleanup
    func stopLocationUpdates() {
        locationUpdateTask?.cancel()
        locationUpdateTask = nil
        
        locationManager.stopUpdatingLocation()
        logger.info("Location updates stopped")
    }
    
    /// Toggle alert status with optimized Core Data operations
    func toggleAlert(_ alert: Alert) {
        performanceMonitor.startTimer(for: "Toggle Alert")
        
        Task {
            do {
                try await coreDataManager.performBackgroundTask { context in
                    // Get the alert in the background context
                    let backgroundAlert = try context.existingObject(with: alert.objectID) as! Alert
                    backgroundAlert.toggleActive()
                }
                
                await loadActiveAlerts()
                logger.info("Alert toggled successfully")
                
            } catch {
                await MainActor.run {
                    errorMessage = "アラートの状態を変更できませんでした"
                    logger.error("Failed to toggle alert: \(error.localizedDescription)")
                }
            }
            
            performanceMonitor.endTimer(for: "Toggle Alert")
        }
    }
    
    /// Delete alert with optimized Core Data operations
    func deleteAlert(_ alert: Alert) {
        performanceMonitor.startTimer(for: "Delete Alert")
        
        Task {
            do {
                try await coreDataManager.performBackgroundTask { context in
                    let backgroundAlert = try context.existingObject(with: alert.objectID) as! Alert
                    context.delete(backgroundAlert)
                }
                
                await loadActiveAlerts()
                logger.info("Alert deleted successfully")
                
            } catch {
                await MainActor.run {
                    errorMessage = "アラートを削除できませんでした"
                    logger.error("Failed to delete alert: \(error.localizedDescription)")
                }
            }
            
            performanceMonitor.endTimer(for: "Delete Alert")
        }
    }
    
    /// Create quick alert for recent station
    func createQuickAlert(for station: StationData) {
        // Implementation will be completed when alert creation flow is implemented
        // Quick alert creation for station
    }
    
    /// Request necessary permissions with performance tracking
    func requestPermissions() async {
        performanceMonitor.startTimer(for: "Request Permissions")
        
        // Request permissions concurrently
        await withTaskGroup(of: Void.self) { group in
            // Location authorization is synchronous
            self.locationManager.requestAuthorization()
            
            group.addTask {
                do {
                    try await self.notificationManager.requestAuthorization()
                } catch {
                    await MainActor.run {
                        self.errorMessage = "通知の許可が必要です"
                    }
                }
            }
        }
        
        performanceMonitor.endTimer(for: "Request Permissions")
        logger.info("Permission requests completed")
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to location updates with debouncing
        locationManager.$location
            .compactMap { $0 }
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.currentLocation = location
                self?.performanceMonitor.logMemoryUsage(context: "Location Update")
            }
            .store(in: &cancellables)
        
        // Subscribe to location errors
        locationManager.$lastError
            .compactMap { $0 }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.logger.warning("Location error: \(error.localizedDescription)")
            }
            .store(in: &cancellables)
        
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
        
        // Monitor alert updates
        NotificationCenter.default.publisher(for: Notification.Name("AlertsUpdated"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadActiveAlerts()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialDataIfNeeded() {
        // Only load data if not already loaded
        guard activeAlerts.isEmpty && recentStations.isEmpty else { return }
        
        Task {
            await loadActiveAlerts()
            await loadRecentStations()
            logger.debug("Initial data loaded")
        }
    }
    
    @MainActor
    private func loadActiveAlerts() async {
        do {
            performanceMonitor.startTimer(for: "Load Active Alerts")
            
            // Load all alerts
            let allRequest = Alert.fetchRequest()
            allRequest.fetchBatchSize = 20
            allRequest.returnsObjectsAsFaults = false
            allRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Alert.createdAt, ascending: false)]
            
            self.allAlerts = try await coreDataManager.optimizedFetch(allRequest)
            
            // Filter active alerts
            self.activeAlerts = self.allAlerts.filter { $0.isActive }
            
            performanceMonitor.endTimer(for: "Load Active Alerts")
            logger.debug("Loaded \(self.allAlerts.count) total alerts, \(self.activeAlerts.count) active")
            
        } catch {
            errorMessage = "アラートを読み込めませんでした"
            logger.error("Failed to load alerts: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func loadRecentStations() async {
        do {
            performanceMonitor.startTimer(for: "Load Recent Stations")
            
            // Get recent stations from alert history with optimized fetch
            let request = Alert.recentAlertsFetchRequest(limit: 5)
            request.fetchBatchSize = 5
            request.relationshipKeyPathsForPrefetching = ["station"]
            
            let recentAlerts = try await coreDataManager.optimizedFetch(request)
            
            // Extract unique stations and convert to StationData
            let stations = recentAlerts.compactMap { $0.station }
            let uniqueStationData = stations
                .reduce(into: [String: StationData]()) { dict, station in
                    guard let stationId = station.stationId else { return }
                    dict[stationId] = StationData(
                        id: stationId,
                        name: station.name ?? "",
                        latitude: station.latitude,
                        longitude: station.longitude,
                        lines: station.lineArray
                    )
                }
                .values
            
            self.recentStations = Array(uniqueStationData.prefix(3))
            
            performanceMonitor.endTimer(for: "Load Recent Stations")
            logger.debug("Loaded \(self.recentStations.count) recent stations")
            
        } catch {
            errorMessage = "最近使用した駅を読み込めませんでした"
            logger.error("Failed to load recent stations: \(error.localizedDescription)")
        }
    }
    
    private func updateLocation() async {
        guard locationStatus == .authorized else {
            logger.debug("Skipped location update - not authorized")
            return
        }
        
        // Location is updated through the subscription to locationManager.$location
        // This method ensures location manager is active if needed
        if !activeAlerts.isEmpty && locationManager.location == nil {
            locationManager.startUpdatingLocation()
            logger.debug("Started location updates for active alerts")
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        dataRefreshTask?.cancel()
        locationUpdateTask?.cancel()
        
        cancellables.removeAll()
        
        // Stop location updates if running
        locationManager.stopUpdatingLocation()
        
        logger.debug("HomeViewModel cleanup completed")
    }
}

// MARK: - Supporting Types

// MARK: - Memory Management

extension HomeViewModel {
    
    /// Check for memory leaks and excessive usage
    func checkMemoryUsage() {
        performanceMonitor.logMemoryUsage(context: "HomeViewModel")
        
        if performanceMonitor.checkMemoryLeak(threshold: 30.0) {
            logger.warning("Potential memory leak detected in HomeViewModel")
        }
    }
    
    /// Force cleanup of resources
    func forceCleanup() {
        cleanup()
        
        // Clear data to free memory
        activeAlerts.removeAll()
        recentStations.removeAll()
        currentLocation = nil
        errorMessage = nil
        
        logger.info("Forced cleanup completed")
    }
}

extension HomeViewModel {
    enum LocationStatus {
        case authorized
        case denied
        case notRequested
        case unknown
        
        var displayText: String {
            switch self {
            case .authorized:
                return "位置情報が利用可能"
            case .denied:
                return "位置情報が拒否されています"
            case .notRequested:
                return "位置情報の許可が必要"
            case .unknown:
                return "位置情報の状態が不明"
            }
        }
        
        var canShowLocation: Bool {
            self == .authorized
        }
    }
}

// MARK: - StationData

/// Data transfer object for station information with memory optimization
struct StationData: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let lines: [String]
    
    // Computed properties are not stored, saving memory
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // Implement Hashable for efficient Set operations
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

