//
//  AlertTypes.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/26.
//

import Foundation

// MARK: - RouteInfo
/// 経路情報を表す構造体
struct RouteInfo: Codable {
    let departureStation: String
    let arrivalStation: String
    let departureTime: Date
    let arrivalTime: Date
    let trainLine: String
    let trainType: String?
    let trainNumber: String?
    let platform: String?
    let transferStations: [String]
    let totalDuration: TimeInterval
    
    init(
        departureStation: String,
        arrivalStation: String,
        departureTime: Date,
        arrivalTime: Date,
        trainLine: String,
        trainType: String? = nil,
        trainNumber: String? = nil,
        platform: String? = nil,
        transferStations: [String] = [],
        totalDuration: TimeInterval? = nil
    ) {
        self.departureStation = departureStation
        self.arrivalStation = arrivalStation
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.trainLine = trainLine
        self.trainType = trainType
        self.trainNumber = trainNumber
        self.platform = platform
        self.transferStations = transferStations
        self.totalDuration = totalDuration ?? arrivalTime.timeIntervalSince(departureTime)
    }
}

// MARK: - WeekDay
/// 曜日を表す列挙型
enum WeekDay: Int, CaseIterable, Codable {
    case sunday = 0
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    
    var localizedName: String {
        switch self {
        case .sunday: return "日曜日"
        case .monday: return "月曜日"
        case .tuesday: return "火曜日"
        case .wednesday: return "水曜日"
        case .thursday: return "木曜日"
        case .friday: return "金曜日"
        case .saturday: return "土曜日"
        }
    }
    
    var shortName: String {
        switch self {
        case .sunday: return "日"
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        }
    }
    
    static func from(date: Date) -> WeekDay {
        let weekday = Calendar.current.component(.weekday, from: date)
        return WeekDay(rawValue: weekday - 1) ?? .sunday
    }
}

// MARK: - TimetableTrainInfo
/// 時刻表の電車情報を表す構造体
struct TimetableTrainInfo {
    let trainNumber: String
    let trainType: String
    let departureStation: String
    let departureTime: Date
    let arrivalStation: String
    let arrivalTime: Date
    let platform: String?
    let intermediateStations: [IntermediateStation]
    
    struct IntermediateStation {
        let name: String
        let arrivalTime: Date?
        let departureTime: Date?
        let platform: String?
    }
    
    init(
        trainNumber: String,
        trainType: String,
        departureStation: String,
        departureTime: Date,
        arrivalStation: String,
        arrivalTime: Date,
        platform: String? = nil,
        intermediateStations: [IntermediateStation] = []
    ) {
        self.trainNumber = trainNumber
        self.trainType = trainType
        self.departureStation = departureStation
        self.departureTime = departureTime
        self.arrivalStation = arrivalStation
        self.arrivalTime = arrivalTime
        self.platform = platform
        self.intermediateStations = intermediateStations
    }
}
