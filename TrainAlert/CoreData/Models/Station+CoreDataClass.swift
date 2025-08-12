import Foundation
import CoreData
import CoreLocation

@objc(Station)
public class Station: NSManagedObject {
    
    // MARK: - Core Data Properties (must be in class body)
    @NSManaged public var stationId: String?
    @NSManaged public var name: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var lines: NSObject?  // Transformable type should be NSObject
    @NSManaged public var isFavorite: Bool
    @NSManaged public var lastUsedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var alerts: NSSet?
    
    // MARK: - Computed Properties
    
    /// Array of line names
    var lineNames: [String] {
        get {
            return lines as? [String] ?? []
        }
        set {
            lines = newValue as NSObject
        }
    }
    
    /// String representation of lines for display
    var linesDisplay: String {
        return lineNames.joined(separator: ", ")
    }
    
    /// CLLocationCoordinate2D representation
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// CLLocation representation
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Core Data Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        createdAt = Date()
        isFavorite = false
        lines = [] as NSObject
    }
    
    // MARK: - Validation
    
    enum ValidationError: LocalizedError {
        case invalidStationId
        case invalidStationName
        case invalidLatitude
        case invalidLongitude
        
        var errorDescription: String? {
            switch self {
            case .invalidStationId:
                return "駅IDが無効です"
            case .invalidStationName:
                return "駅名が無効です"
            case .invalidLatitude:
                return "緯度が無効です（-90〜90の範囲で指定してください）"
            case .invalidLongitude:
                return "経度が無効です（-180〜180の範囲で指定してください）"
            }
        }
    }
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateStation()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateStation()
    }
    
    private func validateStation() throws {
        // 駅IDの検証
        guard let stationId = stationId, !stationId.isEmpty else {
            throw ValidationError.invalidStationId
        }
        
        // 駅名の検証
        guard let name = name, !name.isEmpty else {
            throw ValidationError.invalidStationName
        }
        
        // 座標の検証
        guard latitude >= -90 && latitude <= 90 else {
            throw ValidationError.invalidLatitude
        }
        
        guard longitude >= -180 && longitude <= 180 else {
            throw ValidationError.invalidLongitude
        }
    }
    
    // MARK: - Utility Methods
    
    /// 駅までの距離を計算
    /// - Parameter location: 現在地
    /// - Returns: 距離（メートル）
    func distance(from location: CLLocation) -> CLLocationDistance {
        return self.location.distance(from: location)
    }
    
    /// お気に入りの切り替え
    func toggleFavorite() {
        isFavorite.toggle()
        lastUsedAt = Date()
    }
    
    /// 使用日時を更新
    func updateLastUsed() {
        lastUsedAt = Date()
    }
    
    /// 特定の路線が含まれているかチェック
    /// - Parameter lineName: 路線名
    /// - Returns: 含まれている場合はtrue
    func containsLine(_ lineName: String) -> Bool {
        return lineNames.contains(lineName)
    }
}

// MARK: - Core Data Fetch Requests

extension Station {
    
    /// お気に入り駅のフェッチリクエスト
    @nonobjc public class func favoriteFetchRequest() -> NSFetchRequest<Station> {
        let request = NSFetchRequest<Station>(entityName: "Station")
        request.predicate = NSPredicate(format: "isFavorite == true")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.lastUsedAt, ascending: false)]
        return request
    }
    
    /// 最近使用した駅のフェッチリクエスト
    @nonobjc public class func recentlyUsedFetchRequest(limit: Int = 10) -> NSFetchRequest<Station> {
        let request = NSFetchRequest<Station>(entityName: "Station")
        request.predicate = NSPredicate(format: "lastUsedAt != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.lastUsedAt, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    /// 駅名で検索するフェッチリクエスト
    @nonobjc public class func searchByNameFetchRequest(query: String) -> NSFetchRequest<Station> {
        let request = NSFetchRequest<Station>(entityName: "Station")
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.name, ascending: true)]
        return request
    }
}

// MARK: - Generated accessors for alerts

extension Station {
    
    @objc(addAlertsObject:)
    @NSManaged public func addToAlerts(_ value: Alert)
    
    @objc(removeAlertsObject:)
    @NSManaged public func removeFromAlerts(_ value: Alert)
    
    @objc(addAlerts:)
    @NSManaged public func addToAlerts(_ values: NSSet)
    
    @objc(removeAlerts:)
    @NSManaged public func removeFromAlerts(_ values: NSSet)
}
