import Foundation
import CoreData
import OSLog

/// Core Dataスタックを管理するマネージャークラス
/// シングルトンパターンで実装し、アプリ全体でCore Dataの操作を統一管理する
final class CoreDataManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CoreDataManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "CoreData")
    
    /// メインのPersistent Container
    /// CloudKitとの同期に対応
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TrainAlert")
        
        // CloudKit設定
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.logger.error("Core Data failed to load: \(error.localizedDescription)")
                fatalError("Core Data failed to load: \(error)")
            }
        }
        
        // 自動マージを有効化
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    /// メインコンテキスト（UIスレッドで使用）
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initializer
    
    private init() {}
    
    // MARK: - Context Operations
    
    /// バックグラウンドコンテキストを作成
    /// - Returns: バックグラウンド処理用のコンテキスト
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
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
            try context.save()
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
        persistentContainer.performBackgroundTask { context in
            block(context)
            self.save(context: context)
        }
    }
    
    // MARK: - CRUD Operations for Station
    
    /// 駅を作成
    /// - Parameters:
    ///   - stationId: 駅ID
    ///   - name: 駅名
    ///   - latitude: 緯度
    ///   - longitude: 経度
    ///   - lines: 路線情報（カンマ区切り）
    /// - Returns: 作成された駅エンティティ
    func createStation(stationId: String, name: String, latitude: Double, longitude: Double, lines: String? = nil) -> Station {
        let station = Station(context: viewContext)
        station.stationId = stationId
        station.name = name
        station.latitude = latitude
        station.longitude = longitude
        station.lines = lines
        station.isFavorite = false
        station.lastUsedAt = Date()
        
        save()
        logger.info("Station created: \(name)")
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
    
    /// アクティブなアラートを取得
    /// - Returns: アクティブなアラートの配列
    func fetchActiveAlerts() -> [Alert] {
        let request: NSFetchRequest<Alert> = Alert.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Alert.createdAt, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch active alerts: \(error.localizedDescription)")
            return []
        }
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
        
        do {
            return try viewContext.fetch(request)
        } catch {
            logger.error("Failed to fetch history: \(error.localizedDescription)")
            return []
        }
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
    /// - Parameter entityName: エンティティ名
    func batchDelete(entityName: String) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try persistentContainer.persistentStoreCoordinator.execute(deleteRequest, with: viewContext)
            logger.info("Batch delete completed for \(entityName)")
        } catch {
            logger.error("Failed to batch delete \(entityName): \(error.localizedDescription)")
        }
    }
}

// MARK: - Migration Support

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
}
