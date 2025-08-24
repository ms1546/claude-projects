//
//  SnoozeNotificationManager.swift
//  TrainAlert
//
//  スヌーズ機能の通知管理を行うマネージャー
//

import CoreData
import CoreLocation
import Foundation
import UserNotifications

/// スヌーズ通知管理クラス
class SnoozeNotificationManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = SnoozeNotificationManager()
    
    // MARK: - Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let stationCountCalculator = StationCountCalculator.shared
    private let characterStyleGenerator = CharacterStyleMessageGenerator()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// スヌーズ通知をスケジュール
    /// - Parameters:
    ///   - alert: アラート設定
    ///   - currentStationCount: 現在地から降車駅までの残り駅数
    ///   - railway: 路線情報
    func scheduleSnoozeNotifications(
        for alert: Alert,
        currentStationCount: Int,
        railway: String? = nil
    ) async throws {
        // スヌーズが無効の場合は何もしない
        guard alert.isSnoozeEnabled else { return }
        
        // 既存のスヌーズ通知をキャンセル
        await cancelSnoozeNotifications(for: alert)
        
        // 新しい通知IDの配列
        var notificationIds: [String] = []
        
        // スヌーズ開始駅数から降車駅までの各駅で通知を設定
        let startStation = Int(alert.snoozeStartStations)
        
        for stationsRemaining in (1...startStation).reversed() {
            // 現在地から通知対象駅までの駅数差
            let stationsUntilNotification = currentStationCount - stationsRemaining
            
            // 既に通過している場合はスキップ
            if stationsUntilNotification < 0 {
                continue
            }
            
            // 通知IDを生成
            let notificationId = generateSnoozeNotificationId(
                alertId: alert.id,
                stationsRemaining: stationsRemaining
            )
            notificationIds.append(notificationId)
            
            // 通知内容を生成
            let content = createSnoozeNotificationContent(
                alert: alert,
                stationsRemaining: stationsRemaining,
                railway: railway
            )
            
            // 通知をスケジュール（駅数ベースのため時間は推定）
            // 1駅あたり約2-3分として計算
            let estimatedMinutes = stationsUntilNotification * 2
            await scheduleNotification(
                identifier: notificationId,
                content: content,
                afterMinutes: estimatedMinutes
            )
        }
        
        // 通知IDを保存
        alert.snoozeNotificationIdArray = notificationIds
    }
    
    /// スヌーズ通知をキャンセル
    /// - Parameter alert: アラート設定
    func cancelSnoozeNotifications(for alert: Alert) async {
        let identifiers = alert.snoozeNotificationIdArray
        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            alert.clearSnoozeNotificationIds()
        }
    }
    
    /// 特定の駅数での通知を更新
    /// - Parameters:
    ///   - alert: アラート設定
    ///   - currentStationCount: 現在の残り駅数
    func updateSnoozeNotification(
        for alert: Alert,
        currentStationCount: Int
    ) async throws {
        guard alert.isSnoozeEnabled else { return }
        
        // 現在の駅数に応じた通知があるか確認
        let notificationId = generateSnoozeNotificationId(
            alertId: alert.id,
            stationsRemaining: currentStationCount
        )
        
        // 該当する通知があれば即座に発火
        if alert.snoozeNotificationIdArray.contains(notificationId) {
            let content = createSnoozeNotificationContent(
                alert: alert,
                stationsRemaining: currentStationCount,
                railway: alert.lineName
            )
            
            // 即座に通知
            await scheduleNotification(
                identifier: notificationId,
                content: content,
                afterMinutes: 0
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// スヌーズ通知IDを生成
    private func generateSnoozeNotificationId(
        alertId: UUID,
        stationsRemaining: Int
    ) -> String {
        "snooze_\(alertId.uuidString)_\(stationsRemaining)stations"
    }
    
    /// スヌーズ通知の内容を作成
    private func createSnoozeNotificationContent(
        alert: Alert,
        stationsRemaining: Int,
        railway: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        // タイトル
        content.title = "🚃 駅トントン - スヌーズ通知"
        
        // サブタイトル（駅名と路線）
        let stationName = alert.stationName ?? "降車駅"
        let lineName = railway ?? alert.lineName ?? ""
        content.subtitle = "\(lineName) \(stationName)"
        
        // ボディ（キャラクタースタイルを適用）
        let baseMessage = generateSnoozeMessage(stationsRemaining: stationsRemaining)
        let styledMessage = characterStyleGenerator.generateMessage(
            baseMessage: baseMessage,
            style: alert.characterStyleEnum
        )
        content.body = styledMessage
        
        // サウンド設定（駅数に応じて変化）
        content.sound = stationsRemaining == 1 ? .defaultCritical : .default
        
        // カテゴリーとユーザー情報
        content.categoryIdentifier = "SNOOZE_ALERT"
        content.userInfo = [
            "alertId": alert.id.uuidString,
            "type": "snooze",
            "stationsRemaining": stationsRemaining
        ]
        
        // バッジを更新
        content.badge = NSNumber(value: stationsRemaining)
        
        return content
    }
    
    /// 駅数に応じたスヌーズメッセージを生成
    private func generateSnoozeMessage(stationsRemaining: Int) -> String {
        switch stationsRemaining {
        case 1:
            return "次の駅で降車です！お忘れ物にご注意ください"
        case 2:
            return "あと2駅で到着です！準備を始めましょう"
        case 3:
            return "あと3駅で到着です"
        case 4:
            return "あと4駅で到着予定です"
        case 5:
            return "あと5駅で到着予定です"
        default:
            return "あと\(stationsRemaining)駅で到着予定です"
        }
    }
    
    /// 通知をスケジュール
    private func scheduleNotification(
        identifier: String,
        content: UNMutableNotificationContent,
        afterMinutes: Int
    ) async {
        let trigger: UNNotificationTrigger
        
        if afterMinutes <= 0 {
            // 即座に通知
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: 1,
                repeats: false
            )
        } else {
            // 指定時間後に通知
            trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(afterMinutes * 60),
                repeats: false
            )
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("🔔 スヌーズ通知をスケジュール: \(identifier)")
        } catch {
            print("❌ スヌーズ通知のスケジュールに失敗: \(error)")
        }
    }
}

// MARK: - Character Style Message Generator

/// キャラクタースタイルに応じたメッセージ生成
private class CharacterStyleMessageGenerator {
    func generateMessage(
        baseMessage: String,
        style: CharacterStyle
    ) -> String {
        switch style {
        case .gyaru:
            return "\(baseMessage)〜！"
        case .butler:
            return "\(baseMessage)。"
        case .kansai:
            return "\(baseMessage)やで〜！"
        case .tsundere:
            return "\(baseMessage)...別に心配してないんだから！"
        case .sporty:
            return "\(baseMessage)！ファイト〜！"
        case .healing:
            return "\(baseMessage)ね。"
        }
    }
}
