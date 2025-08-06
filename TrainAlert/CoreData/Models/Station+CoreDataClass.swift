import Foundation
import CoreData
import CoreLocation

@objc(Station)
public class Station: NSManagedObject {
    
    // MARK: - Computed Properties
    
    /// 駅の座標を返す
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 駅の位置情報を返す
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// 路線の配列を返す（カンマ区切り文字列から変換）
    var lineArray: [String] {
        guard let lines = lines else { return [] }
        return lines.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    /// アクティブなアラートの数
    var activeAlertCount: Int {
        return (alerts as? Set<Alert>)?.filter { $0.isActive }.count ?? 0
    }
    
    /// 最後に使用された日時の表示用文字列
    var lastUsedDisplayString: String {
        guard let lastUsedAt = lastUsedAt else {
            return "未使用"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastUsedAt, relativeTo: Date())
    }
    
    // MARK: - Core Data Methods
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // デフォルト値の設定
        if stationId == nil {
            stationId = UUID().uuidString
        }
        
        isFavorite = false
        lastUsedAt = Date()
    }
    
    // MARK: - Validation
    
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
    
    /// 最終使用日時を更新
    func updateLastUsedAt() {
        lastUsedAt = Date()
    }
    
    /// 路線情報を設定（配列から）
    /// - Parameter lineArray: 路線の配列
    func setLines(_ lineArray: [String]) {
        lines = lineArray.joined(separator: ", ")
    }
    
    /// 指定された路線が含まれているかチェック
    /// - Parameter lineName: 路線名
    /// - Returns: 含まれている場合true
    func containsLine(_ lineName: String) -> Bool {
        return lineArray.contains(lineName)
    }
}

// MARK: - Fetch Requests

extension Station {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Station> {
        return NSFetchRequest<Station>(entityName: "Station")
    }
    
    /// 駅IDで検索するFetch Request
    /// - Parameter stationId: 駅ID
    /// - Returns: NSFetchRequest
    static func fetchRequest(stationId: String) -> NSFetchRequest<Station> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "stationId == %@", stationId)
        request.fetchLimit = 1
        return request
    }
    
    /// お気に入り駅を取得するFetch Request
    /// - Returns: NSFetchRequest
    static func favoriteStationsFetchRequest() -> NSFetchRequest<Station> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.lastUsedAt, ascending: false)]
        return request
    }
    
    /// 駅名で検索するFetch Request
    /// - Parameter name: 駅名（部分一致）
    /// - Returns: NSFetchRequest
    static func searchStationsFetchRequest(name: String) -> NSFetchRequest<Station> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", name)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.name, ascending: true)]
        return request
    }
    
    /// 最近使用した駅を取得するFetch Request
    /// - Parameter limit: 取得件数
    /// - Returns: NSFetchRequest
    static func recentStationsFetchRequest(limit: Int = 10) -> NSFetchRequest<Station> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "lastUsedAt != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Station.lastUsedAt, ascending: false)]
        request.fetchLimit = limit
        return request
    }
}

// MARK: - Core Data Properties

extension Station {
    
    @NSManaged public var stationId: String?
    @NSManaged public var name: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var lines: String?
    @NSManaged public var isFavorite: Bool
    @NSManaged public var lastUsedAt: Date?
    @NSManaged public var alerts: NSSet?
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

// MARK: - Identifiable

extension Station: Identifiable {
    public var id: String {
        return stationId ?? UUID().uuidString
    }
}

// MARK: - Validation Errors

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
            return "緯度が無効です（-90〜90の範囲で入力してください）"
        case .invalidLongitude:
            return "経度が無効です（-180〜180の範囲で入力してください）"
        }
    }
}