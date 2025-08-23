//
//  AlertDeletionManager.swift
//  TrainAlert
//
//  Created by Claude Code on 2025/08/24.
//

import CoreData
import Foundation
import OSLog

/// アラート削除処理を一元管理するマネージャー
@MainActor
final class AlertDeletionManager {
    static let shared = AlertDeletionManager()
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert",
        category: "AlertDeletionManager"
    )
    private let notificationManager = NotificationManager.shared
    private let coreDataManager = CoreDataManager.shared
    
    private init() {}
    
    /// アラートを削除する（通知のキャンセルを含む完全な削除）
    /// - Parameter alert: 削除するアラート
    /// - Throws: 削除処理中のエラー
    func deleteAlert(_ alert: Alert) async throws {
        logger.info("Starting alert deletion for alertId: \(alert.alertId?.uuidString ?? "unknown")")
        
        // 1. まず通知をキャンセル
        await cancelAllNotifications(for: alert)
        
        // 2. バックグラウンドタスクのキャンセル
        cancelBackgroundTasks(for: alert)
        
        // 3. ハイブリッド通知の停止
        stopHybridNotificationMonitoring(for: alert)
        
        // 4. Core Dataから削除
        try await deleteFromCoreData(alert)
        
        // 5. 削除が完了したことを検証
        await verifyDeletion(alertId: alert.alertId)
        
        logger.info("Alert deletion completed successfully for alertId: \(alert.alertId?.uuidString ?? "unknown")")
    }
    
    /// アラートに関連するすべての通知をキャンセル
    private func cancelAllNotifications(for alert: Alert) async {
        guard let alertId = alert.alertId else {
            logger.warning("Alert has no alertId, cannot cancel notifications")
            return
        }
        
        let alertIdString = alertId.uuidString
        
        // 基本の通知をキャンセル
        notificationManager.cancelNotification(identifier: alertIdString)
        logger.debug("Cancelled base notification for alertId: \(alertIdString)")
        
        // 繰り返し通知をキャンセル
        if alert.isRepeatingEnabled {
            notificationManager.cancelRepeatingNotifications(alertId: alertIdString)
            logger.debug("Cancelled repeating notifications for alertId: \(alertIdString)")
        }
        
        // 位置情報ベースの通知をキャンセル
        let locationIdentifier = "location_\(alertIdString)"
        notificationManager.cancelNotification(identifier: locationIdentifier)
        logger.debug("Cancelled location-based notification for alertId: \(alertIdString)")
        
        // ハイブリッド通知をキャンセル
        let hybridIdentifier = "hybrid_\(alertIdString)"
        notificationManager.cancelNotification(identifier: hybridIdentifier)
        logger.debug("Cancelled hybrid notification for alertId: \(alertIdString)")
        
        // スヌーズ通知をキャンセル（将来の実装用）
        for i in 1...10 {
            let snoozeIdentifier = "snooze_\(alertIdString)_\(i)"
            notificationManager.cancelNotification(identifier: snoozeIdentifier)
        }
        
        // 保留中の通知を確認してログ出力
        await logPendingNotifications(for: alertIdString)
    }
    
    /// バックグラウンドタスクをキャンセル
    private func cancelBackgroundTasks(for alert: Alert) {
        // AlertMonitoringServiceから該当するアラートを削除
        AlertMonitoringService.shared.removeAlert(with: alert.alertId)
        logger.debug("Removed alert from monitoring service")
    }
    
    /// ハイブリッド通知の監視を停止
    private func stopHybridNotificationMonitoring(for alert: Alert) {
        if HybridNotificationManager.shared.isEnabled {
            HybridNotificationManager.shared.stopMonitoring()
            logger.debug("Stopped hybrid notification monitoring")
        }
    }
    
    /// Core Dataからアラートを削除
    private func deleteFromCoreData(_ alert: Alert) async throws {
        try await coreDataManager.performBackgroundTask { context in
            guard let backgroundAlert = try context.existingObject(with: alert.objectID) as? Alert else {
                throw NSError(domain: "AlertDeletionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Alert not found"])
            }
            context.delete(backgroundAlert)
            try context.save()
        }
        logger.debug("Deleted alert from Core Data")
    }
    
    /// 削除が完了したことを検証
    private func verifyDeletion(alertId: UUID?) async {
        guard let alertId = alertId else { return }
        
        // 保留中の通知を確認
        let pendingRequests = await notificationManager.center.pendingNotificationRequests()
        let alertIdString = alertId.uuidString
        
        let remainingNotifications = pendingRequests.filter { request in
            request.identifier.contains(alertIdString)
        }
        
        if !remainingNotifications.isEmpty {
            logger.error("Found \(remainingNotifications.count) remaining notifications after deletion")
            // 再度キャンセルを試みる
            for notification in remainingNotifications {
                notificationManager.cancelNotification(identifier: notification.identifier)
                logger.debug("Force cancelled notification: \(notification.identifier)")
            }
        } else {
            logger.info("Deletion verified: No remaining notifications found")
        }
    }
    
    /// 保留中の通知をログに出力（デバッグ用）
    private func logPendingNotifications(for alertId: String) async {
        let pendingRequests = await notificationManager.center.pendingNotificationRequests()
        let relatedNotifications = pendingRequests.filter { $0.identifier.contains(alertId) }
        
        logger.debug("Pending notifications for alertId \(alertId): \(relatedNotifications.count)")
        for notification in relatedNotifications {
            logger.debug("  - Notification ID: \(notification.identifier)")
        }
    }
}
