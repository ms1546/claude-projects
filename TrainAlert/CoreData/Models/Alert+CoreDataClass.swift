import Foundation
import CoreData

@objc(Alert)
public class Alert: NSManagedObject {
    // Core Data Properties (must be in class body, not extension)
    @NSManaged public var alertId: UUID?
    @NSManaged public var notificationTime: Int16
    @NSManaged public var notificationDistance: Double
    @NSManaged public var snoozeInterval: Int16
    @NSManaged public var characterStyle: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var lastNotifiedAt: Date?
    @NSManaged public var snoozeCount: Int16
    @NSManaged public var station: Station?
    @NSManaged public var histories: NSSet?
    
    // MARK: - Core Data Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // Set default values using setPrimitiveValue to avoid KVO issues
        let uuid = UUID()
        self.setPrimitiveValue(uuid, forKey: "alertId")
        self.setPrimitiveValue(Date(), forKey: "createdAt")
        self.setPrimitiveValue(true, forKey: "isActive")
        self.setPrimitiveValue(Int16(0), forKey: "snoozeCount")
        self.setPrimitiveValue(Int16(5), forKey: "notificationTime")  // 5分前
        self.setPrimitiveValue(500.0, forKey: "notificationDistance")  // 500m
        self.setPrimitiveValue(Int16(5), forKey: "snoozeInterval")  // 5分
    }
    
    // MARK: - Enums
    
    /// キャラクタースタイルの定義
    enum CharacterStyle: String, CaseIterable {
        case friendly = "friendly"
        case serious = "serious"
        case funny = "funny"
        case motivational = "motivational"
        case polite = "polite"
        
        var displayName: String {
            switch self {
            case .friendly:
                return "親しみやすい"
            case .serious:
                return "真面目"
            case .funny:
                return "ユーモア"
            case .motivational:
                return "やる気を出す"
            case .polite:
                return "丁寧"
            }
        }
        
        var description: String {
            switch self {
            case .friendly:
                return "優しく親しみやすい口調で通知します"
            case .serious:
                return "落ち着いた真面目な口調で通知します"
            case .funny:
                return "楽しいユーモアのある口調で通知します"
            case .motivational:
                return "元気の出る応援的な口調で通知します"
            case .polite:
                return "敬語を使った丁寧な口調で通知します"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// キャラクタースタイルのEnum値
    var characterStyleEnum: CharacterStyle {
        get {
            guard let styleString = characterStyle else {
                return .friendly
            }
            return CharacterStyle(rawValue: styleString) ?? .friendly
        }
        set {
            characterStyle = newValue.rawValue
        }
    }
    
    /// 通知時間の表示用文字列
    var notificationTimeDisplayString: String {
        if notificationTime == 0 {
            return "到着時"
        } else {
            return "\(notificationTime)分前"
        }
    }
    
    /// 通知距離の表示用文字列
    var notificationDistanceDisplayString: String {
        if notificationDistance < 1000 {
            return String(format: "%.0fm", notificationDistance)
        } else {
            return String(format: "%.1fkm", notificationDistance / 1000)
        }
    }
    
    /// スヌーズ間隔の表示用文字列
    var snoozeIntervalDisplayString: String {
        return "\(snoozeInterval)分"
    }
    
    /// アラートの状態表示用文字列
    var statusDisplayString: String {
        return isActive ? "有効" : "無効"
    }
    
    /// 作成日時の表示用文字列
    var createdAtDisplayString: String {
        guard let createdAt = createdAt else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: createdAt)
    }
    
    /// 履歴の件数
    var historyCount: Int {
        return (histories as? Set<History>)?.count ?? 0
    }
    
    /// 最新の履歴
    var latestHistory: History? {
        guard let histories = histories as? Set<History> else {
            return nil
        }
        return histories.max(by: { ($0.notifiedAt ?? Date.distantPast) < ($1.notifiedAt ?? Date.distantPast) })
    }
    
    // MARK: - Core Data Methods
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateAlert()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateAlert()
    }
    
    private func validateAlert() throws {
        // アラートIDの検証
        guard alertId != nil else {
            throw AlertValidationError.invalidAlertId
        }
        
        // 通知時間の検証（0-60分）
        guard notificationTime >= 0 && notificationTime <= 60 else {
            throw AlertValidationError.invalidNotificationTime
        }
        
        // 通知距離の検証（50m-10km）
        guard notificationDistance >= 50 && notificationDistance <= 10000 else {
            throw AlertValidationError.invalidNotificationDistance
        }
        
        // スヌーズ間隔の検証（1-30分）
        guard snoozeInterval >= 1 && snoozeInterval <= 30 else {
            throw AlertValidationError.invalidSnoozeInterval
        }
        
        // キャラクタースタイルの検証
        if let characterStyle = characterStyle {
            guard CharacterStyle(rawValue: characterStyle) != nil else {
                throw AlertValidationError.invalidCharacterStyle
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// アラートの有効/無効を切り替え
    func toggleActive() {
        isActive.toggle()
    }
    
    /// アラートを有効にする
    func activate() {
        isActive = true
    }
    
    /// アラートを無効にする
    func deactivate() {
        isActive = false
    }
    
    /// 通知設定を更新
    /// - Parameters:
    ///   - time: 通知時間（分前）
    ///   - distance: 通知距離（メートル）
    ///   - snooze: スヌーズ間隔（分）
    ///   - style: キャラクタースタイル
    func updateNotificationSettings(time: Int16? = nil,
                                   distance: Double? = nil,
                                   snooze: Int16? = nil,
                                   style: CharacterStyle? = nil) {
        if let time = time {
            notificationTime = time
        }
        
        if let distance = distance {
            notificationDistance = distance
        }
        
        if let snooze = snooze {
            snoozeInterval = snooze
        }
        
        if let style = style {
            characterStyleEnum = style
        }
    }
    
    /// 履歴を追加
    /// - Parameter message: 通知メッセージ
    /// - Returns: 作成された履歴
    func addHistory(message: String) -> History {
        let context = managedObjectContext!
        let history = History(context: context)
        history.historyId = UUID()
        history.alert = self
        history.message = message
        history.notifiedAt = Date()
        
        addToHistories(history)
        return history
    }
    
    /// 指定された日数より古い履歴を削除
    /// - Parameter days: 保持する日数
    func cleanupOldHistory(olderThan days: Int) {
        guard let histories = histories as? Set<History> else { return }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let oldHistories = histories.filter { history in
            guard let notifiedAt = history.notifiedAt else { return false }
            return notifiedAt < cutoffDate
        }
        
        for history in oldHistories {
            removeFromHistories(history)
            managedObjectContext?.delete(history)
        }
    }
}

// MARK: - Fetch Requests

extension Alert {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Alert> {
        return NSFetchRequest<Alert>(entityName: "Alert")
    }
    
    /// アクティブなアラートを取得するFetch Request
    /// - Returns: NSFetchRequest
    static func activeAlertsFetchRequest() -> NSFetchRequest<Alert> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Alert.createdAt, ascending: false)]
        return request
    }
    
    /// 特定の駅のアラートを取得するFetch Request
    /// - Parameter station: 駅
    /// - Returns: NSFetchRequest
    static func alertsFetchRequest(for station: Station) -> NSFetchRequest<Alert> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "station == %@", station)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Alert.createdAt, ascending: false)]
        return request
    }
    
    /// アラートIDで検索するFetch Request
    /// - Parameter alertId: アラートID
    /// - Returns: NSFetchRequest
    static func fetchRequest(alertId: UUID) -> NSFetchRequest<Alert> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "alertId == %@", alertId as CVarArg)
        request.fetchLimit = 1
        return request
    }
    
    /// 最近作成されたアラートを取得するFetch Request
    /// - Parameter limit: 取得件数
    /// - Returns: NSFetchRequest
    static func recentAlertsFetchRequest(limit: Int = 10) -> NSFetchRequest<Alert> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Alert.createdAt, ascending: false)]
        request.fetchLimit = limit
        return request
    }
}

// MARK: - Core Data Properties

extension Alert {
    // Properties are already defined in the class body
}

// MARK: - Generated accessors for histories

extension Alert {
    
    @objc(addHistoriesObject:)
    @NSManaged public func addToHistories(_ value: History)
    
    @objc(removeHistoriesObject:)
    @NSManaged public func removeFromHistories(_ value: History)
    
    @objc(addHistories:)
    @NSManaged public func addToHistories(_ values: NSSet)
    
    @objc(removeHistories:)
    @NSManaged public func removeFromHistories(_ values: NSSet)
}

// MARK: - Identifiable

extension Alert: Identifiable {
    public var id: UUID {
        return alertId ?? UUID()
    }
}

// MARK: - Validation Errors

enum AlertValidationError: LocalizedError {
    case invalidAlertId
    case invalidNotificationTime
    case invalidNotificationDistance
    case invalidSnoozeInterval
    case invalidCharacterStyle
    
    var errorDescription: String? {
        switch self {
        case .invalidAlertId:
            return "アラートIDが無効です"
        case .invalidNotificationTime:
            return "通知時間が無効です（0〜60分の範囲で入力してください）"
        case .invalidNotificationDistance:
            return "通知距離が無効です（50m〜10kmの範囲で入力してください）"
        case .invalidSnoozeInterval:
            return "スヌーズ間隔が無効です（1〜30分の範囲で入力してください）"
        case .invalidCharacterStyle:
            return "キャラクタースタイルが無効です"
        }
    }
}
