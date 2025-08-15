//
//  RouteAlert+CoreDataClass.swift
//  TrainAlert
//
//  時刻表連携アラートのCore Dataエンティティ
//

import CoreData
import Foundation

@objc(RouteAlert)
public class RouteAlert: NSManagedObject {
    // MARK: - Core Data Properties
    
    @NSManaged public var routeId: UUID?
    @NSManaged public var departureStation: String?
    @NSManaged public var arrivalStation: String?
    @NSManaged public var departureTime: Date?
    @NSManaged public var arrivalTime: Date?
    @NSManaged public var trainNumber: String?
    @NSManaged public var trainType: String?
    @NSManaged public var railway: String?
    @NSManaged public var routeData: Data?
    @NSManaged public var notificationMinutes: Int16
    @NSManaged public var isActive: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    
    // MARK: - Computed Properties
    
    /// 経路詳細情報
    var routeDetails: RouteSearchResult? {
        get {
            guard let data = routeData else { return nil }
            return try? JSONDecoder().decode(RouteSearchResult.self, from: data)
        }
        set {
            guard let value = newValue else {
                routeData = nil
                return
            }
            routeData = try? JSONEncoder().encode(value)
        }
    }
    
    /// 出発時刻の文字列表現
    var departureTimeString: String {
        guard let time = departureTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: time)
    }
    
    /// 到着時刻の文字列表現
    var arrivalTimeString: String {
        guard let time = arrivalTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: time)
    }
    
    /// 通知予定時刻
    var notificationTime: Date? {
        guard let arrival = arrivalTime else { return nil }
        return arrival.addingTimeInterval(TimeInterval(-notificationMinutes * 60))
    }
    
    // MARK: - Lifecycle
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        routeId = UUID()
        createdAt = Date()
        updatedAt = Date()
        isActive = true
        notificationMinutes = 5
    }
    
    override public func willSave() {
        super.willSave()
        if hasChanges {
            updatedAt = Date()
        }
    }
}

// MARK: - Core Data Fetch Request

extension RouteAlert {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RouteAlert> {
        NSFetchRequest<RouteAlert>(entityName: "RouteAlert")
    }
    
    /// アクティブな経路アラートを取得
    static func fetchActiveRouteAlerts(context: NSManagedObjectContext) throws -> [RouteAlert] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "departureTime", ascending: true)]
        return try context.fetch(request)
    }
    
    /// 特定の駅間の経路アラートを取得
    static func fetchRouteAlerts(
        from departureStation: String,
        to arrivalStation: String,
        context: NSManagedObjectContext
    ) throws -> [RouteAlert] {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "departureStation == %@ AND arrivalStation == %@",
            departureStation,
            arrivalStation
        )
        request.sortDescriptors = [NSSortDescriptor(key: "departureTime", ascending: true)]
        return try context.fetch(request)
    }
}

// MARK: - Helper Methods

extension RouteAlert {
    /// 経路アラートを作成
    static func create(
        from routeResult: RouteSearchResult,
        notificationMinutes: Int16,
        in context: NSManagedObjectContext
    ) -> RouteAlert {
        let routeAlert = RouteAlert(context: context)
        routeAlert.departureStation = routeResult.departureStation
        routeAlert.arrivalStation = routeResult.arrivalStation
        routeAlert.departureTime = routeResult.departureTime
        routeAlert.arrivalTime = routeResult.arrivalTime
        routeAlert.trainNumber = routeResult.trainNumber
        routeAlert.trainType = routeResult.trainType
        routeAlert.notificationMinutes = notificationMinutes
        routeAlert.routeDetails = routeResult
        
        return routeAlert
    }
    
    /// 通知をスケジュール
    func scheduleNotification() {
        guard let notificationTime = notificationTime,
              notificationTime > Date() else { return }
        
        // NotificationManagerを使用して通知をスケジュール
        Task {
            await NotificationManager.shared.scheduleRouteNotification(
                routeAlert: self,
                at: notificationTime
            )
        }
    }
}
