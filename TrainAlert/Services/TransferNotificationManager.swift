//
//  TransferNotificationManager.swift
//  TrainAlert
//
//  乗り換え経路の通知管理
//

import CoreLocation
import Foundation
import UserNotifications

@MainActor
class TransferNotificationManager: ObservableObject {
    // MARK: - Singleton
    static let shared = TransferNotificationManager()
    
    // MARK: - Properties
    private let notificationManager = NotificationManager.shared
    private let alertMonitoringService = AlertMonitoringService.shared
    private let openAIClient = OpenAIClient.shared
    
    @Published var activeTransferAlerts: [TransferAlert] = []
    @Published var isMonitoring = false
    
    // MARK: - Initialization
    
    private init() {
        loadActiveTransferAlerts()
    }
    
    // MARK: - Public Methods
    
    /// 乗り換えアラートの通知をスケジュール
    func scheduleTransferNotifications(for alert: TransferAlert) async throws {
        guard let route = alert.transferRoute else {
            throw TransferNotificationError.invalidRoute
        }
        
        // すべての通知ポイントを取得
        let notificationPoints = route.notificationPoints
        
        for point in notificationPoints {
            let identifier = alert.notificationIdentifier(
                for: point.notificationType,
                stationName: point.stationName
            )
            
            // 通知時刻を計算
            let notificationDate = calculateNotificationDate(
                for: point,
                notificationTime: alert.notificationTime
            )
            
            // 過去の時刻はスキップ
            guard notificationDate > Date() else { continue }
            
            // 通知コンテンツを作成
            let content = try await createNotificationContent(
                for: point,
                alert: alert,
                route: route
            )
            
            // 時間ベースのトリガーを作成
            let timeInterval = notificationDate.timeIntervalSinceNow
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, timeInterval),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            try await notificationManager.center.add(request)
            print("📅 乗り換え通知をスケジュール: \(point.stationName) - \(point.notificationType)")
        }
    }
    
    /// 乗り換えアラートのすべての通知をキャンセル
    func cancelTransferNotifications(for alert: TransferAlert) {
        let identifiers = alert.generateNotificationIdentifiers()
        notificationManager.center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🚫 乗り換え通知をキャンセル: \(identifiers.count)件")
    }
    
    /// アクティブな乗り換えアラートを監視開始
    func startMonitoring() {
        isMonitoring = true
        loadActiveTransferAlerts()
        
        // 定期的にチェック（30秒ごと）
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.checkActiveTransferAlerts()
            }
        }
    }
    
    /// 監視を停止
    func stopMonitoring() {
        isMonitoring = false
    }
    
    // MARK: - Private Methods
    
    /// アクティブな乗り換えアラートを読み込み
    private func loadActiveTransferAlerts() {
        let request = TransferAlert.activeTransferAlertsFetchRequest()
        
        do {
            activeTransferAlerts = try CoreDataManager.shared.viewContext.fetch(request)
            print("📍 アクティブな乗り換えアラート: \(activeTransferAlerts.count)件")
        } catch {
            print("❌ 乗り換えアラートの読み込みエラー: \(error)")
        }
    }
    
    /// アクティブなアラートをチェック
    private func checkActiveTransferAlerts() {
        let now = Date()
        
        for alert in activeTransferAlerts {
            guard alert.isActive,
                  let route = alert.transferRoute else { continue }
            
            // 次の通知ポイントを確認
            if let nextPoint = route.nextTransferStation(from: now) {
                let notificationDate = calculateNotificationDate(
                    for: NotificationPoint(
                        id: UUID(),
                        stationName: nextPoint.stationName,
                        notificationType: .transfer,
                        scheduledTime: nextPoint.arrivalTime,
                        message: ""
                    ),
                    notificationTime: alert.notificationTime
                )
                
                // 通知時刻が近い場合（5分以内）
                if notificationDate.timeIntervalSinceNow < 5 * 60 {
                    print("⏰ もうすぐ乗り換え: \(nextPoint.stationName)")
                }
            }
        }
    }
    
    /// 通知時刻を計算
    private func calculateNotificationDate(
        for point: NotificationPoint,
        notificationTime: Int16
    ) -> Date {
        switch point.notificationType {
        case .arrival:
            // 到着通知は指定された分数前
            return point.scheduledTime.addingTimeInterval(-Double(notificationTime) * 60)
        case .transfer:
            // 乗り換え通知は到着時
            return point.scheduledTime
        case .departure:
            // 出発通知は2分前（固定）
            return point.scheduledTime.addingTimeInterval(-2 * 60)
        }
    }
    
    /// 通知コンテンツを作成
    private func createNotificationContent(
        for point: NotificationPoint,
        alert: TransferAlert,
        route: TransferRoute
    ) async throws -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = NotificationCategory.trainAlert.identifier
        content.sound = .defaultCritical
        
        // キャラクタースタイルを取得
        let characterStyle = CharacterStyle(rawValue: alert.characterStyle ?? "") ?? .healing
        
        // タイトルとボディを設定
        switch point.notificationType {
        case .arrival:
            content.title = "🚃 もうすぐ\(point.stationName)駅です！"
            content.body = await generateMessage(
                for: point.stationName,
                type: .arrival,
                characterStyle: characterStyle
            )
            
        case .transfer:
            content.title = "🔄 乗り換えです"
            if let transferInfo = route.transferInfo(for: point.stationName) {
                content.body = "ここで\(transferInfo.toLine)に乗り換えてください"
                content.subtitle = "乗り換え時間: \(Int(transferInfo.transferTime / 60))分"
            } else {
                content.body = point.message
            }
            
        case .departure:
            content.title = "🚅 まもなく発車"
            content.body = point.message
        }
        
        // ユーザー情報を追加
        content.userInfo = [
            "transferAlertId": alert.transferAlertId?.uuidString ?? "",
            "stationName": point.stationName,
            "notificationType": String(describing: point.notificationType),
            "type": "transfer"
        ]
        
        content.badge = NSNumber(value: 1)
        
        return content
    }
    
    /// メッセージを生成（AI or フォールバック）
    private func generateMessage(
        for stationName: String,
        type: NotificationPoint.NotificationType,
        characterStyle: CharacterStyle
    ) async -> String {
        // AI生成を試みる
        if openAIClient.hasAPIKey() {
            do {
                let arrivalTimeString = type == .arrival ? "まもなく" : ""
                return try await openAIClient.generateNotificationMessage(
                    for: stationName,
                    arrivalTime: arrivalTimeString,
                    characterStyle: characterStyle
                )
            } catch {
                print("⚠️ AI生成エラー: \(error)")
            }
        }
        
        // フォールバック
        return characterStyle.generateDefaultMessage(for: stationName)
    }
}

// MARK: - Errors

enum TransferNotificationError: LocalizedError {
    case invalidRoute
    case notificationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidRoute:
            return "無効な乗り換え経路です"
        case .notificationFailed:
            return "通知のスケジュールに失敗しました"
        }
    }
}

// MARK: - Extension for Alert Monitoring

extension TransferNotificationManager {
    /// ハイブリッド監視を開始（位置情報と時間の併用）
    func startHybridMonitoring(for alert: TransferAlert) {
        guard let route = alert.transferRoute else { return }
        
        // 各駅の位置情報を取得して位置ベースの通知も設定
        Task {
            for section in route.sections {
                // 到着駅の位置情報を取得（実際にはAPIから取得）
                if let station = await fetchStationInfo(name: section.arrivalStation) {
                    let location = CLLocation(
                        latitude: station.latitude,
                        longitude: station.longitude
                    )
                    
                    // 位置ベースの通知を追加
                    try? await notificationManager.scheduleLocationBasedAlert(
                        for: section.arrivalStation,
                        targetLocation: location,
                        radius: 500 // 500m以内
                    )
                }
            }
        }
    }
    
    /// 駅情報を取得（仮実装）
    private func fetchStationInfo(name: String) async -> (latitude: Double, longitude: Double)? {
        // 実際にはAPIから取得
        // ここでは主要駅の座標を返す仮実装
        switch name {
        case "東京":
            return (35.6812, 139.7671)
        case "新宿":
            return (35.6896, 139.7006)
        case "渋谷":
            return (35.6580, 139.7016)
        default:
            return nil
        }
    }
}

