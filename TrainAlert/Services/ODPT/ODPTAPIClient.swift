//
//  ODPTAPIClient.swift
//  TrainAlert
//
//  ODPT APIクライアント
//

import CoreLocation
import Foundation

/// ODPT APIクライアント
@MainActor
final class ODPTAPIClient {
    static let shared = ODPTAPIClient()
    
    private let configuration = ODPTAPIConfiguration.shared
    private let session: URLSession
    private let cache = URLCache(
        memoryCapacity: 10 * 1_024 * 1_024,  // 10MB
        diskCapacity: 50 * 1_024 * 1_024,     // 50MB
        diskPath: "odpt_cache"
    )
    
    // 駅情報のメモリキャッシュ
    private var stationCache: [String: ODPTStation] = [:]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 60 // 60秒に延長
        config.timeoutIntervalForResource = 120 // リソース全体のタイムアウト
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// 駅を検索
    func searchStations(by name: String) async throws -> [ODPTStation] {
        // 開発中・APIキーがない場合は常にモックデータを使用
        let useMockData = false // 実際のAPIを使用
        
        if useMockData || !configuration.hasAPIKey || configuration.apiKey.isEmpty {
            print("ODPT API: Using mock data")
            return getMockStations(matching: name)
        }
        
        print("ODPT API: Using real API with key: \(configuration.apiKey.prefix(10))...")
        
        // URLを確認
        let urlString = "\(configuration.baseURL)/odpt:Station"
        print("ODPT API URL: \(urlString)")
        
        var components = URLComponents(string: urlString)!
        // dc:titleは完全一致が必要な可能性があるため、全件取得してクライアント側でフィルタリング
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey)
        ]
        
        // APIキーの権限に応じて事業者を限定
        // 現在のAPIキーではJR線にアクセスできないため、コメントアウト
        // if name.count >= 2 {
        //     // JR東日本の駅に限定
        //     components.queryItems?.append(URLQueryItem(name: "odpt:operator", value: "odpt.Operator:JR-East"))
        // }
        
        guard let url = components.url else {
            throw ODPTAPIError.invalidResponse
        }
        
        // タイムアウトを設定したリクエスト
        var request = URLRequest(url: url)
        request.timeoutInterval = 60.0 // 60秒のタイムアウト
        
        // 全駅データを取得してクライアント側でフィルタリング
        let allStations: [ODPTStation] = try await self.request(urlRequest: request)
        
        // 駅名でフィルタリング（部分一致）
        let filteredStations = allStations.filter { station in
            let stationName = station.stationTitle?.ja ?? station.title
            return stationName.lowercased().contains(name.lowercased())
        }
        
        print("ODPT API: Found \(filteredStations.count) stations matching '\(name)' from \(allStations.count) total")
        return filteredStations
    }
    
    /// URLRequestを使用したリクエスト
    private func request<T: Decodable>(urlRequest: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ODPTAPIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    throw ODPTAPIError.decodingError(error)
                }
            case 429:
                throw ODPTAPIError.rateLimitExceeded
            default:
                throw ODPTAPIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is ODPTAPIError {
                throw error
            }
            throw ODPTAPIError.networkError(error)
        }
    }
    
    /// 駅の時刻表を取得
    func getStationTimetable(
        stationId: String,
        railwayId: String,
        direction: String? = nil,
        calendar: String? = nil
    ) async throws -> [ODPTStationTimetable] {
        // IDの形式をチェック（HeartRails形式の場合はモックを返す）
        let isHeartRailsFormat = stationId.hasPrefix("heartrails:")
        let isValidODPTFormat = stationId.hasPrefix("odpt.Station:")
        
        // 開発中・APIキーがない場合、またはID形式が不正な場合はモック時刻表を返す
        if !configuration.hasAPIKey || isHeartRailsFormat || !isValidODPTFormat {
            print("ODPT API: Returning mock timetable (invalid ID format or no API key)")
            return getMockTimetable(for: stationId, railway: railwayId)
        }
        
        // ODPT APIのパラメータを設定
        var components = URLComponents(string: "\(configuration.baseURL)/odpt:StationTimetable")!
        var queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey)
        ]
        
        // 駅IDのみで検索（railwayやcalendarは後で絞り込む）
        queryItems.append(URLQueryItem(name: "odpt:station", value: stationId))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw ODPTAPIError.invalidResponse
        }
        
        print("ODPT API: Fetching timetable from URL: \(url.absoluteString)")
        let allTimetables: [ODPTStationTimetable] = try await request(url: url)
        print("ODPT API: Received \(allTimetables.count) timetables for station")
        
        // 取得したデータから指定された路線でフィルタリング
        var filteredTimetables = allTimetables.filter { timetable in
            let matchesRailway = timetable.railway == railwayId
            let matchesDirection = direction == nil || timetable.railDirection == direction
            
            if !matchesRailway {
                print("  Filtered out: railway mismatch \(timetable.railway) != \(railwayId)")
            }
            
            return matchesRailway && matchesDirection
        }
        
        // カレンダーでフィルタリング（指定がある場合）
        if let calendar = calendar {
            let calendarFiltered = filteredTimetables.filter { timetable in
                timetable.calendar == nil || timetable.calendar == calendar
            }
            
            // 指定されたカレンダーの時刻表がない場合は、利用可能な時刻表を返す
            if calendarFiltered.isEmpty {
                print("ODPT API: No timetables for calendar \(calendar), returning all available timetables")
                print("ODPT API: Available calendars: \(Set(filteredTimetables.compactMap { $0.calendar }))")
            } else {
                filteredTimetables = calendarFiltered
            }
        }
        
        print("ODPT API: After filtering: \(filteredTimetables.count) timetables")
        return filteredTimetables
    }
    
    /// 列車時刻表を取得
    func getTrainTimetable(
        trainNumber: String,
        railwayId: String,
        calendar: String = "odpt.Calendar:Weekday"
    ) async throws -> [ODPTTrainTimetable] {
        guard configuration.hasAPIKey else {
            throw ODPTAPIError.missingAPIKey
        }
        
        var components = URLComponents(string: "\(configuration.baseURL)/odpt:TrainTimetable")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey),
            URLQueryItem(name: "odpt:trainNumber", value: trainNumber),
            URLQueryItem(name: "odpt:railway", value: railwayId),
            URLQueryItem(name: "odpt:calendar", value: calendar)
        ]
        
        guard let url = components.url else {
            throw ODPTAPIError.invalidResponse
        }
        
        return try await request(url: url)
    }
    
    /// リアルタイム列車情報を取得
    func getTrainInfo(railwayId: String) async throws -> [ODPTTrain] {
        guard configuration.hasAPIKey else {
            throw ODPTAPIError.missingAPIKey
        }
        
        var components = URLComponents(string: "\(configuration.baseURL)/odpt:Train")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey),
            URLQueryItem(name: "odpt:railway", value: railwayId)
        ]
        
        guard let url = components.url else {
            throw ODPTAPIError.invalidResponse
        }
        
        return try await request(url: url)
    }
    
    /// 最寄り駅を検索（緯度経度から）
    func getNearbyStations(location: CLLocation, radius: Double = 1_000) async throws -> [ODPTStation] {
        // 開発中・APIキーがない場合はモックデータから最寄り駅を返す
        let useMockData = false // 実際のAPIを使用
        
        if useMockData || !configuration.hasAPIKey {
            print("ODPT API: Using mock nearby stations")
            // とりあえず東京駅を返す
            return getMockStations(matching: "東京").prefix(1).map { $0 }
        }
        
        // TODO: 実装を完成させる
        // 1. 全駅データをキャッシュから取得または初回ロード
        // 2. 位置情報で絞り込み
        // 3. 距離でソート
        
        return []
    }
    
    // MARK: - Private Methods
    
    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("ODPT API Request: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ODPTAPIError.invalidResponse
            }
            
            print("ODPT API Response: Status \(httpResponse.statusCode), Data size: \(data.count) bytes")
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    // デバッグ用：レスポンスの最初の500文字を出力
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("ODPT API Response JSON (first 500 chars): \(String(jsonString.prefix(500)))")
                    }
                    
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("Decoding error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Failed to decode JSON: \(jsonString)")
                    }
                    throw ODPTAPIError.decodingError(error)
                }
            case 429:
                throw ODPTAPIError.rateLimitExceeded
            default:
                throw ODPTAPIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            if error is ODPTAPIError {
                throw error
            }
            throw ODPTAPIError.networkError(error)
        }
    }
    
    /// 路線情報を取得
    func getRailwayInfo(railwayId: String) async throws -> ODPTRailway? {
        guard configuration.hasAPIKey else {
            throw ODPTAPIError.missingAPIKey
        }
        
        var components = URLComponents(string: "\(configuration.baseURL)/odpt:Railway")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey),
            URLQueryItem(name: "owl:sameAs", value: railwayId)
        ]
        
        guard let url = components.url else {
            throw ODPTAPIError.invalidResponse
        }
        
        let railways: [ODPTRailway] = try await request(url: url)
        return railways.first
    }
    
    /// 駅IDから駅情報を取得
    func getStation(stationId: String) async throws -> ODPTStation? {
        // キャッシュをチェック
        if let cachedStation = stationCache[stationId] {
            return cachedStation
        }
        
        guard configuration.hasAPIKey else {
            // APIキーがない場合はnil返す（ハードコーディングは禁止）
            return nil
        }
        
        // API呼び出し
        var components = URLComponents(string: "\(configuration.baseURL)/odpt:Station")!
        components.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey),
            URLQueryItem(name: "owl:sameAs", value: stationId)
        ]
        
        guard let url = components.url else {
            throw ODPTAPIError.invalidResponse
        }
        
        let stations: [ODPTStation] = try await request(url: url)
        if let station = stations.first {
            // キャッシュに保存
            stationCache[stationId] = station
            return station
        }
        
        return nil
    }
    
    /// 同じ路線の全駅を順序付きで取得
    func getStationsOnRailway(railwayId: String) async throws -> [ODPTStation] {
        // まず路線情報を取得して駅の順序を確認
        if let railway = try await getRailwayInfo(railwayId: railwayId),
           let stationOrder = railway.stationOrder {
            // 駅の順序情報がある場合は、それに基づいて全駅を取得
            var orderedStations: [ODPTStation] = []
            
            // 順序に従って並べる
            let sortedOrder = stationOrder.sorted { $0.index < $1.index }
            
            for order in sortedOrder {
                // 各駅の情報を取得（キャッシュを活用）
                var components = URLComponents(string: "\(configuration.baseURL)/odpt:Station")!
                components.queryItems = [
                    URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey),
                    URLQueryItem(name: "owl:sameAs", value: order.station)
                ]
                
                if let url = components.url {
                    let stations: [ODPTStation] = try await request(url: url)
                    if let station = stations.first {
                        orderedStations.append(station)
                    }
                }
            }
            
            return orderedStations
        } else {
            // 順序情報がない場合は、路線IDで全駅を取得
            var components = URLComponents(string: "\(configuration.baseURL)/odpt:Station")!
            components.queryItems = [
                URLQueryItem(name: "acl:consumerKey", value: configuration.apiKey),
                URLQueryItem(name: "odpt:railway", value: railwayId)
            ]
            
            guard let url = components.url else {
                throw ODPTAPIError.invalidResponse
            }
            
            return try await request(url: url)
        }
    }
    
    /// キャッシュをクリア
    func clearCache() {
        cache.removeAllCachedResponses()
    }
}

// MARK: - Mock Data

extension ODPTAPIClient {
    /// モック駅データを返す
    private func getMockStations(matching query: String) -> [ODPTStation] {
        print("ODPT Mock: Searching for '\(query)'")
        
        // ひらがな読みも追加
        let stationData: [(kanji: String, hiragana: String, romaji: String, code: String)] = [
            ("東京", "とうきょう", "Tokyo", "JY01"),
            ("新宿", "しんじゅく", "Shinjuku", "JY17"),
            ("渋谷", "しぶや", "Shibuya", "JY20"),
            ("池袋", "いけぶくろ", "Ikebukuro", "JY13"),
            ("上野", "うえの", "Ueno", "JY05"),
            ("品川", "しながわ", "Shinagawa", "JY25")
        ]
        
        let mockStations = [
            ODPTStation(
                id: "urn:uuid:mock-tokyo-1",
                sameAs: "odpt.Station:JR-East.Yamanote.Tokyo",
                date: "2024-01-01T00:00:00+09:00",
                title: "東京",
                stationTitle: ODPTMultilingualTitle(ja: "東京", en: "Tokyo"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                `operator`: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY01",
                connectingRailway: ["odpt.Railway:JR-East.ChuoRapid", "odpt.Railway:JR-East.Keihin-TohokuNegishi"]
            ),
            ODPTStation(
                id: "urn:uuid:mock-shinjuku-1",
                sameAs: "odpt.Station:JR-East.Yamanote.Shinjuku",
                date: "2024-01-01T00:00:00+09:00",
                title: "新宿",
                stationTitle: ODPTMultilingualTitle(ja: "新宿", en: "Shinjuku"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                `operator`: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY17",
                connectingRailway: ["odpt.Railway:JR-East.ChuoRapid", "odpt.Railway:JR-East.ShonanShinjuku"]
            ),
            ODPTStation(
                id: "urn:uuid:mock-shibuya-1",
                sameAs: "odpt.Station:JR-East.Yamanote.Shibuya",
                date: "2024-01-01T00:00:00+09:00",
                title: "渋谷",
                stationTitle: ODPTMultilingualTitle(ja: "渋谷", en: "Shibuya"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                `operator`: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY20",
                connectingRailway: ["odpt.Railway:TokyuDenentoshi", "odpt.Railway:TokyuToyoko"]
            ),
            ODPTStation(
                id: "urn:uuid:mock-ikebukuro-1",
                sameAs: "odpt.Station:JR-East.Yamanote.Ikebukuro",
                date: "2024-01-01T00:00:00+09:00",
                title: "池袋",
                stationTitle: ODPTMultilingualTitle(ja: "池袋", en: "Ikebukuro"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                `operator`: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY13",
                connectingRailway: ["odpt.Railway:TobuTojo", "odpt.Railway:SeibuIkebukuro"]
            ),
            ODPTStation(
                id: "urn:uuid:mock-ueno-1",
                sameAs: "odpt.Station:JR-East.Yamanote.Ueno",
                date: "2024-01-01T00:00:00+09:00",
                title: "上野",
                stationTitle: ODPTMultilingualTitle(ja: "上野", en: "Ueno"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                `operator`: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY05",
                connectingRailway: ["odpt.Railway:JR-East.Keihin-TohokuNegishi"]
            ),
            ODPTStation(
                id: "urn:uuid:mock-shinagawa-1",
                sameAs: "odpt.Station:JR-East.Yamanote.Shinagawa",
                date: "2024-01-01T00:00:00+09:00",
                title: "品川",
                stationTitle: ODPTMultilingualTitle(ja: "品川", en: "Shinagawa"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                `operator`: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY25",
                connectingRailway: ["odpt.Railway:JR-East.Tokaido"]
            )
        ]
        
        // クエリに基づいてフィルタリング - ひらがなにも対応
        let lowercasedQuery = query.lowercased()
        let filtered = mockStations.enumerated().compactMap { index, station -> ODPTStation? in
            let jaTitle = station.stationTitle?.ja?.lowercased() ?? ""
            let enTitle = station.stationTitle?.en?.lowercased() ?? ""
            let title = station.title.lowercased()
            
            // 対応するひらがな読みを取得
            let hiragana = index < stationData.count ? stationData[index].hiragana : ""
            
            let matches = jaTitle.contains(lowercasedQuery) ||
                   enTitle.contains(lowercasedQuery) ||
                   title.contains(lowercasedQuery) ||
                   hiragana.contains(lowercasedQuery)
            
            if matches {
                print("ODPT Mock: Found match - \(station.stationTitle?.ja ?? station.title)")
                return station
            }
            
            return nil
        }
        
        print("ODPT Mock: Found \(filtered.count) stations matching '\(query)'")
        return filtered
    }
    
    /// モック時刻表データを返す
    private func getMockTimetable(for stationId: String, railway: String) -> [ODPTStationTimetable] {
        // 現在時刻から2時間分の時刻表を生成
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        var timetableObjects: [ODPTTrainTimetableObject] = []
        
        // 5分間隔で列車を生成
        for i in 0..<24 {
            let minute = (currentMinute / 5 + i) * 5 % 60
            let hour = (currentHour + (currentMinute / 5 + i) * 5 / 60) % 24
            
            timetableObjects.append(
                ODPTTrainTimetableObject(
                    departureTime: String(format: "%02d:%02d", hour, minute),
                    trainType: "odpt.TrainType:JR-East.Local",
                    trainTypeTitle: ODPTMultilingualTitle(ja: "各駅停車", en: "Local"),
                    trainNumber: String(format: "%d%02d", hour, minute),
                    trainName: nil,
                    destinationStation: ["odpt.Station:JR-East.Yamanote.Osaki"],
                    destinationStationTitle: ODPTMultilingualTitle(ja: "大崎", en: "Osaki"),
                    isLast: false,
                    isOrigin: false,
                    platformNumber: "1",
                    note: nil
                )
            )
        }
        
        return [
            ODPTStationTimetable(
                id: "urn:uuid:mock-timetable-1",
                sameAs: "odpt.StationTimetable:JR-East.Yamanote.\(stationId)",
                date: "2024-01-01T00:00:00+09:00",
                issuedBy: "odpt.Operator:JR-East",
                railway: railway,
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                station: stationId,
                stationTitle: ODPTMultilingualTitle(ja: "駅", en: "Station"),
                railDirection: "odpt.RailDirection:JR-East.Osaki",
                railDirectionTitle: ODPTMultilingualTitle(ja: "大崎方面", en: "For Osaki"),
                calendar: "odpt.Calendar:Weekday",
                calendarTitle: ODPTMultilingualTitle(ja: "平日", en: "Weekday"),
                stationTimetableObject: timetableObjects
            )
        ]
    }
}

// MARK: - 経路検索関連

extension ODPTAPIClient {
    /// 簡易的な経路検索（時刻表ベース）
    /// 注：ODPT APIには直接的な経路検索APIがないため、時刻表から組み立てる必要がある
    func searchRoute(
        from departureStation: String,
        to arrivalStation: String,
        departureTime: Date? = nil
    ) async throws -> [RouteSearchResult] {
        // TODO: 実装
        // 1. 出発駅と到着駅の路線を特定
        // 2. 同一路線なら直通列車を検索
        // 3. 異なる路線なら乗り換え駅を特定
        // 4. 時刻表から該当する列車を検索
        // 5. RouteSearchResultに変換
        
        []
    }
}
