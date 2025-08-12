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
    func toStation() -> StationModel? {
        guard let lat = Double(y),
              let lon = Double(x) else {
            return nil
        }
        
        return StationModel(
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
    let stations: [StationModel]
    let timestamp: Date
    let location: CLLocationCoordinate2D
    
    init(stations: [StationModel], location: CLLocationCoordinate2D) {
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
        static let searchResult = "cached_search_result"
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
    
    func clearAllCache() {
        queue.async {
            let keys = self.userDefaults.dictionaryRepresentation().keys
            for key in keys where key.hasPrefix(CacheKeys.stationData) || key.hasPrefix(CacheKeys.lineData) || key.hasPrefix(CacheKeys.searchResult) {
                self.userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    // Search result cache methods
    func set(_ key: String, stations: [StationModel]) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                do {
                    // Create a simple cache structure for search results
                    let data = try JSONEncoder().encode(stations)
                    let cacheKey = "\(CacheKeys.searchResult)_\(key)"
                    self.userDefaults.set(data, forKey: cacheKey)
                    // Also store timestamp
                    self.userDefaults.set(Date(), forKey: "\(cacheKey)_timestamp")
                } catch {
                    // Failed to cache search result
                }
                continuation.resume()
            }
        }
    }
    
    func get(_ key: String) async -> [StationModel]? {
        await withCheckedContinuation { continuation in
            queue.async {
                let cacheKey = "\(CacheKeys.searchResult)_\(key)"
                guard let data = self.userDefaults.data(forKey: cacheKey),
                      let stations = try? JSONDecoder().decode([StationModel].self, from: data),
                      let timestamp = self.userDefaults.object(forKey: "\(cacheKey)_timestamp") as? Date else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Check if cache is expired (24 hours)
                if Date().timeIntervalSince(timestamp) > 86400 {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: stations)
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
    func getNearbyStations(latitude: Double, longitude: Double) async throws -> [StationModel] {
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        // Check cache first
        if let cachedData = cache.getCachedStationData(for: location) {
            // Using cached station data
            return cachedData.stations
        }
        
        // Build URL
        guard var components = URLComponents(string: baseURL) else {
            throw StationAPIError.invalidURL
        }
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
            
            // Convert to StationModel and aggregate lines for same station
            var stationDict: [String: (lat: Double, lon: Double, lines: Set<String>)] = [:]
            
            for info in stationInfos {
                
                guard let lat = Double(info.y),
                      let lon = Double(info.x) else {
                    continue
                }
                
                // Aggregate lines for the same station name
                if var existingStation = stationDict[info.name] {
                    existingStation.lines.insert(info.line)
                    stationDict[info.name] = existingStation
                } else {
                    stationDict[info.name] = (lat: lat, lon: lon, lines: [info.line])
                }
            }
            
            // Convert to StationModel array
            let stations = stationDict.map { (name, data) in
                StationModel(
                    id: "\(name)_\(data.lat)_\(data.lon)",
                    name: name,
                    latitude: data.lat,
                    longitude: data.lon,
                    lines: Array(data.lines).sorted()
                )
            }
            
            // Sort by distance
            let currentLocation = CLLocation(latitude: latitude, longitude: longitude)
            let sortedStations = stations.sorted { station1, station2 in
                let location1 = CLLocation(latitude: station1.latitude, longitude: station1.longitude)
                let location2 = CLLocation(latitude: station2.latitude, longitude: station2.longitude)
                return currentLocation.distance(from: location1) < currentLocation.distance(from: location2)
            }
            
            // Cache the results
            let cachedData = CachedStationData(stations: sortedStations, location: location)
            cache.cacheStationData(cachedData, for: location)
            
            return sortedStations
            
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
        guard var components = URLComponents(string: baseURL) else {
            throw StationAPIError.invalidURL
        }
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
    func searchStations(query: String, near location: CLLocationCoordinate2D? = nil) async throws -> [StationModel] {
        // If query is empty, return empty array
        guard !query.isEmpty else {
            return []
        }
        
        // Check cache first
        let cacheKey = "search_\(query)"
        if let cachedStations = await cache.get(cacheKey) {
            return sortStationsByLocation(cachedStations, location: location)
        }
        
        // Search stations using API
        do {
            let stations = try await searchStationsByAPI(query: query)
            
            // Cache the result
            await cache.set(cacheKey, stations: stations)
            
            return sortStationsByLocation(stations, location: location)
        } catch {
            // API search failed, fall back to offline data
            return searchOfflineStations(query: query, near: location)
        }
    }
    
    /// Search stations using HeartRails API
    private func searchStationsByAPI(query: String) async throws -> [StationModel] {
        var allStations: [StationModel] = []
        
        // Search major lines for stations matching the query
        let majorLines = [
            "JR山手線", "JR中央線", "JR総武線", "JR京浜東北線",
            "JR東海道線", "JR横須賀線", "JR埼京線", "JR南武線",
            "東京メトロ銀座線", "東京メトロ丸ノ内線", "東京メトロ日比谷線",
            "東急東横線", "東急田園都市線", "小田急線", "京王線"
        ]
        
        // Fetch stations from each line
        await withTaskGroup(of: [StationModel]?.self) { group in
            for line in majorLines {
                group.addTask {
                    try? await self.fetchStationsByLine(line)
                }
            }
            
            for await stations in group {
                if let stations = stations {
                    allStations.append(contentsOf: stations)
                }
            }
        }
        
        // Filter and deduplicate stations
        var uniqueStations: [String: StationModel] = [:]
        
        for station in allStations {
            // Check if station name matches query
            if station.name.localizedCaseInsensitiveContains(query) ||
               matchesHiraganaReading(station.name, query: query) {
                
                if let existing = uniqueStations[station.name] {
                    // Merge lines
                    var merged = existing
                    merged.lines = Array(Set(existing.lines + station.lines)).sorted()
                    uniqueStations[station.name] = merged
                } else {
                    uniqueStations[station.name] = station
                }
            }
        }
        
        return Array(uniqueStations.values)
    }
    
    /// Fetch stations by line name
    private func fetchStationsByLine(_ line: String) async throws -> [StationModel] {
        guard var components = URLComponents(string: baseURL) else {
            throw StationAPIError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "method", value: "getStations"),
            URLQueryItem(name: "line", value: line)
        ]
        
        guard let url = components.url else {
            throw StationAPIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        // Check response status
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw StationAPIError.serverError(httpResponse.statusCode)
        }
        
        let apiResponse = try JSONDecoder().decode(StationResponse.self, from: data)
        let stations = apiResponse.response.station?.compactMap { info -> StationModel? in
            guard let lat = Double(info.y),
                  let lon = Double(info.x) else {
                return nil
            }
            
            return StationModel(
                id: "\(info.name)_\(info.line)",
                name: info.name,
                latitude: lat,
                longitude: lon,
                lines: [info.line]
            )
        } ?? []
        
        return stations
    }
    
    /// Check if station name matches hiragana reading
    private func matchesHiraganaReading(_ stationName: String, query: String) -> Bool {
        let stationNameVariations: [String: String] = [
            "よこはま": "横浜",
            "しぶや": "渋谷",
            "しんじゅく": "新宿",
            "とうきょう": "東京",
            "いけぶくろ": "池袋",
            "うえの": "上野",
            "しながわ": "品川",
            "あきはばら": "秋葉原",
            "はらじゅく": "原宿",
            "えびす": "恵比寿",
            "めぐろ": "目黒",
            "かわさき": "川崎",
            "おおみや": "大宮",
            "ちば": "千葉",
            "たちかわ": "立川",
            "ふなばし": "船橋",
            "きちじょうじ": "吉祥寺",
            "まちだ": "町田",
            "なかの": "中野",
            "むさしこすぎ": "武蔵小杉"
        ]
        
        for (reading, kanji) in stationNameVariations {
            if kanji == stationName && reading.localizedCaseInsensitiveContains(query) {
                return true
            }
        }
        
        return false
    }
    
    /// Sort stations by distance from location
    private func sortStationsByLocation(_ stations: [StationModel], location: CLLocationCoordinate2D?) -> [StationModel] {
        guard let location = location else {
            return stations
        }
        
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return stations.sorted { station1, station2 in
            let location1 = CLLocation(latitude: station1.latitude, longitude: station1.longitude)
            let location2 = CLLocation(latitude: station2.latitude, longitude: station2.longitude)
            return currentLocation.distance(from: location1) < currentLocation.distance(from: location2)
        }
    }
    
    /// Search offline stations (fallback)
    private func searchOfflineStations(query: String, near location: CLLocationCoordinate2D?) -> [StationModel] {
        // 主要駅のリスト（オフライン検索用）
        let majorStations: [StationModel] = [
            // 山手線主要駅
            StationModel(
                id: "tokyo", name: "東京", latitude: 35.6812, longitude: 139.7671,
                lines: ["JR山手線", "JR中央線", "JR京浜東北線", "JR東海道線", "JR横須賀線", "JR総武線快速", "JR京葉線", "東京メトロ丸ノ内線"]
            ),
            StationModel(
                id: "shinjuku", name: "新宿", latitude: 35.6896, longitude: 139.7006,
                lines: ["JR山手線", "JR中央線", "JR埼京線", "JR湘南新宿ライン", "JR総武線",
                        "小田急線", "京王線", "東京メトロ丸ノ内線", "東京メトロ副都心線", "都営新宿線", "都営大江戸線"]
            ),
            StationModel(
                id: "shibuya", name: "渋谷", latitude: 35.6580, longitude: 139.7016,
                lines: ["JR山手線", "JR埼京線", "JR湘南新宿ライン", "東急東横線", "東急田園都市線",
                        "京王井の頭線", "東京メトロ銀座線", "東京メトロ半蔵門線", "東京メトロ副都心線"]
            ),
            StationModel(
                id: "ikebukuro", name: "池袋", latitude: 35.7295, longitude: 139.7109,
                lines: ["JR山手線", "JR埼京線", "JR湘南新宿ライン", "東武東上線", "西武池袋線",
                        "東京メトロ丸ノ内線", "東京メトロ有楽町線", "東京メトロ副都心線"]
            ),
            StationModel(
                id: "shinagawa", name: "品川", latitude: 35.6284, longitude: 139.7387,
                lines: ["JR山手線", "JR京浜東北線", "JR東海道線", "JR横須賀線", "JR東海道新幹線", "京急本線"]
            ),
            StationModel(
                id: "ueno", name: "上野", latitude: 35.7141, longitude: 139.7774,
                lines: ["JR山手線", "JR京浜東北線", "JR高崎線", "JR宇都宮線", "JR常磐線",
                        "東京メトロ銀座線", "東京メトロ日比谷線"]
            ),
            StationModel(
                id: "akihabara", name: "秋葉原", latitude: 35.6984, longitude: 139.7731,
                lines: ["JR山手線", "JR京浜東北線", "JR総武線", "つくばエクスプレス", "東京メトロ日比谷線"]
            ),
            StationModel(
                id: "harajuku", name: "原宿", latitude: 35.6702, longitude: 139.7026,
                lines: ["JR山手線", "東京メトロ千代田線（明治神宮前）", "東京メトロ副都心線（明治神宮前）"]
            ),
            StationModel(
                id: "ebisu", name: "恵比寿", latitude: 35.6467, longitude: 139.7100,
                lines: ["JR山手線", "JR埼京線", "JR湘南新宿ライン", "東京メトロ日比谷線"]
            ),
            StationModel(
                id: "meguro", name: "目黒", latitude: 35.6339, longitude: 139.7158,
                lines: ["JR山手線", "東急目黒線", "東京メトロ南北線", "都営三田線"]
            ),
            
            // その他主要駅
            StationModel(
                id: "yokohama", name: "横浜", latitude: 35.4657, longitude: 139.6223,
                lines: ["JR東海道線", "JR横須賀線", "JR京浜東北線", "JR根岸線",
                        "京急本線", "東急東横線", "相鉄線", "横浜市営地下鉄ブルーライン"]
            ),
            StationModel(
                id: "kawasaki", name: "川崎", latitude: 35.5308, longitude: 139.6973,
                lines: ["JR東海道線", "JR京浜東北線", "JR南武線"]
            ),
            StationModel(
                id: "omiya", name: "大宮", latitude: 35.9064, longitude: 139.6238,
                lines: ["JR京浜東北線", "JR高崎線", "JR東北線", "JR埼京線", "JR川越線",
                        "東武野田線", "埼玉新都市交通"]
            ),
            StationModel(
                id: "chiba", name: "千葉", latitude: 35.6131, longitude: 140.1139,
                lines: ["JR総武線", "JR成田線", "JR外房線", "JR内房線", "千葉都市モノレール"]
            ),
            StationModel(
                id: "tachikawa", name: "立川", latitude: 35.6978, longitude: 139.4138,
                lines: ["JR中央線", "JR青梅線", "JR南武線", "多摩都市モノレール"]
            ),
            StationModel(
                id: "funabashi", name: "船橋", latitude: 35.7020, longitude: 139.9854,
                lines: ["JR総武線", "東武野田線", "京成本線"]
            ),
            StationModel(
                id: "kichijoji", name: "吉祥寺", latitude: 35.7032, longitude: 139.5800,
                lines: ["JR中央線", "JR総武線", "京王井の頭線"]
            ),
            StationModel(
                id: "machida", name: "町田", latitude: 35.5461, longitude: 139.4386,
                lines: ["JR横浜線", "小田急線"]
            ),
            StationModel(
                id: "nakano", name: "中野", latitude: 35.7056, longitude: 139.6658,
                lines: ["JR中央線", "JR総武線", "東京メトロ東西線"]
            ),
            StationModel(
                id: "musashikosugi", name: "武蔵小杉", latitude: 35.5765, longitude: 139.6594,
                lines: ["JR横須賀線", "JR湘南新宿ライン", "JR南武線", "東急東横線", "東急目黒線"]
            )
        ]
        
        // クエリで絞り込み（駅名のみで検索）
        let filteredStations = majorStations.filter { station in
            // 駅名で検索（漢字、ひらがな、カタカナ）
            station.name.localizedCaseInsensitiveContains(query) ||
            matchesHiraganaReading(station.name, query: query)
        }
        
        return sortStationsByLocation(filteredStations, location: location)
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
