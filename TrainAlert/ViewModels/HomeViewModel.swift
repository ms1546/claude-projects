//
//  HomeViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import Combine
import CoreData
import CoreLocation

@MainActor
class HomeViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    private let locationManager: LocationManager
    private let notificationManager: NotificationManager
    
    // MARK: - Published Properties
    
    @Published var activeAlerts: [Alert] = []
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
    
    // MARK: - Initialization
    
    init(
        coreDataManager: CoreDataManager = CoreDataManager.shared,
        locationManager: LocationManager = LocationManager(),
        notificationManager: NotificationManager = NotificationManager.shared
    ) {
        self.coreDataManager = coreDataManager
        self.locationManager = locationManager
        self.notificationManager = notificationManager
        
        setupSubscriptions()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    /// Refresh all data
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await loadActiveAlerts()
            await loadRecentStations()
            await updateLocation()
            refreshDate = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Start location updates
    func startLocationUpdates() {
        locationManager.requestAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    /// Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Toggle alert status
    func toggleAlert(_ alert: Alert) {
        do {
            alert.toggleActive()
            try coreDataManager.saveContext()
            
            Task {
                await loadActiveAlerts()
            }
        } catch {
            errorMessage = "アラートの状態を変更できませんでした"
        }
    }
    
    /// Delete alert
    func deleteAlert(_ alert: Alert) {
        do {
            coreDataManager.viewContext.delete(alert)
            try coreDataManager.saveContext()
            
            Task {
                await loadActiveAlerts()
            }
        } catch {
            errorMessage = "アラートを削除できませんでした"
        }
    }
    
    /// Create quick alert for recent station
    func createQuickAlert(for station: StationData) {
        // Implementation will be completed when alert creation flow is implemented
        print("Quick alert creation for \(station.name)")
    }
    
    /// Request necessary permissions
    func requestPermissions() async {
        // Request location permission
        locationManager.requestAuthorization()
        
        // Request notification permission
        do {
            try await notificationManager.requestAuthorization()
        } catch {
            errorMessage = "通知の許可が必要です"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to location updates
        locationManager.$location
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentLocation, on: self)
            .store(in: &cancellables)
        
        // Subscribe to location errors
        locationManager.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadActiveAlerts()
            await loadRecentStations()
        }
    }
    
    @MainActor
    private func loadActiveAlerts() async {
        do {
            let request = Alert.activeAlertsFetchRequest()
            activeAlerts = try coreDataManager.viewContext.fetch(request)
        } catch {
            errorMessage = "アクティブなアラートを読み込めませんでした"
        }
    }
    
    @MainActor
    private func loadRecentStations() async {
        do {
            // Get recent stations from alert history
            let request = Alert.recentAlertsFetchRequest(limit: 5)
            let recentAlerts = try coreDataManager.viewContext.fetch(request)
            
            // Extract unique stations and convert to StationData
            let stations = recentAlerts.compactMap { $0.station }
            let uniqueStations = Array(NSOrderedSet(array: stations.map { station in
                StationData(
                    id: station.stationId ?? "",
                    name: station.name ?? "",
                    latitude: station.latitude,
                    longitude: station.longitude,
                    lines: station.lineArray
                )
            })).compactMap { $0 as? StationData }
            
            recentStations = Array(uniqueStations.prefix(3))
        } catch {
            errorMessage = "最近使用した駅を読み込めませんでした"
        }
    }
    
    private func updateLocation() async {
        guard locationStatus == .authorized else { return }
        
        // Location is updated through the subscription to locationManager.$location
        // This method can be used for manual location updates if needed
    }
}

// MARK: - Supporting Types

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

/// Data transfer object for station information
struct StationData: Identifiable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let lines: [String]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
