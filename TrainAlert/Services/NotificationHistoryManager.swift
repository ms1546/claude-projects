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
    /// - Returns: 保存された履歴、エラーの場合はnil
    @discardableResult
    func saveNotificationHistory(
        userInfo: [AnyHashable: Any],
        notificationType: String,
        message: String? = nil
    ) -> History? {
        // アラートIDを取得
        var alertId: UUID?
        
        // userInfoからアラートIDを取得（複数のキー名に対応）
        if let alertIdString = userInfo["alertId"] as? String {
            alertId = UUID(uuidString: alertIdString)
        } else if let routeAlertIdString = userInfo["routeAlertId"] as? String {
            alertId = UUID(uuidString: routeAlertIdString)
        }
        
        // 駅名を取得
        let stationName = userInfo["stationName"] as? String ?? "不明な駅"
        
        // 履歴メッセージを構築
        let historyMessage = buildHistoryMessage(
            stationName: stationName,
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
                stationName: stationName
            )
        } else {
            // アラートIDがない場合は独立した履歴として保存
            return saveStandaloneHistory(
                message: historyMessage,
                notificationType: notificationType,
                stationName: stationName
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
            print("✅ RouteAlert通知履歴を保存しました: \(routeAlert.arrivalStation ?? "不明")")
            return history
        } catch {
            print("❌ RouteAlert通知履歴の保存に失敗しました: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
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
                print("✅ 通知履歴を保存しました (Alert: \(alertId.uuidString))")
                return history
            } else {
                print("⚠️ アラートが見つかりません: \(alertId.uuidString)")
                // アラートが見つからない場合も独立した履歴として保存
                return saveStandaloneHistory(
                    message: message,
                    notificationType: notificationType,
                    stationName: stationName
                )
            }
        } catch {
            print("❌ 通知履歴の保存に失敗しました: \(error.localizedDescription)")
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
            print("✅ 独立した通知履歴を保存しました")
            return history
        } catch {
            print("❌ 独立した通知履歴の保存に失敗しました: \(error.localizedDescription)")
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
                print("✅ \(oldHistories.count)件の古い履歴を削除しました")
            }
        } catch {
            print("❌ 古い履歴の削除に失敗しました: \(error.localizedDescription)")
        }
    }
    
    /// デバッグ用：すべての履歴をログ出力
    func debugPrintAllHistory() {
        let histories = coreDataManager.fetchHistory(limit: 100)
        
        print("===== 通知履歴一覧 =====")
        for history in histories {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .medium
            
            let dateString = history.notifiedAt.map { dateFormatter.string(from: $0) } ?? "不明"
            let stationName = history.stationName ?? "不明"
            let message = history.message ?? "メッセージなし"
            
            print("[\(dateString)] \(stationName): \(message)")
        }
        print("======================")
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
            print("⚠️ 通知履歴の保存が最大リトライ回数を超えました: \(stationName)")
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
        print("🔄 通知履歴をリトライキューに追加しました: \(stationName) (試行回数: \(attemptCount + 1))")
    }
    
    /// 保存待ち履歴を処理
    private func processPendingSaves() {
        guard !pendingSaves.isEmpty else { return }
        
        print("🔄 保存待ち履歴を処理中: \(pendingSaves.count)件")
        
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
