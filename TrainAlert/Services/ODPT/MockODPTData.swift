//
//  MockODPTData.swift
//  TrainAlert
//
//  Mock data for ODPT API
//

import CoreLocation
import Foundation

/// Mock ODPT Data Provider
struct MockODPTData {
    // MARK: - Mock Stations
    
    static let mockStations: [ODPTStation] = [
        // JR山手線
        ODPTStation(
            id: "odpt.Station:JR-East.Yamanote.Tokyo",
            title: "東京",
            titleEn: "Tokyo",
            titleJa: "とうきょう",
            railway: ["odpt.Railway:JR-East.Yamanote", "odpt.Railway:JR-East.ChuoRapid"],
            operatorID: "odpt.Operator:JR-East",
            stationCode: "JY01",
            latitude: 35.681382,
            longitude: 139.766084,
            region: "東京都"
        ),
        ODPTStation(
            id: "odpt.Station:JR-East.Yamanote.Shinjuku",
            title: "新宿",
            titleEn: "Shinjuku",
            titleJa: "しんじゅく",
            railway: ["odpt.Railway:JR-East.Yamanote", "odpt.Railway:JR-East.ChuoRapid"],
            operatorID: "odpt.Operator:JR-East",
            stationCode: "JY17",
            latitude: 35.689506,
            longitude: 139.700465,
            region: "東京都"
        ),
        ODPTStation(
            id: "odpt.Station:JR-East.Yamanote.Shibuya",
            title: "渋谷",
            titleEn: "Shibuya",
            titleJa: "しぶや",
            railway: ["odpt.Railway:JR-East.Yamanote"],
            operatorID: "odpt.Operator:JR-East",
            stationCode: "JY20",
            latitude: 35.658517,
            longitude: 139.701334,
            region: "東京都"
        ),
        ODPTStation(
            id: "odpt.Station:JR-East.Yamanote.Shinagawa",
            title: "品川",
            titleEn: "Shinagawa",
            titleJa: "しながわ",
            railway: ["odpt.Railway:JR-East.Yamanote", "odpt.Railway:JR-East.Tokaido"],
            operatorID: "odpt.Operator:JR-East",
            stationCode: "JY25",
            latitude: 35.630152,
            longitude: 139.740786,
            region: "東京都"
        ),
        // 東京メトロ
        ODPTStation(
            id: "odpt.Station:TokyoMetro.Ginza.Ginza",
            title: "銀座",
            titleEn: "Ginza",
            titleJa: "ぎんざ",
            railway: ["odpt.Railway:TokyoMetro.Ginza", "odpt.Railway:TokyoMetro.Marunouchi", "odpt.Railway:TokyoMetro.Hibiya"],
            operatorID: "odpt.Operator:TokyoMetro",
            stationCode: "G09",
            latitude: 35.671739,
            longitude: 139.763928,
            region: "東京都"
        ),
        ODPTStation(
            id: "odpt.Station:TokyoMetro.Tozai.Nakano",
            title: "中野",
            titleEn: "Nakano",
            titleJa: "なかの",
            railway: ["odpt.Railway:TokyoMetro.Tozai", "odpt.Railway:JR-East.ChuoRapid"],
            operatorID: "odpt.Operator:TokyoMetro",
            stationCode: "T01",
            latitude: 35.706464,
            longitude: 139.665742,
            region: "東京都"
        )
    ]
    
    // MARK: - Mock Railways
    
    static let mockRailways: [ODPTRailway] = [
        ODPTRailway(
            id: "odpt.Railway:JR-East.Yamanote",
            title: "山手線",
            titleEn: "Yamanote Line",
            titleJa: "やまのてせん",
            operatorID: "odpt.Operator:JR-East",
            lineColor: "#9ACD32",
            lineSymbol: "JY",
            stationOrder: [
                StationOrder(station: "odpt.Station:JR-East.Yamanote.Tokyo", index: 1),
                StationOrder(station: "odpt.Station:JR-East.Yamanote.Yurakucho", index: 2),
                StationOrder(station: "odpt.Station:JR-East.Yamanote.Shimbashi", index: 3),
                StationOrder(station: "odpt.Station:JR-East.Yamanote.Hamamatsucho", index: 4),
                StationOrder(station: "odpt.Station:JR-East.Yamanote.Tamachi", index: 5),
                StationOrder(station: "odpt.Station:JR-East.Yamanote.Shinagawa", index: 6)
            ]
        ),
        ODPTRailway(
            id: "odpt.Railway:JR-East.ChuoRapid",
            title: "中央線快速",
            titleEn: "Chuo Rapid Line",
            titleJa: "ちゅうおうせんかいそく",
            operatorID: "odpt.Operator:JR-East",
            lineColor: "#FF6600",
            lineSymbol: "JC",
            stationOrder: nil
        ),
        ODPTRailway(
            id: "odpt.Railway:TokyoMetro.Ginza",
            title: "銀座線",
            titleEn: "Ginza Line",
            titleJa: "ぎんざせん",
            operatorID: "odpt.Operator:TokyoMetro",
            lineColor: "#FF9500",
            lineSymbol: "G",
            stationOrder: nil
        )
    ]
    
    // MARK: - Search Methods
    
    /// 駅名検索
    static func searchStations(query: String) -> [ODPTStation] {
        let lowercaseQuery = query.lowercased()
        return mockStations.filter { station in
            station.title.contains(query) ||
            (station.titleEn?.lowercased().contains(lowercaseQuery) ?? false) ||
            (station.titleJa?.contains(query) ?? false)
        }
    }
    
    /// 位置情報による駅検索
    static func searchStations(near location: CLLocation, radius: Double) -> [ODPTStation] {
        mockStations.filter { station in
            guard let lat = station.latitude, let lon = station.longitude else { return false }
            let stationLocation = CLLocation(latitude: lat, longitude: lon)
            return stationLocation.distance(from: location) <= radius
        }.sorted { station1, station2 in
            let loc1 = CLLocation(latitude: station1.latitude!, longitude: station1.longitude!)
            let loc2 = CLLocation(latitude: station2.latitude!, longitude: station2.longitude!)
            return loc1.distance(from: location) < loc2.distance(from: location)
        }
    }
    
    /// 路線情報取得
    static func getRailway(id: String) -> ODPTRailway {
        mockRailways.first { $0.id == id } ?? mockRailways[0]
    }
    
    /// 経路検索
    static func searchRoutes(from: String, to: String, departureTime: Date? = nil) -> [RouteSearchResult] {
        let fromStation = mockStations.first { $0.id == from } ?? mockStations[0]
        let toStation = mockStations.first { $0.id == to } ?? mockStations[1]
        
        let now = departureTime ?? Date()
        let departureTime1 = now.addingTimeInterval(300) // 5分後
        let arrivalTime1 = departureTime1.addingTimeInterval(1_800) // 30分後
        
        let departureTime2 = now.addingTimeInterval(600) // 10分後
        let arrivalTime2 = departureTime2.addingTimeInterval(2_100) // 35分後
        
        // 直通ルート
        let route1 = RouteSearchResult(
            id: UUID().uuidString,
            departureStation: fromStation,
            arrivalStation: toStation,
            departureTime: departureTime1,
            arrivalTime: arrivalTime1,
            duration: 30,
            transferCount: 0,
            sections: [
                RouteSection(
                    index: 0,
                    railway: mockRailways[0],
                    trainType: "普通",
                    departureStation: fromStation,
                    arrivalStation: toStation,
                    departureTime: departureTime1,
                    arrivalTime: arrivalTime1,
                    stopCount: 5,
                    delay: nil
                )
            ],
            fare: 200,
            totalDelay: nil
        )
        
        // 乗り換えありルート
        let transferStation = mockStations[2] // 渋谷
        let route2 = RouteSearchResult(
            id: UUID().uuidString,
            departureStation: fromStation,
            arrivalStation: toStation,
            departureTime: departureTime2,
            arrivalTime: arrivalTime2,
            duration: 35,
            transferCount: 1,
            sections: [
                RouteSection(
                    index: 0,
                    railway: mockRailways[0],
                    trainType: "快速",
                    departureStation: fromStation,
                    arrivalStation: transferStation,
                    departureTime: departureTime2,
                    arrivalTime: departureTime2.addingTimeInterval(900),
                    stopCount: 3,
                    delay: nil
                ),
                RouteSection(
                    index: 1,
                    railway: mockRailways[1],
                    trainType: "普通",
                    departureStation: transferStation,
                    arrivalStation: toStation,
                    departureTime: departureTime2.addingTimeInterval(1_200),
                    arrivalTime: arrivalTime2,
                    stopCount: 4,
                    delay: nil
                )
            ],
            fare: 220,
            totalDelay: nil
        )
        
        return [route1, route2]
    }
    
    /// 列車時刻表取得
    static func getTrainTimetable(railway: String, calendar: String) -> [ODPTTrainTimetable] {
        let timetable1 = ODPTTrainTimetable(
            id: "odpt.TrainTimetable:JR-East.Yamanote.1001.Weekday",
            railway: railway,
            operatorID: "odpt.Operator:JR-East",
            trainNumber: "1001",
            trainType: "odpt.TrainType:JR-East.Local",
            trainName: nil,
            destinationStation: ["odpt.Station:JR-East.Yamanote.Shinagawa"],
            timetableObject: [
                TimetableObject(
                    departureTime: "06:00",
                    arrivalTime: nil,
                    station: "odpt.Station:JR-East.Yamanote.Tokyo"
                ),
                TimetableObject(
                    departureTime: "06:03",
                    arrivalTime: "06:02",
                    station: "odpt.Station:JR-East.Yamanote.Yurakucho"
                ),
                TimetableObject(
                    departureTime: "06:06",
                    arrivalTime: "06:05",
                    station: "odpt.Station:JR-East.Yamanote.Shimbashi"
                ),
                TimetableObject(
                    departureTime: nil,
                    arrivalTime: "06:12",
                    station: "odpt.Station:JR-East.Yamanote.Shinagawa"
                )
            ],
            calendar: calendar
        )
        
        return [timetable1]
    }
    
    /// リアルタイム列車情報取得
    static func getRealTimeTrainInfo(railway: String) -> [ODPTTrain] {
        let train1 = ODPTTrain(
            id: "odpt.Train:JR-East.Yamanote.1001",
            trainNumber: "1001",
            trainType: "odpt.TrainType:JR-East.Local",
            delay: 120, // 2分遅延
            fromStation: "odpt.Station:JR-East.Yamanote.Tokyo",
            toStation: "odpt.Station:JR-East.Yamanote.Yurakucho",
            railway: railway,
            date: ISO8601DateFormatter().string(from: Date())
        )
        
        return [train1]
    }
}
