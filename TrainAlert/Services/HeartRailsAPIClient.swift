//
//  HeartRailsAPIClient.swift
//  TrainAlert
//
//  HeartRails Express API クライアント
//  駅名検索専用の高速API
//

import CoreLocation
import Foundation

/// HeartRails Express API レスポンスモデル
struct HeartRailsResponse: Codable {
    let response: HeartRailsStationResponse
}

struct HeartRailsStationResponse: Codable {
    let station: [HeartRailsStation]?
}

struct HeartRailsStation: Codable {
    let name: String
    let prefecture: String
    let line: String
    let x: Double  // 経度
    let y: Double  // 緯度
    let postal: String?
    let address: String?
    let prev: String?
    let next: String?
    let distance: String?
}

/// HeartRails Express API クライアント
@MainActor
final class HeartRailsAPIClient {
    static let shared = HeartRailsAPIClient()
    
    private let baseURL = "http://express.heartrails.com/api/json"
    private let session: URLSession
    
    // よく使われる駅名の別名マッピング
    private let stationAliases: [String: String] = [
        "読売ランド": "読売ランド前",
        "成田": "京成成田",
        "羽田": "羽田空港第1・第2ターミナル",
        "羽田空港": "羽田空港第1・第2ターミナル",
        "ディズニー": "舞浜",
        "ディズニーランド": "舞浜",
        "スカイツリー": "とうきょうスカイツリー",
        "東京スカイツリー": "とうきょうスカイツリー",
        "築地": "築地市場",
        "豊洲市場": "市場前",
        "お台場": "台場",
        "ビッグサイト": "東京ビッグサイト",
        "有明": "国際展示場",
        "晴海": "勝どき",
        "六本木ヒルズ": "六本木",
        "東京タワー": "神谷町",
        "皇居": "二重橋前",
        "国会議事堂": "国会議事堂前",
        "東大": "本郷三丁目",
        "早稲田": "早稲田",
        "慶応": "日吉",
        "慶應": "日吉",
        "明治大学": "御茶ノ水",
        "青学": "表参道",
        "青山学院": "表参道"
    ]
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0  // 5秒のタイムアウト
        config.timeoutIntervalForResource = 10.0
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }
    
    /// 駅名で検索
    func searchStations(by name: String) async throws -> [HeartRailsStation] {
        guard !name.isEmpty else { return [] }
        
        // まずエイリアスをチェック
        let searchName = stationAliases[name] ?? name
        
        // 入力されたままで検索（エイリアスがあればそれを使用）
        var stations = await searchStationsExact(name: searchName)
        
        // 結果が0件の場合、いくつかのパターンを試す
        if stations.isEmpty {
            // 「前」を追加して検索（例：読売ランド → 読売ランド前）
            stations = await searchStationsExact(name: searchName + "前")
            
            // それでも見つからない場合、「駅」を追加
            if stations.isEmpty {
                stations = await searchStationsExact(name: searchName + "駅")
            }
            
            // 「ヶ」と「ケ」の変換を試す
            if stations.isEmpty && (searchName.contains("ヶ") || searchName.contains("ケ")) {
                let altName = searchName.contains("ヶ") ? 
                    searchName.replacingOccurrences(of: "ヶ", with: "ケ") :
                    searchName.replacingOccurrences(of: "ケ", with: "ヶ")
                stations = await searchStationsExact(name: altName)
            }
            
            // 「ノ」と「の」の変換を試す
            if stations.isEmpty && (searchName.contains("ノ") || searchName.contains("の")) {
                let altName = searchName.contains("ノ") ?
                    searchName.replacingOccurrences(of: "ノ", with: "の") :
                    searchName.replacingOccurrences(of: "の", with: "ノ")
                stations = await searchStationsExact(name: altName)
            }
        }
        
        return stations
    }
    
    /// 駅名で完全一致検索（内部メソッド）
    private func searchStationsExact(name: String) async -> [HeartRailsStation] {
        var components = URLComponents(string: "\(baseURL)/station")!
        components.queryItems = [
            URLQueryItem(name: "method", value: "getStations"),
            URLQueryItem(name: "name", value: name)
        ]
        
        guard let url = components.url else {
            return []
        }
        
        print("HeartRails API: Searching for '\(name)' - URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HeartRails API: Response status code: \(httpResponse.statusCode)")
            }
            
            let decodedResponse = try JSONDecoder().decode(HeartRailsResponse.self, from: data)
            let stations = decodedResponse.response.station ?? []
            print("HeartRails API: Found \(stations.count) stations")
            
            return stations
        } catch {
            print("HeartRails API Error: \(error)")
            return []
        }
    }
    
    /// 座標から最寄り駅を検索
    func getNearbyStations(location: CLLocation, radius: Double = 2_000) async throws -> [HeartRailsStation] {
        var components = URLComponents(string: "\(baseURL)/station")!
        components.queryItems = [
            URLQueryItem(name: "method", value: "getStations"),
            URLQueryItem(name: "x", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "y", value: String(location.coordinate.latitude))
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(HeartRailsResponse.self, from: data)
            return response.response.station ?? []
        } catch {
            print("HeartRails API Error: \(error)")
            return []
        }
    }
}

// MARK: - ODPT Station への変換

extension HeartRailsStation {
    /// HeartRails Station を ODPT Station 形式に変換
    func toODPTStation() -> ODPTStation {
        // 路線名を含めて一意のIDを生成
        let uniqueId = "heartrails:\(name):\(line)"
        return ODPTStation(
            id: uniqueId,
            sameAs: uniqueId,
            date: nil,
            title: name,
            stationTitle: ODPTMultilingualTitle(ja: name, en: nil),
            railway: line,
            railwayTitle: ODPTMultilingualTitle(ja: line, en: nil),
            `operator`: prefecture,
            operatorTitle: ODPTMultilingualTitle(ja: prefecture, en: nil),
            stationCode: nil,
            connectingRailway: nil
        )
    }
}
