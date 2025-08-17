import CoreData
import Foundation
import OSLog

/// お気に入り経路を管理するマネージャークラス
final class FavoriteRouteManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = FavoriteRouteManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "FavoriteRoute")
    private let coreDataManager = CoreDataManager.shared
    private let maxFavorites = 20 // お気に入りの最大保存数
    
    // MARK: - Published Properties
    
    @Published var favoriteRoutes: [FavoriteRoute] = []
    
    // MARK: - Initializer
    
    private init() {
        fetchFavoriteRoutes()
    }
    
    // MARK: - CRUD Operations
    
    /// お気に入り経路を作成
    /// - Parameters:
    ///   - departureStation: 出発駅名
    ///   - arrivalStation: 到着駅名
    ///   - departureTime: デフォルトの出発時刻
    ///   - nickName: ニックネーム（オプション）
    ///   - routeData: 経路の詳細データ（JSONエンコード済み）
    /// - Returns: 作成されたFavoriteRoute、既に存在する場合はnil
    func createFavoriteRoute(
        departureStation: String,
        arrivalStation: String,
        departureTime: Date? = nil,
        nickName: String? = nil,
        routeData: Data? = nil
    ) -> FavoriteRoute? {
        // 重複チェック
        if isDuplicate(departureStation: departureStation, arrivalStation: arrivalStation) {
            logger.warning("Duplicate favorite route: \(departureStation) to \(arrivalStation)")
            return nil
        }
        
        // 最大数チェック
        if favoriteRoutes.count >= maxFavorites {
            logger.warning("Maximum favorite routes reached: \(maxFavorites)")
            // 最も古いものを削除（オプション）
            if let oldestRoute = favoriteRoutes.min(by: { $0.lastUsedAt ?? Date.distantPast < $1.lastUsedAt ?? Date.distantPast }) {
                delete(oldestRoute)
            }
        }
        
        let context = coreDataManager.viewContext
        let favoriteRoute = FavoriteRoute(context: context)
        
        favoriteRoute.routeId = UUID()
        favoriteRoute.departureStation = departureStation
        favoriteRoute.arrivalStation = arrivalStation
        favoriteRoute.departureTime = departureTime
        favoriteRoute.nickName = nickName
        favoriteRoute.routeData = routeData
        favoriteRoute.sortOrder = Int16(favoriteRoutes.count)
        favoriteRoute.createdAt = Date()
        favoriteRoute.lastUsedAt = Date()
        
        coreDataManager.save()
        fetchFavoriteRoutes()
        
        logger.info("Favorite route created: \(departureStation) to \(arrivalStation)")
        return favoriteRoute
    }
    
    /// お気に入り経路を取得
    func fetchFavoriteRoutes() {
        let request: NSFetchRequest<FavoriteRoute> = FavoriteRoute.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FavoriteRoute.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \FavoriteRoute.createdAt, ascending: false)
        ]
        
        do {
            let routes = try coreDataManager.viewContext.fetch(request)
            // メインスレッドで@Published変数を更新
            DispatchQueue.main.async { [weak self] in
                self?.favoriteRoutes = routes
            }
            logger.info("Fetched \(routes.count) favorite routes")
        } catch {
            logger.error("Failed to fetch favorite routes: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.favoriteRoutes = []
            }
        }
    }
    
    /// お気に入り経路を更新
    /// - Parameters:
    ///   - route: 更新する経路
    ///   - nickName: 新しいニックネーム
    ///   - departureTime: 新しいデフォルト出発時刻
    func updateFavoriteRoute(_ route: FavoriteRoute, nickName: String? = nil, departureTime: Date? = nil) {
        if let nickName = nickName {
            route.nickName = nickName
        }
        if let departureTime = departureTime {
            route.departureTime = departureTime
        }
        
        coreDataManager.save()
        fetchFavoriteRoutes()
        
        logger.info("Favorite route updated: \(route.departureStation ?? "") to \(route.arrivalStation ?? "")")
    }
    
    /// お気に入り経路を削除
    /// - Parameter route: 削除する経路
    func delete(_ route: FavoriteRoute) {
        coreDataManager.delete(route)
        fetchFavoriteRoutes()
        
        logger.info("Favorite route deleted: \(route.departureStation ?? "") to \(route.arrivalStation ?? "")")
    }
    
    /// お気に入り経路を使用（最終利用日時を更新）
    /// - Parameter route: 使用する経路
    func useFavoriteRoute(_ route: FavoriteRoute) {
        route.lastUsedAt = Date()
        coreDataManager.save()
        
        logger.info("Favorite route used: \(route.departureStation ?? "") to \(route.arrivalStation ?? "")")
    }
    
    // MARK: - Sorting Methods
    
    /// 並び順を更新
    /// - Parameter routes: 新しい順序の経路配列
    func updateSortOrder(_ routes: [FavoriteRoute]) {
        for (index, route) in routes.enumerated() {
            route.sortOrder = Int16(index)
        }
        
        coreDataManager.save()
        fetchFavoriteRoutes()
        
        logger.info("Sort order updated for \(routes.count) routes")
    }
    
    /// 利用頻度順に並び替え
    func sortByFrequency() {
        let sorted = favoriteRoutes.sorted { route1, route2 in
            let date1 = route1.lastUsedAt ?? Date.distantPast
            let date2 = route2.lastUsedAt ?? Date.distantPast
            return date1 > date2
        }
        
        updateSortOrder(sorted)
    }
    
    /// 最近使った順に並び替え
    func sortByRecentUsage() {
        let sorted = favoriteRoutes.sorted { route1, route2 in
            let date1 = route1.lastUsedAt ?? Date.distantPast
            let date2 = route2.lastUsedAt ?? Date.distantPast
            return date1 > date2
        }
        
        updateSortOrder(sorted)
    }
    
    /// 作成日順に並び替え
    func sortByCreatedDate() {
        let sorted = favoriteRoutes.sorted { route1, route2 in
            let date1 = route1.createdAt ?? Date.distantPast
            let date2 = route2.createdAt ?? Date.distantPast
            return date1 < date2
        }
        
        updateSortOrder(sorted)
    }
    
    // MARK: - Utility Methods
    
    /// 重複チェック
    /// - Parameters:
    ///   - departureStation: 出発駅名
    ///   - arrivalStation: 到着駅名
    /// - Returns: 重複している場合true
    private func isDuplicate(departureStation: String, arrivalStation: String) -> Bool {
        favoriteRoutes.contains { route in
            route.departureStation == departureStation &&
            route.arrivalStation == arrivalStation
        }
    }
    
    /// お気に入り経路から検索
    /// - Parameter searchText: 検索テキスト
    /// - Returns: 検索結果の経路配列
    func searchFavoriteRoutes(searchText: String) -> [FavoriteRoute] {
        guard !searchText.isEmpty else { return favoriteRoutes }
        
        let lowercasedSearch = searchText.lowercased()
        return favoriteRoutes.filter { route in
            let departureMatch = route.departureStation?.lowercased().contains(lowercasedSearch) ?? false
            let arrivalMatch = route.arrivalStation?.lowercased().contains(lowercasedSearch) ?? false
            let nickNameMatch = route.nickName?.lowercased().contains(lowercasedSearch) ?? false
            
            return departureMatch || arrivalMatch || nickNameMatch
        }
    }
    
    /// お気に入りの数を取得
    var favoriteCount: Int {
        favoriteRoutes.count
    }
    
    /// お気に入りが上限に達しているか
    var isAtMaxCapacity: Bool {
        favoriteCount >= maxFavorites
    }
}
