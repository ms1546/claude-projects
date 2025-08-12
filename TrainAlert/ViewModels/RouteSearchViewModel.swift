//
//  RouteSearchViewModel.swift
//  TrainAlert
//
//  経路検索画面のViewModel
//

import Foundation
import SwiftUI

@MainActor
class RouteSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchResults: [RouteSearchResult] = []
    @Published var isSearching = false
    @Published var hasSearched = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private var odptClient: ODPTAPIClient?
    
    // MARK: - Initialization
    
    init() {
        setupODPTClient()
    }
    
    // MARK: - Public Methods
    
    func setupODPTClient() {
        // API設定を確認してクライアントを初期化
        let config = ODPTAPIConfiguration.shared
        odptClient = ODPTAPIClient(
            apiKey: config.apiKey,
            useMockData: config.useMockData
        )
    }
    
    func searchRoutes(from: String, to: String, time: Date, searchType: RouteSearchView.SearchType) async {
        isSearching = true
        hasSearched = true
        errorMessage = nil
        searchResults = []
        
        do {
            guard let odptClient = odptClient else {
                throw ODPTAPIError.noAPIKey
            }
            
            // 駅名から駅IDを取得
            async let departureStations = odptClient.searchStations(query: from)
            async let arrivalStations = odptClient.searchStations(query: to)
            
            let (depStations, arrStations) = try await (departureStations, arrivalStations)
            
            guard let departureStation = depStations.first else {
                throw RouteSearchError.stationNotFound(from)
            }
            
            guard let arrivalStation = arrStations.first else {
                throw RouteSearchError.stationNotFound(to)
            }
            
            // 経路検索
            let results = try await odptClient.searchRoutes(
                from: departureStation.id,
                to: arrivalStation.id,
                departureTime: searchType == .departure ? time : nil
            )
            
            // 到着時刻指定の場合はフィルタリング
            if searchType == .arrival {
                searchResults = results.filter { route in
                    route.arrivalTime <= time
                }.sorted { $0.arrivalTime > $1.arrivalTime }
            } else {
                searchResults = results
            }
            
            if searchResults.isEmpty {
                errorMessage = "指定された条件の経路が見つかりませんでした"
            }
        } catch let error as RouteSearchError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "経路検索中にエラーが発生しました"
        }
        
        isSearching = false
    }
}

// MARK: - Error Types

enum RouteSearchError: LocalizedError {
    case stationNotFound(String)
    case noRoutesFound
    
    var errorDescription: String? {
        switch self {
        case .stationNotFound(let name):
            return "駅「\(name)」が見つかりませんでした"
        case .noRoutesFound:
            return "経路が見つかりませんでした"
        }
    }
}
