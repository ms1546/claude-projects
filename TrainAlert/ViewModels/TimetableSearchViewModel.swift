//
//  TimetableSearchViewModel.swift
//  TrainAlert
//
//  時刻表検索画面のViewModel
//

import Combine
import Foundation

@MainActor
final class TimetableSearchViewModel: ObservableObject {
    @Published var timetables: [ODPTStationTimetable] = []
    @Published var displayedTrains: [ODPTTrainTimetableObject] = []
    @Published var directions: [String] = []
    @Published var selectedRailway: String?
    @Published var nearestTrain: ODPTTrainTimetableObject?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = ODPTAPIClient.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentStation: ODPTStation?
    private var selectedDirection: String?
    
    // MARK: - Public Methods
    
    /// 駅の時刻表を読み込む
    func loadTimetable(for station: ODPTStation) async {
        isLoading = true
        showError = false
        errorMessage = nil
        currentStation = station
        selectedRailway = station.railway
        
        do {
            // 現在の曜日に対応するカレンダータイプを取得
            let calendar = getCurrentCalendarType()
            
            // 時刻表を取得（カレンダーは指定せず、利用可能なものを取得）
            let fetchedTimetables = try await apiClient.getStationTimetable(
                stationId: station.sameAs,
                railwayId: station.railway,
                direction: nil,
                calendar: nil  // カレンダーを指定しないで全て取得
            )
            
            await MainActor.run {
                self.timetables = fetchedTimetables
                self.extractDirections()
                
                // 最初の方向を選択
                if let firstDirection = directions.first {
                    self.selectDirection(firstDirection)
                }
                
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.showError = true
                self.errorMessage = "時刻表の取得に失敗しました: \(error.localizedDescription)"
                print("時刻表取得エラー: \(error)")
            }
        }
    }
    
    /// 方向を選択
    func selectDirection(_ direction: String) {
        selectedDirection = direction
        updateDisplayedTrains()
    }
    
    /// 方向のタイトルを取得
    func getDirectionTitle(for direction: String) -> String {
        // 該当する時刻表から方向のタイトルを取得
        if let timetable = timetables.first(where: { $0.railDirection == direction }) {
            return timetable.railDirectionTitle?.ja ?? direction.components(separatedBy: ".").last ?? direction
        }
        return direction.components(separatedBy: ".").last ?? direction
    }
    
    /// 現在時刻に近いかどうか
    func isNearCurrentTime(_ train: ODPTTrainTimetableObject) -> Bool {
        guard let trainTime = parseTime(train.departureTime) else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let trainMinutes = trainTime.hour * 60 + trainTime.minute
        
        // 前後15分以内なら近い時刻とする
        return abs(trainMinutes - currentMinutes) <= 15
    }
    
    /// 過去の時刻かどうか
    func isPastTime(_ train: ODPTTrainTimetableObject) -> Bool {
        guard let trainTime = parseTime(train.departureTime) else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let trainMinutes = trainTime.hour * 60 + trainTime.minute
        
        return trainMinutes < currentMinutes
    }
    
    // MARK: - Private Methods
    
    /// 方向を抽出
    private func extractDirections() {
        let uniqueDirections = Set(timetables.compactMap { $0.railDirection })
        directions = Array(uniqueDirections).sorted()
    }
    
    /// 表示する列車を更新
    private func updateDisplayedTrains() {
        guard let direction = selectedDirection else {
            displayedTrains = []
            return
        }
        
        // 選択された方向の時刻表を取得
        guard let timetable = timetables.first(where: { $0.railDirection == direction }) else {
            displayedTrains = []
            return
        }
        
        // 時刻でソート
        let sortedTrains = timetable.stationTimetableObject.sorted { train1, train2 in
            guard let time1 = parseTime(train1.departureTime),
                  let time2 = parseTime(train2.departureTime) else {
                return false
            }
            
            if time1.hour != time2.hour {
                return time1.hour < time2.hour
            }
            return time1.minute < time2.minute
        }
        
        displayedTrains = sortedTrains
        
        // 現在時刻に最も近い列車を見つける
        findNearestTrain()
    }
    
    /// 現在時刻に最も近い列車を見つける
    private func findNearestTrain() {
        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        
        var nearestDiff = Int.max
        var nearest: ODPTTrainTimetableObject?
        
        for train in displayedTrains {
            guard let trainTime = parseTime(train.departureTime) else { continue }
            
            let trainMinutes = trainTime.hour * 60 + trainTime.minute
            let diff = trainMinutes - currentMinutes
            
            // 未来の列車で最も近いものを選択
            if diff >= 0 && diff < nearestDiff {
                nearestDiff = diff
                nearest = train
            }
        }
        
        // 未来の列車がない場合は最初の列車を選択
        if nearest == nil {
            nearest = displayedTrains.first
        }
        
        nearestTrain = nearest
    }
    
    /// 時刻文字列をパース
    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        return (hour: components[0], minute: components[1])
    }
    
    /// 現在の曜日に対応するカレンダータイプを取得
    private func getCurrentCalendarType() -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        
        // 日本の祝日判定は簡易的に実装（実際にはより詳細な判定が必要）
        switch weekday {
        case 1: // 日曜日
            return "odpt.Calendar:SundayHoliday"
        case 7: // 土曜日
            return "odpt.Calendar:Saturday"
        default: // 平日
            return "odpt.Calendar:Weekday"
        }
    }
}

// MARK: - Station Search ViewModel

@MainActor
final class StationSearchViewModel: ObservableObject {
    @Published var stations: [ODPTStation] = []
    @Published var isSearching = false
    
    private let apiClient = ODPTAPIClient.shared
    private var searchTask: Task<Void, Never>?
    
    func searchStations(query: String) {
        // 前の検索をキャンセル
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            stations = []
            return
        }
        
        searchTask = Task {
            isSearching = true
            
            do {
                let results = try await apiClient.searchStations(by: query)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        self.stations = results
                        self.isSearching = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.stations = []
                        self.isSearching = false
                        print("駅検索エラー: \(error)")
                    }
                }
            }
        }
    }
}
