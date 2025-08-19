//
//  RouteSearchViewModel.swift
//  TrainAlert
//
//  経路検索画面のViewModel
//

import Combine
import CoreLocation
import Foundation
import SwiftUI

@MainActor
class RouteSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var departureStation: String = ""
    @Published var arrivalStation: String = ""
    @Published var departureTime = Date()
    @Published var searchResults: [RouteSearchResult] = [] {
        didSet {
            print("searchResults didSet: \(searchResults.count) results")
        }
    }
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // 駅検索用
    @Published var departureStationSuggestions: [ODPTStation] = []
    @Published var arrivalStationSuggestions: [ODPTStation] = []
    @Published var isSearchingDepartureStation: Bool = false
    @Published var isSearchingArrivalStation: Bool = false
    
    // 選択された駅
    @Published var selectedDepartureStation: ODPTStation?
    @Published var selectedArrivalStation: ODPTStation?
    
    // お気に入り状態の監視用
    @Published var favoriteRoutes: [FavoriteRoute] = []
    
    // MARK: - Private Properties
    
    private let apiClient = ODPTAPIClient.shared
    private let heartRailsClient = HeartRailsAPIClient.shared
    private let cacheManager = APICacheManager.shared
    private let favoriteRouteManager = FavoriteRouteManager.shared
    private var searchTask: Task<Void, Never>?
    private var stationSearchTask: Task<Void, Never>?
    private var departureSearchWorkItem: DispatchWorkItem?
    private var arrivalSearchWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    
    init() {
        // お気に入りリストを初期化
        loadFavoriteRoutes()
        
        // FavoriteRouteManagerの変更を監視
        favoriteRouteManager.$favoriteRoutes
            .sink { [weak self] routes in
                print("FavoriteRouteManager updated: \(routes.count) routes")
                self?.favoriteRoutes = routes
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var canSearch: Bool {
        selectedDepartureStation != nil && selectedArrivalStation != nil
    }
    
    /// 現在サポートされている路線検索の制約を取得
    var searchConstraintMessage: String? {
        guard let departureStation = selectedDepartureStation else { return nil }
        
        // 将来的に複数路線対応時はここを変更
        return "\(departureStation.railwayTitle?.ja ?? departureStation.railway ?? "")の駅のみ検索可能"
    }
    
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: departureTime)
    }
    
    // MARK: - Public Methods
    
    /// 出発駅を検索
    func searchDepartureStation(_ query: String) {
        // 前の検索をキャンセル
        departureSearchWorkItem?.cancel()
        stationSearchTask?.cancel()
        
        // 空の検索の場合は即座にクリア
        guard !query.isEmpty else {
            departureStationSuggestions = []
            isSearchingDepartureStation = false
            return
        }
        
        // 1文字の場合も即座にクリア（2文字以上で検索）
        guard query.count >= 2 else {
            departureStationSuggestions = []
            isSearchingDepartureStation = false
            return
        }
        
        // デバウンス：0.5秒待機してから検索
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            self.stationSearchTask = Task {
                await MainActor.run {
                    self.isSearchingDepartureStation = true
                }
                
                defer {
                    Task {
                        await MainActor.run {
                            self.isSearchingDepartureStation = false
                        }
                    }
                }
                
                do {
                    // まずキャッシュを確認
                    if let cachedStations = self.cacheManager.getCachedStationSearchResult(forQuery: query) {
                        if !Task.isCancelled {
                            await MainActor.run {
                                self.departureStationSuggestions = Array(cachedStations.prefix(10))
                            }
                        }
                        return
                    }
                    
                    // HeartRails APIで高速に駅名検索
                    let heartRailsStations = try await self.heartRailsClient.searchStations(by: query)
                    
                    // ODPT形式に変換
                    let stations = heartRailsStations.map { $0.toODPTStation() }
                    
                    // キャッシュに保存
                    self.cacheManager.cacheStationSearchResult(stations, forQuery: query)
                    
                    // タスクがキャンセルされていない場合のみ更新
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.departureStationSuggestions = Array(stations.prefix(10))
                        }
                    }
                } catch {
                    // エラーは無視して空の結果を返す
                    await MainActor.run {
                        self.departureStationSuggestions = []
                    }
                }
            }
        }
        
        departureSearchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// 到着駅を検索
    func searchArrivalStation(_ query: String) {
        // 前の検索をキャンセル
        arrivalSearchWorkItem?.cancel()
        stationSearchTask?.cancel()
        
        // 空の検索の場合は即座にクリア
        guard !query.isEmpty else {
            arrivalStationSuggestions = []
            isSearchingArrivalStation = false
            return
        }
        
        // 1文字の場合も即座にクリア（2文字以上で検索）
        guard query.count >= 2 else {
            arrivalStationSuggestions = []
            isSearchingArrivalStation = false
            return
        }
        
        // デバウンス：0.5秒待機してから検索
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            self.stationSearchTask = Task {
                await MainActor.run {
                    self.isSearchingArrivalStation = true
                }
                
                defer {
                    Task {
                        await MainActor.run {
                            self.isSearchingArrivalStation = false
                        }
                    }
                }
                
                do {
                    // まずキャッシュを確認
                    if let cachedStations = self.cacheManager.getCachedStationSearchResult(forQuery: query) {
                        if !Task.isCancelled {
                            await MainActor.run {
                                // 駅候補をフィルタリング
                                let filteredStations = self.filterStations(cachedStations, for: .arrival)
                                self.arrivalStationSuggestions = Array(filteredStations.prefix(10))
                            }
                        }
                        return
                    }
                    
                    // HeartRails APIで高速に駅名検索
                    let heartRailsStations = try await self.heartRailsClient.searchStations(by: query)
                    
                    // ODPT形式に変換
                    let stations = heartRailsStations.map { $0.toODPTStation() }
                    
                    // 駅候補をフィルタリング
                    let filteredStations = self.filterStations(stations, for: .arrival)
                    
                    // キャッシュに保存（フィルタリング前のデータを保存）
                    self.cacheManager.cacheStationSearchResult(stations, forQuery: query)
                    
                    // タスクがキャンセルされていない場合のみ更新
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.arrivalStationSuggestions = Array(filteredStations.prefix(10))
                        }
                    }
                } catch {
                    // エラーは無視して空の結果を返す
                    await MainActor.run {
                        self.arrivalStationSuggestions = []
                    }
                }
            }
        }
        
        arrivalSearchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    /// 出発駅を選択
    func selectDepartureStation(_ station: ODPTStation) {
        selectedDepartureStation = station
        departureStation = station.stationTitle?.ja ?? station.title
        departureStationSuggestions = []
    }
    
    /// 到着駅を選択
    func selectArrivalStation(_ station: ODPTStation) {
        selectedArrivalStation = station
        arrivalStation = station.stationTitle?.ja ?? station.title
        arrivalStationSuggestions = []
    }
    
    // 駅のODPT IDを保持（TrainTimetable取得用）
    private var odptDepartureStationId: String?
    private var odptArrivalStationId: String?
    
    /// 経路を検索
    func searchRoute() {
        print("searchRoute called - canSearch: \(canSearch), isSearching: \(isSearching)")
        print("selectedDepartureStation: \(selectedDepartureStation?.stationTitle?.ja ?? "nil")")
        print("selectedArrivalStation: \(selectedArrivalStation?.stationTitle?.ja ?? "nil")")
        
        guard canSearch,
              !isSearching,
              let departureStation = selectedDepartureStation,
              let arrivalStation = selectedArrivalStation else { 
            print("searchRoute guard failed - canSearch: \(canSearch), isSearching: \(isSearching)")
            return 
        }
        
        searchTask?.cancel()
        searchTask = Task {
            await MainActor.run {
                self.isSearching = true
                print("isSearching set to true")
            }
            defer { 
                Task {
                    await MainActor.run {
                        self.isSearching = false
                        print("isSearching set to false")
                    }
                }
            }
            
            do {
                print("Starting route search...")
                
                // Step 1: HeartRails駅情報からODPT IDへの変換を試みる
                var odptRailwayId: String?
                
                // 出発駅のID変換
                let departureLineName = departureStation.railwayTitle?.ja ?? departureStation.railway ?? ""
                print("Departure line name: \(departureLineName)")
                if !departureLineName.isEmpty {
                    self.odptDepartureStationId = StationIDMapper.convertToODPTStationIDWithCache(
                        stationName: departureStation.stationTitle?.ja ?? departureStation.title,
                        lineName: departureLineName
                    )
                    odptRailwayId = StationIDMapper.getODPTRailwayID(from: departureLineName)
                    print("ODPT departure station ID: \(self.odptDepartureStationId ?? "nil")")
                    print("ODPT railway ID: \(odptRailwayId ?? "nil")")
                }
                
                // 到着駅のID変換（メンバ変数に保存）
                let arrivalLineName = arrivalStation.railwayTitle?.ja ?? arrivalStation.railway ?? ""
                if !arrivalLineName.isEmpty {
                    self.odptArrivalStationId = StationIDMapper.convertToODPTStationIDWithCache(
                        stationName: arrivalStation.stationTitle?.ja ?? arrivalStation.title,
                        lineName: arrivalLineName
                    )
                    print("ODPT arrival station ID: \(self.odptArrivalStationId ?? "nil")")
                }
                
                // 出発駅と到着駅が同じ路線かチェック
                let isDifferentLine = departureStation.railway != arrivalStation.railway
                if isDifferentLine {
                    print("⚠️ 異なる路線間の経路検索です")
                    print("  出発: \(departureStation.railway ?? "") - \(departureStation.stationTitle?.ja ?? "")")
                    print("  到着: \(arrivalStation.railway ?? "") - \(arrivalStation.stationTitle?.ja ?? "")")
                }
                
                // ODPT APIがサポートしている路線かチェック
                let supportedRailways = [
                    "odpt.Railway:JR-East",  // JR東日本の全路線
                    "odpt.Railway:TokyoMetro",  // 東京メトロの全路線
                    "odpt.Railway:Toei"  // 都営地下鉄の全路線
                ]
                
                let isSupported = supportedRailways.contains { prefix in
                    odptRailwayId?.hasPrefix(prefix) ?? false
                }
                
                // Step 2: 変換が成功し、かつサポートされている路線の場合は時刻表データを取得
                // ただし、現在は同一路線のみ対応
                if let stationId = self.odptDepartureStationId,
                   let railwayId = odptRailwayId,
                   isSupported && !isDifferentLine {
                    print("Fetching timetable for station: \(stationId), railway: \(railwayId)")
                    
                    // キャッシュを確認（空の結果はキャッシュしない）
                    if let cachedTimetables = cacheManager.getCachedTimetable(forStation: stationId, railway: railwayId),
                       !cachedTimetables.isEmpty {
                        print("Using cached timetables: \(cachedTimetables.count) timetables")
                        let results = await createRouteResults(from: cachedTimetables)
                        print("Setting search results from cache: \(results.count) routes")
                        await MainActor.run {
                            self.searchResults = results
                            print("Search results actually set: \(self.searchResults.count)")
                        }
                        return
                    } else if let cachedTimetables = cacheManager.getCachedTimetable(forStation: stationId, railway: railwayId),
                              cachedTimetables.isEmpty {
                        print("Cached result is empty, clearing cache and fetching fresh data")
                        cacheManager.clearCachedTimetable(forStation: stationId, railway: railwayId)
                    }
                    
                    // ODPT APIから時刻表を取得
                    print("Fetching from ODPT API...")
                    
                    // 現在の曜日に応じてカレンダータイプを選択
                    let calendarType = getCalendarType()
                    print("Using calendar type: \(calendarType)")
                    
                    var timetables = try await apiClient.getStationTimetable(
                        stationId: stationId,
                        railwayId: railwayId,
                        calendar: calendarType
                    )
                    
                    print("ODPT API: Received \(timetables.count) timetables")
                    
                    // もし時刻表が取得できなかった場合、他のカレンダータイプも試す
                    if timetables.isEmpty {
                        // 全てのカレンダータイプを試す（最も可能性の高い順）
                        let allCalendarTypes: [String]
                        if calendarType == "odpt.Calendar:SundayHoliday" {
                            // 日曜日の場合、まずWeekdayを試す（多くの事業者が日曜もWeekdayデータを使用）
                            allCalendarTypes = ["odpt.Calendar:Weekday", "odpt.Calendar:SaturdayHoliday"]
                        } else {
                            // その他の曜日の場合
                            allCalendarTypes = ["odpt.Calendar:Weekday", "odpt.Calendar:SaturdayHoliday", "odpt.Calendar:SundayHoliday"]
                                .filter { $0 != calendarType }
                        }
                        
                        for tryCalendarType in allCalendarTypes {
                            let tryTimetables = try await apiClient.getStationTimetable(
                                stationId: stationId,
                                railwayId: railwayId,
                                calendar: tryCalendarType
                            )
                            if !tryTimetables.isEmpty {
                                timetables = tryTimetables
                                break
                            }
                        }
                    }
                    
                    // 空の結果の場合はエラーとして扱う
                    if timetables.isEmpty {
                        print("⚠️ ERROR: ODPT API returned empty timetables")
                        print("  Station ID: \(stationId)")
                        print("  Railway ID: \(railwayId)")
                        print("  Calendar: \(calendarType)")
                        print("  Possible causes:")
                        print("  - API key does not have permission for timetable data")
                        print("  - Station/Railway ID format is incorrect")
                        print("  - API service is temporarily unavailable")
                        
                        await MainActor.run {
                            let availableOperators = ODPTAPIConfiguration.shared.availableOperators
                            let operatorsList = availableOperators.map { "• \($0)" }.joined(separator: "\n")
                            
                            self.errorMessage = """
                            時刻表データを取得できませんでした。
                            
                            現在のAPIキーで利用可能な路線：
                            \(operatorsList)
                            
                            \(ODPTAPIConfiguration.shared.isJRAvailable ? "" : "JR線の時刻表データにはアクセスできません。\n")上記の路線の駅をお試しください。
                            """
                            self.showError = true
                            self.searchResults = []
                        }
                        return
                    } else {
                        // 正常な結果のみキャッシュに保存
                        cacheManager.cacheTimetable(timetables, forStation: stationId, railway: railwayId)
                    }
                    
                    // 時刻表から経路を生成（TrainTimetableも取得）
                    let results = await createRouteResults(from: timetables)
                    print("Setting search results from API: \(results.count) routes")
                    print("Source: REAL API DATA (ODPT)")
                    await MainActor.run {
                        self.searchResults = results
                    }
                } else {
                    // データが取得できない理由を明確化
                    let reason: String
                    if isDifferentLine {
                        reason = "異なる路線間の経路検索には対応していません"
                    } else if !isSupported {
                        reason = "この路線の時刻表データは利用できません"
                    } else {
                        reason = "駅情報の取得に失敗しました"
                    }
                    
                    print("🚫 検索失敗: \(reason)")
                    
                    await MainActor.run {
                        self.searchResults = []
                        self.errorMessage = reason
                        self.showError = true
                    }
                }
            } catch {
                print("Route search error: \(error)")
                handleError(error)
            }
        }
    }
    
    /// 最寄り駅から設定
    func setNearbyStation(for type: StationType, location: CLLocation) {
        Task {
            do {
                // HeartRails APIで最寄り駅を検索
                let heartRailsStations = try await heartRailsClient.getNearbyStations(location: location)
                if let nearestStation = heartRailsStations.first {
                    let odptStation = nearestStation.toODPTStation()
                    switch type {
                    case .departure:
                        selectDepartureStation(odptStation)
                    case .arrival:
                        selectArrivalStation(odptStation)
                    }
                }
            } catch {
                handleError(error)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 駅候補をフィルタリング（将来の複数路線対応のため分離）
    private func filterStations(_ stations: [ODPTStation], for searchType: StationType) -> [ODPTStation] {
        // 現在は同一路線のみサポート
        // 将来的にはここで複数路線の乗換を考慮したフィルタリングを実装
        
        switch searchType {
        case .arrival:
            if let departureRailway = selectedDepartureStation?.railway {
                return stations.filter { $0.railway == departureRailway }
            }
        case .departure:
            if let arrivalRailway = selectedArrivalStation?.railway {
                return stations.filter { $0.railway == arrivalRailway }
            }
        }
        
        return stations
    }
    
    private func createRouteResults(from timetables: [ODPTStationTimetable]) async -> [RouteSearchResult] {
        print("Creating route results from \(timetables.count) timetables")
        
        // 時刻表から指定時刻以降の列車を抽出
        var results: [RouteSearchResult] = []
        
        let calendar = Calendar.current
        let targetTime = calendar.dateComponents([.hour, .minute], from: departureTime)
        
        // 出発駅と到着駅の正しい方向を判定する必要がある
        for timetable in timetables {
            print("Processing timetable with \(timetable.stationTimetableObject.count) trains")
            print("Timetable direction: \(timetable.railDirectionTitle?.ja ?? "不明")")
            print("Rail direction ID: \(timetable.railDirection ?? "nil")")
            
            // 方向の確認（将来的には駅の順序から判定する必要がある）
            // 現在は全ての方向を試す
            
            for train in timetable.stationTimetableObject {
                // 出発時刻をパース
                let components = train.departureTime.split(separator: ":").compactMap { Int($0) }
                guard components.count == 2 else { 
                    print("Invalid departure time format: \(train.departureTime)")
                    continue 
                }
                
                var trainDepartureComponents = calendar.dateComponents([.year, .month, .day], from: departureTime)
                trainDepartureComponents.hour = components[0]
                trainDepartureComponents.minute = components[1]
                
                guard let trainDepartureTime = calendar.date(from: trainDepartureComponents),
                      trainDepartureTime >= departureTime else { continue }
                
                // 列車番号がある場合は詳細な時刻表を取得
                var actualArrivalTime: Date?
                
                if let trainNumber = train.trainNumber,
                   let departureStationId = self.odptDepartureStationId,
                   let arrivalStationId = self.odptArrivalStationId {
                    print("Fetching train timetable for train \(trainNumber)")
                    print("Looking for: \(departureStationId) -> \(arrivalStationId)")
                    
                    do {
                        // TrainTimetableを取得して正確な到着時刻を探す
                        let trainTimetables = try await apiClient.getTrainTimetable(
                            trainNumber: trainNumber,
                            railwayId: timetable.railway,
                            calendar: timetable.calendar ?? "odpt.Calendar:Weekday"
                        )
                        
                        // 到着駅の時刻を探す
                        for trainTimetable in trainTimetables {
                            print("Train \(trainNumber) direction: \(trainTimetable.railDirectionTitle?.ja ?? "不明")")
                            
                            var foundDeparture = false
                            var departureIndex = -1
                            var arrivalIndex = -1
                            
                            // まず駅の順序を確認
                            for (index, stop) in trainTimetable.trainTimetableObject.enumerated() {
                                let stationId = stop.departureStation ?? stop.arrivalStation ?? ""
                                print("  Stop \(index): \(stationId) - dep: \(stop.departureTime ?? "nil"), arr: \(stop.arrivalTime ?? "nil")")
                                
                                if stop.departureStation == departureStationId || stop.arrivalStation == departureStationId {
                                    foundDeparture = true
                                    departureIndex = index
                                    print("    -> Found departure station at index \(index)")
                                }
                                if stop.arrivalStation == arrivalStationId || stop.departureStation == arrivalStationId {
                                    arrivalIndex = index
                                    print("    -> Found arrival station at index \(index)")
                                }
                            }
                            
                            // 出発駅の後に到着駅がある場合のみ有効
                            if foundDeparture && arrivalIndex > departureIndex && arrivalIndex >= 0 {
                                let arrivalStop = trainTimetable.trainTimetableObject[arrivalIndex]
                                // 到着時刻を取得（到着時刻がない場合は出発時刻を使用）
                                let timeString = arrivalStop.arrivalTime ?? arrivalStop.departureTime ?? ""
                                if let arrivalTime = parseTime(timeString, baseDate: trainDepartureTime) {
                                    actualArrivalTime = arrivalTime
                                    print("✅ Found actual arrival time: \(timeString) at station index \(arrivalIndex)")
                                    print("   Duration: \((arrivalTime.timeIntervalSince(trainDepartureTime) / 60)) minutes")
                                    break
                                }
                            } else if foundDeparture && departureIndex >= 0 && arrivalIndex >= 0 {
                                print("⚠️ Wrong direction: departure at \(departureIndex), arrival at \(arrivalIndex)")
                            }
                        }
                        
                        if actualArrivalTime == nil {
                            print("⚠️ Could not find arrival time for this direction")
                        }
                    } catch {
                        print("Failed to fetch train timetable: \(error)")
                    }
                }
                
                // 実際の到着時刻が取得できなかった場合はスキップ
                guard let arrivalTime = actualArrivalTime else {
                    print("⚠️ Skipping train \(train.trainNumber ?? "unknown") - no arrival time available")
                    continue
                }
                
                // デバッグ：最初の列車の詳細をログ出力
                if results.isEmpty {
                    print("First train details:")
                    print("  Departure time: \(train.departureTime)")
                    print("  Train type: \(train.trainTypeTitle?.ja ?? "nil")")
                    print("  Train number: \(train.trainNumber ?? "nil")")
                    print("  Destination: \(train.destinationStationTitle?.ja ?? "nil")")
                    print("  Actual arrival time: \(actualArrivalTime != nil ? "取得成功" : "推定値使用")")
                }
                
                let result = RouteSearchResult(
                    departureStation: selectedDepartureStation?.stationTitle?.ja ?? "",
                    arrivalStation: selectedArrivalStation?.stationTitle?.ja ?? "",
                    departureTime: trainDepartureTime,
                    arrivalTime: arrivalTime,
                    trainType: train.trainTypeTitle?.ja,
                    trainNumber: train.trainNumber,
                    transferCount: 0,
                    sections: [
                        RouteSection(
                            departureStation: selectedDepartureStation?.stationTitle?.ja ?? "",
                            arrivalStation: selectedArrivalStation?.stationTitle?.ja ?? "",
                            departureTime: trainDepartureTime,
                            arrivalTime: arrivalTime,
                            trainType: train.trainTypeTitle?.ja,
                            trainNumber: train.trainNumber,
                            railway: timetable.railway
                        )
                    ],
                    isActualArrivalTime: actualArrivalTime != nil
                )
                
                results.append(result)
                
                // 最大10件まで
                if results.count >= 10 {
                    break
                }
            }
        }
        
        // 統計情報を出力
        let actualCount = results.filter { $0.isActualArrivalTime }.count
        let estimatedCount = results.count - actualCount
        print("Generated \(results.count) route results")
        print("  - Actual arrival times: \(actualCount)")
        print("  - Estimated arrival times: \(estimatedCount)")
        
        return results
    }
    
    /// 時刻文字列をDateに変換
    private func parseTime(_ timeString: String, baseDate: Date) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        
        guard let parsedDate = calendar.date(from: dateComponents) else { return nil }
        
        // 時刻が基準時刻より前の場合は翌日として扱う（深夜運行対応）
        if parsedDate < baseDate {
            return calendar.date(byAdding: .day, value: 1, to: parsedDate)
        }
        
        return parsedDate
    }
    
    /// 現在の曜日に応じたカレンダータイプを取得
    private func getCalendarType() -> String {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: Date())
        
        // 日本の祝日判定は複雑なため、簡易的に土日のみ判定
        switch weekday {
        case 1: // 日曜日
            return "odpt.Calendar:SundayHoliday"
        case 7: // 土曜日
            return "odpt.Calendar:SaturdayHoliday"  // Saturdayではなく、SaturdayHolidayを使用
        default: // 平日
            return "odpt.Calendar:Weekday"
        }
    }
    
    private func handleError(_ error: Error) {
        if let odptError = error as? ODPTAPIError {
            errorMessage = odptError.localizedDescription
        } else {
            errorMessage = "エラーが発生しました: \(error.localizedDescription)"
        }
        showError = true
    }
    
    // MARK: - Favorite Route Methods
    
    /// お気に入りに経路を保存
    /// - Parameter route: 保存する経路
    /// - Returns: 保存成功の場合true、既に存在または上限に達している場合false
    func saveFavoriteRoute(_ route: RouteSearchResult) -> Bool {
        print("saveFavoriteRoute called for: \(route.departureStation) -> \(route.arrivalStation)")
        
        // RouteSearchResultをJSONエンコード
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let routeData = try? encoder.encode(route) else {
            print("Failed to encode route data")
            return false
        }
        
        // お気に入りに保存
        let favoriteRoute = favoriteRouteManager.createFavoriteRoute(
            departureStation: route.departureStation,
            arrivalStation: route.arrivalStation,
            departureTime: route.departureTime,
            nickName: nil,
            routeData: routeData
        )
        
        if favoriteRoute != nil {
            print("Favorite route saved successfully")
            // 保存成功後、お気に入りリストを更新
            loadFavoriteRoutes()
        } else {
            print("Failed to save favorite route")
        }
        
        return favoriteRoute != nil
    }
    
    /// お気に入りの空き容量を確認
    var canAddFavorite: Bool {
        !favoriteRouteManager.isAtMaxCapacity
    }
    
    /// お気に入りの残り枠数
    var remainingFavoriteCapacity: Int {
        20 - favoriteRouteManager.favoriteCount
    }
    
    /// 経路がお気に入りに登録済みかチェック
    /// - Parameter route: チェックする経路
    /// - Returns: 登録済みの場合true
    func isFavoriteRoute(_ route: RouteSearchResult) -> Bool {
        // 時刻を分単位で比較するためのフォーマッタ
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        let routeTimeString = formatter.string(from: route.departureTime)
        
        return favoriteRoutes.contains { favorite in
            guard let favoriteDepartureTime = favorite.departureTime else { return false }
            let favoriteTimeString = formatter.string(from: favoriteDepartureTime)
            
            return favorite.departureStation == route.departureStation &&
                   favorite.arrivalStation == route.arrivalStation &&
                   favoriteTimeString == routeTimeString
        }
    }
    
    /// お気に入りリストを読み込む
    private func loadFavoriteRoutes() {
        favoriteRouteManager.fetchFavoriteRoutes()
        // favoriteRoutesはFavoriteRouteManagerの監視で自動更新される
    }
    
    /// お気に入りをトグル（登録/解除）
    /// - Parameter route: トグルする経路
    /// - Returns: トグル結果（true: 追加、false: 削除、nil: エラー）
    func toggleFavoriteRoute(_ route: RouteSearchResult) -> Bool? {
        print("toggleFavoriteRoute called for: \(route.departureStation) -> \(route.arrivalStation)")
        
        // RouteSearchResultをJSONエンコード
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let routeData = try? encoder.encode(route)
        
        // お気に入りをトグル
        let result = favoriteRouteManager.toggleFavorite(
            departureStation: route.departureStation,
            arrivalStation: route.arrivalStation,
            departureTime: route.departureTime,
            nickName: nil,
            routeData: routeData
        )
        
        if result != nil {
            print("Favorite route toggled: \(result == true ? "added" : "removed")")
            // トグル後、お気に入りリストを更新
            loadFavoriteRoutes()
        } else {
            print("Failed to toggle favorite route")
        }
        
        return result
    }
    
    // MARK: - Nested Types
    
    enum StationType {
        case departure
        case arrival
    }
}
