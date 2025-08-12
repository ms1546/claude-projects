//
//  ODPTModels.swift
//  TrainAlert
//
//  ODPT (Open Data Public Transportation) API Models
//  Based on official ODPT API specification
//

import Foundation

// MARK: - Station Models

/// 駅情報
struct ODPTStation: Codable {
    /// 固有識別子 (e.g., "odpt.Station:JR-East.Yamanote.Tokyo")
    let id: String
    
    /// 駅名（日本語）
    let title: String
    
    /// 駅名（英語）
    let titleEn: String?
    
    /// 駅名（かな）
    let titleJa: String?
    
    /// 所属路線のID配列
    let railway: [String]
    
    /// 運営会社
    let operatorID: String
    
    /// 駅番号
    let stationCode: String?
    
    /// 緯度
    let latitude: Double?
    
    /// 経度
    let longitude: Double?
    
    /// 地域
    let region: String?
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case title = "dc:title"
        case titleEn = "odpt:stationTitle.en"
        case titleJa = "odpt:stationTitle.ja"
        case railway = "odpt:railway"
        case operatorID = "odpt:operator"
        case stationCode = "odpt:stationCode"
        case latitude = "geo:lat"
        case longitude = "geo:long"
        case region = "odpt:region"
    }
}

// MARK: - Railway Models

/// 路線情報
struct ODPTRailway: Codable {
    /// 固有識別子 (e.g., "odpt.Railway:JR-East.Yamanote")
    let id: String
    
    /// 路線名（日本語）
    let title: String
    
    /// 路線名（英語）
    let titleEn: String?
    
    /// 路線名（かな）
    let titleJa: String?
    
    /// 運営会社
    let operatorID: String
    
    /// 路線カラー
    let lineColor: String?
    
    /// 路線記号
    let lineSymbol: String?
    
    /// 駅の順序リスト
    let stationOrder: [StationOrder]?
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case title = "dc:title"
        case titleEn = "odpt:railwayTitle.en"
        case titleJa = "odpt:railwayTitle.ja"
        case operatorID = "odpt:operator"
        case lineColor = "odpt:color"
        case lineSymbol = "odpt:lineCode"
        case stationOrder = "odpt:stationOrder"
    }
}

/// 駅の順序情報
struct StationOrder: Codable {
    /// 駅のID
    let station: String
    
    /// 順序インデックス
    let index: Int
    
    private enum CodingKeys: String, CodingKey {
        case station = "odpt:station"
        case index = "odpt:index"
    }
}

// MARK: - Train Timetable Models

/// 列車時刻表
struct ODPTTrainTimetable: Codable {
    /// 固有識別子
    let id: String
    
    /// 路線ID
    let railway: String
    
    /// 運営会社
    let operatorID: String
    
    /// 列車番号
    let trainNumber: String
    
    /// 列車種別 (e.g., "odpt.TrainType:JR-East.Local")
    let trainType: String
    
    /// 列車名称（のぞみ、ひかり等）
    let trainName: String?
    
    /// 行先駅ID配列
    let destinationStation: [String]?
    
    /// 時刻表オブジェクト配列
    let timetableObject: [TimetableObject]
    
    /// カレンダーID（平日、土休日等）
    let calendar: String
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case railway = "odpt:railway"
        case operatorID = "odpt:operator"
        case trainNumber = "odpt:trainNumber"
        case trainType = "odpt:trainType"
        case trainName = "odpt:trainName"
        case destinationStation = "odpt:destinationStation"
        case timetableObject = "odpt:trainTimetableObject"
        case calendar = "odpt:calendar"
    }
}

/// 時刻表オブジェクト
struct TimetableObject: Codable {
    /// 出発時刻 (HH:mm形式)
    let departureTime: String?
    
    /// 到着時刻 (HH:mm形式)
    let arrivalTime: String?
    
    /// 駅ID
    let station: String
    
    private enum CodingKeys: String, CodingKey {
        case departureTime = "odpt:departureTime"
        case arrivalTime = "odpt:arrivalTime"
        case station = "odpt:departureStation"
    }
}

// MARK: - Train Information (Real-time)

/// リアルタイム列車位置情報
struct ODPTTrain: Codable {
    /// 固有識別子
    let id: String
    
    /// 列車番号
    let trainNumber: String
    
    /// 列車種別
    let trainType: String
    
    /// 遅延時間（秒）
    let delay: Int?
    
    /// 現在位置（出発駅）
    let fromStation: String?
    
    /// 現在位置（到着駅）
    let toStation: String?
    
    /// 路線ID
    let railway: String
    
    /// 更新日時
    let date: String
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case trainNumber = "odpt:trainNumber"
        case trainType = "odpt:trainType"
        case delay = "odpt:delay"
        case fromStation = "odpt:fromStation"
        case toStation = "odpt:toStation"
        case railway = "odpt:railway"
        case date = "dc:date"
    }
}

// MARK: - Calendar

/// カレンダー情報（平日、土休日等）
struct ODPTCalendar: Codable {
    /// 固有識別子 (e.g., "odpt.Calendar:Weekday", "odpt.Calendar:Holiday")
    let id: String
    
    /// カレンダー名
    let title: String
    
    /// 有効日付配列
    let dates: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case title = "dc:title"
        case dates = "odpt:day"
    }
}

// MARK: - Operator

/// 事業者情報
struct ODPTOperator: Codable {
    /// 固有識別子 (e.g., "odpt.Operator:JR-East")
    let id: String
    
    /// 事業者名（日本語）
    let title: String
    
    /// 事業者名（英語）
    let titleEn: String?
    
    private enum CodingKeys: String, CodingKey {
        case id = "@id"
        case title = "dc:title"
        case titleEn = "odpt:operatorTitle.en"
    }
}

// MARK: - Route Search Result

/// 経路検索結果（アプリ内で構築）
struct RouteSearchResult: Identifiable {
    /// 経路ID（内部生成）
    let id: String
    
    /// 出発駅
    let departureStation: ODPTStation
    
    /// 到着駅
    let arrivalStation: ODPTStation
    
    /// 出発時刻
    let departureTime: Date
    
    /// 到着時刻
    let arrivalTime: Date
    
    /// 所要時間（分）
    let duration: Int
    
    /// 乗り換え回数
    let transferCount: Int
    
    /// 経路詳細
    let sections: [RouteSection]
    
    /// 運賃
    let fare: Int?
    
    /// 遅延時間（秒）
    let totalDelay: Int?
}

/// 経路区間
struct RouteSection {
    /// 区間番号
    let index: Int
    
    /// 路線情報
    let railway: ODPTRailway
    
    /// 列車種別
    let trainType: String
    
    /// 出発駅
    let departureStation: ODPTStation
    
    /// 到着駅  
    let arrivalStation: ODPTStation
    
    /// 出発時刻
    let departureTime: Date
    
    /// 到着時刻
    let arrivalTime: Date
    
    /// 停車駅数
    let stopCount: Int
    
    /// 遅延時間（秒）
    let delay: Int?
}
