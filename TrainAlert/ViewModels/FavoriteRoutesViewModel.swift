//
//  FavoriteRoutesViewModel.swift
//  TrainAlert
//
//  お気に入り経路画面のViewModel
//

import Combine
import CoreData
import Foundation
import SwiftUI

@MainActor
class FavoriteRoutesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var favoriteRoutes: [FavoriteRoute] = []
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .manual
    @Published var isEditing: Bool = false
    @Published var showingNicknameEditor: Bool = false
    @Published var selectedRoute: FavoriteRoute?
    @Published var editingNickname: String = ""
    
    // MARK: - Properties
    
    private let favoriteRouteManager = FavoriteRouteManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredRoutes: [FavoriteRoute] {
        if searchText.isEmpty {
            return favoriteRoutes
        } else {
            return favoriteRouteManager.searchFavoriteRoutes(searchText: searchText)
        }
    }
    
    var isAtMaxCapacity: Bool {
        favoriteRouteManager.isAtMaxCapacity
    }
    
    var favoriteCount: Int {
        favoriteRouteManager.favoriteCount
    }
    
    // MARK: - Sort Options
    
    enum SortOption: String, CaseIterable {
        case manual = "手動"
        case recentUse = "最近使った順"
        case frequency = "よく使う順"
        case created = "作成日順"
        
        var iconName: String {
            switch self {
            case .manual:
                return "arrow.up.arrow.down"
            case .recentUse:
                return "clock"
            case .frequency:
                return "chart.bar"
            case .created:
                return "calendar"
            }
        }
    }
    
    // MARK: - Initializer
    
    init() {
        loadFavoriteRoutes()
        
        // FavoriteRouteManagerの変更を監視
        favoriteRouteManager.$favoriteRoutes
            .sink { [weak self] routes in
                self?.favoriteRoutes = routes
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// お気に入り経路を読み込む
    func loadFavoriteRoutes() {
        favoriteRouteManager.fetchFavoriteRoutes()
        favoriteRoutes = favoriteRouteManager.favoriteRoutes
    }
    
    /// お気に入り経路を使用（選択）
    /// - Parameter route: 使用する経路
    /// - Returns: 経路データのデコード結果
    func useFavoriteRoute(_ route: FavoriteRoute) -> RouteSearchResult? {
        favoriteRouteManager.useFavoriteRoute(route)
        
        // routeDataからRouteSearchResultをデコード
        guard let routeData = route.routeData else { return nil }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(RouteSearchResult.self, from: routeData)
            return result
        } catch {
            print("Failed to decode route data: \(error)")
            return nil
        }
    }
    
    /// お気に入り経路を削除
    /// - Parameter route: 削除する経路
    func deleteFavoriteRoute(_ route: FavoriteRoute) {
        favoriteRouteManager.delete(route)
        loadFavoriteRoutes()
    }
    
    /// 複数のお気に入り経路を削除
    /// - Parameter offsets: 削除するインデックス
    func deleteFavoriteRoutes(at offsets: IndexSet) {
        let routesToDelete = offsets.map { filteredRoutes[$0] }
        
        // Core Dataから削除
        routesToDelete.forEach { route in
            favoriteRouteManager.delete(route)
        }
        
        // 削除後すぐにリストを更新
        withAnimation {
            favoriteRouteManager.fetchFavoriteRoutes()
            favoriteRoutes = favoriteRouteManager.favoriteRoutes
        }
    }
    
    /// ニックネームを編集
    /// - Parameter route: 編集する経路
    func startEditingNickname(for route: FavoriteRoute) {
        selectedRoute = route
        editingNickname = route.nickName ?? ""
        showingNicknameEditor = true
    }
    
    /// ニックネームを保存
    func saveNickname() {
        guard let route = selectedRoute else { return }
        
        let nickname = editingNickname.isEmpty ? nil : editingNickname
        favoriteRouteManager.updateFavoriteRoute(route, nickName: nickname)
        
        showingNicknameEditor = false
        selectedRoute = nil
        editingNickname = ""
        loadFavoriteRoutes()
    }
    
    /// ニックネーム編集をキャンセル
    func cancelNicknameEdit() {
        showingNicknameEditor = false
        selectedRoute = nil
        editingNickname = ""
    }
    
    /// 並び順を変更
    /// - Parameter option: 並び替えオプション
    func changeSortOption(_ option: SortOption) {
        sortOption = option
        
        switch option {
        case .manual:
            // 手動並び替えモードに戻す
            loadFavoriteRoutes()
        case .recentUse:
            favoriteRouteManager.sortByRecentUsage()
        case .frequency:
            favoriteRouteManager.sortByFrequency()
        case .created:
            favoriteRouteManager.sortByCreatedDate()
        }
        
        loadFavoriteRoutes()
    }
    
    /// 手動で並び順を更新
    /// - Parameters:
    ///   - source: 移動元のインデックス
    ///   - destination: 移動先のインデックス
    func moveRoute(from source: IndexSet, to destination: Int) {
        var routes = filteredRoutes
        routes.move(fromOffsets: source, toOffset: destination)
        favoriteRouteManager.updateSortOrder(routes)
        loadFavoriteRoutes()
    }
    
    /// お気に入りに空きがあるか確認
    /// - Returns: 空きがある場合true
    func hasCapacity() -> Bool {
        !isAtMaxCapacity
    }
    
    /// お気に入りの残り枠数を取得
    /// - Returns: 残り枠数
    func remainingCapacity() -> Int {
        20 - favoriteCount // 最大20件
    }
}
