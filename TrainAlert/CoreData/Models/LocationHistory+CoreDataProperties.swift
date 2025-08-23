//
//  LocationHistory+CoreDataProperties.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/24.
//

import CoreData
import Foundation

extension LocationHistory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LocationHistory> {
        NSFetchRequest<LocationHistory>(entityName: "LocationHistory")
    }
    
    @NSManaged public var accuracy: Double
    @NSManaged public var altitude: Double
    @NSManaged public var confidence: Double
    @NSManaged public var course: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var environment: String?
    @NSManaged public var historyId: UUID?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var mode: String?
    @NSManaged public var speed: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var routeAlert: RouteAlert?
    @NSManaged public var station: Station?
}
