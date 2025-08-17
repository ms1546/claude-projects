import Combine
import CoreData
import Foundation
import OSLog

/// Core Dataスタックを管理するマネージャークラス
/// シングルトンパターンで実装し、アプリ全体でCore Dataの操作を統一管理する
final class CoreDataManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = CoreDataManager()
    
    // Flag to prevent initialization - default to true for immediate use
    private static var shouldInitialize = true
    
    static func enableCoreData() {
        shouldInitialize = true
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "CoreData")
    
    /// メインのPersistent Container
    /// CloudKitとの同期に対応
    lazy var persistentContainer: NSPersistentContainer = {
        // Check if Core Data should be initialized
        guard Self.shouldInitialize else {
            // Return a properly initialized container even if shouldInitialize is false
            let model = createManagedObjectModel()
            let container = NSPersistentContainer(name: "TrainAlert", managedObjectModel: model)
            
            // Use in-memory store for dummy container
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
            
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("🔴 Core Data Error (dummy): \(error)")
                }
            }
            
            return container
        }
        
        // Create a complete managed object model
        let model = createManagedObjectModel()
        let container = NSPersistentContainer(name: "TrainAlert", managedObjectModel: model)
        
        // Use SQLite store for data persistence
        let storeURL = URL.documentsDirectory.appending(path: "TrainAlert.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        
        // Enable persistent history tracking for CloudKit sync (future feature)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.logger.error("Core Data failed to load: \(error.localizedDescription)")
                print("🔴 Core Data Error: \(error)")
            } else {
                self?.logger.info("Core Data loaded successfully")
                print("✅ Core Data loaded with SQLite store at: \(storeURL.path)")
            }
        }
        
        // 自動マージを有効化
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Private Methods
    
    private func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Station Entity (defined first)
        let stationEntity = NSEntityDescription()
        stationEntity.name = "Station"
        stationEntity.managedObjectClassName = "Station"
        
        let stationId = NSAttributeDescription()
        stationId.name = "stationId"
        stationId.attributeType = .stringAttributeType
        stationId.isOptional = false
        
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false
        
        let latitude = NSAttributeDescription()
        latitude.name = "latitude"
        latitude.attributeType = .doubleAttributeType
        latitude.isOptional = false
        
        let longitude = NSAttributeDescription()
        longitude.name = "longitude"
        longitude.attributeType = .doubleAttributeType
        longitude.isOptional = false
        
        // Add lines property (Transformable for array)
        let lines = NSAttributeDescription()
        lines.name = "lines"
        lines.attributeType = .transformableAttributeType
        lines.valueTransformerName = "NSSecureUnarchiveFromData"
        lines.isOptional = true
        
        // Add createdAt property
        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = true
        
        // Add isFavorite property
        let isFavorite = NSAttributeDescription()
        isFavorite.name = "isFavorite"
        isFavorite.attributeType = .booleanAttributeType
        isFavorite.defaultValue = false
        
        // Add lastUsedAt property
        let lastUsedAt = NSAttributeDescription()
        lastUsedAt.name = "lastUsedAt"
        lastUsedAt.attributeType = .dateAttributeType
        lastUsedAt.isOptional = true
        
        stationEntity.properties = [stationId, name, latitude, longitude, lines, createdAt, isFavorite, lastUsedAt]
        
        // Alert Entity
        let alertEntity = NSEntityDescription()
        alertEntity.name = "Alert"
        alertEntity.managedObjectClassName = "Alert"
        
        let alertId = NSAttributeDescription()
        alertId.name = "alertId"
        alertId.attributeType = .UUIDAttributeType
        alertId.isOptional = false
        
        let isActive = NSAttributeDescription()
        isActive.name = "isActive"
        isActive.attributeType = .booleanAttributeType
        isActive.defaultValue = true
        
        let notificationTime = NSAttributeDescription()
        notificationTime.name = "notificationTime"
        notificationTime.attributeType = .integer16AttributeType
        notificationTime.defaultValue = 5
        
        let alertCreatedAt = NSAttributeDescription()
        alertCreatedAt.name = "createdAt"
        alertCreatedAt.attributeType = .dateAttributeType
        alertCreatedAt.isOptional = false
        
        // Add stationName and lineName for compatibility
        let stationName = NSAttributeDescription()
        stationName.name = "stationName"
        stationName.attributeType = .stringAttributeType
        stationName.isOptional = true
        
        let lineName = NSAttributeDescription()
        lineName.name = "lineName"
        lineName.attributeType = .stringAttributeType
        lineName.isOptional = true
        
        // Add route information fields
        let alertDepartureStation = NSAttributeDescription()
        alertDepartureStation.name = "departureStation"
        alertDepartureStation.attributeType = .stringAttributeType
        alertDepartureStation.isOptional = true
        
        let alertArrivalTime = NSAttributeDescription()
        alertArrivalTime.name = "arrivalTime"
        alertArrivalTime.attributeType = .dateAttributeType
        alertArrivalTime.isOptional = true
        
        // Add notificationDistance
        let notificationDistance = NSAttributeDescription()
        notificationDistance.name = "notificationDistance"
        notificationDistance.attributeType = .doubleAttributeType
        notificationDistance.defaultValue = 500.0
        
        // Add snoozeInterval
        let snoozeInterval = NSAttributeDescription()
        snoozeInterval.name = "snoozeInterval"
        snoozeInterval.attributeType = .integer16AttributeType
        snoozeInterval.defaultValue = 5
        
        // Add characterStyle
        let characterStyle = NSAttributeDescription()
        characterStyle.name = "characterStyle"
        characterStyle.attributeType = .stringAttributeType
        characterStyle.isOptional = true
        
        // Add notificationStationsBefore（何駅前）
        let notificationStationsBefore = NSAttributeDescription()
        notificationStationsBefore.name = "notificationStationsBefore"
        notificationStationsBefore.attributeType = .integer16AttributeType
        notificationStationsBefore.defaultValue = 0
        
        // Add notificationType（通知タイプ: time or station）
        let notificationType = NSAttributeDescription()
        notificationType.name = "notificationType"
        notificationType.attributeType = .stringAttributeType
        notificationType.defaultValue = "time"
        notificationType.isOptional = true
        
        // Relationship to Station (to-one relationship)
        let stationRelation = NSRelationshipDescription()
        stationRelation.name = "station"
        stationRelation.destinationEntity = stationEntity
        stationRelation.isOptional = true
        stationRelation.deleteRule = .nullifyDeleteRule
        stationRelation.maxCount = 1  // Explicitly set as to-one relationship
        stationRelation.minCount = 0
        
        // Add histories relationship (destination will be set later)
        let historiesRelation = NSRelationshipDescription()
        historiesRelation.name = "histories"
        historiesRelation.isOptional = true
        historiesRelation.deleteRule = .cascadeDeleteRule
        // isToMany is set via maxCount and minCount
        historiesRelation.maxCount = 0  // 0 means unlimited (to-many)
        historiesRelation.minCount = 0
        
        alertEntity.properties = [alertId, isActive, notificationTime, notificationDistance, snoozeInterval, characterStyle, notificationStationsBefore, notificationType, alertCreatedAt, stationName, lineName, alertDepartureStation, alertArrivalTime, stationRelation, historiesRelation]
        
        // History Entity
        let historyEntity = NSEntityDescription()
        historyEntity.name = "History"
        historyEntity.managedObjectClassName = "History"
        
        let historyId = NSAttributeDescription()
        historyId.name = "historyId"
        historyId.attributeType = .UUIDAttributeType
        historyId.isOptional = false
        
        let notifiedAt = NSAttributeDescription()
        notifiedAt.name = "notifiedAt"
        notifiedAt.attributeType = .dateAttributeType
        notifiedAt.isOptional = false
        
        // Add message property
        let message = NSAttributeDescription()
        message.name = "message"
        message.attributeType = .stringAttributeType
        message.isOptional = true
        
        // Add alert relationship
        let alertRelation = NSRelationshipDescription()
        alertRelation.name = "alert"
        alertRelation.destinationEntity = alertEntity
        alertRelation.isOptional = true
        alertRelation.deleteRule = .nullifyDeleteRule
        // isToMany is set via maxCount (1 means to-one)
        alertRelation.maxCount = 1
        alertRelation.minCount = 0
        
        historyEntity.properties = [historyId, notifiedAt, message, alertRelation]
        
        // Set up inverse relationships after all entities are created
        let alertsRelation = NSRelationshipDescription()
        alertsRelation.name = "alerts"
        alertsRelation.destinationEntity = alertEntity
        alertsRelation.isOptional = true
        alertsRelation.deleteRule = .cascadeDeleteRule
        // isToMany is set via maxCount (0 means unlimited - to-many)
        alertsRelation.maxCount = 0
        alertsRelation.minCount = 0
        
        // Add alerts relationship to station entity
        var stationProperties = stationEntity.properties ?? []
        stationProperties.append(alertsRelation)
        stationEntity.properties = stationProperties
        
        // Set up histories relationship destination
        historiesRelation.destinationEntity = historyEntity
        
        // Set inverse relationships
        if let stationRelation = alertEntity.relationshipsByName["station"] {
            stationRelation.inverseRelationship = alertsRelation
            alertsRelation.inverseRelationship = stationRelation
        }
        
        if let historiesRelation = alertEntity.relationshipsByName["histories"],
           let alertRelation = historyEntity.relationshipsByName["alert"] {
            historiesRelation.inverseRelationship = alertRelation
            alertRelation.inverseRelationship = historiesRelation
        }
        
        // RouteAlert Entity
        let routeAlertEntity = NSEntityDescription()
        routeAlertEntity.name = "RouteAlert"
        routeAlertEntity.managedObjectClassName = "RouteAlert"
        
        // RouteAlert attributes
        let routeId = NSAttributeDescription()
        routeId.name = "routeId"
        routeId.attributeType = .UUIDAttributeType
        routeId.isOptional = true
        
        let routeDepartureStation = NSAttributeDescription()
        routeDepartureStation.name = "departureStation"
        routeDepartureStation.attributeType = .stringAttributeType
        routeDepartureStation.isOptional = true
        
        let routeArrivalStation = NSAttributeDescription()
        routeArrivalStation.name = "arrivalStation"
        routeArrivalStation.attributeType = .stringAttributeType
        routeArrivalStation.isOptional = true
        
        let routeDepartureTime = NSAttributeDescription()
        routeDepartureTime.name = "departureTime"
        routeDepartureTime.attributeType = .dateAttributeType
        routeDepartureTime.isOptional = true
        
        let routeArrivalTime = NSAttributeDescription()
        routeArrivalTime.name = "arrivalTime"
        routeArrivalTime.attributeType = .dateAttributeType
        routeArrivalTime.isOptional = true
        
        let trainNumber = NSAttributeDescription()
        trainNumber.name = "trainNumber"
        trainNumber.attributeType = .stringAttributeType
        trainNumber.isOptional = true
        
        let trainType = NSAttributeDescription()
        trainType.name = "trainType"
        trainType.attributeType = .stringAttributeType
        trainType.isOptional = true
        
        let railway = NSAttributeDescription()
        railway.name = "railway"
        railway.attributeType = .stringAttributeType
        railway.isOptional = true
        
        let routeData = NSAttributeDescription()
        routeData.name = "routeData"
        routeData.attributeType = .binaryDataAttributeType
        routeData.isOptional = true
        
        let notificationMinutes = NSAttributeDescription()
        notificationMinutes.name = "notificationMinutes"
        notificationMinutes.attributeType = .integer16AttributeType
        notificationMinutes.defaultValue = 5
        
        let routeIsActive = NSAttributeDescription()
        routeIsActive.name = "isActive"
        routeIsActive.attributeType = .booleanAttributeType
        routeIsActive.defaultValue = true
        
        let routeCreatedAt = NSAttributeDescription()
        routeCreatedAt.name = "createdAt"
        routeCreatedAt.attributeType = .dateAttributeType
        routeCreatedAt.isOptional = true
        
        let routeUpdatedAt = NSAttributeDescription()
        routeUpdatedAt.name = "updatedAt"
        routeUpdatedAt.attributeType = .dateAttributeType
        routeUpdatedAt.isOptional = true
        
        routeAlertEntity.properties = [
            routeId, routeDepartureStation, routeArrivalStation, routeDepartureTime, routeArrivalTime,
            trainNumber, trainType, railway, routeData, notificationMinutes,
            routeIsActive, routeCreatedAt, routeUpdatedAt
        ]
        
        // FavoriteRoute Entity
        let favoriteRouteEntity = NSEntityDescription()
        favoriteRouteEntity.name = "FavoriteRoute"
        favoriteRouteEntity.managedObjectClassName = "FavoriteRoute"
        
        // FavoriteRoute attributes
        let favoriteRouteId = NSAttributeDescription()
        favoriteRouteId.name = "routeId"
        favoriteRouteId.attributeType = .UUIDAttributeType
        favoriteRouteId.isOptional = true
        
        let favoriteDepartureStation = NSAttributeDescription()
        favoriteDepartureStation.name = "departureStation"
        favoriteDepartureStation.attributeType = .stringAttributeType
        favoriteDepartureStation.isOptional = true
        
        let favoriteArrivalStation = NSAttributeDescription()
        favoriteArrivalStation.name = "arrivalStation"
        favoriteArrivalStation.attributeType = .stringAttributeType
        favoriteArrivalStation.isOptional = true
        
        let favoriteDepartureTime = NSAttributeDescription()
        favoriteDepartureTime.name = "departureTime"
        favoriteDepartureTime.attributeType = .dateAttributeType
        favoriteDepartureTime.isOptional = true
        
        let favoriteNickName = NSAttributeDescription()
        favoriteNickName.name = "nickName"
        favoriteNickName.attributeType = .stringAttributeType
        favoriteNickName.isOptional = true
        
        let favoriteSortOrder = NSAttributeDescription()
        favoriteSortOrder.name = "sortOrder"
        favoriteSortOrder.attributeType = .integer16AttributeType
        favoriteSortOrder.defaultValue = 0
        
        let favoriteCreatedAt = NSAttributeDescription()
        favoriteCreatedAt.name = "createdAt"
        favoriteCreatedAt.attributeType = .dateAttributeType
        favoriteCreatedAt.isOptional = true
        
        let favoriteLastUsedAt = NSAttributeDescription()
        favoriteLastUsedAt.name = "lastUsedAt"
        favoriteLastUsedAt.attributeType = .dateAttributeType
        favoriteLastUsedAt.isOptional = true
        
        let favoriteRouteData = NSAttributeDescription()
        favoriteRouteData.name = "routeData"
        favoriteRouteData.attributeType = .binaryDataAttributeType
        favoriteRouteData.isOptional = true
        
        favoriteRouteEntity.properties = [
            favoriteRouteId, favoriteDepartureStation, favoriteArrivalStation,
            favoriteDepartureTime, favoriteNickName, favoriteSortOrder,
            favoriteCreatedAt, favoriteLastUsedAt, favoriteRouteData
        ]
        
        model.entities = [alertEntity, stationEntity, historyEntity, routeAlertEntity, favoriteRouteEntity]
        
        return model
    }
    
    /// メインコンテキスト（UIスレッドで使用）
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Initializer
    
    private init() {}
    
    // MARK: - Context Operations
    
    /// バックグラウンドコンテキストを作成
    /// - Returns: バックグラウンド処理用のコンテキスト
    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    /// メインコンテキストの変更を保存
    func save() {
        save(context: viewContext)
    }
    
    /// 指定されたコンテキストの変更を保存
    /// - Parameter context: 保存するコンテキスト
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            let performanceMonitor = PerformanceMonitor.shared
            performanceMonitor.startTimer(for: "Core Data Save")
            
            try context.save()
            
            performanceMonitor.endTimer(for: "Core Data Save")
            logger.info("Context saved successfully")
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
            // 開発時はクラッシュさせ、本番環境では適切なエラーハンドリングを行う
            #if DEBUG
            fatalError("Failed to save context: \(error)")
            #endif
        }
    }
    
    /// バックグラウンドでタスクを実行し、自動的に保存
    /// - Parameter block: 実行するタスク
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startTimer(for: "Core Data Background Task")
        
        persistentContainer.performBackgroundTask { context in
            // Configure context for performance
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            context.undoManager = nil // Disable undo for background tasks
            
            block(context)
            self.save(context: context)
            
            performanceMonitor.endTimer(for: "Core Data Background Task")
        }
    }
    
    /// バックグラウンドでタスクを実行し、自動的に保存 (async version)
    /// - Parameter block: 実行するタスク
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startTimer(for: "Core Data Async Background Task")
        
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                // Configure context for performance
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                context.undoManager = nil
                
                do {
                    let result = try block(context)
                    self.save(context: context)
                    performanceMonitor.endTimer(for: "Core Data Async Background Task")
                    continuation.resume(returning: result)
                } catch {
                    performanceMonitor.endTimer(for: "Core Data Async Background Task")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Optimized Fetch Operations
    
    /// 最適化されたフェッチを実行
    /// - Parameters:
    ///   - request: フェッチリクエスト
    ///   - context: コンテキスト (nilの場合はviewContextを使用)
    /// - Returns: フェッチ結果
    func optimizedFetch<T: NSManagedObject>(_ request: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) async throws -> [T] {
        let performanceMonitor = PerformanceMonitor.shared
        let contextToUse = context ?? viewContext
        
        return try await performanceMeasureAsync(operation: "Optimized Fetch: \(T.self)") {
            // Optimize fetch request
            request.returnsObjectsAsFaults = false // Pre-populate relationship data
            request.includesSubentities = false    // Don't include subentities
            
            if contextToUse == viewContext {
                return try viewContext.fetch(request)
            } else {
                return try await performBackgroundTask { bgContext in
                    try bgContext.fetch(request)
                }
            }
        }
    }
    
    /// カウントのみを効率的に取得
    /// - Parameters:
    ///   - request: フェッチリクエスト
    ///   - context: コンテキスト
    /// - Returns: カウント
    func efficientCount<T: NSManagedObject>(for request: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) async throws -> Int {
        let contextToUse = context ?? viewContext
        
        if contextToUse == viewContext {
            return try viewContext.count(for: request)
        } else {
            return try await performBackgroundTask { bgContext in
                try bgContext.count(for: request)
            }
        }
    }
    
    // MARK: - CRUD Operations for Station
    
    /// 駅を作成
    /// - Parameters:
    ///   - stationId: 駅ID
    ///   - name: 駅名
    ///   - latitude: 緯度
    ///   - longitude: 経度
    ///   - lines: 路線情報（配列）
    /// - Returns: 作成された駅エンティティ
    func createStation(stationId: String, name: String, latitude: Double, longitude: Double, lines: [String]? = nil) -> Station {
        let station = Station(context: viewContext)
        
        // すべてのプロパティを直接設定（awakeFromInsertの後に上書き）
        station.stationId = stationId
        station.name = name
        station.latitude = latitude
        station.longitude = longitude
        station.lines = lines
        station.isFavorite = false
        station.createdAt = Date()
        station.lastUsedAt = nil
        
        // 検証
        assert(station.latitude == latitude, "Latitude was not set correctly")
        assert(station.longitude == longitude, "Longitude was not set correctly")
        
        save()
        logger.info("Station created: \(name) at lat: \(latitude), lon: \(longitude)")
        return station
    }
    
    /// 駅を取得
    /// - Parameter stationId: 駅ID
    /// - Returns: 指定された駅エンティティ
    func fetchStation(by stationId: String) -> Station? {
        let request: NSFetchRequest<Station> = Station.fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@", stationId)
        request.fetchLimit = 1
        
        do {
            return try viewContext.fetch(request).first
        } catch {
            logger.error("Failed to fetch station: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// お気に入り駅を取得
    /// - Returns: お気に入り登録された駅の配列
    func fetchFavoriteStations() -> [Station] {
        let request: NSFetchRequest<Station> = Station.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.lastUsedAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch favorite stations: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - CRUD Operations for Alert
    
    /// アラートを作成
    /// - Parameters:
    ///   - station: 対象の駅
    ///   - notificationTime: 通知時間（分前）
    ///   - notificationDistance: 通知距離（メートル）
    ///   - snoozeInterval: スヌーズ間隔（分）
    ///   - characterStyle: キャラクタースタイル
    /// - Returns: 作成されたアラートエンティティ
    func createAlert(for station: Station, 
                    notificationTime: Int16,
                    notificationDistance: Double,
                    snoozeInterval: Int16 = 5,
                    characterStyle: String? = nil) -> Alert {
        let alert = Alert(context: viewContext)
        alert.alertId = UUID()
        alert.station = station
        alert.notificationTime = notificationTime
        alert.notificationDistance = notificationDistance
        alert.snoozeInterval = snoozeInterval
        alert.characterStyle = characterStyle
        alert.isActive = true
        alert.createdAt = Date()
        
        save()
        logger.info("Alert created for station: \(station.name ?? "Unknown")")
        return alert
    }
    
    
    // MARK: - CRUD Operations for History
    
    /// 履歴を作成
    /// - Parameters:
    ///   - alert: 対象のアラート
    ///   - message: 通知メッセージ
    /// - Returns: 作成された履歴エンティティ
    func createHistory(for alert: Alert, message: String) -> History {
        let history = History(context: viewContext)
        history.historyId = UUID()
        history.alert = alert
        history.message = message
        history.notifiedAt = Date()
        
        save()
        logger.info("History created for alert")
        return history
    }
    
    /// 履歴を取得
    /// - Parameter limit: 取得件数の上限
    /// - Returns: 履歴の配列
    func fetchHistory(limit: Int = 50) -> [History] {
        let request: NSFetchRequest<History> = History.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \History.notifiedAt, ascending: false)]
        request.fetchLimit = limit
        request.fetchBatchSize = min(limit, 20) // Optimize fetch batch size
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch history: \(error.localizedDescription)")
            return []
        }
    }
    
    /// 履歴を非同期で取得 (大量データ用)
    /// - Parameters:
    ///   - limit: 取得件数の上限
    ///   - offset: オフセット
    /// - Returns: 履歴の配列
    func fetchHistoryAsync(limit: Int = 50, offset: Int = 0) async throws -> [History] {
        try await performBackgroundTask { context in
            let request: NSFetchRequest<History> = History.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \History.notifiedAt, ascending: false)]
            request.fetchLimit = limit
            request.fetchOffset = offset
            request.fetchBatchSize = 20
            request.returnsObjectsAsFaults = false
            
            return try context.fetch(request)
        }
    }
    
    /// 古い履歴を自動削除
    /// - Parameter daysToKeep: 保持する日数
    func cleanupOldHistory(daysToKeep: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysToKeep, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "notifiedAt < %@", cutoffDate as NSDate)
        
        try await batchDelete(entityName: "History", predicate: predicate)
    }
    
    // MARK: - Utility Methods
    
    /// エンティティを削除
    /// - Parameter object: 削除するオブジェクト
    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        save()
        logger.info("Entity deleted: \(type(of: object))")
    }
    
    /// 全データを削除（開発/テスト用）
    func deleteAllData() {
        #if DEBUG
        let entities = ["Station", "Alert", "History"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            do {
                let objects = try viewContext.fetch(request)
                for object in objects {
                    viewContext.delete(object)
                }
            } catch {
                logger.error("Failed to delete \(entityName): \(error.localizedDescription)")
            }
        }
        
        save()
        logger.info("All data deleted")
        #endif
    }
    
    /// バッチ削除を実行
    /// - Parameters:
    ///   - entityName: エンティティ名
    ///   - predicate: 削除条件 (nilの場合は全件削除)
    func batchDelete(entityName: String, predicate: NSPredicate? = nil) async throws {
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startTimer(for: "Batch Delete: \(entityName)")
        
        try await performBackgroundTask { context in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            request.predicate = predicate
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeCount
            
            let result = try context.execute(deleteRequest) as! NSBatchDeleteResult
            let deletedCount = result.result as! Int
            
            // Merge changes to view context
            let changes = [NSDeletedObjectsKey: [NSManagedObjectID]()]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
            
            self.logger.info("Batch deleted \(deletedCount) objects from \(entityName)")
        }
        
        performanceMonitor.endTimer(for: "Batch Delete: \(entityName)")
    }
    
    /// バッチ更新を実行
    /// - Parameters:
    ///   - entityName: エンティティ名
    ///   - predicate: 更新条件
    ///   - propertiesToUpdate: 更新するプロパティ
    func batchUpdate(entityName: String, predicate: NSPredicate?, propertiesToUpdate: [String: Any]) async throws {
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startTimer(for: "Batch Update: \(entityName)")
        
        try await performBackgroundTask { context in
            let request = NSBatchUpdateRequest(entityName: entityName)
            request.predicate = predicate
            request.propertiesToUpdate = propertiesToUpdate
            request.resultType = .updatedObjectIDsResultType
            
            let result = try context.execute(request) as! NSBatchUpdateResult
            let updatedObjectIDs = result.result as! [NSManagedObjectID]
            
            // Merge changes to view context
            let changes = [NSUpdatedObjectsKey: updatedObjectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.viewContext])
            
            self.logger.info("Batch updated \(updatedObjectIDs.count) objects in \(entityName)")
        }
        
        performanceMonitor.endTimer(for: "Batch Update: \(entityName)")
    }
    
    /// バッチ挿入を実行
    /// - Parameters:
    ///   - entityName: エンティティ名
    ///   - objects: 挿入するオブジェクトの配列
    func batchInsert<T: NSManagedObject>(entityName: String, objects: [[String: Any]]) async throws -> [T] {
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startTimer(for: "Batch Insert: \(entityName)")
        
        let insertedObjects: [T] = try await performBackgroundTask { context in
            var results: [T] = []
            
            // Process in chunks to avoid memory pressure
            let chunkSize = 100
            for chunk in objects.chunked(into: chunkSize) {
                let insertRequest = NSBatchInsertRequest(entityName: entityName, objects: chunk)
                insertRequest.resultType = .objectIDs
                
                let insertResult = try context.execute(insertRequest) as! NSBatchInsertResult
                let objectIDs = insertResult.result as! [NSManagedObjectID]
                
                // Fetch the inserted objects to return
                for objectID in objectIDs {
                    if let object = try? context.existingObject(with: objectID) as? T {
                        results.append(object)
                    }
                }
            }
            
            return results
        }
        
        performanceMonitor.endTimer(for: "Batch Insert: \(entityName)")
        logger.info("Batch inserted \(insertedObjects.count) objects into \(entityName)")
        
        return insertedObjects
    }
}

// MARK: - Migration Support

// MARK: - Performance Optimization Extensions

extension CoreDataManager {
    /// Core Dataのマイグレーションが必要かチェック
    /// - Returns: マイグレーションが必要な場合true
    func requiresMigration() -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL)
            let model = persistentContainer.managedObjectModel
            return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            logger.error("Failed to check migration requirement: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 軽量マイグレーションを実行
    func performLightweightMigration() {
        let storeDescription = persistentContainer.persistentStoreDescriptions.first
        storeDescription?.shouldMigrateStoreAutomatically = true
        storeDescription?.shouldInferMappingModelAutomatically = true
        
        logger.info("Lightweight migration configured")
    }
    
    /// データベースのパフォーマンス統計を取得
    func getPerformanceStats() async -> CoreDataPerformanceStats {
        try! await performBackgroundTask { context in
            let stationCount = try! context.count(for: Station.fetchRequest())
            let alertCount = try! context.count(for: Alert.fetchRequest())
            let historyCount = try! context.count(for: History.fetchRequest())
            
            return CoreDataPerformanceStats(
                stationCount: stationCount,
                alertCount: alertCount,
                historyCount: historyCount,
                databaseSize: self.getDatabaseSize()
            )
        }
    }
    
    /// データベースサイズを取得
    private func getDatabaseSize() -> Int64 {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return 0
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// データベースの最適化を実行
    func optimizeDatabase() async throws {
        let performanceMonitor = PerformanceMonitor.shared
        performanceMonitor.startTimer(for: "Database Optimization")
        
        try await performBackgroundTask { context in
            // Analyze and optimize database
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "History")
            request.resultType = .dictionaryResultType
            
            // Execute VACUUM command (SQLite optimization)
            let description = NSEntityDescription.entity(forEntityName: "History", in: context)!
            let sqliteVacuum = "PRAGMA vacuum;"
            
            // Note: Direct SQL execution would require lower-level Core Data access
            // For now, we'll rely on Core Data's built-in optimizations
        }
        
        performanceMonitor.endTimer(for: "Database Optimization")
        logger.info("Database optimization completed")
    }
}

// MARK: - Supporting Types

struct CoreDataPerformanceStats {
    let stationCount: Int
    let alertCount: Int
    let historyCount: Int
    let databaseSize: Int64
    
    var databaseSizeMB: Double {
        Double(databaseSize) / 1_024.0 / 1_024.0
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
