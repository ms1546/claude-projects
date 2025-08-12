//
//  ODPTAPIClient.swift
//  TrainAlert
//
//  ODPT API Client with Mock Data Support
//

import CoreLocation
import Foundation

/// ODPT API Client Protocol
protocol ODPTAPIClientProtocol {
    func searchStations(query: String) async throws -> [ODPTStation]
    func searchStations(near location: CLLocation, radius: Double) async throws -> [ODPTStation]
    func getRailway(id: String) async throws -> ODPTRailway
    func searchRoutes(from: String, to: String, departureTime: Date?) async throws -> [RouteSearchResult]
    func getTrainTimetable(railway: String, calendar: String) async throws -> [ODPTTrainTimetable]
    func getRealTimeTrainInfo(railway: String) async throws -> [ODPTTrain]
}

/// ODPT API Client
class ODPTAPIClient: ODPTAPIClientProtocol {
    // MARK: - Properties
    
    /// API base URL
    private let baseURL = "https://api.odpt.org/api/v4"
    
    /// API Key (will be set after approval)
    private var apiKey: String?
    
    /// Use mock data flag
    private var useMockData: Bool
    
    /// URLSession
    private let session: URLSession
    
    // MARK: - Initialization
    
    init(apiKey: String? = nil, useMockData: Bool = true) {
        self.apiKey = apiKey
        self.useMockData = useMockData
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// 駅名検索
    func searchStations(query: String) async throws -> [ODPTStation] {
        if useMockData {
            return MockODPTData.searchStations(query: query)
        }
        
        guard let apiKey = apiKey else {
            throw ODPTAPIError.noAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/places/Station")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: apiKey),
            URLQueryItem(name: "dc:title", value: query)
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([ODPTStation].self, from: data)
    }
    
    /// 位置情報による駅検索
    func searchStations(near location: CLLocation, radius: Double) async throws -> [ODPTStation] {
        if useMockData {
            return MockODPTData.searchStations(near: location, radius: radius)
        }
        
        guard let apiKey = apiKey else {
            throw ODPTAPIError.noAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/places/Station")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: apiKey),
            URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "radius", value: String(radius))
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([ODPTStation].self, from: data)
    }
    
    /// 路線情報取得
    func getRailway(id: String) async throws -> ODPTRailway {
        if useMockData {
            return MockODPTData.getRailway(id: id)
        }
        
        guard let apiKey = apiKey else {
            throw ODPTAPIError.noAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/odpt:Railway")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: apiKey),
            URLQueryItem(name: "@id", value: id)
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        let railways = try JSONDecoder().decode([ODPTRailway].self, from: data)
        guard let railway = railways.first else {
            throw ODPTAPIError.notFound
        }
        return railway
    }
    
    /// 経路検索
    func searchRoutes(from: String, to: String, departureTime: Date? = nil) async throws -> [RouteSearchResult] {
        if useMockData {
            return MockODPTData.searchRoutes(from: from, to: to, departureTime: departureTime)
        }
        
        // Note: ODPT APIには経路検索エンドポイントがないため、
        // 時刻表データを組み合わせてアプリ側で経路を構築する必要がある
        // ここではモックデータを返す
        return MockODPTData.searchRoutes(from: from, to: to, departureTime: departureTime)
    }
    
    /// 列車時刻表取得
    func getTrainTimetable(railway: String, calendar: String) async throws -> [ODPTTrainTimetable] {
        if useMockData {
            return MockODPTData.getTrainTimetable(railway: railway, calendar: calendar)
        }
        
        guard let apiKey = apiKey else {
            throw ODPTAPIError.noAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/odpt:TrainTimetable")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: apiKey),
            URLQueryItem(name: "odpt:railway", value: railway),
            URLQueryItem(name: "odpt:calendar", value: calendar)
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([ODPTTrainTimetable].self, from: data)
    }
    
    /// リアルタイム列車情報取得
    func getRealTimeTrainInfo(railway: String) async throws -> [ODPTTrain] {
        if useMockData {
            return MockODPTData.getRealTimeTrainInfo(railway: railway)
        }
        
        guard let apiKey = apiKey else {
            throw ODPTAPIError.noAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/odpt:Train")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: apiKey),
            URLQueryItem(name: "odpt:railway", value: railway)
        ]
        
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode([ODPTTrain].self, from: data)
    }
}

// MARK: - Error Types

enum ODPTAPIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case notFound
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "APIキーが設定されていません"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .notFound:
            return "データが見つかりません"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Configuration

struct ODPTAPIConfiguration {
    static let shared = ODPTAPIConfiguration()
    
    /// API Key storage key
    private let apiKeyStorageKey = "ODPTAPIKey"
    
    /// Get stored API key
    var apiKey: String? {
        get {
            UserDefaults.standard.string(forKey: apiKeyStorageKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: apiKeyStorageKey)
        }
    }
    
    /// Check if API is available
    var isAPIAvailable: Bool {
        apiKey != nil
    }
    
    /// Use mock data flag
    var useMockData: Bool {
        get {
            !isAPIAvailable || UserDefaults.standard.bool(forKey: "UseODPTMockData")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "UseODPTMockData")
        }
    }
}
