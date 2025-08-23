//
//  TransferAlert+CoreDataClass.swift
//  TrainAlert
//
//  乗り換え対応のCore Dataエンティティ
//

import CoreData
import Foundation

@objc(TransferAlert)
public class TransferAlert: NSManagedObject {
    // MARK: - Computed Properties
    
    /// TransferRouteオブジェクトとして取得
    var transferRoute: TransferRoute? {
        get {
            guard let data = transferRouteData else { return nil }
            return try? JSONDecoder().decode(TransferRoute.self, from: data)
        }
        set {
            transferRouteData = try? JSONEncoder().encode(newValue)
        }
    }
    
    /// 乗り換え回数
    var transferCount: Int {
        Int(transferCountValue)
    }
    
    /// 出発駅名
    var departureStationName: String {
        transferRoute?.departureStation ?? departureStation ?? "未設定"
    }
    
    /// 到着駅名
    var arrivalStationName: String {
        transferRoute?.arrivalStation ?? arrivalStation ?? "未設定"
    }
    
    /// 総所要時間の表示文字列
    var totalDurationString: String {
        let hours = Int(totalDuration) / 3_600
        let minutes = (Int(totalDuration) % 3_600) / 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    // MARK: - Core Data Methods
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        
        // デフォルト値の設定
        if transferAlertId == nil {
            transferAlertId = UUID()
        }
        
        if createdAt == nil {
            createdAt = Date()
        }
        
        isActive = true
        notificationTime = 5 // 5分前
    }
    
    // MARK: - Validation
    
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateTransferAlert()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateTransferAlert()
    }
    
    private func validateTransferAlert() throws {
        // TransferAlertIDの検証
        guard transferAlertId != nil else {
            throw TransferAlertValidationError.invalidTransferAlertId
        }
        
        // 乗り換え回数の検証（1〜5回）
        guard transferCountValue >= 1 && transferCountValue <= 5 else {
            throw TransferAlertValidationError.invalidTransferCount
        }
        
        // 通知時間の検証（0〜60分）
        guard notificationTime >= 0 && notificationTime <= 60 else {
            throw TransferAlertValidationError.invalidNotificationTime
        }
        
        // 経路データの検証
        guard transferRouteData != nil else {
            throw TransferAlertValidationError.invalidTransferRoute
        }
    }
    
    // MARK: - Utility Methods
    
    /// アラートの有効/無効を切り替え
    func toggleActive() {
        isActive.toggle()
    }
    
    /// 通知設定を更新
    func updateNotificationSettings(time: Int16) {
        notificationTime = time
    }
    
    /// 各区間および乗り換え駅の通知IDを生成
    func generateNotificationIdentifiers() -> [String] {
        guard let route = transferRoute else { return [] }
        var identifiers: [String] = []
        
        // 各区間の到着通知ID
        for (index, section) in route.sections.enumerated() {
            // 最終区間の到着通知
            if index == route.sections.count - 1 {
                identifiers.append("transfer_alert_arrival_\(transferAlertId?.uuidString ?? "")_\(section.arrivalStation)")
            }
            
            // 乗り換え駅の通知
            if let transfer = route.transferStations.first(where: { $0.stationName == section.arrivalStation }) {
                identifiers.append("transfer_alert_transfer_\(transferAlertId?.uuidString ?? "")_\(transfer.stationName)")
            }
        }
        
        return identifiers
    }
    
    /// アラートタイプに応じた通知識別子を取得
    func notificationIdentifier(for type: NotificationPoint.NotificationType, stationName: String) -> String {
        let baseId = transferAlertId?.uuidString ?? UUID().uuidString
        switch type {
        case .arrival:
            return "transfer_alert_arrival_\(baseId)_\(stationName)"
        case .transfer:
            return "transfer_alert_transfer_\(baseId)_\(stationName)"
        case .departure:
            return "transfer_alert_departure_\(baseId)_\(stationName)"
        }
    }
}

// MARK: - Fetch Requests

extension TransferAlert {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransferAlert> {
        NSFetchRequest<TransferAlert>(entityName: "TransferAlert")
    }
    
    /// アクティブな乗り換えアラートを取得
    static func activeTransferAlertsFetchRequest() -> NSFetchRequest<TransferAlert> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransferAlert.createdAt, ascending: false)]
        return request
    }
    
    /// 特定の駅を含む乗り換えアラートを取得
    static func transferAlertsFetchRequest(containingStation stationName: String) -> NSFetchRequest<TransferAlert> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "departureStation CONTAINS[cd] %@ OR arrivalStation CONTAINS[cd] %@",
            stationName, stationName
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TransferAlert.createdAt, ascending: false)]
        return request
    }
}

// MARK: - Core Data Properties

extension TransferAlert {
    @NSManaged public var transferAlertId: UUID?
    @NSManaged public var departureStation: String?
    @NSManaged public var arrivalStation: String?
    @NSManaged public var departureTime: Date?
    @NSManaged public var arrivalTime: Date?
    @NSManaged public var totalDuration: Double
    @NSManaged public var transferCountValue: Int16
    @NSManaged public var transferRouteData: Data?
    @NSManaged public var notificationTime: Int16
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var characterStyle: String?
}

// MARK: - Identifiable

extension TransferAlert: Identifiable {
    public var id: UUID {
        transferAlertId ?? UUID()
    }
}

// MARK: - Validation Errors

enum TransferAlertValidationError: LocalizedError {
    case invalidTransferAlertId
    case invalidTransferCount
    case invalidNotificationTime
    case invalidTransferRoute
    
    var errorDescription: String? {
        switch self {
        case .invalidTransferAlertId:
            return "乗り換えアラートIDが無効です"
        case .invalidTransferCount:
            return "乗り換え回数が無効です（1〜5回の範囲で入力してください）"
        case .invalidNotificationTime:
            return "通知時間が無効です（0〜60分の範囲で入力してください）"
        case .invalidTransferRoute:
            return "乗り換え経路データが無効です"
        }
    }
}

