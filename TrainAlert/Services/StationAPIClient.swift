//
//  StationAPIClient.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation

// MARK: - API Response Models

struct StationResponse: Codable {
    let response: StationResponseData
}

struct StationResponseData: Codable {
    let station: [StationInfo]?
}

struct StationInfo: Codable {
    let name: String
    let prefecture: String
    let line: String
    let x: String  // longitude
    let y: String  // latitude
    let distance: String?
    let postal: String?
    let next: String?
    let prev: String?
    
    // Convert to our Station model
    func toStation() -> Station? {
        guard let lat = Double(y),
              let lon = Double(x) else {
            return nil
        }
        
        return Station(
            id: "\(name)_\(prefecture)_\(line)",
            name: name,
            latitude: lat,
            longitude: lon,
            lines: [line]
        )
    }
}

struct LineResponse: Codable {
    let response: LineResponseData
}

struct LineResponseData: Codable {
    let line: [LineInfo]?
}

struct LineInfo: Codable {
    let name: String
    // swiftlint:disable:next identifier_name
    let company_name: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        // swiftlint:disable:next identifier_name
        case company_name
    }
}

// MARK: - API Errors

enum StationAPIError: Error, LocalizedError {
    case networkError(Error)
    case invalidURL
    case noData
    case decodingError(Error)
    case noStationsFound
    case requestTimeout
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .invalidURL:
            return "不正なURL"
        case .noData:
            return "データが取得できませんでした"
        case .decodingError(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .noStationsFound:
            return "駅が見つかりませんでした"
        case .requestTimeout:
            return "リクエストがタイムアウトしました"
        case .serverError(let code):
            return "サーバーエラー (コード: \(code))"
        }
    }
}

// MARK: - Cache Models

struct CachedStationData: Codable {
    let stations: [Station]
    let timestamp: Date
    let location: CLLocationCoordinate2D
    
    init(stations: [Station], location: CLLocationCoordinate2D) {
        self.stations = stations
        self.timestamp = Date()
        self.location = location
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes cache
    }
}

struct CachedLineData: Codable {
    let lines: [LineInfo]
    let timestamp: Date
    let stationName: String
    
    init(lines: [LineInfo], stationName: String) {
        self.lines = lines
        self.timestamp = Date()
        self.stationName = stationName
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 1800 // 30 minutes cache
    }
}

// MARK: - Cache Manager

class StationAPICache {
    private let userDefaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "station.api.cache", qos: .utility)
    
    private enum CacheKeys {
        static let stationData = "cached_station_data"
        static let lineData = "cached_line_data"
    }
    
    func cacheStationData(_ data: CachedStationData, for location: CLLocationCoordinate2D) {
        queue.async {
            do {
                let encoded = try JSONEncoder().encode(data)
                let key = "\(CacheKeys.stationData)_\(location.latitude)_\(location.longitude)"
                self.userDefaults.set(encoded, forKey: key)
            } catch {
                // Failed to cache station data
            }
        }
    }
    
    func getCachedStationData(for location: CLLocationCoordinate2D, within radius: CLLocationDistance = 1000) -> CachedStationData? {
        // Search for cached data within radius
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(CacheKeys.stationData) {
            if let data = userDefaults.data(forKey: key),
               let cached = try? JSONDecoder().decode(CachedStationData.self, from: data) {
                let cachedLocation = CLLocation(latitude: cached.location.latitude, longitude: cached.location.longitude)
                let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                
                if cachedLocation.distance(from: currentLocation) <= radius && !cached.isExpired {
                    return cached
                }
            }
        }
        return nil
    }
    
    func cacheLineData(_ data: CachedLineData) {
        queue.async {
            do {
                let encoded = try JSONEncoder().encode(data)
                let key = "\(CacheKeys.lineData)_\(data.stationName)"
                self.userDefaults.set(encoded, forKey: key)
            } catch {
                // Failed to cache line data
            }
        }
    }
    
    func getCachedLineData(for stationName: String) -> CachedLineData? {
        let key = "\(CacheKeys.lineData)_\(stationName)"
        guard let data = userDefaults.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedLineData.self, from: data),
              !cached.isExpired else {
            return nil
        }
        return cached
    }
    
    func clearExpiredCache() {
        queue.async {
            let keys = self.userDefaults.dictionaryRepresentation().keys
            for key in keys where key.hasPrefix(CacheKeys.stationData) || key.hasPrefix(CacheKeys.lineData) {
                if let data = self.userDefaults.data(forKey: key) {
                    // Try to decode as station data
                    if let stationData = try? JSONDecoder().decode(CachedStationData.self, from: data) {
                        if stationData.isExpired {
                            self.userDefaults.removeObject(forKey: key)
                        }
                    }
                    // Try to decode as line data
                    else if let lineData = try? JSONDecoder().decode(CachedLineData.self, from: data) {
                        if lineData.isExpired {
                            self.userDefaults.removeObject(forKey: key)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - StationAPIClient

@MainActor
class StationAPIClient: ObservableObject {
    private let baseURL = "http://express.heartrails.com/api/json"
    private let session: URLSession
    private let cache = StationAPICache()
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10.0
        configuration.timeoutIntervalForResource = 30.0
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .useProtocolCachePolicy
        
        self.session = URLSession(configuration: configuration)
        
        // Clear expired cache on initialization
        cache.clearExpiredCache()
    }
    
    // MARK: - Public API Methods
    
    /// 指定された座標の最寄り駅を検索
    func getNearbyStations(latitude: Double, longitude: Double) async throws -> [Station] {
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // Check cache first
        if let cachedData = cache.getCachedStationData(for: location) {
            // Using cached station data
            return cachedData.stations
        }
        
        // Build URL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "method", value: "getStations"),
            URLQueryItem(name: "x", value: String(longitude)),
            URLQueryItem(name: "y", value: String(latitude))
        ]
        
        guard let url = components.url else {
            throw StationAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    break
                case 408:
                    throw StationAPIError.requestTimeout
                case 500...599:
                    throw StationAPIError.serverError(httpResponse.statusCode)
                default:
                    throw StationAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Decode response
            let stationResponse = try JSONDecoder().decode(StationResponse.self, from: data)
            
            guard let stationInfos = stationResponse.response.station else {
                throw StationAPIError.noStationsFound
            }
            
            // Convert to Station models
            let stations = stationInfos.compactMap { $0.toStation() }
            
            // Cache the results
            let cachedData = CachedStationData(stations: stations, location: location)
            cache.cacheStationData(cachedData, for: location)
            
            return stations
            
        } catch let error as DecodingError {
            throw StationAPIError.decodingError(error)
        } catch let error as StationAPIError {
            throw error
        } catch {
            throw StationAPIError.networkError(error)
        }
    }
    
    /// 指定された駅の路線情報を取得
    func getStationLines(stationName: String) async throws -> [LineInfo] {
        // Check cache first
        if let cachedData = cache.getCachedLineData(for: stationName) {
            // Using cached line data
            return cachedData.lines
        }
        
        // Build URL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "method", value: "getLines"),
            URLQueryItem(name: "name", value: stationName)
        ]
        
        guard let url = components.url else {
            throw StationAPIError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Check response status
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    break
                case 408:
                    throw StationAPIError.requestTimeout
                case 500...599:
                    throw StationAPIError.serverError(httpResponse.statusCode)
                default:
                    throw StationAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Decode response
            let lineResponse = try JSONDecoder().decode(LineResponse.self, from: data)
            
            guard let lines = lineResponse.response.line else {
                return [] // No lines found is not an error
            }
            
            // Cache the results
            let cachedData = CachedLineData(lines: lines, stationName: stationName)
            cache.cacheLineData(cachedData)
            
            return lines
            
        } catch let error as DecodingError {
            throw StationAPIError.decodingError(error)
        } catch let error as StationAPIError {
            throw error
        } catch {
            throw StationAPIError.networkError(error)
        }
    }
    
    /// 駅名で検索（部分一致）
    func searchStations(query: String, near location: CLLocationCoordinate2D? = nil) async throws -> [Station] {
        // まず近くの駅を取得
        let nearbyStations: [Station]
        if let location = location {
            nearbyStations = try await getNearbyStations(latitude: location.latitude, longitude: location.longitude)
        } else {
            nearbyStations = []
        }
        
        // クエリで絞り込み
        let filteredStations = nearbyStations.filter { station in
            station.name.localizedCaseInsensitiveContains(query)
        }
        
        return filteredStations
    }
    
    // MARK: - Utility Methods
    
    /// キャッシュをクリア
    func clearCache() {
        cache.clearExpiredCache()
    }
    
    /// キャッシュサイズを取得
    func getCacheSize() -> Int {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        return keys.filter { $0.hasPrefix("cached_station_data") || $0.hasPrefix("cached_line_data") }.count
    }
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
}
