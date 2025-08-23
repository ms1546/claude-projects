//
//  TransferNotificationSettingsViewModel.swift
//  TrainAlert
//
//  乗り換え経路の通知設定ViewModel
//

import CoreData
import CoreLocation
import Foundation
import SwiftUI

@MainActor
class TransferNotificationSettingsViewModel: ObservableObject {
    // MARK: - Properties
    
    private let coreDataManager = CoreDataManager.shared
    private let notificationManager = NotificationManager.shared
    
    // MARK: - Methods
    
    /// 乗り換えアラートを作成
    func createTransferAlert(
        route: TransferRoute,
        notificationTime: Int16,
        characterStyle: CharacterStyle,
        enableTransferNotifications: Bool
    ) async throws {
        _ = try await coreDataManager.performBackgroundTask { context in
            // TransferAlertエンティティを作成
            let alert = TransferAlert(context: context)
            alert.transferAlertId = UUID()
            alert.departureStation = route.departureStation
            alert.arrivalStation = route.arrivalStation
            alert.departureTime = route.departureTime
            alert.arrivalTime = route.arrivalTime
            alert.totalDuration = route.totalDuration
            alert.transferCountValue = Int16(route.transferCount)
            alert.transferRoute = route
            alert.notificationTime = notificationTime
            alert.characterStyle = characterStyle.rawValue
            alert.isActive = true
            alert.createdAt = Date()
            
            try context.save()
            
            // 通知スケジュールは非同期では実行できないため、Taskで実行
            Task { @MainActor in
                await self.scheduleNotifications(
                    for: alert,
                    route: route,
                    characterStyle: characterStyle,
                    enableTransferNotifications: enableTransferNotifications
                )
            }
        }
    }
    
    /// 通知をスケジュール
    private func scheduleNotifications(
        for alert: TransferAlert,
        route: TransferRoute,
        characterStyle: CharacterStyle,
        enableTransferNotifications: Bool
    ) async {
        let notificationPoints = route.notificationPoints
        
        for point in notificationPoints {
            // 乗り換え通知が無効で、乗り換えタイプの通知の場合はスキップ
            if !enableTransferNotifications && point.notificationType == .transfer {
                continue
            }
            
            let identifier = alert.notificationIdentifier(
                for: point.notificationType,
                stationName: point.stationName
            )
            
            // 通知時間を考慮した通知時刻を計算
            let notificationDate: Date
            switch point.notificationType {
            case .arrival:
                // 到着通知は指定された分数前
                notificationDate = point.scheduledTime.addingTimeInterval(
                    -Double(alert.notificationTime) * 60
                )
            case .transfer:
                // 乗り換え通知は到着時
                notificationDate = point.scheduledTime
            case .departure:
                // 出発通知は出発の2分前（固定）
                notificationDate = point.scheduledTime.addingTimeInterval(-2 * 60)
            }
            
            // 過去の時刻の場合はスキップ
            guard notificationDate > Date() else { continue }
            
            // 通知をスケジュール
            do {
                if let station = findStation(named: point.stationName) {
                    let location = CLLocation(
                        latitude: station.latitude,
                        longitude: station.longitude
                    )
                    
                    try await notificationManager.scheduleTrainAlert(
                        for: point.stationName,
                        arrivalTime: point.scheduledTime,
                        currentLocation: nil,
                        targetLocation: location,
                        characterStyle: characterStyle
                    )
                } else {
                    // 駅情報がない場合は時間ベースの通知のみ
                    await scheduleTimeBasedNotification(
                        identifier: identifier,
                        point: point,
                        notificationDate: notificationDate,
                        characterStyle: characterStyle
                    )
                }
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    /// 時間ベースの通知をスケジュール
    private func scheduleTimeBasedNotification(
        identifier: String,
        point: NotificationPoint,
        notificationDate: Date,
        characterStyle: CharacterStyle
    ) async {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = .defaultCritical
        
        // タイトルとボディを設定
        switch point.notificationType {
        case .arrival:
            content.title = "🚃 もうすぐ\(point.stationName)駅です！"
            content.body = point.message
        case .transfer:
            content.title = "🔄 乗り換えです"
            content.body = point.message
        case .departure:
            content.title = "🚅 まもなく発車"
            content.body = point.message
        }
        
        content.userInfo = [
            "stationName": point.stationName,
            "notificationType": String(describing: point.notificationType),
            "transferAlertId": identifier
        ]
        
        // 時間トリガーを作成
        let timeInterval = notificationDate.timeIntervalSinceNow
        guard timeInterval > 0 else { return }
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled notification: \(identifier)")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
    
    /// 駅情報を検索（仮実装）
    private func findStation(named name: String) -> Station? {
        // 実際にはCore Dataから駅情報を検索
        // ここでは仮実装としてnilを返す
        nil
    }
}

