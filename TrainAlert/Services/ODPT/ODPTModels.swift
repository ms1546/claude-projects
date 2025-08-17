//
//  ODPTModels.swift
//  TrainAlert
//
//  ODPT APIのレスポンスモデル定義
//

import Foundation

// MARK: - 駅時刻表

/// 駅時刻表
struct ODPTStationTimetable: Codable {
    let id: String
    let sameAs: String
    let date: String?
    let issuedBy: String?
    let railway: String
    let railwayTitle: ODPTMultilingualTitle?
    let station: String
    let stationTitle: ODPTMultilingualTitle?
    let railDirection: String?
    let railDirectionTitle: ODPTMultilingualTitle?
    let calendar: String?
    let calendarTitle: ODPTMultilingualTitle?
    let stationTimetableObject: [ODPTTrainTimetableObject]
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case sameAs = "owl:sameAs"
        case date = "dc:date"
        case issuedBy = "dct:issued"
        case railway = "odpt:railway"
        case railwayTitle = "odpt:railwayTitle"
        case station = "odpt:station"
        case stationTitle = "odpt:stationTitle"
        case railDirection = "odpt:railDirection"
        case railDirectionTitle = "odpt:railDirectionTitle"
        case calendar = "odpt:calendar"
        case calendarTitle = "odpt:calendarTitle"
        case stationTimetableObject = "odpt:stationTimetableObject"
    }
}

/// 列車時刻表オブジェクト
struct ODPTTrainTimetableObject: Codable {
    let departureTime: String
    let trainType: String?
    let trainTypeTitle: ODPTMultilingualTitle?
    let trainNumber: String?
    let trainName: ODPTMultilingualTitle?
    let destinationStation: [String]?
    let destinationStationTitle: ODPTMultilingualTitle?
    let isLast: Bool?
    let isOrigin: Bool?
    let platformNumber: String?
    let note: ODPTMultilingualTitle?
    
    private enum CodingKeys: String, CodingKey {
        case departureTime = "odpt:departureTime"
        case trainType = "odpt:trainType"
        case trainTypeTitle = "odpt:trainTypeTitle"
        case trainNumber = "odpt:trainNumber"
        case trainName = "odpt:trainName"
        case destinationStation = "odpt:destinationStation"
        case destinationStationTitle = "odpt:destinationStationTitle"
        case isLast = "odpt:isLast"
        case isOrigin = "odpt:isOrigin"
        case platformNumber = "odpt:platformNumber"
        case note = "odpt:note"
    }
}

// MARK: - 列車時刻表

/// 列車時刻表
struct ODPTTrainTimetable: Codable {
    let id: String
    let sameAs: String
    let trainNumber: String
    let railway: String
    let railwayTitle: ODPTMultilingualTitle?
    let trainType: String?
    let trainTypeTitle: ODPTMultilingualTitle?
    let railDirection: String?
    let railDirectionTitle: ODPTMultilingualTitle?
    let trainName: ODPTMultilingualTitle?
    let trainTimetableObject: [ODPTTrainTimetableObject2]
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case sameAs = "owl:sameAs"
        case trainNumber = "odpt:trainNumber"
        case railway = "odpt:railway"
        case railwayTitle = "odpt:railwayTitle"
        case trainType = "odpt:trainType"
        case trainTypeTitle = "odpt:trainTypeTitle"
        case railDirection = "odpt:railDirection"
        case railDirectionTitle = "odpt:railDirectionTitle"
        case trainName = "odpt:trainName"
        case trainTimetableObject = "odpt:trainTimetableObject"
    }
}

/// 列車時刻表オブジェクト（駅ごと）
struct ODPTTrainTimetableObject2: Codable {
    let arrivalTime: String?
    let arrivalStation: String?
    let arrivalStationTitle: ODPTMultilingualTitle?
    let departureTime: String?
    let departureStation: String?
    let departureStationTitle: ODPTMultilingualTitle?
    let platformNumber: String?
    
    private enum CodingKeys: String, CodingKey {
        case arrivalTime = "odpt:arrivalTime"
        case arrivalStation = "odpt:arrivalStation"
        case arrivalStationTitle = "odpt:arrivalStationTitle"
        case departureTime = "odpt:departureTime"
        case departureStation = "odpt:departureStation"
        case departureStationTitle = "odpt:departureStationTitle"
        case platformNumber = "odpt:platformNumber"
    }
}

// MARK: - 駅情報

/// 駅情報
struct ODPTStation: Codable {
    let id: String
    let sameAs: String
    let date: String?
    let title: String
    let stationTitle: ODPTMultilingualTitle?
    let railway: String
    let railwayTitle: ODPTMultilingualTitle?
    let `operator`: String
    let operatorTitle: ODPTMultilingualTitle?
    let stationCode: String?
    let connectingRailway: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case sameAs = "owl:sameAs"
        case date = "dc:date"
        case title = "dc:title"
        case stationTitle = "odpt:stationTitle"
        case railway = "odpt:railway"
        case railwayTitle = "odpt:railwayTitle"
        case `operator` = "odpt:operator"
        case operatorTitle = "odpt:operatorTitle"
        case stationCode = "odpt:stationCode"
        case connectingRailway = "odpt:connectingRailway"
    }
}

// MARK: - 列車情報（リアルタイム）

/// 列車情報（リアルタイム）
struct ODPTTrain: Codable {
    let id: String
    let sameAs: String
    let date: String
    let valid: String?
    let railway: String
    let railwayTitle: ODPTMultilingualTitle?
    let trainType: String?
    let trainTypeTitle: ODPTMultilingualTitle?
    let trainNumber: String
    let trainName: ODPTMultilingualTitle?
    let railDirection: String?
    let railDirectionTitle: ODPTMultilingualTitle?
    let delay: Int?
    let fromStation: String?
    let fromStationTitle: ODPTMultilingualTitle?
    let toStation: String?
    let toStationTitle: ODPTMultilingualTitle?
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case sameAs = "owl:sameAs"
        case date = "dc:date"
        case valid = "dct:valid"
        case railway = "odpt:railway"
        case railwayTitle = "odpt:railwayTitle"
        case trainType = "odpt:trainType"
        case trainTypeTitle = "odpt:trainTypeTitle"
        case trainNumber = "odpt:trainNumber"
        case trainName = "odpt:trainName"
        case railDirection = "odpt:railDirection"
        case railDirectionTitle = "odpt:railDirectionTitle"
        case delay = "odpt:delay"
        case fromStation = "odpt:fromStation"
        case fromStationTitle = "odpt:fromStationTitle"
        case toStation = "odpt:toStation"
        case toStationTitle = "odpt:toStationTitle"
    }
}

// MARK: - 共通モデル

/// 多言語タイトル
struct ODPTMultilingualTitle: Codable {
    let ja: String?
    let en: String?
}

/// 位置情報
struct ODPTGeoLocation: Codable {
    let lat: Double
    let long: Double
}
