//
//  RouteSearchViewModel.swift
//  TrainAlert
//
//  経路検索画面のViewModel
//

import CoreLocation
import Foundation
import SwiftUI

@MainActor
class RouteSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var departureStation: String = ""
    @Published var arrivalStation: String = ""
    @Published var departureTime = Date()
    @Published var searchResults: [RouteSearchResult] = []
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
    
    // MARK: - Private Properties
    
    private let apiClient = ODPTAPIClient.shared
    private let heartRailsClient = HeartRailsAPIClient.shared
    private var searchTask: Task<Void, Never>?
    private var stationSearchTask: Task<Void, Never>?
    private var departureSearchWorkItem: DispatchWorkItem?
    private var arrivalSearchWorkItem: DispatchWorkItem?
    
    // MARK: - Computed Properties
    
    var canSearch: Bool {
        !departureStation.isEmpty && !arrivalStation.isEmpty &&
        selectedDepartureStation != nil && selectedArrivalStation != nil
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
                    // HeartRails APIで高速に駅名検索
                    let heartRailsStations = try await self.heartRailsClient.searchStations(by: query)
                    
                    // ODPT形式に変換
                    let stations = heartRailsStations.map { $0.toODPTStation() }
                    
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
                    // HeartRails APIで高速に駅名検索
                    let heartRailsStations = try await self.heartRailsClient.searchStations(by: query)
                    
                    // ODPT形式に変換
                    let stations = heartRailsStations.map { $0.toODPTStation() }
                    
                    // タスクがキャンセルされていない場合のみ更新
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.arrivalStationSuggestions = Array(stations.prefix(10))
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
    
    /// 経路を検索
    func searchRoute() {
        guard canSearch,
              let departureStationId = selectedDepartureStation?.sameAs,
              let arrivalStationId = selectedArrivalStation?.sameAs else { return }
        
        searchTask?.cancel()
        searchTask = Task {
            isSearching = true
            defer { isSearching = false }
            
            do {
                // 現在の実装では時刻表から経路を組み立てる
                // TODO: より高度な経路検索アルゴリズムを実装
                
                // まず出発駅の時刻表を取得
                if let railway = selectedDepartureStation?.railway {
                    let timetables = try await apiClient.getStationTimetable(
                        stationId: departureStationId,
                        railwayId: railway
                    )
                    
                    // 時刻表から経路を生成（簡易実装）
                    searchResults = createRouteResults(from: timetables)
                }
            } catch {
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
    
    private func createRouteResults(from timetables: [ODPTStationTimetable]) -> [RouteSearchResult] {
        // 簡易実装：時刻表から指定時刻以降の列車を抽出
        var results: [RouteSearchResult] = []
        
        let calendar = Calendar.current
        let targetTime = calendar.dateComponents([.hour, .minute], from: departureTime)
        
        for timetable in timetables {
            for train in timetable.stationTimetableObject {
                // 出発時刻をパース
                let components = train.departureTime.split(separator: ":").compactMap { Int($0) }
                guard components.count == 2 else { continue }
                
                var trainDepartureComponents = calendar.dateComponents([.year, .month, .day], from: departureTime)
                trainDepartureComponents.hour = components[0]
                trainDepartureComponents.minute = components[1]
                
                guard let trainDepartureTime = calendar.date(from: trainDepartureComponents),
                      trainDepartureTime >= departureTime else { continue }
                
                // 仮の到着時刻を計算（実際にはTrainTimetableから取得すべき）
                let estimatedArrivalTime = trainDepartureTime.addingTimeInterval(30 * 60) // 30分後と仮定
                
                let result = RouteSearchResult(
                    departureStation: selectedDepartureStation?.stationTitle?.ja ?? "",
                    arrivalStation: selectedArrivalStation?.stationTitle?.ja ?? "",
                    departureTime: trainDepartureTime,
                    arrivalTime: estimatedArrivalTime,
                    trainType: train.trainTypeTitle?.ja,
                    trainNumber: train.trainNumber,
                    transferCount: 0,
                    sections: [
                        RouteSection(
                            departureStation: selectedDepartureStation?.stationTitle?.ja ?? "",
                            arrivalStation: selectedArrivalStation?.stationTitle?.ja ?? "",
                            departureTime: trainDepartureTime,
                            arrivalTime: estimatedArrivalTime,
                            trainType: train.trainTypeTitle?.ja,
                            trainNumber: train.trainNumber,
                            railway: timetable.railway
                        )
                    ]
                )
                
                results.append(result)
                
                // 最大10件まで
                if results.count >= 10 {
                    break
                }
            }
        }
        
        return results
    }
    
    private func handleError(_ error: Error) {
        if let odptError = error as? ODPTAPIError {
            errorMessage = odptError.localizedDescription
        } else {
            errorMessage = "エラーが発生しました: \(error.localizedDescription)"
        }
        showError = true
    }
    
    // MARK: - Nested Types
    
    enum StationType {
        case departure
        case arrival
    }
}
