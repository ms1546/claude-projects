//
//  RouteSearchAlgorithm.swift
//  TrainAlert
//
//  経路探索アルゴリズムの実装
//

import CoreLocation
import Foundation

/// 経路探索アルゴリズムクラス
class RouteSearchAlgorithm {
    /// 駅のノード情報
    struct StationNode {
        let name: String
        let line: String
        let location: CLLocationCoordinate2D
    }
    
    /// エッジ（駅間の接続）情報
    struct Edge {
        let from: StationNode
        let to: StationNode
        let travelTime: Int // 所要時間（分）
        let isTransfer: Bool // 乗り換えかどうか
    }
    
    /// 経路探索結果
    struct SearchResult {
        let route: [StationNode]
        let totalTime: Int
        let transferCount: Int
        let sections: [RouteSection]
    }
    
    /// 経路の区間情報
    struct RouteSection: Equatable {
        let line: String
        let fromStation: String
        let toStation: String
        let stations: [String]
        let duration: Int
    }
    
    private let connectionManager = StationConnectionManager.shared
    
    /// 経路探索を実行
    func searchRoute(
        from departureStation: String,
        departureLine: String,
        to arrivalStation: String,
        arrivalLine: String?
    ) async throws -> [SearchResult] {
        // 簡易実装：直通可能な場合
        if let directRoute = try await searchDirectRoute(
            from: departureStation,
            line: departureLine,
            to: arrivalStation
        ) {
            return [directRoute]
        }
        
        // 1回乗り換えの経路を探索
        if let transferRoutes = try await searchWithOneTransfer(
            from: departureStation,
            departureLine: departureLine,
            to: arrivalStation,
            arrivalLine: arrivalLine
        ) {
            return transferRoutes
        }
        
        // 経路が見つからない場合
        return []
    }
    
    /// 直通経路を探索
    private func searchDirectRoute(
        from departure: String,
        line: String,
        to arrival: String
    ) async throws -> SearchResult? {
        // ODPTAPIを使って同一路線内での経路を検索
        // ここでは簡易的な実装
        
        // 同一路線内で到達可能かチェック
        // 実際にはODPT APIで駅の順序を確認する必要がある
        
        let route = [
            StationNode(name: departure, line: line, location: CLLocationCoordinate2D()),
            StationNode(name: arrival, line: line, location: CLLocationCoordinate2D())
        ]
        
        let section = RouteSection(
            line: line,
            fromStation: departure,
            toStation: arrival,
            stations: [departure, arrival],
            duration: 20 // 仮の値
        )
        
        // 簡易的に直通できない場合はnilを返す
        // 実際にはAPIで確認が必要
        if departure == arrival {
            return nil
        }
        
        // 同一路線でない場合は直通不可
        let departureLines = connectionManager.getLines(for: departure)
        let arrivalLines = connectionManager.getLines(for: arrival)
        
        if !departureLines.contains(line) || !arrivalLines.contains(line) {
            return nil
        }
        
        return SearchResult(
            route: route,
            totalTime: 20,
            transferCount: 0,
            sections: [section]
        )
    }
    
    /// 1回乗り換えの経路を探索
    private func searchWithOneTransfer(
        from departure: String,
        departureLine: String,
        to arrival: String,
        arrivalLine: String?
    ) async throws -> [SearchResult]? {
        var results: [SearchResult] = []
        
        // 出発駅の路線一覧を取得
        let departureLines = connectionManager.getLines(for: departure)
        
        // 到着駅の路線一覧を取得
        let arrivalLines = connectionManager.getLines(for: arrival)
        
        // 共通の乗り換え駅を探す
        for transferStation in connectionManager.findTransferStations(from: departureLine, to: "") {
            // 乗り換え駅が到着駅への路線を持っているか確認
            let transferLines = transferStation.lines
            
            for arrivalLine in arrivalLines {
                if transferLines.contains(arrivalLine) && arrivalLine != departureLine {
                    // 経路を構築
                    let route = [
                        StationNode(name: departure, line: departureLine, location: CLLocationCoordinate2D()),
                        StationNode(name: transferStation.stationName, line: departureLine, location: transferStation.location),
                        StationNode(name: transferStation.stationName, line: arrivalLine, location: transferStation.location),
                        StationNode(name: arrival, line: arrivalLine, location: CLLocationCoordinate2D())
                    ]
                    
                    let sections = [
                        RouteSection(
                            line: departureLine,
                            fromStation: departure,
                            toStation: transferStation.stationName,
                            stations: [departure, transferStation.stationName],
                            duration: 15 // 仮の値
                        ),
                        RouteSection(
                            line: arrivalLine,
                            fromStation: transferStation.stationName,
                            toStation: arrival,
                            stations: [transferStation.stationName, arrival],
                            duration: 15 // 仮の値
                        )
                    ]
                    
                    let totalTime = 15 + transferStation.transferTime + 15
                    
                    let result = SearchResult(
                        route: route,
                        totalTime: totalTime,
                        transferCount: 1,
                        sections: sections
                    )
                    
                    results.append(result)
                    
                    // 最初の3つの結果のみ返す
                    if results.count >= 3 {
                        return results
                    }
                }
            }
        }
        
        return results.isEmpty ? nil : results
    }
    
    /// 所要時間でソート
    func sortByDuration(_ results: [SearchResult]) -> [SearchResult] {
        results.sorted { $0.totalTime < $1.totalTime }
    }
    
    /// 乗り換え回数でソート
    func sortByTransferCount(_ results: [SearchResult]) -> [SearchResult] {
        results.sorted { $0.transferCount < $1.transferCount }
    }
}

