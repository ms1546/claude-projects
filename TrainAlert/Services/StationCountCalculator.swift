//
//  StationCountCalculator.swift
//  TrainAlert
//
//  駅数ベースの通知計算ロジック
//

import CoreLocation
import Foundation

/// 駅数カウント計算機
@MainActor
class StationCountCalculator {
    // MARK: - Singleton
    static let shared = StationCountCalculator()
    
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
        // DEBUG: Total stops in timetable
        // print("[DEBUG] Total stops in timetable: \(timetable.trainTimetableObject.count)")
        for (index, obj) in timetable.trainTimetableObject.enumerated() {
            let stationId = obj.departureStation ?? obj.arrivalStation ?? ""
            
            // まず時刻表に含まれる駅名を使用
            var stationName = obj.departureStationTitle?.ja ?? obj.arrivalStationTitle?.ja ?? ""
            
            // デバッグログで取得した駅名情報を表示
            // DEBUG: Station name extraction
            // print("[DEBUG] Station \(index): stationId=\(stationId)")
            // print("  departureStationTitle.ja: \(obj.departureStationTitle?.ja ?? "nil")")
            // print("  arrivalStationTitle.ja: \(obj.arrivalStationTitle?.ja ?? "nil")")
            // print("  extracted stationName: \(stationName)")
            
            // 駅名が取得できなかった場合は、駅IDから個別に取得を試みる
            if stationName.isEmpty && !stationId.isEmpty {
                if let station = try? await apiClient.getStation(stationId: stationId) {
                    stationName = station.stationTitle?.ja ?? station.title
                    // DEBUG: Fetched from API
                    // print("  fetched from API: \(stationName)")
                } else {
                    // それでも取得できない場合は、IDの最後の部分を使用（英語名）
                    // TODO: これは暫定対応で、実際にはAPIから日本語名を取得すべき
                    stationName = stationId.components(separatedBy: ".").last ?? ""
                    // DEBUG: Fallback to English name
                    // print("[STATION NAME DEBUG] Fallback to English name from ID: '\(stationId)' -> '\(stationName)'")
                    
                    // 英語名を日本語名に変換する試み
                    let romanizer = StationNameRomanizer.shared
                    if let japaneseName = romanizer.toJapanese(stationName) {
                        // print("[STATION NAME DEBUG] Found Japanese name: '\(japaneseName)'")
                        stationName = japaneseName
                    }
                }
            }
            
            // 出発駅から到着駅までの区間を抽出
            // 駅名の正規化（「駅」を除去して比較）
            let normalizedStationName = stationName.replacingOccurrences(of: "駅", with: "")
            let normalizedDepartureStation = departureStation.replacingOccurrences(of: "駅", with: "")
            let normalizedArrivalStation = arrivalStation.replacingOccurrences(of: "駅", with: "")
            
            if normalizedStationName == normalizedDepartureStation || 
               stationName == departureStation ||
               stationId.lowercased().contains(normalizedDepartureStation.lowercased()) {
                foundDeparture = true
                // DEBUG: Found departure station
                // print("[DEBUG] Found departure station at index \(index): \(stationName)")
            }
            
            if foundDeparture && !foundArrival {
                // 通過駅の判定：両方の時刻がnilの場合のみ通過駅とする
                // 注：ODPTデータでは、多くの駅で到着時刻と出発時刻が同じ値になることがある
                // これは必ずしも通過駅を意味しない
                let isPassingStation = (obj.arrivalTime == nil && obj.departureTime == nil)
                
                // DEBUG: Adding stop
                // print("[DEBUG] Adding stop \(index): \(stationName) (\(stationId))")
                // print("  arrivalTime: \(obj.arrivalTime ?? "nil"), departureTime: \(obj.departureTime ?? "nil")")
                // print("  isPassingStation: \(isPassingStation)")
                stopStations.append(StopStation(
                    stationId: stationId,
                    stationName: stationName,
                    arrivalTime: obj.arrivalTime,
                    departureTime: obj.departureTime,
                    isPassingStation: isPassingStation
                ))
            }
            
            if normalizedStationName == normalizedArrivalStation ||
               stationName == arrivalStation ||
               stationId.lowercased().contains(normalizedArrivalStation.lowercased()) {
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
    
    /// 現在地から降車駅までの残り駅数を計算
    func calculateStationCount(
        from currentLocation: CLLocation,
        to arrivalStation: String,
        on railway: String
    ) async -> Result<Int, StationCountError> {
        // 簡易実装：現在地から最寄り駅を推定し、駅数を計算
        // TODO: 実際の実装では、GPSから現在の最寄り駅を特定し、
        // 路線上の駅リストから残り駅数を計算する
        
        // デモ用に固定値を返す
        .success(3)
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
