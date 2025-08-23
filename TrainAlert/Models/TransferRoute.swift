//
//  TransferRoute.swift
//  TrainAlert
//
//  乗り換え経路関連のモデル定義
//

import CoreLocation
import Foundation

/// 乗り換え経路全体を表すモデル
struct TransferRoute: Codable, Identifiable {
    let id: UUID
    let sections: [RouteSection]            // 各区間（既存のRouteSectionを活用）
    let transferStations: [TransferStation] // 乗り換え駅情報
    let totalDuration: TimeInterval         // 総所要時間
    let departureTime: Date                 // 出発時刻
    let arrivalTime: Date                   // 到着時刻
    let createdAt: Date
    
    /// 出発駅名
    var departureStation: String? {
        sections.first?.departureStation
    }
    
    /// 到着駅名
    var arrivalStation: String? {
        sections.last?.arrivalStation
    }
    
    /// 乗り換え回数
    var transferCount: Int {
        max(0, sections.count - 1)
    }
    
    init(
        sections: [RouteSection],
        transferStations: [TransferStation]
    ) {
        self.id = UUID()
        self.sections = sections
        self.transferStations = transferStations
        self.departureTime = sections.first?.departureTime ?? Date()
        self.arrivalTime = sections.last?.arrivalTime ?? Date()
        self.totalDuration = arrivalTime.timeIntervalSince(departureTime)
        self.createdAt = Date()
    }
}

/// 乗り換え駅情報
struct TransferStation: Codable, Identifiable {
    let id: UUID
    let stationName: String
    let fromLine: String          // 乗車していた路線
    let toLine: String            // 乗り換え先の路線
    let transferTime: TimeInterval // 乗り換え時間
    let platform: String?         // プラットフォーム情報（可能な場合）
    let arrivalTime: Date         // 到着時刻
    let departureTime: Date       // 出発時刻
    
    init(
        stationName: String,
        fromLine: String,
        toLine: String,
        arrivalTime: Date,
        departureTime: Date,
        platform: String? = nil
    ) {
        self.id = UUID()
        self.stationName = stationName
        self.fromLine = fromLine
        self.toLine = toLine
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.transferTime = departureTime.timeIntervalSince(arrivalTime)
        self.platform = platform
    }
}

// MARK: - Extensions

extension TransferRoute {
    /// 指定された駅が乗り換え駅かどうかを判定
    func isTransferStation(_ stationName: String) -> Bool {
        transferStations.contains { $0.stationName == stationName }
    }
    
    /// 指定された駅の乗り換え情報を取得
    func transferInfo(for stationName: String) -> TransferStation? {
        transferStations.first { $0.stationName == stationName }
    }
    
    /// 次の乗り換え駅を取得（現在時刻ベース）
    func nextTransferStation(from currentTime: Date = Date()) -> TransferStation? {
        transferStations.first { $0.arrivalTime > currentTime }
    }
    
    /// 指定された区間のインデックスを取得
    func sectionIndex(departureStation: String, arrivalStation: String) -> Int? {
        sections.firstIndex { section in
            section.departureStation == departureStation &&
            section.arrivalStation == arrivalStation
        }
    }
}

// MARK: - Notification Support

extension TransferRoute {
    /// 通知が必要なポイントのリスト
    var notificationPoints: [NotificationPoint] {
        var points: [NotificationPoint] = []
        
        // 各区間の到着通知
        for (index, section) in sections.enumerated() {
            // 最終到着駅の通知
            if index == sections.count - 1 {
                points.append(NotificationPoint(
                    id: UUID(),
                    stationName: section.arrivalStation,
                    notificationType: .arrival,
                    scheduledTime: section.arrivalTime,
                    message: "もうすぐ\(section.arrivalStation)駅に到着します"
                ))
            }
            
            // 乗り換え駅の通知
            if let transferStation = transferStations.first(where: { $0.stationName == section.arrivalStation }) {
                points.append(NotificationPoint(
                    id: UUID(),
                    stationName: transferStation.stationName,
                    notificationType: .transfer,
                    scheduledTime: transferStation.arrivalTime,
                    message: "\(transferStation.stationName)駅で\(transferStation.toLine)に乗り換えてください"
                ))
            }
        }
        
        return points
    }
}

/// 通知ポイント
struct NotificationPoint: Identifiable {
    let id: UUID
    let stationName: String
    let notificationType: NotificationType
    let scheduledTime: Date
    let message: String
    
    enum NotificationType {
        case arrival    // 到着通知
        case transfer   // 乗り換え通知
        case departure  // 出発通知（将来の拡張用）
    }
}

// MARK: - Mock Data

extension TransferRoute {
    /// テスト用のモックデータ
    static var mockData: TransferRoute {
        let sections = [
            RouteSection(
                departureStation: "新宿",
                arrivalStation: "渋谷",
                departureTime: Date(),
                arrivalTime: Date().addingTimeInterval(10 * 60),
                trainType: "各駅停車",
                trainNumber: nil,
                railway: "JR山手線"
            ),
            RouteSection(
                departureStation: "渋谷",
                arrivalStation: "表参道",
                departureTime: Date().addingTimeInterval(15 * 60),
                arrivalTime: Date().addingTimeInterval(20 * 60),
                trainType: "各駅停車",
                trainNumber: nil,
                railway: "東京メトロ銀座線"
            )
        ]
        
        let transferStations = [
            TransferStation(
                stationName: "渋谷",
                fromLine: "JR山手線",
                toLine: "東京メトロ銀座線",
                arrivalTime: Date().addingTimeInterval(10 * 60),
                departureTime: Date().addingTimeInterval(15 * 60),
                platform: "3番線"
            )
        ]
        
        return TransferRoute(sections: sections, transferStations: transferStations)
    }
}

