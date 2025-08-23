//
//  LocationHistory+CoreDataClass.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/24.
//

import CoreData
import CoreLocation
import Foundation

@objc(LocationHistory)
public class LocationHistory: NSManagedObject {
    // MARK: - Computed Properties
    
    /// CLLocationに変換
    var toCLLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy,
            course: course,
            speed: speed,
            timestamp: timestamp ?? Date()
        )
    }
    
    /// 環境タイプ（文字列からEnumに変換）
    var environmentType: LocationAccuracyManager.EnvironmentType {
        get {
            guard let envString = environment else { return .unknown }
            switch envString {
            case "outdoor": return .outdoor
            case "indoor": return .indoor
            case "underground": return .underground
            case "tunnel": return .tunnel
            default: return .unknown
            }
        }
        set {
            switch newValue {
            case .outdoor: environment = "outdoor"
            case .indoor: environment = "indoor"
            case .underground: environment = "underground"
            case .tunnel: environment = "tunnel"
            case .unknown: environment = "unknown"
            }
        }
    }
    
    /// 通知モード（文字列からEnumに変換）
    var notificationMode: HybridNotificationManager.NotificationMode? {
        get {
            guard let modeString = mode else { return nil }
            return HybridNotificationManager.NotificationMode(rawValue: modeString)
        }
        set {
            mode = newValue?.rawValue
        }
    }
    
    // MARK: - Helper Methods
    
    /// 指定された駅からの距離を計算
    func distance(from station: Station) -> CLLocationDistance {
        let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
        return toCLLocation.distance(from: stationLocation)
    }
    
    /// デバッグ用の説明
    override public var debugDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: timestamp ?? Date())
        
        var desc = "[\(timeString)] "
        desc += "(\(String(format: "%.6f", latitude)), \(String(format: "%.6f", longitude))) "
        desc += "精度: \(Int(accuracy))m "
        
        if speed > 0 {
            desc += "速度: \(String(format: "%.1f", speed * 3.6))km/h "
        }
        
        if let station = station {
            desc += "駅: \(station.name ?? "不明") "
        }
        
        desc += "環境: \(environmentType.displayName) "
        desc += "信頼度: \(Int(confidence * 100))%"
        
        return desc
    }
}

// MARK: - Core Data Extensions

extension LocationHistory {
    /// 新しい位置情報履歴を作成
    static func create(
        in context: NSManagedObjectContext,
        location: CLLocation,
        routeAlert: RouteAlert? = nil,
        station: Station? = nil,
        environment: LocationAccuracyManager.EnvironmentType = .unknown,
        mode: HybridNotificationManager.NotificationMode? = nil,
        confidence: Double = 1.0
    ) -> LocationHistory {
        let history = LocationHistory(context: context)
        history.historyId = UUID()
        history.createdAt = Date()
        history.timestamp = location.timestamp
        history.latitude = location.coordinate.latitude
        history.longitude = location.coordinate.longitude
        history.altitude = location.altitude
        history.accuracy = location.horizontalAccuracy
        history.speed = location.speed
        history.course = location.course
        history.confidence = confidence
        history.environmentType = environment
        history.notificationMode = mode
        history.routeAlert = routeAlert
        history.station = station
        
        return history
    }
    
    /// 指定期間の履歴を取得
    static func fetchHistory(
        from startDate: Date,
        to endDate: Date,
        routeAlert: RouteAlert? = nil,
        in context: NSManagedObjectContext
    ) throws -> [LocationHistory] {
        let request: NSFetchRequest<LocationHistory> = LocationHistory.fetchRequest()
        
        var predicates: [NSPredicate] = []
        predicates.append(NSPredicate(format: "timestamp >= %@ AND timestamp <= %@", startDate as NSDate, endDate as NSDate))
        
        if let routeAlert = routeAlert {
            predicates.append(NSPredicate(format: "routeAlert == %@", routeAlert))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        return try context.fetch(request)
    }
    
    /// 最新の位置情報を取得
    static func fetchLatest(
        for routeAlert: RouteAlert? = nil,
        in context: NSManagedObjectContext
    ) throws -> LocationHistory? {
        let request: NSFetchRequest<LocationHistory> = LocationHistory.fetchRequest()
        
        if let routeAlert = routeAlert {
            request.predicate = NSPredicate(format: "routeAlert == %@", routeAlert)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    /// 古い履歴を削除（デフォルトで7日以上前）
    static func deleteOldHistory(
        olderThan days: Int = 7,
        in context: NSManagedObjectContext
    ) throws {
        let request: NSFetchRequest<NSFetchRequestResult> = LocationHistory.fetchRequest()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        request.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        try context.execute(deleteRequest)
    }
    
    /// 駅付近の履歴を取得
    static func fetchNearStation(
        _ station: Station,
        within distance: CLLocationDistance = 1_000,
        in context: NSManagedObjectContext
    ) throws -> [LocationHistory] {
        let request: NSFetchRequest<LocationHistory> = LocationHistory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        // まず全ての履歴を取得してからフィルタリング（Core Dataでは距離計算の述語が作れないため）
        let allHistory = try context.fetch(request)
        
        return allHistory.filter { history in
            history.distance(from: station) <= distance
        }
    }
}

// MARK: - Analytics Extensions

extension LocationHistory {
    /// 平均速度を計算
    static func calculateAverageSpeed(
        for histories: [LocationHistory]
    ) -> CLLocationSpeed {
        let speeds = histories.compactMap { $0.speed }.filter { $0 > 0 }
        guard !speeds.isEmpty else { return 0 }
        return speeds.reduce(0, +) / Double(speeds.count)
    }
    
    /// 平均精度を計算
    static func calculateAverageAccuracy(
        for histories: [LocationHistory]
    ) -> CLLocationAccuracy {
        let accuracies = histories.map { $0.accuracy }.filter { $0 > 0 }
        guard !accuracies.isEmpty else { return 0 }
        return accuracies.reduce(0, +) / Double(accuracies.count)
    }
    
    /// 移動パターンを分析
    static func analyzeMovementPattern(
        histories: [LocationHistory]
    ) -> (totalDistance: CLLocationDistance, averageSpeed: CLLocationSpeed, stops: Int) {
        guard histories.count >= 2 else {
            return (0, 0, 0)
        }
        
        var totalDistance: CLLocationDistance = 0
        var stops = 0
        let speedThreshold: CLLocationSpeed = 1.0 // 1 m/s以下を停止とみなす
        
        for i in 1..<histories.count {
            let prev = histories[i - 1]
            let curr = histories[i]
            
            let distance = curr.toCLLocation.distance(from: prev.toCLLocation)
            totalDistance += distance
            
            if curr.speed < speedThreshold && prev.speed >= speedThreshold {
                stops += 1
            }
        }
        
        let averageSpeed = calculateAverageSpeed(for: histories)
        
        return (totalDistance, averageSpeed, stops)
    }
}
