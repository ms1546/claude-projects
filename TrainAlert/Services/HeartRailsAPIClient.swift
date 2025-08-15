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
        
        var components = URLComponents(string: "\(baseURL)/station")!
        components.queryItems = [
            URLQueryItem(name: "method", value: "getStations"),
            URLQueryItem(name: "name", value: name)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
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
            // エラー時は空配列を返す
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
        ODPTStation(
            id: "heartrails:\(name)",
            sameAs: "heartrails.Station:\(name)",
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
