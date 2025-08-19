//
//  StationCountCalculator.swift
//  TrainAlert
//
//  駅数ベースの通知計算ロジック
//

import Foundation

/// 駅数カウント計算機
@MainActor
class StationCountCalculator {
    private let apiClient = ODPTAPIClient.shared
    
    /// 停車駅情報
    struct StopStation {
        let stationId: String
        let stationName: String
        let arrivalTime: String?
        let departureTime: String?
        let isPassingStation: Bool  // 通過駅かどうか
    }
    
    /// 通知駅情報
    struct NotificationStation {
        let station: StopStation
        let stationsBeforeArrival: Int  // 到着駅まで何駅か
        let estimatedTime: Date?
    }
    
    /// 列車の停車駅リストを取得
    func getStopStations(
        trainNumber: String,
        railwayId: String,
        departureStation: String,
        arrivalStation: String
    ) async throws -> [StopStation] {
        // 列車時刻表を取得
        let trainTimetables = try await apiClient.getTrainTimetable(
            trainNumber: trainNumber,
            railwayId: railwayId
        )
        
        guard let timetable = trainTimetables.first else {
            throw StationCountError.trainNotFound
        }
        
        var stopStations: [StopStation] = []
        var foundDeparture = false
        var foundArrival = false
        
        // 時刻表オブジェクトから停車駅を抽出
        for obj in timetable.trainTimetableObject {
            let stationId = obj.departureStation ?? obj.arrivalStation ?? ""
            let stationName = obj.departureStationTitle?.ja ?? 
                            obj.arrivalStationTitle?.ja ?? 
                            stationId.components(separatedBy: ".").last ?? ""
            
            // 出発駅から到着駅までの区間を抽出
            if stationName.contains(departureStation) || stationId.contains(departureStation) {
                foundDeparture = true
            }
            
            if foundDeparture && !foundArrival {
                // 通過駅の判定：到着時刻と出発時刻が同じ、または時刻がない場合
                let isPassingStation = (obj.arrivalTime == nil && obj.departureTime == nil) ||
                                     (obj.arrivalTime == obj.departureTime && obj.arrivalTime != nil)
                
                stopStations.append(StopStation(
                    stationId: stationId,
                    stationName: stationName,
                    arrivalTime: obj.arrivalTime,
                    departureTime: obj.departureTime,
                    isPassingStation: isPassingStation
                ))
            }
            
            if stationName.contains(arrivalStation) || stationId.contains(arrivalStation) {
                foundArrival = true
                break
            }
        }
        
        if !foundDeparture || !foundArrival {
            throw StationCountError.stationNotFoundInRoute
        }
        
        return stopStations
    }
    
    /// 通知駅を特定する
    func getNotificationStation(
        stopStations: [StopStation],
        stationsBeforeArrival: Int
    ) -> NotificationStation? {
        // 停車駅のみをフィルタリング（通過駅を除外）
        let actualStopStations = stopStations.filter { !$0.isPassingStation }
        
        // 到着駅のインデックスを特定
        guard let arrivalIndex = actualStopStations.lastIndex(where: { _ in true }) else {
            return nil
        }
        
        // 通知駅のインデックスを計算
        let notificationIndex = arrivalIndex - stationsBeforeArrival
        
        // 範囲チェック
        guard notificationIndex >= 0 && notificationIndex < actualStopStations.count else {
            return nil
        }
        
        let notificationStation = actualStopStations[notificationIndex]
        
        // 通知時刻を計算（出発時刻を使用）
        let estimatedTime = parseTime(notificationStation.departureTime ?? notificationStation.arrivalTime)
        
        return NotificationStation(
            station: notificationStation,
            stationsBeforeArrival: stationsBeforeArrival,
            estimatedTime: estimatedTime
        )
    }
    
    /// 現在の列車の停車駅を使用して通知設定を計算（モックデータ版）
    func calculateNotificationWithMockData(
        route: RouteSearchResult,
        stationsBeforeArrival: Int
    ) -> NotificationStation? {
        // 実際のAPIが利用できない間は、シンプルな計算を行う
        // 仮に5分ごとに1駅進むと仮定
        let minutesPerStation = 5
        let notificationMinutes = stationsBeforeArrival * minutesPerStation
        
        let notificationTime = route.arrivalTime.addingTimeInterval(TimeInterval(-notificationMinutes * 60))
        
        // モック駅情報を作成
        let mockStation = StopStation(
            stationId: "mock.station",
            stationName: "\(stationsBeforeArrival)駅前",
            arrivalTime: nil,
            departureTime: nil,
            isPassingStation: false
        )
        
        return NotificationStation(
            station: mockStation,
            stationsBeforeArrival: stationsBeforeArrival,
            estimatedTime: notificationTime
        )
    }
    
    // MARK: - Private Methods
    
    private func parseTime(_ timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        // 今日の日付に時刻を設定
        if let time = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            
            return calendar.date(from: components)
        }
        
        return nil
    }
}

// MARK: - Errors

enum StationCountError: LocalizedError {
    case trainNotFound
    case stationNotFoundInRoute
    case insufficientStations
    
    var errorDescription: String? {
        switch self {
        case .trainNotFound:
            return "指定された列車が見つかりません"
        case .stationNotFoundInRoute:
            return "指定された駅が経路上に見つかりません"
        case .insufficientStations:
            return "指定された駅数が経路上の駅数を超えています"
        }
    }
}
