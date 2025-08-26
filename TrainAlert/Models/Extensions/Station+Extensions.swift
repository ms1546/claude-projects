//
//  Station+Extensions.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/26.
//

import CoreData
import Foundation

extension Station {
    /// Find or create a station entity
    static func findOrCreate(
        stationId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        lines: [String],
        in context: NSManagedObjectContext
    ) throws -> Station {
        let fetchRequest = Station.fetchRequest(stationId: stationId)
        
        if let existingStation = try context.fetch(fetchRequest).first {
            // Update existing station if needed
            existingStation.lastUsedAt = Date()
            return existingStation
        } else {
            // Create new station
            let newStation = Station(context: context)
            newStation.stationId = stationId
            newStation.name = name
            newStation.latitude = latitude
            newStation.longitude = longitude
            newStation.lines = lines
            newStation.isFavorite = false
            newStation.createdAt = Date()
            newStation.lastUsedAt = Date()
            return newStation
        }
    }
}
