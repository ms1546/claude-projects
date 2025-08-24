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
    private let routeSearchAlgorithm = RouteSearchAlgorithm()
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
        // 乗り換え対応により制約メッセージを更新
        nil  // 制約なし
    }
    
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(departureTime) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: departureTime)
        } else if calendar.isDateInTomorrow(departureTime) {
            formatter.dateFormat = "'明日' HH:mm"
            return formatter.string(from: departureTime)
        } else {
            // 2日以上先の場合は日付も表示
            formatter.dateFormat = "M/d HH:mm"
            return formatter.string(from: departureTime)
        }
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
                    // 非同期版を使用して正しい駅IDを取得
                    self.odptDepartureStationId = await StationIDMapper.convertToODPTStationIDAsync(
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
                    // 非同期版を使用して正しい駅IDを取得
                    self.odptArrivalStationId = await StationIDMapper.convertToODPTStationIDAsync(
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
                    
                    // 乗り換え経路探索を実行
                    await searchTransferRoute(
                        from: departureStation,
                        to: arrivalStation
                    )
                    return
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
                    
                    // 出発駅の時刻表を取得
                    var departureTimetables = try await apiClient.getStationTimetable(
                        stationId: stationId,
                        railwayId: railwayId,
                        calendar: calendarType
                    )
                    
                    print("ODPT API: Received \(departureTimetables.count) departure timetables")
                    
                    // 到着駅の時刻表も取得（同じ路線の場合のみ）
                    guard let arrivalStationId = odptArrivalStationId else {
                        print("Error: Arrival station ID is nil")
                        return
                    }
                    
                    var arrivalTimetables = try await apiClient.getStationTimetable(
                        stationId: arrivalStationId,
                        railwayId: railwayId,
                        calendar: calendarType
                    )
                    
                    print("ODPT API: Received \(arrivalTimetables.count) arrival timetables")
                    
                    // もし時刻表が取得できなかった場合、他のカレンダータイプも試す
                    if departureTimetables.isEmpty || arrivalTimetables.isEmpty {
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
                            if departureTimetables.isEmpty {
                                let tryDepartureTimetables = try await apiClient.getStationTimetable(
                                    stationId: stationId,
                                    railwayId: railwayId,
                                    calendar: tryCalendarType
                                )
                                if !tryDepartureTimetables.isEmpty {
                                    departureTimetables = tryDepartureTimetables
                                }
                            }
                            
                            if arrivalTimetables.isEmpty {
                                let tryArrivalTimetables = try await apiClient.getStationTimetable(
                                    stationId: arrivalStationId,
                                    railwayId: railwayId,
                                    calendar: tryCalendarType
                                )
                                if !tryArrivalTimetables.isEmpty {
                                    arrivalTimetables = tryArrivalTimetables
                                }
                            }
                            
                            if !departureTimetables.isEmpty && !arrivalTimetables.isEmpty {
                                break
                            }
                        }
                    }
                    
                    // 空の結果の場合はエラーとして扱う
                    if departureTimetables.isEmpty || arrivalTimetables.isEmpty {
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
                    }
                    
                    // 正しい方向の電車を抽出（両方の駅に停車する電車のみ）
                    var validTrainNumbers = Set<String>()
                    
                    // 出発駅の時刻表から電車番号を収集
                    for depTimetable in departureTimetables {
                        for train in depTimetable.stationTimetableObject {
                            if let trainNumber = train.trainNumber {
                                validTrainNumbers.insert(trainNumber)
                            }
                        }
                    }
                    
                    // 到着駅の時刻表と照合して、共通の電車番号のみを残す
                    var arrivalTrainNumbers = Set<String>()
                    for arrTimetable in arrivalTimetables {
                        for train in arrTimetable.stationTimetableObject {
                            if let trainNumber = train.trainNumber {
                                arrivalTrainNumbers.insert(trainNumber)
                            }
                        }
                    }
                    
                    // 両方の駅に停車する電車のみを有効とする
                    validTrainNumbers = validTrainNumbers.intersection(arrivalTrainNumbers)
                    print("Found \(validTrainNumbers.count) trains that stop at both stations")
                    
                    // 出発駅の時刻表を使用（フィルタリングは後で行う）
                    // validTrainNumbersは createRouteResults に渡して、そこでフィルタリング
                    let filteredTimetables = departureTimetables
                    
                    print("Will process \(validTrainNumbers.count) valid trains from \(filteredTimetables.map { $0.stationTimetableObject.count }.reduce(0, +)) total trains")
                    
                    // 正常な結果のみキャッシュに保存
                    cacheManager.cacheTimetable(filteredTimetables, forStation: stationId, railway: railwayId)
                    
                    // 時刻表から経路を生成（TrainTimetableも取得）
                    let results = await createRouteResults(from: filteredTimetables, validTrainNumbers: validTrainNumbers)
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
    
    /// 駅候補をフィルタリング（乗り換え対応版）
    private func filterStations(_ stations: [ODPTStation], for searchType: StationType) -> [ODPTStation] {
        // 乗り換え対応のため、同一路線の制限を緩和
        // ただし、完全に自由ではなく、妥当な経路のみを候補として表示
        
        switch searchType {
        case .arrival:
            // 到着駅の選択時は、基本的にすべての駅を候補として表示
            // ただし、同一路線の駅を優先的に表示
            if let departureRailway = selectedDepartureStation?.railway {
                // 同一路線の駅を先頭に、その他の駅を後ろに配置
                let sameLineStations = stations.filter { $0.railway == departureRailway }
                let otherStations = stations.filter { $0.railway != departureRailway }
                return sameLineStations + otherStations
            }
        case .departure:
            // 出発駅の選択時も同様
            if let arrivalRailway = selectedArrivalStation?.railway {
                let sameLineStations = stations.filter { $0.railway == arrivalRailway }
                let otherStations = stations.filter { $0.railway != arrivalRailway }
                return sameLineStations + otherStations
            }
        }
        
        return stations
    }
    
    private func createRouteResults(from timetables: [ODPTStationTimetable], validTrainNumbers: Set<String>? = nil) async -> [RouteSearchResult] {
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
            
            // validTrainNumbersが指定されている場合は、既に方向が確認済み
            // 指定されていない場合は、全ての方向を試す（後方互換性のため）
            
            for train in timetable.stationTimetableObject {
                // validTrainNumbersが指定されている場合は、それに含まれる電車のみを処理
                if let validNumbers = validTrainNumbers,
                   let trainNumber = train.trainNumber,
                   !validNumbers.contains(trainNumber) {
                    continue
                }
                
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
                                    
                                    // 中間駅情報を保存（後でsections作成に使用）
                                    var stopStations: [(name: String, depTime: Date?, arrTime: Date?)] = []
                                    for i in departureIndex...arrivalIndex {
                                        let stop = trainTimetable.trainTimetableObject[i]
                                        
                                        // 駅名を取得（日本語名がなければ駅IDから抽出）
                                        var stationName = stop.departureStationTitle?.ja ?? stop.arrivalStationTitle?.ja ?? ""
                                        
                                        // 日本語名が取得できない場合は、駅IDから取得を試みる
                                        if stationName.isEmpty {
                                            let stationId = stop.departureStation ?? stop.arrivalStation ?? ""
                                            if !stationId.isEmpty {
                                                // APIから駅情報を取得（非同期だが、ここでは同期的に処理）
                                                stationName = stationId.components(separatedBy: ".").last ?? ""
                                            }
                                        }
                                        
                                        let depTimeStr = stop.departureTime ?? stop.arrivalTime ?? ""
                                        let arrTimeStr = stop.arrivalTime ?? stop.departureTime ?? ""
                                        
                                        let depTime = depTimeStr.isEmpty ? nil : parseTime(depTimeStr, baseDate: trainDepartureTime)
                                        let arrTime = arrTimeStr.isEmpty ? nil : parseTime(arrTimeStr, baseDate: trainDepartureTime)
                                        
                                        stopStations.append((name: stationName, depTime: depTime, arrTime: arrTime))
                                    }
                                    
                                    // 中間駅情報を sections に変換
                                    var sections: [RouteSection] = []
                                    if stopStations.count > 1 {
                                        for i in 0..<(stopStations.count - 1) {
                                            let currentStop = stopStations[i]
                                            let nextStop = stopStations[i + 1]
                                            
                                            if let depTime = currentStop.depTime ?? currentStop.arrTime,
                                               let arrTime = nextStop.arrTime ?? nextStop.depTime {
                                                sections.append(RouteSection(
                                                    departureStation: currentStop.name,
                                                    arrivalStation: nextStop.name,
                                                    departureTime: depTime,
                                                    arrivalTime: arrTime,
                                                    trainType: train.trainTypeTitle?.ja,
                                                    trainNumber: train.trainNumber,
                                                    railway: timetable.railway
                                                ))
                                            }
                                        }
                                    }
                                    
                                    // sections が作成できた場合は result に含める
                                    if !sections.isEmpty {
                                        let result = RouteSearchResult(
                                            departureStation: selectedDepartureStation?.stationTitle?.ja ?? "",
                                            arrivalStation: selectedArrivalStation?.stationTitle?.ja ?? "",
                                            departureTime: trainDepartureTime,
                                            arrivalTime: arrivalTime,
                                            trainType: train.trainTypeTitle?.ja,
                                            trainNumber: train.trainNumber,
                                            transferCount: 0,
                                            sections: sections,
                                            isActualArrivalTime: true
                                        )
                                        print("✅ Created route with \(sections.count) sections")
                                        for (idx, section) in sections.enumerated() {
                                            print("   Section \(idx): \(section.departureStation) -> \(section.arrivalStation)")
                                        }
                                        results.append(result)
                                        // 最大10件まで
                                        if results.count >= 10 {
                                            return results
                                        }
                                    }
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
    
    /// 選択された出発日時に応じたカレンダータイプを取得
    private func getCalendarType() -> String {
        // CalendarHelperを使用して、出発日時に応じたカレンダーIDを取得
        CalendarHelper.shared.getODPTCalendarId(for: departureTime)
    }
    
    private func handleError(_ error: Error) {
        if let odptError = error as? ODPTAPIError {
            errorMessage = odptError.localizedDescription
        } else {
            errorMessage = "エラーが発生しました: \(error.localizedDescription)"
        }
        showError = true
    }
    
    /// 乗り換え経路を検索
    private func searchTransferRoute(from departureStation: ODPTStation, to arrivalStation: ODPTStation) async {
        print("🚃 Starting transfer route search...")
        
        do {
            // 経路探索を実行
            let searchResults = try await routeSearchAlgorithm.searchRoute(
                from: departureStation.stationTitle?.ja ?? departureStation.title,
                departureLine: departureStation.railwayTitle?.ja ?? departureStation.railway ?? "",
                to: arrivalStation.stationTitle?.ja ?? arrivalStation.title,
                arrivalLine: arrivalStation.railwayTitle?.ja ?? arrivalStation.railway
            )
            
            print("Found \(searchResults.count) transfer routes")
            
            // RouteSearchResultに変換
            var routeResults: [RouteSearchResult] = []
            
            for (index, result) in searchResults.enumerated() {
                print("Converting route \(index + 1):")
                print("  Total time: \(result.totalTime) minutes")
                print("  Transfer count: \(result.transferCount)")
                print("  Sections: \(result.sections.count)")
                
                // 各区間の詳細情報を出力
                for (sectionIndex, section) in result.sections.enumerated() {
                    print("  Section \(sectionIndex + 1): \(section.fromStation) -> \(section.toStation) (\(section.line))")
                }
                
                // 出発時刻を計算（現在時刻から適切な時刻を選択）
                let calendar = Calendar.current
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: departureTime)
                dateComponents.hour = calendar.component(.hour, from: departureTime)
                dateComponents.minute = calendar.component(.minute, from: departureTime)
                
                guard let baseTime = calendar.date(from: dateComponents) else { continue }
                
                // 到着時刻を計算
                let arrivalTime = baseTime.addingTimeInterval(TimeInterval(result.totalTime * 60))
                
                // RouteSection配列を作成
                var routeSections: [RouteSection] = []
                var currentTime = baseTime
                
                for section in result.sections {
                    let sectionDepartureTime = currentTime
                    let sectionArrivalTime = currentTime.addingTimeInterval(TimeInterval(section.duration * 60))
                    
                    routeSections.append(RouteSection(
                        departureStation: section.fromStation,
                        arrivalStation: section.toStation,
                        departureTime: sectionDepartureTime,
                        arrivalTime: sectionArrivalTime,
                        trainType: nil,  // 乗り換え検索では列車種別は不明
                        trainNumber: nil,
                        railway: section.line
                    ))
                    
                    // 次の区間の開始時刻を更新（乗り換え時間を考慮）
                    if section != result.sections.last {
                        let transferTime = StationConnectionManager.shared.getTransferTime(for: section.toStation)
                        currentTime = sectionArrivalTime.addingTimeInterval(TimeInterval(transferTime * 60))
                    } else {
                        currentTime = sectionArrivalTime
                    }
                }
                
                let routeResult = RouteSearchResult(
                    departureStation: departureStation.stationTitle?.ja ?? departureStation.title,
                    arrivalStation: arrivalStation.stationTitle?.ja ?? arrivalStation.title,
                    departureTime: baseTime,
                    arrivalTime: arrivalTime,
                    trainType: nil,
                    trainNumber: nil,
                    transferCount: result.transferCount,
                    sections: routeSections,
                    isActualArrivalTime: false  // 乗り換え検索では推定時刻
                )
                
                routeResults.append(routeResult)
                
                // 最大5件まで
                if routeResults.count >= 5 {
                    break
                }
            }
            
            // 結果を設定
            await MainActor.run {
                if routeResults.isEmpty {
                    self.errorMessage = "乗り換え経路が見つかりませんでした"
                    self.showError = true
                    self.searchResults = []
                } else {
                    self.searchResults = routeResults
                    print("✅ Set \(routeResults.count) transfer routes")
                }
            }
        } catch {
            print("Transfer route search error: \(error)")
            await MainActor.run {
                self.errorMessage = "乗り換え経路の検索に失敗しました"
                self.showError = true
                self.searchResults = []
            }
        }
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
