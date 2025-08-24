//
//  StationConnectionManager.swift
//  TrainAlert
//
//  乗り換え駅の接続情報を管理するクラス
//

import CoreLocation
import Foundation

/// 乗り換え情報を管理するマネージャー
class StationConnectionManager {
    static let shared = StationConnectionManager()
    
    private init() {}
    
    /// 駅間の接続情報
    struct StationConnection {
        let stationName: String
        let lines: [String]
        let transferTime: Int // 乗り換え時間（分）
        let location: CLLocationCoordinate2D
    }
    
    /// 主要な乗り換え駅のマッピング
    private let majorTransferStations: [StationConnection] = [
        // 山手線の主要乗り換え駅
        StationConnection(
            stationName: "東京",
            lines: ["JR山手線", "JR京浜東北線", "JR東海道線", "JR中央線", "JR総武線", "JR京葉線", "東京メトロ丸ノ内線"],
            transferTime: 5,
            location: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        ),
        StationConnection(
            stationName: "新宿",
            lines: ["JR山手線", "JR中央線", "JR総武線", "JR湘南新宿ライン", "小田急線", "京王線", "東京メトロ丸ノ内線", "東京メトロ副都心線", "都営新宿線", "都営大江戸線"],
            transferTime: 5,
            location: CLLocationCoordinate2D(latitude: 35.6896, longitude: 139.7006)
        ),
        StationConnection(
            stationName: "渋谷",
            lines: ["JR山手線", "JR湘南新宿ライン", "東急東横線", "東急田園都市線", "京王井の頭線", "東京メトロ銀座線", "東京メトロ半蔵門線", "東京メトロ副都心線"],
            transferTime: 5,
            location: CLLocationCoordinate2D(latitude: 35.6580, longitude: 139.7016)
        ),
        StationConnection(
            stationName: "池袋",
            lines: ["JR山手線", "JR湘南新宿ライン", "東武東上線", "西武池袋線", "東京メトロ丸ノ内線", "東京メトロ有楽町線", "東京メトロ副都心線"],
            transferTime: 4,
            location: CLLocationCoordinate2D(latitude: 35.7295, longitude: 139.7109)
        ),
        StationConnection(
            stationName: "品川",
            lines: ["JR山手線", "JR京浜東北線", "JR東海道線", "JR横須賀線", "京急本線"],
            transferTime: 3,
            location: CLLocationCoordinate2D(latitude: 35.6284, longitude: 139.7387)
        ),
        StationConnection(
            stationName: "秋葉原",
            lines: ["JR山手線", "JR京浜東北線", "JR総武線", "東京メトロ日比谷線", "つくばエクスプレス"],
            transferTime: 3,
            location: CLLocationCoordinate2D(latitude: 35.6984, longitude: 139.7731)
        ),
        StationConnection(
            stationName: "上野",
            lines: ["JR山手線", "JR京浜東北線", "JR常磐線", "JR高崎線", "JR宇都宮線", "東京メトロ銀座線", "東京メトロ日比谷線"],
            transferTime: 4,
            location: CLLocationCoordinate2D(latitude: 35.7141, longitude: 139.7774)
        ),
        
        // その他の主要乗り換え駅
        StationConnection(
            stationName: "大手町",
            lines: ["東京メトロ丸ノ内線", "東京メトロ東西線", "東京メトロ千代田線", "東京メトロ半蔵門線", "都営三田線"],
            transferTime: 5,
            location: CLLocationCoordinate2D(latitude: 35.6862, longitude: 139.7645)
        ),
        StationConnection(
            stationName: "表参道",
            lines: ["東京メトロ銀座線", "東京メトロ千代田線", "東京メトロ半蔵門線"],
            transferTime: 3,
            location: CLLocationCoordinate2D(latitude: 35.6654, longitude: 139.7123)
        ),
        StationConnection(
            stationName: "新橋",
            lines: ["JR山手線", "JR京浜東北線", "JR東海道線", "東京メトロ銀座線", "都営浅草線", "ゆりかもめ"],
            transferTime: 4,
            location: CLLocationCoordinate2D(latitude: 35.6662, longitude: 139.7584)
        )
    ]
    
    /// 駅名から接続情報を取得
    func getConnectionInfo(for stationName: String) -> StationConnection? {
        majorTransferStations.first { $0.stationName == stationName }
    }
    
    /// 2つの路線が接続している駅を検索
    func findTransferStations(from line1: String, to line2: String) -> [StationConnection] {
        majorTransferStations.filter { station in
            station.lines.contains(line1) && station.lines.contains(line2)
        }
    }
    
    /// 駅が乗り換え可能駅かどうかを判定
    func isTransferStation(_ stationName: String) -> Bool {
        majorTransferStations.contains { $0.stationName == stationName }
    }
    
    /// 駅の路線一覧を取得
    func getLines(for stationName: String) -> [String] {
        getConnectionInfo(for: stationName)?.lines ?? []
    }
    
    /// 乗り換え時間を取得（デフォルト: 3分）
    func getTransferTime(for stationName: String) -> Int {
        getConnectionInfo(for: stationName)?.transferTime ?? 3
    }
}

