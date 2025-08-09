import Foundation
import CoreData

@objc(History)
public class History: NSManagedObject {
    
    // MARK: - Computed Properties
    
    /// 通知日時の表示用文字列
    var notifiedAtDisplayString: String {
        guard let notifiedAt = notifiedAt else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: notifiedAt)
    }
    
    /// 通知日時の相対表示文字列（例: "2時間前"）
    var notifiedAtRelativeString: String {
        guard let notifiedAt = notifiedAt else {
            return "不明"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: notifiedAt, relativeTo: Date())
    }
    
    /// 通知時間の詳細表示文字列
    var notifiedAtDetailString: String {
        guard let notifiedAt = notifiedAt else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日(EEEE) HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: notifiedAt)
    }
    
    /// メッセージのプレビュー（最初の50文字）
    var messagePreview: String {
        guard let message = message else {
            return ""
        }
        
        if message.count <= 50 {
            return message
        }
        
        let endIndex = message.index(message.startIndex, offsetBy: 50)
        return String(message[..<endIndex]) + "..."
    }
    
    /// 関連する駅情報
    var stationName: String? {
        return alert?.station?.name
    }
    
    /// 関連するアラートのキャラクタースタイル
    var characterStyle: String? {
        return alert?.characterStyle
    }
    
    /// 通知が今日のものかどうか
    var isToday: Bool {
        guard let notifiedAt = notifiedAt else {
            return false
        }
        
        return Calendar.current.isDateInToday(notifiedAt)
    }
    
    /// 通知が今週のものかどうか
    var isThisWeek: Bool {
        guard let notifiedAt = notifiedAt else {
            return false
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return false
        }
        
        return weekInterval.contains(notifiedAt)
    }
    
    // MARK: - Core Data Methods
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        
        // デフォルト値の設定
        if historyId == nil {
            historyId = UUID()
        }
        
        if notifiedAt == nil {
            notifiedAt = Date()
        }
    }
    
    // MARK: - Validation
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateHistory()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateHistory()
    }
    
    private func validateHistory() throws {
        // 履歴IDの検証
        guard historyId != nil else {
            throw HistoryValidationError.invalidHistoryId
        }
        
        // メッセージの検証
        guard let message = message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HistoryValidationError.invalidMessage
        }
        
        // メッセージ長の検証（最大1000文字）
        guard message.count <= 1000 else {
            throw HistoryValidationError.messageTooLong
        }
        
        // 通知日時の検証
        guard let notifiedAt = notifiedAt else {
            throw HistoryValidationError.invalidNotifiedAt
        }
        
        // 未来の日時でないことを確認
        guard notifiedAt <= Date() else {
            throw HistoryValidationError.futureNotificationDate
        }
    }
    
    // MARK: - Utility Methods
    
    /// メッセージを更新
    /// - Parameter newMessage: 新しいメッセージ
    func updateMessage(_ newMessage: String) {
        message = newMessage
    }
    
    /// 通知時刻を更新
    /// - Parameter date: 新しい通知時刻
    func updateNotifiedAt(_ date: Date) {
        notifiedAt = date
    }
    
    /// メッセージに含まれるキーワードを検索
    /// - Parameter keyword: 検索キーワード
    /// - Returns: キーワードが含まれている場合true
    func containsKeyword(_ keyword: String) -> Bool {
        guard let message = message else {
            return false
        }
        
        return message.localizedCaseInsensitiveContains(keyword)
    }
    
    /// メッセージの文字数を取得
    var messageCharacterCount: Int {
        return message?.count ?? 0
    }
    
    /// 関連するアラートが有効かどうか
    var isAlertActive: Bool {
        return alert?.isActive ?? false
    }
}

// MARK: - Fetch Requests

extension History {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<History> {
        return NSFetchRequest<History>(entityName: "History")
    }
    
    /// 最近の履歴を取得するFetch Request
    /// - Parameter limit: 取得件数
    /// - Returns: NSFetchRequest
    static func recentHistoryFetchRequest(limit: Int = 50) -> NSFetchRequest<History> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \History.notifiedAt, ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    /// 特定のアラートの履歴を取得するFetch Request
    /// - Parameter alert: アラート
    /// - Returns: NSFetchRequest
    static func historyFetchRequest(for alert: Alert) -> NSFetchRequest<History> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "alert == %@", alert)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \History.notifiedAt, ascending: false)]
        return request
    }
    
    /// 履歴IDで検索するFetch Request
    /// - Parameter historyId: 履歴ID
    /// - Returns: NSFetchRequest
    static func fetchRequest(historyId: UUID) -> NSFetchRequest<History> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "historyId == %@", historyId as CVarArg)
        request.fetchLimit = 1
        return request
    }
    
    /// 日付範囲で履歴を取得するFetch Request
    /// - Parameters:
    ///   - startDate: 開始日
    ///   - endDate: 終了日
    /// - Returns: NSFetchRequest
    static func historyFetchRequest(from startDate: Date, to endDate: Date) -> NSFetchRequest<History> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "notifiedAt >= %@ AND notifiedAt <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \History.notifiedAt, ascending: false)]
        return request
    }
    
    /// 今日の履歴を取得するFetch Request
    /// - Returns: NSFetchRequest
    static func todayHistoryFetchRequest() -> NSFetchRequest<History> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        return historyFetchRequest(from: startOfDay, to: endOfDay)
    }
    
    /// 今週の履歴を取得するFetch Request
    /// - Returns: NSFetchRequest
    static func thisWeekHistoryFetchRequest() -> NSFetchRequest<History> {
        let calendar = Calendar.current
        let now = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return fetchRequest()
        }
        
        return historyFetchRequest(from: weekInterval.start, to: weekInterval.end)
    }
    
    /// キーワードで検索するFetch Request
    /// - Parameter keyword: 検索キーワード
    /// - Returns: NSFetchRequest
    static func searchHistoryFetchRequest(keyword: String) -> NSFetchRequest<History> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "message CONTAINS[cd] %@", keyword)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \History.notifiedAt, ascending: false)]
        return request
    }
}

// MARK: - Core Data Properties

extension History {
    
    @NSManaged public var historyId: UUID?
    @NSManaged public var message: String?
    @NSManaged public var notifiedAt: Date?
    @NSManaged public var alert: Alert?
}

// MARK: - Identifiable

extension History: Identifiable {
    public var id: UUID {
        return historyId ?? UUID()
    }
}

// MARK: - Validation Errors

enum HistoryValidationError: LocalizedError {
    case invalidHistoryId
    case invalidMessage
    case messageTooLong
    case invalidNotifiedAt
    case futureNotificationDate
    
    var errorDescription: String? {
        switch self {
        case .invalidHistoryId:
            return "履歴IDが無効です"
        case .invalidMessage:
            return "メッセージが無効です"
        case .messageTooLong:
            return "メッセージが長すぎます（最大1000文字）"
        case .invalidNotifiedAt:
            return "通知日時が無効です"
        case .futureNotificationDate:
            return "未来の日時は設定できません"
        }
    }
}

// MARK: - Grouping Support

extension History {
    
    /// 履歴を日付でグループ化するためのキー
    var dateGroupKey: String {
        guard let notifiedAt = notifiedAt else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: notifiedAt)
    }
    
    /// 履歴を月でグループ化するためのキー
    var monthGroupKey: String {
        guard let notifiedAt = notifiedAt else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: notifiedAt)
    }
    
    /// 履歴を年でグループ化するためのキー
    var yearGroupKey: String {
        guard let notifiedAt = notifiedAt else {
            return "不明"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: notifiedAt)
    }
}

