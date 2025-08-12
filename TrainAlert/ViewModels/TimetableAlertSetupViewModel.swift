//
//  TimetableAlertSetupViewModel.swift
//  TrainAlert
//
//  時刻表ベースの目覚まし設定画面のViewModel
//

import CoreData
import CoreLocation
import Foundation

@MainActor
class TimetableAlertSetupViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private var locationManager: LocationManager?
    private var notificationManager: NotificationManager?
    private var coreDataManager: CoreDataManager?
    
    // MARK: - Setup
    
    func setupWithDependencies(
        locationManager: LocationManager,
        notificationManager: NotificationManager
    ) {
        self.locationManager = locationManager
        self.notificationManager = notificationManager
        self.coreDataManager = CoreDataManager.shared
    }
    
    // MARK: - Public Methods
    
    func createTimetableAlert(
        route: RouteSearchResult,
        notificationMinutes: Int,
        isRepeating: Bool,
        repeatDays: [Int],
        useAIMessage: Bool,
        customMessage: String?
    ) async -> Alert? {
        isSaving = true
        errorMessage = nil
        
        do {
            // 通知権限を確認
            guard let notificationManager = notificationManager else {
                throw AlertCreationError.missingDependency
            }
            
            let hasPermission = try await notificationManager.requestAuthorization()
            guard hasPermission else {
                throw AlertCreationError.notificationPermissionDenied
            }
            
            // Core Dataコンテキストを取得
            guard let context = coreDataManager?.viewContext else {
                throw AlertCreationError.coreDataError
            }
            
            // Alertエンティティを作成
            let alert = Alert(context: context)
            alert.id = UUID()
            alert.createdAt = Date()
            alert.isActive = true
            
            // 基本情報を設定
            alert.stationName = route.arrivalStation.title
            alert.lineName = route.sections.map { $0.railway.title }.joined(separator: "・")
            
            // 位置情報を設定
            if let lat = route.arrivalStation.latitude,
               let lon = route.arrivalStation.longitude {
                alert.latitude = lat
                alert.longitude = lon
                alert.notificationDistance = 2_000 // デフォルト2km
            }
            
            // 通知設定
            alert.notificationTime = Int16(notificationMinutes)
            alert.useAIMessage = useAIMessage
            if !useAIMessage, let message = customMessage, !message.isEmpty {
                alert.customMessage = message
            }
            
            // 時刻表情報を設定
            alert.isTimetableBased = true
            alert.arrivalTime = route.arrivalTime
            alert.departureTime = route.departureTime
            alert.routeDetails = encodeRouteDetails(route)
            
            // 繰り返し設定
            if isRepeating && !repeatDays.isEmpty {
                alert.isRepeating = true
                alert.repeatDays = repeatDays.map { Int16($0) }
                
                // 次の通知時刻を計算
                alert.nextNotificationTime = calculateNextNotificationTime(
                    arrivalTime: route.arrivalTime,
                    notificationMinutes: notificationMinutes,
                    repeatDays: repeatDays
                )
            } else {
                alert.isRepeating = false
                alert.nextNotificationTime = route.arrivalTime.addingTimeInterval(-Double(notificationMinutes * 60))
            }
            
            // 通知をスケジュール
            if alert.isRepeating {
                // 繰り返し通知をスケジュール
                for day in repeatDays {
                    let notificationTime = calculateNotificationTimeForDay(
                        arrivalTime: route.arrivalTime,
                        notificationMinutes: notificationMinutes,
                        targetDay: day
                    )
                    
                    try await notificationManager.scheduleRepeatingNotification(
                        for: alert,
                        at: notificationTime,
                        weekday: day + 1 // 0=日曜 -> 1=日曜に変換
                    )
                }
            } else {
                // 単発通知をスケジュール
                if let notificationTime = alert.nextNotificationTime,
                   notificationTime > Date() {
                    try await notificationManager.scheduleNotification(
                        for: alert,
                        at: notificationTime
                    )
                }
            }
            
            // 保存
            try context.save()
            
            isSaving = false
            return alert
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func encodeRouteDetails(_ route: RouteSearchResult) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let routeData = RouteData(
                departureStationId: route.departureStation.id,
                departureStationName: route.departureStation.title,
                arrivalStationId: route.arrivalStation.id,
                arrivalStationName: route.arrivalStation.title,
                sections: route.sections.map { section in
                    RouteSectionData(
                        railwayId: section.railway.id,
                        railwayName: section.railway.title,
                        lineColor: section.railway.lineColor,
                        departureStationName: section.departureStation.title,
                        arrivalStationName: section.arrivalStation.title,
                        trainType: section.trainType
                    )
                },
                duration: route.duration,
                transferCount: route.transferCount,
                fare: route.fare
            )
            
            let data = try encoder.encode(routeData)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func calculateNextNotificationTime(
        arrivalTime: Date,
        notificationMinutes: Int,
        repeatDays: [Int]
    ) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // 到着時刻から通知時刻を計算
        let notificationTime = arrivalTime.addingTimeInterval(-Double(notificationMinutes * 60))
        
        // 今日の曜日を取得（1=日曜...7=土曜）
        let todayWeekday = calendar.component(.weekday, from: now)
        
        // 次の該当曜日を探す
        for dayOffset in 0..<7 {
            let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now)!
            let targetWeekday = calendar.component(.weekday, from: targetDate)
            
            // 曜日変換（repeatDays: 0=日曜...6=土曜 -> weekday: 1=日曜...7=土曜）
            let targetDayIndex = targetWeekday == 1 ? 0 : targetWeekday - 1
            
            if repeatDays.contains(targetDayIndex) {
                // 該当曜日の通知時刻を計算
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                let timeComponents = calendar.dateComponents([.hour, .minute], from: notificationTime)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                
                if let candidateDate = calendar.date(from: components),
                   candidateDate > now {
                    return candidateDate
                }
            }
        }
        
        return nil
    }
    
    private func calculateNotificationTimeForDay(
        arrivalTime: Date,
        notificationMinutes: Int,
        targetDay: Int
    ) -> Date {
        let calendar = Calendar.current
        let notificationTime = arrivalTime.addingTimeInterval(-Double(notificationMinutes * 60))
        
        var components = calendar.dateComponents([.hour, .minute], from: notificationTime)
        components.weekday = targetDay == 0 ? 1 : targetDay + 1 // 0=日曜 -> 1=日曜に変換
        
        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? notificationTime
    }
}

// MARK: - Supporting Types

private struct RouteData: Codable {
    let departureStationId: String
    let departureStationName: String
    let arrivalStationId: String
    let arrivalStationName: String
    let sections: [RouteSectionData]
    let duration: Int
    let transferCount: Int
    let fare: Int?
}

private struct RouteSectionData: Codable {
    let railwayId: String
    let railwayName: String
    let lineColor: String?
    let departureStationName: String
    let arrivalStationName: String
    let trainType: String
}

// MARK: - Error Types

enum AlertCreationError: LocalizedError {
    case missingDependency
    case notificationPermissionDenied
    case coreDataError
    case invalidRoute
    
    var errorDescription: String? {
        switch self {
        case .missingDependency:
            return "システムエラーが発生しました"
        case .notificationPermissionDenied:
            return "通知の許可が必要です"
        case .coreDataError:
            return "データの保存に失敗しました"
        case .invalidRoute:
            return "無効な経路情報です"
        }
    }
}
