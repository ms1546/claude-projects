//
//  APICacheManager.swift
//  TrainAlert
//
//  APIレスポンスのキャッシュ管理
//

import Foundation

/// APIキャッシュマネージャー
@MainActor
final class APICacheManager {
    static let shared = APICacheManager()
    
    private init() {}
    
    // MARK: - Cache Storage
    
    /// 駅検索結果のキャッシュ
    private var stationSearchCache = NSCache<NSString, CachedStationSearchResult>()
    
    /// 時刻表データのキャッシュ
    private var timetableCache = NSCache<NSString, CachedTimetableResult>()
    
    /// ODPT駅詳細のキャッシュ
    private var odptStationCache = NSCache<NSString, CachedODPTStation>()
    
    // MARK: - Cache Configuration
    
    private let cacheExpirationTime: TimeInterval = 3_600 // 1時間
    private let timetableCacheExpirationTime: TimeInterval = 86_400 // 24時間
    
    // MARK: - Station Search Cache
    
    /// 駅検索結果をキャッシュ
    func cacheStationSearchResult(_ stations: [ODPTStation], forQuery query: String) {
        let cached = CachedStationSearchResult(stations: stations, timestamp: Date())
        stationSearchCache.setObject(cached, forKey: query as NSString)
    }
    
    /// キャッシュから駅検索結果を取得
    func getCachedStationSearchResult(forQuery query: String) -> [ODPTStation]? {
        guard let cached = stationSearchCache.object(forKey: query as NSString) else {
            return nil
        }
        
        // キャッシュの有効期限をチェック
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationTime {
            stationSearchCache.removeObject(forKey: query as NSString)
            return nil
        }
        
        return cached.stations
    }
    
    // MARK: - Timetable Cache
    
    /// 時刻表データをキャッシュ
    func cacheTimetable(_ timetable: [ODPTStationTimetable], forStation stationID: String, railway railwayID: String) {
        let cacheKey = "\(stationID):\(railwayID)" as NSString
        let cached = CachedTimetableResult(timetables: timetable, timestamp: Date())
        timetableCache.setObject(cached, forKey: cacheKey)
    }
    
    /// キャッシュから時刻表データを取得
    func getCachedTimetable(forStation stationID: String, railway railwayID: String) -> [ODPTStationTimetable]? {
        let cacheKey = "\(stationID):\(railwayID)" as NSString
        guard let cached = timetableCache.object(forKey: cacheKey) else {
            return nil
        }
        
        // 時刻表は長めにキャッシュ
        if Date().timeIntervalSince(cached.timestamp) > timetableCacheExpirationTime {
            timetableCache.removeObject(forKey: cacheKey)
            return nil
        }
        
        return cached.timetables
    }
    
    /// 特定の時刻表キャッシュをクリア
    func clearCachedTimetable(forStation stationID: String, railway railwayID: String) {
        let cacheKey = "\(stationID):\(railwayID)" as NSString
        timetableCache.removeObject(forKey: cacheKey)
    }
    
    // MARK: - ODPT Station Cache
    
    /// ODPT駅詳細をキャッシュ
    func cacheODPTStation(_ station: ODPTStation) {
        let cached = CachedODPTStation(station: station, timestamp: Date())
        odptStationCache.setObject(cached, forKey: station.id as NSString)
    }
    
    /// キャッシュからODPT駅詳細を取得
    func getCachedODPTStation(id: String) -> ODPTStation? {
        guard let cached = odptStationCache.object(forKey: id as NSString) else {
            return nil
        }
        
        if Date().timeIntervalSince(cached.timestamp) > cacheExpirationTime {
            odptStationCache.removeObject(forKey: id as NSString)
            return nil
        }
        
        return cached.station
    }
    
    // MARK: - Cache Management
    
    /// すべてのキャッシュをクリア
    func clearAllCaches() {
        stationSearchCache.removeAllObjects()
        timetableCache.removeAllObjects()
        odptStationCache.removeAllObjects()
    }
    
    /// 期限切れのキャッシュを削除
    func removeExpiredCaches() {
        // NSCacheは自動的にメモリ管理を行うため、手動での削除は不要
        // 必要に応じて実装を追加
    }
}

// MARK: - Cache Models

/// キャッシュされた駅検索結果
private class CachedStationSearchResult {
    let stations: [ODPTStation]
    let timestamp: Date
    
    init(stations: [ODPTStation], timestamp: Date) {
        self.stations = stations
        self.timestamp = timestamp
    }
}

/// キャッシュされた時刻表データ
private class CachedTimetableResult {
    let timetables: [ODPTStationTimetable]
    let timestamp: Date
    
    init(timetables: [ODPTStationTimetable], timestamp: Date) {
        self.timetables = timetables
        self.timestamp = timestamp
    }
}

/// キャッシュされたODPT駅データ
private class CachedODPTStation {
    let station: ODPTStation
    let timestamp: Date
    
    init(station: ODPTStation, timestamp: Date) {
        self.station = station
        self.timestamp = timestamp
    }
}

// MARK: - UserDefaults Cache for Persistent Storage

extension APICacheManager {
    /// よく使う駅をUserDefaultsに保存
    func saveFrequentlyUsedStations(_ stations: [ODPTStation]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(stations) {
            UserDefaults.standard.set(encoded, forKey: "FrequentlyUsedStations")
        }
    }
    
    /// よく使う駅を読み込み
    func loadFrequentlyUsedStations() -> [ODPTStation]? {
        guard let data = UserDefaults.standard.data(forKey: "FrequentlyUsedStations") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([ODPTStation].self, from: data)
    }
}
