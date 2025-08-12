//
//  StationAPIClient.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation
import os.log

// MARK: - API Models

struct OverpassElement: Codable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let tags: [String: String]?
}

struct OverpassResponse: Codable {
    let elements: [OverpassElement]
}

// MARK: - Errors

enum StationAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    case noData
    case serverError(Int)
    case offlineError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        case .decodingError(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .noData:
            return "データが見つかりませんでした"
        case .serverError(let code):
            return "サーバーエラー (コード: \(code))"
        case .offlineError:
            return "オフラインです。インターネット接続を確認してください"
        }
    }
}

// MARK: - Station API Client

/// 駅情報APIクライアント
class StationAPIClient: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL = "https://overpass-api.de/api/interpreter"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "StationAPI")
    private let cache = StationCache()
    private let urlSession: URLSession
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// 指定された座標の最寄り駅を検索
    func getNearbyStations(latitude: Double, longitude: Double, radius: Double = 2000) async throws -> [StationModel] {
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // Check cache first
        if let cachedStations = cache.getCachedStationData(for: location) {
            logger.debug("Using cached station data")
            return cachedStations
        }
        
        // Build Overpass Query with detailed tags
        let query = """
        [out:json][timeout:25];
        (
          node[railway=station]
          (around:\(radius),\(latitude),\(longitude));
          way[railway=station]
          (around:\(radius),\(latitude),\(longitude));
        );
        out center;
        """
        
        // Make API request
        let stations = try await fetchStations(query: query)
        
        // Cache the results
        cache.setCachedStationData(stations, for: location)
        
        return stations
    }
    
    /// 駅名で検索（部分一致）
    func searchStations(query: String, near location: CLLocationCoordinate2D? = nil) async throws -> [StationModel] {
        guard !query.isEmpty else {
            return []
        }
        
        // Check if we have internet connection
        guard await isNetworkAvailable() else {
            throw StationAPIError.offlineError
        }
        
        // Escape special characters for regex
        let escapedQuery = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
        
        // Build Overpass Query
        let overpassQuery: String
        if let location = location {
            // Search near a specific location
            overpassQuery = """
            [out:json][timeout:25];
            (
              node[railway=station][name~"\(escapedQuery)",i]
              (around:50000,\(location.latitude),\(location.longitude));
              way[railway=station][name~"\(escapedQuery)",i]
              (around:50000,\(location.latitude),\(location.longitude));
            );
            out center;
            """
        } else {
            // Search in Tokyo area (wider search)
            overpassQuery = """
            [out:json][timeout:25];
            (
              node[railway=station][name~"\(escapedQuery)",i]
              (35.5,139.5,35.9,140.0);
              way[railway=station][name~"\(escapedQuery)",i]
              (35.5,139.5,35.9,140.0);
            );
            out center;
            """
        }
        
        return try await fetchStations(query: overpassQuery)
    }
    
    // MARK: - Private Methods
    
    private func fetchStations(query: String) async throws -> [StationModel] {
        // Create request
        guard var components = URLComponents(string: baseURL) else {
            throw StationAPIError.invalidURL
        }
        
        components.queryItems = [URLQueryItem(name: "data", value: query)]
        
        guard let url = components.url else {
            throw StationAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            // Make request
            let (data, response) = try await urlSession.data(for: request)
            
            // Check response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StationAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw StationAPIError.serverError(httpResponse.statusCode)
            }
            
            // Parse response
            let overpassResponse = try JSONDecoder().decode(OverpassResponse.self, from: data)
            
            // Convert to StationModel
            let stations = overpassResponse.elements.compactMap { element -> StationModel? in
                // Skip elements without coordinates
                guard let lat = element.lat,
                      let lon = element.lon,
                      let tags = element.tags else {
                    return nil
                }
                
                guard let name = tags["name"] ?? tags["name:ja"] ?? tags["name:en"] else {
                    return nil
                }
                
                // Extract railway lines from tags
                let lines = extractRailwayLines(from: tags)
                
                return StationModel(
                    id: "\(element.id)",
                    name: name,
                    latitude: lat,
                    longitude: lon,
                    lines: lines
                )
            }
            
            logger.info("Fetched \(stations.count) stations from API")
            return stations
            
        } catch let error as DecodingError {
            logger.error("Decoding error: \(error)")
            throw StationAPIError.decodingError(error)
        } catch let error as StationAPIError {
            throw error
        } catch {
            logger.error("Network error: \(error)")
            throw StationAPIError.networkError(error)
        }
    }
    
    private func extractRailwayLines(from tags: [String: String]) -> [String] {
        var lines: Set<String> = []
        
        // Common railway line tags in OSM (priority order)
        // 1. Line name tags
        if let lineName = tags["line"] {
            lines.insert(lineName)
        }
        if let lineNameJa = tags["line:ja"] {
            lines.insert(lineNameJa)
        }
        if let lineNameEn = tags["line:en"] {
            lines.insert(lineNameEn)
        }
        
        // 2. Railway specific tags
        if let railway = tags["railway:line"] {
            lines.insert(railway)
        }
        if let railwayRef = tags["railway:ref"] {
            lines.insert(railwayRef)
        }
        
        // 3. Route information
        if let route = tags["route"] {
            lines.insert(route)
        }
        if let routeName = tags["route_name"] {
            lines.insert(routeName)
        }
        
        // 4. Network information
        if let network = tags["network"] {
            // Clean up network names (remove prefecture suffixes like "東京")
            let cleanedNetwork = network
                .replacingOccurrences(of: "東京", with: "")
                .replacingOccurrences(of: "京王", with: "京王")
                .replacingOccurrences(of: "東武", with: "東武")
                .replacingOccurrences(of: "京急", with: "京急")
                .replacingOccurrences(of: "京成", with: "京成")
                .trimmingCharacters(in: .whitespaces)
            if !cleanedNetwork.isEmpty {
                lines.insert(cleanedNetwork)
            }
        }
        
        // 5. Operator information (as fallback)
        if let operator_ = tags["operator"] {
            // Map common operators to their line prefixes
            let operatorMapping: [String: String] = [
                "JR East": "JR",
                "JR東日本": "JR",
                "Tokyo Metro": "東京メトロ",
                "東京地下鉄": "東京メトロ",
                "Toei": "都営",
                "東京都交通局": "都営"
            ]
            
            if let mappedOperator = operatorMapping[operator_] {
                lines.insert(mappedOperator)
            } else if !operator_.isEmpty && lines.isEmpty {
                lines.insert(operator_)
            }
        }
        
        // 6. Additional tags
        if let service = tags["service"] {
            lines.insert(service)
        }
        
        // If no specific lines found, add a generic indicator
        if lines.isEmpty {
            lines.insert("鉄道駅")
        }
        
        // Return sorted array
        return Array(lines).sorted()
    }
    
    private func isNetworkAvailable() async -> Bool {
        // Simple network check
        do {
            let (_, response) = try await urlSession.data(from: URL(string: "https://www.google.com")!)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Station Cache

/// Simple in-memory cache for station data
class StationCache {
    private struct CachedData {
        let stations: [StationModel]
        let timestamp: Date
    }
    
    private var cache: [String: CachedData] = [:]
    private let cacheValidityDuration: TimeInterval = 24 * 60 * 60 // 24 hours
    
    func getCachedStationData(for location: CLLocationCoordinate2D) -> [StationModel]? {
        let key = cacheKey(for: location)
        
        guard let cachedData = cache[key] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cachedData.timestamp) > cacheValidityDuration {
            cache.removeValue(forKey: key)
            return nil
        }
        
        return cachedData.stations
    }
    
    func setCachedStationData(_ stations: [StationModel], for location: CLLocationCoordinate2D) {
        let key = cacheKey(for: location)
        cache[key] = CachedData(stations: stations, timestamp: Date())
    }
    
    private func cacheKey(for location: CLLocationCoordinate2D) -> String {
        // Round to 3 decimal places (about 100m precision)
        let lat = round(location.latitude * 1000) / 1000
        let lon = round(location.longitude * 1000) / 1000
        return "\(lat),\(lon)"
    }
}
