//
//  Alert+CoreDataProperties.swift
//  TrainAlert
//
//  Created by Claude on 2024/08/24.
//
//

import CoreData
import Foundation

extension Alert {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Alert> {
        NSFetchRequest<Alert>(entityName: "Alert")
    }

    @NSManaged public var alertId: UUID?
    @NSManaged public var arrivalTime: Date?
    @NSManaged public var characterStyle: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var departureStation: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var isSnoozeEnabled: Bool
    @NSManaged public var lastNotifiedAt: Date?
    @NSManaged public var lineName: String?
    @NSManaged public var notificationDistance: Double
    @NSManaged public var notificationStationsBefore: Int16
    @NSManaged public var notificationTime: Int16
    @NSManaged public var notificationType: String?
    @NSManaged public var snoozeCount: Int16
    @NSManaged public var snoozeInterval: Int16
    @NSManaged public var snoozeNotificationIds: String?
    @NSManaged public var snoozeStartStations: Int16
    @NSManaged public var stationName: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var histories: NSSet?
    @NSManaged public var station: Station?
}

// MARK: Generated accessors for histories
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
