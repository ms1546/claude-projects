//
//  NotificationHistoryManager.swift
//  TrainAlert
//
//  通知履歴の記録を一元管理するマネージャー
//

import CoreData
import CoreLocation
import Foundation
import UserNotifications

@MainActor
class NotificationHistoryManager {
    // MARK: - Singleton
    
    static let shared = NotificationHistoryManager()
    
    // MARK: - Properties
    
    private let coreDataManager = CoreDataManager.shared
    
    // リトライ用のキュー
    private var pendingSaves: [(userInfo: [AnyHashable: Any], type: String, message: String?)] = []
    private var retryTimer: Timer?
    private let maxRetryAttempts = 3
    private let retryInterval: TimeInterval = 5.0
    
    // MARK: - Initialization
    
    private init() {
        setupRetryTimer()
    }
    
    // MARK: - Public Methods
    
    /// 通知履歴を保存
    /// - Parameters:
    ///   - userInfo: 通知のuserInfo
    ///   - notificationType: 通知タイプ（trainAlert, locationAlert, snoozeAlert, route）
    ///   - message: 通知メッセージ
    ///   - isUserInteraction: ユーザーインタラクション（タップ）による呼び出しかどうか
    /// - Returns: 保存された履歴、エラーの場合はnil
    @discardableResult
    func saveNotificationHistory(
        userInfo: [AnyHashable: Any],
        notificationType: String,
        message: String? = nil,
        isUserInteraction: Bool = false
    ) -> History? {
        // 駅名を先に取得
        var stationName = userInfo["stationName"] as? String
        if stationName == nil {
            stationName = userInfo["arrivalStation"] as? String
        }
        let finalStationName = stationName ?? "不明な駅"
        
        // 重複チェック: 同じ駅・同じタイプの通知が短時間に複数回保存されるのを防ぐ
        let recentHistories = coreDataManager.fetchHistory(limit: 20)
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        
        for history in recentHistories {
            if let historyDate = history.notifiedAt,
               historyDate > thirtySecondsAgo {
                // 駅名と通知タイプが同じ場合は重複とみなす
                if let historyMessage = history.message,
                   historyMessage.contains(finalStationName) &&
                   historyMessage.contains(getNotificationTypeEmoji(notificationType)) {
                    // 重複通知を検出したためスキップ
                    return nil
                }
            }
        }
        
        // アラートIDを取得
        var alertId: UUID?
        
        // userInfoからアラートIDを取得（複数のキー名に対応）
        if let alertIdString = userInfo["alertId"] as? String {
            alertId = UUID(uuidString: alertIdString)
        } else if let routeAlertIdString = userInfo["routeAlertId"] as? String {
            alertId = UUID(uuidString: routeAlertIdString)
        }
        
        
        // 履歴メッセージを構築
        let historyMessage = buildHistoryMessage(
            stationName: finalStationName,
            notificationType: notificationType,
            customMessage: message,
            userInfo: userInfo
        )
        
        // アラートIDがある場合は既存のアラートに履歴を追加
        if let alertId = alertId {
            return saveHistoryForAlert(
                alertId: alertId,
                message: historyMessage,
                notificationType: notificationType,
                stationName: finalStationName
            )
        } else {
            // アラートIDがない場合は独立した履歴として保存
            return saveStandaloneHistory(
                message: historyMessage,
                notificationType: notificationType,
                stationName: finalStationName
            )
        }
    }
    
    /// RouteAlertの通知履歴を保存
    /// - Parameters:
    ///   - routeAlert: RouteAlertエンティティ
    ///   - message: 通知メッセージ
    /// - Returns: 保存された履歴、エラーの場合はnil
    @discardableResult
    func saveRouteAlertHistory(
        routeAlert: RouteAlert,
        message: String
    ) -> History? {
        let context = coreDataManager.viewContext
        
        // 履歴を作成
        let history = History(context: context)
        history.historyId = UUID()
        history.notifiedAt = Date()
        history.message = message
        
        // 保存
        do {
            try context.save()
            // RouteAlert通知履歴を保存
            return history
        } catch {
            // RouteAlert通知履歴の保存に失敗
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /// 通知タイプに対応する絵文字を取得
    private func getNotificationTypeEmoji(_ type: String) -> String {
        switch type {
        case "trainAlert":
            return "🚃"
        case "locationAlert":
            return "📍"
        case "snoozeAlert":
            return "😴"
        case "route":
            return "🚆"
        case "repeating":
            return "🔄"
        default:
            return "📱"
        }
    }
    
    /// 既存のアラートに履歴を追加
    private func saveHistoryForAlert(
        alertId: UUID,
        message: String,
        notificationType: String,
        stationName: String
    ) -> History? {
        let context = coreDataManager.viewContext
        
        // アラートを検索
        let request = Alert.fetchRequest(alertId: alertId)
        
        do {
            if let alert = try context.fetch(request).first {
                // アラートに履歴を追加
                let history = alert.addHistory(message: message)
                
                // 保存
                try context.save()
                // 通知履歴を保存
                return history
            } else {
                // アラートが見つからない
                // アラートが見つからない場合も独立した履歴として保存
                return saveStandaloneHistory(
                    message: message,
                    notificationType: notificationType,
                    stationName: stationName
                )
            }
        } catch {
            // 通知履歴の保存に失敗
            // リトライキューに追加
            addToPendingSaves(
                alertId: alertId,
                message: message,
                notificationType: notificationType,
                stationName: stationName
            )
            return nil
        }
    }
    
    /// 独立した履歴として保存（アラートに紐付かない）
    private func saveStandaloneHistory(
        message: String,
        notificationType: String,
        stationName: String
    ) -> History? {
        let context = coreDataManager.viewContext
        
        let history = History(context: context)
        history.historyId = UUID()
        history.notifiedAt = Date()
        history.message = message
        
        do {
            try context.save()
            // 独立した通知履歴を保存
            return history
        } catch {
            // 独立した通知履歴の保存に失敗
            return nil
        }
    }
    
    /// 履歴メッセージを構築
    private func buildHistoryMessage(
        stationName: String,
        notificationType: String,
        customMessage: String?,
        userInfo: [AnyHashable: Any]
    ) -> String {
        if let customMessage = customMessage, !customMessage.isEmpty {
            return customMessage
        }
        
        // デフォルトメッセージを生成
        switch notificationType {
        case "trainAlert":
            return "🚃 \(stationName)駅の通知を送信しました"
            
        case "locationAlert":
            if let distance = userInfo["distance"] as? Double {
                return "📍 \(stationName)駅から\(Int(distance))mの地点で通知しました"
            } else {
                return "📍 \(stationName)駅付近で通知しました"
            }
            
        case "snoozeAlert":
            if let snoozeCount = userInfo["snoozeCount"] as? Int {
                return "😴 \(stationName)駅のスヌーズ通知（\(snoozeCount)回目）"
            } else {
                return "😴 \(stationName)駅のスヌーズ通知"
            }
            
        case "route":
            if let departureStation = userInfo["departureStation"] as? String,
               !departureStation.isEmpty {
                return "🚆 \(departureStation) → \(stationName)の経路通知"
            } else {
                return "🚆 \(stationName)駅への経路通知"
            }
            
        case "repeating":
            if let pattern = userInfo["pattern"] as? String {
                return "🔄 \(stationName)駅の繰り返し通知（\(pattern)）"
            } else {
                return "🔄 \(stationName)駅の繰り返し通知"
            }
            
        default:
            return "📱 \(stationName)駅の通知"
        }
    }
    
    /// 古い履歴を削除
    /// - Parameter days: 保持する日数（デフォルト: 30日）
    func cleanupOldHistory(olderThan days: Int = 30) {
        let context = coreDataManager.viewContext
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let request: NSFetchRequest<History> = History.fetchRequest()
        request.predicate = NSPredicate(format: "notifiedAt < %@", cutoffDate as NSDate)
        
        do {
            let oldHistories = try context.fetch(request)
            for history in oldHistories {
                context.delete(history)
            }
            
            if !oldHistories.isEmpty {
                try context.save()
                // 古い履歴を削除
            }
        } catch {
            // 古い履歴の削除に失敗
        }
    }
    
    /// デバッグ用：すべての履歴をログ出力
    func debugPrintAllHistory() {
        // デバッグログは削除済み
    }
    
    // MARK: - Retry Mechanism
    
    /// リトライタイマーのセットアップ
    private func setupRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingSaves()
            }
        }
    }
    
    /// 保存失敗した履歴をリトライキューに追加
    private func addToPendingSaves(
        alertId: UUID? = nil,
        message: String,
        notificationType: String,
        stationName: String,
        attemptCount: Int = 0
    ) {
        // 最大リトライ回数を超えていない場合のみ追加
        guard attemptCount < maxRetryAttempts else {
            // 通知履歴の保存が最大リトライ回数を超えた
            return
        }
        
        var userInfo: [AnyHashable: Any] = [
            "stationName": stationName,
            "attemptCount": attemptCount + 1
        ]
        
        if let alertId = alertId {
            userInfo["alertId"] = alertId.uuidString
        }
        
        pendingSaves.append((userInfo: userInfo, type: notificationType, message: message))
        // 通知履歴をリトライキューに追加
    }
    
    /// 保存待ち履歴を処理
    private func processPendingSaves() {
        guard !pendingSaves.isEmpty else { return }
        
        // 保存待ち履歴を処理中
        
        let currentPendingSaves = pendingSaves
        pendingSaves.removeAll()
        
        for (userInfo, notificationType, message) in currentPendingSaves {
            let attemptCount = userInfo["attemptCount"] as? Int ?? 1
            
            // 再度保存を試みる
            let result = saveNotificationHistory(
                userInfo: userInfo,
                notificationType: notificationType,
                message: message
            )
            
            // 失敗した場合、試行回数をインクリメントして再度キューに追加
            if result == nil {
                if let alertIdString = userInfo["alertId"] as? String,
                   let alertId = UUID(uuidString: alertIdString) {
                    addToPendingSaves(
                        alertId: alertId,
                        message: message ?? "",
                        notificationType: notificationType,
                        stationName: userInfo["stationName"] as? String ?? "不明",
                        attemptCount: attemptCount
                    )
                } else {
                    addToPendingSaves(
                        message: message ?? "",
                        notificationType: notificationType,
                        stationName: userInfo["stationName"] as? String ?? "不明",
                        attemptCount: attemptCount
                    )
                }
            }
        }
    }
    
    /// クリーンアップ
    deinit {
        retryTimer?.invalidate()
        retryTimer = nil
    }
}

