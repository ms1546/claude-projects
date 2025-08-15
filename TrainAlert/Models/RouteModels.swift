//
//  RouteModels.swift
//  TrainAlert
//
//  経路検索関連のモデル定義
//

import Foundation

/// 経路検索結果
struct RouteSearchResult: Codable {
    let departureStation: String
    let arrivalStation: String
    let departureTime: Date
    let arrivalTime: Date
    let trainType: String?
    let trainNumber: String?
    let transferCount: Int
    let sections: [RouteSection]
    
    enum CodingKeys: String, CodingKey {
        case departureStation
        case arrivalStation
        case departureTime
        case arrivalTime
        case trainType
        case trainNumber
        case transferCount
        case sections
    }
}

/// 経路区間
struct RouteSection: Codable {
    let departureStation: String
    let arrivalStation: String
    let departureTime: Date
    let arrivalTime: Date
    let trainType: String?
    let trainNumber: String?
    let railway: String
    
    enum CodingKeys: String, CodingKey {
        case departureStation
        case arrivalStation
        case departureTime
        case arrivalTime
        case trainType
        case trainNumber
        case railway
    }
}

// MARK: - Equatable

extension RouteSearchResult: Equatable {
    static func == (lhs: RouteSearchResult, rhs: RouteSearchResult) -> Bool {
        lhs.departureStation == rhs.departureStation &&
               lhs.arrivalStation == rhs.arrivalStation &&
               lhs.departureTime == rhs.departureTime &&
               lhs.arrivalTime == rhs.arrivalTime &&
               lhs.trainNumber == rhs.trainNumber
    }
}

// MARK: - Identifiable

extension RouteSearchResult: Identifiable {
    var id: String {
        "\(departureStation)_\(arrivalStation)_\(departureTime.timeIntervalSince1970)_\(trainNumber ?? "")"
    }
}
