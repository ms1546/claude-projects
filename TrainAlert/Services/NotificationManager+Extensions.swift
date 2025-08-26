//
//  NotificationManager+Extensions.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/26.
//

import CoreLocation
import Foundation

extension NotificationManager {
    /// Request authorization and return if granted
    func requestAuthorizationWithResult() async throws -> Bool {
        try await requestAuthorization()
        return isPermissionGranted
    }
    
    /// Schedule notifications for an alert
    func scheduleNotifications(for alert: Alert) async throws {
        guard let stationName = alert.stationName ?? alert.station?.name else {
            throw NotificationError.invalidConfiguration
        }
        
        if let arrivalTime = alert.arrivalTime,
           let station = alert.station {
            let targetLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            
            try await scheduleTrainAlert(
                for: stationName,
                arrivalTime: arrivalTime,
                currentLocation: nil,
                targetLocation: targetLocation,
                characterStyle: CharacterStyle(rawValue: alert.characterStyle ?? "") ?? .gyaru
            )
        }
    }
}
