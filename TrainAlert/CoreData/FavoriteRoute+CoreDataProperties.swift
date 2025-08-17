//
//  FavoriteRoute+CoreDataProperties.swift
//  TrainAlert
//
//  Created by Claude on 2025/01/17.
//
//

import CoreData
import Foundation

extension FavoriteRoute {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FavoriteRoute> {
        NSFetchRequest<FavoriteRoute>(entityName: "FavoriteRoute")
    }
    
    @NSManaged public var routeId: UUID?
    @NSManaged public var departureStation: String?
    @NSManaged public var arrivalStation: String?
    @NSManaged public var departureTime: Date?
    @NSManaged public var nickName: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastUsedAt: Date?
    @NSManaged public var routeData: Data?  // 経路の詳細情報をJSONで保存
    
    // リレーションシップ
    @NSManaged public var departureStationEntity: Station?
    @NSManaged public var arrivalStationEntity: Station?
}

// MARK: - Identifiable
extension FavoriteRoute: Identifiable {
    public var id: UUID {
        routeId ?? UUID()
    }
}
