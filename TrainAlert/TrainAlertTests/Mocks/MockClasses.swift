//
//  MockClasses.swift
//  TrainAlertTests
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation
import Combine
import UserNotifications
@testable import TrainAlert

// MARK: - Mock LocationManager

@MainActor
class MockLocationManager: ObservableObject {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdatingLocation = false
    @Published var lastError: LocationError?
    
    // Mock behavior configuration
    var shouldFailLocationUpdates = false
    var shouldDenyAuthorization = false
    var mockLocation: CLLocation?
    var mockAuthorizationDelay: TimeInterval = 0.1
    
    // Tracking for testing
    var didRequestAuthorization = false
    var didStartUpdatingLocation = false
    var didStopUpdatingLocation = false
    var targetStation: CLLocation?
    
    init() {
        // Set default mock location (Tokyo Station)
        self.mockLocation = CLLocation(latitude: 35.6812, longitude: 139.7673)
    }
    
    func requestAuthorization() {
        didRequestAuthorization = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + mockAuthorizationDelay) {
            if self.shouldDenyAuthorization {
                self.authorizationStatus = .denied
                self.lastError = .authorizationDenied
            } else {
                self.authorizationStatus = .authorizedWhenInUse
            }
        }
    }
    
    func startUpdatingLocation(targetStation: CLLocation? = nil) {
        didStartUpdatingLocation = true
        self.targetStation = targetStation
        
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            lastError = .authorizationDenied
            return
        }
        
        isUpdatingLocation = true
        
        if shouldFailLocationUpdates {
            lastError = .locationUnavailable
            return
        }
        
        // Simulate location update after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.location = self.mockLocation
            self.lastError = nil
        }
    }
    
    func stopUpdatingLocation() {
        didStopUpdatingLocation = true
        isUpdatingLocation = false
    }
    
    func distance(from location1: CLLocation, to location2: CLLocation) -> CLLocationDistance {
        return location1.distance(from: location2)
    }
    
    func distanceToTargetStation() -> CLLocationDistance? {
        guard let currentLocation = location,
              let target = targetStation else {
            return nil
        }
        return distance(from: currentLocation, to: target)
    }
    
    // Helper methods for testing
    func simulateLocationUpdate(_ location: CLLocation) {
        self.location = location
        self.lastError = nil
    }
    
    func simulateLocationError(_ error: LocationError) {
        self.lastError = error
    }
    
    func simulateAuthorizationChange(_ status: CLAuthorizationStatus) {
        self.authorizationStatus = status
    }
    
    func reset() {
        location = nil
        authorizationStatus = .notDetermined
        isUpdatingLocation = false
        lastError = nil
        didRequestAuthorization = false
        didStartUpdatingLocation = false
        didStopUpdatingLocation = false
        targetStation = nil
        shouldFailLocationUpdates = false
        shouldDenyAuthorization = false
        mockLocation = CLLocation(latitude: 35.6812, longitude: 139.7673)
    }
}

// MARK: - Mock StationAPIClient

@MainActor
class MockStationAPIClient: ObservableObject {
    
    // Mock behavior configuration
    var shouldFailRequests = false
    var shouldReturnEmptyResults = false
    var mockDelay: TimeInterval = 0.1
    var mockError: StationAPIError?
    
    // Mock data
    var mockStations: [Station] = []
    var mockLines: [LineInfo] = []
    
    // Tracking for testing
    var lastSearchQuery: String?
    var lastSearchLocation: CLLocationCoordinate2D?
    var requestCount = 0
    
    init() {
        setupMockData()
    }
    
    private func setupMockData() {
        mockStations = [
            Station(
                id: "tokyo_station",
                name: "東京",
                latitude: 35.6812,
                longitude: 139.7673,
                lines: ["JR山手線", "JR東海道本線"]
            ),
            Station(
                id: "shibuya_station",
                name: "渋谷",
                latitude: 35.6580,
                longitude: 139.7016,
                lines: ["JR山手線", "東急東横線"]
            ),
            Station(
                id: "shinjuku_station",
                name: "新宿",
                latitude: 35.6896,
                longitude: 139.7006,
                lines: ["JR山手線", "JR中央線"]
            )
        ]
        
        mockLines = [
            LineInfo(name: "JR山手線", company_name: "JR東日本"),
            LineInfo(name: "JR東海道本線", company_name: "JR東日本"),
            LineInfo(name: "東急東横線", company_name: "東急電鉄")
        ]
    }
    
    func getNearbyStations(latitude: Double, longitude: Double) async throws -> [Station] {
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if shouldFailRequests {
            throw StationAPIError.networkError(NSError(domain: "MockError", code: 1, userInfo: nil))
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldReturnEmptyResults {
            return []
        }
        
        // Filter stations by distance (simplified mock logic)
        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        let nearbyStations = mockStations.filter { station in
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            return userLocation.distance(from: stationLocation) <= 50000 // 50km radius
        }
        
        return nearbyStations
    }
    
    func getStationLines(stationName: String) async throws -> [LineInfo] {
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if shouldFailRequests {
            throw StationAPIError.networkError(NSError(domain: "MockError", code: 1, userInfo: nil))
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldReturnEmptyResults {
            return []
        }
        
        // Return lines for known stations
        if let station = mockStations.first(where: { $0.name == stationName }) {
            return mockLines.filter { line in
                station.lines.contains(line.name)
            }
        }
        
        return []
    }
    
    func searchStations(query: String, near location: CLLocationCoordinate2D? = nil) async throws -> [Station] {
        lastSearchQuery = query
        lastSearchLocation = location
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if shouldFailRequests {
            throw StationAPIError.networkError(NSError(domain: "MockError", code: 1, userInfo: nil))
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldReturnEmptyResults {
            return []
        }
        
        // Filter by search query
        var results = mockStations.filter { station in
            station.name.localizedCaseInsensitiveContains(query)
        }
        
        // If location is provided, sort by distance
        if let location = location {
            let searchLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            results = results.sorted { station1, station2 in
                let location1 = CLLocation(latitude: station1.latitude, longitude: station1.longitude)
                let location2 = CLLocation(latitude: station2.latitude, longitude: station2.longitude)
                
                return searchLocation.distance(from: location1) < searchLocation.distance(from: location2)
            }
        }
        
        return results
    }
    
    func clearCache() {
        // Mock implementation - nothing to clear
    }
    
    func getCacheSize() -> Int {
        return mockStations.count // Mock cache size
    }
    
    // Helper methods for testing
    func addMockStation(_ station: Station) {
        mockStations.append(station)
    }
    
    func addMockLine(_ line: LineInfo) {
        mockLines.append(line)
    }
    
    func reset() {
        requestCount = 0
        lastSearchQuery = nil
        lastSearchLocation = nil
        shouldFailRequests = false
        shouldReturnEmptyResults = false
        mockError = nil
        setupMockData()
    }
}

// MARK: - Mock OpenAIClient

@MainActor
class MockOpenAIClient: ObservableObject {
    
    // Mock behavior configuration
    var shouldFailRequests = false
    var shouldReturnEmptyMessage = false
    var mockDelay: TimeInterval = 0.1
    var mockError: OpenAIError?
    var hasValidAPIKey = false
    
    // Tracking for testing
    var requestCount = 0
    var lastStationName: String?
    var lastArrivalTime: String?
    var lastCharacterStyle: CharacterStyle?
    
    // Mock responses
    var mockResponses: [String] = [
        "もうすぐ{station}に到着だよ！起きて〜",
        "{station}駅です。お疲れさまでした！",
        "終点{station}駅〜。降りる準備はできましたか？"
    ]
    
    func setAPIKey(_ key: String) {
        hasValidAPIKey = !key.isEmpty && key.hasPrefix("sk-")
    }
    
    func hasAPIKey() -> Bool {
        return hasValidAPIKey
    }
    
    func validateAPIKey(_ key: String) async throws -> Bool {
        requestCount += 1
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldFailRequests {
            throw OpenAIError.invalidAPIKey
        }
        
        return key.hasPrefix("sk-") && key.count > 20
    }
    
    func generateNotificationMessage(
        for stationName: String,
        arrivalTime: String,
        characterStyle: CharacterStyle
    ) async throws -> String {
        lastStationName = stationName
        lastArrivalTime = arrivalTime
        lastCharacterStyle = characterStyle
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if !hasValidAPIKey {
            throw OpenAIError.missingAPIKey
        }
        
        if shouldFailRequests {
            throw OpenAIError.networkUnavailable
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        if shouldReturnEmptyMessage {
            return ""
        }
        
        // Return mock response with station name replaced
        let mockResponse = mockResponses.randomElement() ?? "駅に到着しました。"
        return mockResponse.replacingOccurrences(of: "{station}", with: stationName)
    }
    
    // Helper methods for testing
    func addMockResponse(_ response: String) {
        mockResponses.append(response)
    }
    
    func reset() {
        requestCount = 0
        lastStationName = nil
        lastArrivalTime = nil
        lastCharacterStyle = nil
        shouldFailRequests = false
        shouldReturnEmptyMessage = false
        mockError = nil
        hasValidAPIKey = false
        mockResponses = [
            "もうすぐ{station}に到着だよ！起きて〜",
            "{station}駅です。お疲れさまでした！",
            "終点{station}駅〜。降りる準備はできましたか？"
        ]
    }
}

// MARK: - Mock NotificationManager

@MainActor
class MockNotificationManager: ObservableObject {
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isPermissionGranted: Bool = false
    @Published var lastError: NotificationError?
    @Published var settings = NotificationSettings()
    
    // Mock behavior configuration
    var shouldGrantPermission = false
    var shouldFailRequests = false
    var mockDelay: TimeInterval = 0.1
    var mockError: NotificationError?
    
    // Tracking for testing
    var requestCount = 0
    var scheduledNotifications: [String] = []
    var cancelledNotifications: [String] = []
    var permissionRequested = false
    
    func requestAuthorization() async throws {
        permissionRequested = true
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        if shouldFailRequests {
            throw NotificationError.permissionDenied
        }
        
        // Simulate delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        isPermissionGranted = shouldGrantPermission
        authorizationStatus = shouldGrantPermission ? .authorized : .denied
        
        if !shouldGrantPermission {
            lastError = .permissionDenied
        }
    }
    
    func checkAuthorizationStatus() async {
        // Simulate checking status
        try? await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
    }
    
    func scheduleTrainAlert(
        for stationName: String,
        arrivalTime: Date,
        currentLocation: CLLocation?,
        targetLocation: CLLocation,
        characterStyle: CharacterStyle = .healing
    ) async throws {
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        if shouldFailRequests {
            throw NotificationError.notificationFailed
        }
        
        // Simulate delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        let identifier = "train_alert_\(stationName)_\(Int(arrivalTime.timeIntervalSince1970))"
        scheduledNotifications.append(identifier)
    }
    
    func scheduleLocationBasedAlert(
        for stationName: String,
        targetLocation: CLLocation,
        radius: CLLocationDistance = 500
    ) async throws {
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        if shouldFailRequests {
            throw NotificationError.notificationFailed
        }
        
        // Simulate delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        let identifier = "location_alert_\(stationName)"
        scheduledNotifications.append(identifier)
    }
    
    func scheduleSnoozeNotification(for originalIdentifier: String, stationName: String) async throws {
        requestCount += 1
        
        if let error = mockError {
            throw error
        }
        
        guard isPermissionGranted else {
            throw NotificationError.permissionDenied
        }
        
        // Simulate delay
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        
        let snoozeIdentifier = "\(originalIdentifier)_snooze"
        scheduledNotifications.append(snoozeIdentifier)
    }
    
    func cancelNotification(identifier: String) {
        cancelledNotifications.append(identifier)
        scheduledNotifications.removeAll { $0 == identifier }
    }
    
    func cancelAllNotifications() {
        cancelledNotifications.append(contentsOf: scheduledNotifications)
        scheduledNotifications.removeAll()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        // Return empty array for mock
        return []
    }
    
    func updateCharacterStyle(_ style: CharacterStyle) {
        settings = NotificationSettings(
            defaultAdvanceTime: settings.defaultAdvanceTime,
            snoozeInterval: settings.snoozeInterval,
            maxSnoozeCount: settings.maxSnoozeCount,
            characterStyle: style
        )
    }
    
    func updateAdvanceTime(_ time: TimeInterval) {
        settings = NotificationSettings(
            defaultAdvanceTime: time,
            snoozeInterval: settings.snoozeInterval,
            maxSnoozeCount: settings.maxSnoozeCount,
            characterStyle: settings.characterStyle
        )
    }
    
    func updateSnoozeInterval(_ interval: TimeInterval) {
        settings = NotificationSettings(
            defaultAdvanceTime: settings.defaultAdvanceTime,
            snoozeInterval: interval,
            maxSnoozeCount: settings.maxSnoozeCount,
            characterStyle: settings.characterStyle
        )
    }
    
    func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .heavy) {
        // Mock implementation - do nothing
    }
    
    func generateNotificationHapticPattern() {
        // Mock implementation - do nothing
    }
    
    // Helper methods for testing
    func isNotificationScheduled(_ identifier: String) -> Bool {
        return scheduledNotifications.contains(identifier)
    }
    
    func isNotificationCancelled(_ identifier: String) -> Bool {
        return cancelledNotifications.contains(identifier)
    }
    
    func reset() {
        authorizationStatus = .notDetermined
        isPermissionGranted = false
        lastError = nil
        requestCount = 0
        scheduledNotifications.removeAll()
        cancelledNotifications.removeAll()
        permissionRequested = false
        shouldGrantPermission = false
        shouldFailRequests = false
        mockError = nil
        settings = NotificationSettings()
    }
}

// MARK: - Mock CoreDataManager

class MockCoreDataManager: CoreDataManager {
    
    // Mock behavior configuration
    var shouldFailSave = false
    var shouldFailFetch = false
    var mockDelay: TimeInterval = 0.0
    
    // Mock data storage
    var mockStations: [String: MockStation] = [:]
    var mockAlerts: [String: MockAlert] = [:]
    var mockHistory: [String: MockHistory] = [:]
    
    // Tracking for testing
    var saveCount = 0
    var fetchCount = 0
    var deleteCount = 0
    
    override init() {
        super.init()
        setupInMemoryStore()
    }
    
    private func setupInMemoryStore() {
        // Use in-memory store for testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
    }
    
    override func save() {
        saveCount += 1
        
        if shouldFailSave {
            // Simulate save failure
            print("Mock CoreDataManager: Save failed")
            return
        }
        
        // Call super to perform actual save for in-memory store
        super.save()
    }
    
    override func createStation(stationId: String, name: String, latitude: Double, longitude: Double, lines: String? = nil) -> Station {
        let station = super.createStation(stationId: stationId, name: name, latitude: latitude, longitude: longitude, lines: lines)
        
        // Store mock data for tracking
        mockStations[stationId] = MockStation(
            id: stationId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            lines: lines ?? "",
            isFavorite: false
        )
        
        return station
    }
    
    override func fetchStation(by stationId: String) -> Station? {
        fetchCount += 1
        
        if shouldFailFetch {
            return nil
        }
        
        return super.fetchStation(by: stationId)
    }
    
    override func createAlert(for station: Station, notificationTime: Int16, notificationDistance: Double, snoozeInterval: Int16 = 5, characterStyle: String? = nil) -> Alert {
        let alert = super.createAlert(
            for: station,
            notificationTime: notificationTime,
            notificationDistance: notificationDistance,
            snoozeInterval: snoozeInterval,
            characterStyle: characterStyle
        )
        
        // Store mock data for tracking
        let alertId = alert.alertId?.uuidString ?? UUID().uuidString
        mockAlerts[alertId] = MockAlert(
            id: alertId,
            stationId: station.stationId ?? "",
            notificationTime: Int(notificationTime),
            notificationDistance: notificationDistance,
            isActive: true
        )
        
        return alert
    }
    
    override func createHistory(for alert: Alert, message: String) -> History {
        let history = super.createHistory(for: alert, message: message)
        
        // Store mock data for tracking
        let historyId = history.historyId?.uuidString ?? UUID().uuidString
        mockHistory[historyId] = MockHistory(
            id: historyId,
            alertId: alert.alertId?.uuidString ?? "",
            message: message,
            notifiedAt: Date()
        )
        
        return history
    }
    
    override func delete(_ object: NSManagedObject) {
        deleteCount += 1
        super.delete(object)
        
        // Remove from mock data
        if let station = object as? Station,
           let stationId = station.stationId {
            mockStations.removeValue(forKey: stationId)
        } else if let alert = object as? Alert,
                  let alertId = alert.alertId?.uuidString {
            mockAlerts.removeValue(forKey: alertId)
        } else if let history = object as? History,
                  let historyId = history.historyId?.uuidString {
            mockHistory.removeValue(forKey: historyId)
        }
    }
    
    // Helper methods for testing
    func getMockStation(id: String) -> MockStation? {
        return mockStations[id]
    }
    
    func getMockAlert(id: String) -> MockAlert? {
        return mockAlerts[id]
    }
    
    func getMockHistory(id: String) -> MockHistory? {
        return mockHistory[id]
    }
    
    func reset() {
        saveCount = 0
        fetchCount = 0
        deleteCount = 0
        shouldFailSave = false
        shouldFailFetch = false
        mockStations.removeAll()
        mockAlerts.removeAll()
        mockHistory.removeAll()
        deleteAllData()
    }
}

// MARK: - Mock Data Structures

struct MockStation {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let lines: String
    let isFavorite: Bool
}

struct MockAlert {
    let id: String
    let stationId: String
    let notificationTime: Int
    let notificationDistance: Double
    let isActive: Bool
}

struct MockHistory {
    let id: String
    let alertId: String
    let message: String
    let notifiedAt: Date
}

// MARK: - Mock URLSession for Network Testing

class MockURLSession: URLSession {
    
    var mockData: Data?
    var mockResponse: HTTPURLResponse?
    var mockError: Error?
    var requestDelay: TimeInterval = 0.0
    
    override func data(from url: URL) async throws -> (Data, URLResponse) {
        // Simulate network delay
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }
        
        if let error = mockError {
            throw error
        }
        
        let response = mockResponse ?? HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let data = mockData ?? Data()
        
        return (data, response)
    }
    
    // Helper methods for testing
    func configureMockResponse(data: Data?, statusCode: Int = 200, error: Error? = nil) {
        self.mockData = data
        self.mockError = error
        if let url = URL(string: "https://example.com") {
            self.mockResponse = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        }
    }
    
    func reset() {
        mockData = nil
        mockResponse = nil
        mockError = nil
        requestDelay = 0.0
    }
}
