//
//  AlertMonitoringService.swift
//  TrainAlert
//
//  アラートの条件を監視し、適切なタイミングで通知を発火するサービス
//

import Combine
import CoreData
import CoreLocation
import Foundation
import UserNotifications

@MainActor
class AlertMonitoringService: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = AlertMonitoringService()
    
    // MARK: - Properties
    @Published var isMonitoring = false
    @Published var activeAlerts: [Alert] = []
    @Published var lastNotificationTime: Date?
    @Published var monitoringError: Error?
    
    private let locationManager = LocationManager()
    private let notificationManager = NotificationManager.shared
    private let stationCountCalculator = StationCountCalculator.shared
    private var viewContext: NSManagedObjectContext {
        CoreDataManager.shared.viewContext
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var locationUpdateTimer: Timer?
    
    // 通知済みアラートを追跡（同じアラートで何度も通知しないように）
    private var notifiedAlerts = Set<UUID>()
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationUpdates()
    }
    
    // MARK: - Public Methods
    
    /// 監視を開始
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        loadActiveAlerts()
        
        // 定期的にアラートをチェック（30秒ごと）
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkAllAlerts()
        }
        
        // 初回チェック
        checkAllAlerts()
        
        // アラート監視を開始
    }
    
    /// 監視を停止
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
        
        // アラート監視を停止
    }
    
    /// アクティブなアラートを再読み込み
    func reloadAlerts() {
        loadActiveAlerts()
        if isMonitoring {
            checkAllAlerts()
        }
    }
    
    /// 特定のアラートを監視対象から削除
    /// - Parameter alertId: 削除するアラートのID
    func removeAlert(with alertId: UUID?) {
        guard let alertId = alertId else { return }
        
        // activeAlertsから削除
        activeAlerts.removeAll { $0.alertId == alertId }
        
        // 通知済みリストからも削除
        notifiedAlerts.remove(alertId)
        
        // アラートを監視対象から削除
    }
    
    // MARK: - Private Methods
    
    private func setupLocationUpdates() {
        // 位置情報の更新を監視
        locationManager.$location
            .sink { [weak self] location in
                guard let self = self, location != nil, self.isMonitoring else { return }
                // 位置が更新されたらアラートをチェック
                self.checkLocationBasedAlerts()
            }
            .store(in: &cancellables)
    }
    
    private func loadActiveAlerts() {
        let request = Alert.activeAlertsFetchRequest()
        do {
            activeAlerts = try viewContext.fetch(request)
            // アクティブなアラート
        } catch {
            // アラートの読み込みエラー
            monitoringError = error
        }
    }
    
    private func checkAllAlerts() {
        Task {
            await checkTimeBasedAlerts()
            checkLocationBasedAlerts()
            await checkStationBasedAlerts()
        }
    }
    
    /// 時間ベースのアラートをチェック
    private func checkTimeBasedAlerts() async {
        let now = Date()
        
        for alert in activeAlerts {
            guard alert.notificationTime > 0,
                  let alertId = alert.alertId,
                  !notifiedAlerts.contains(alertId) else { continue }
            
            // 到着時刻が設定されている場合（経路から作成）
            if let arrivalTime = alert.arrivalTime {
                let notificationTime = arrivalTime.addingTimeInterval(-Double(alert.notificationTime) * 60)
                
                // 通知時刻を過ぎていて、到着時刻はまだの場合、かつまだ通知していない場合
                if now >= notificationTime && now < arrivalTime && !notifiedAlerts.contains(alertId) {
                    await sendNotification(for: alert, reason: "時間ベース")
                    notifiedAlerts.insert(alertId)
                }
            }
        }
    }
    
    /// 距離ベースのアラートをチェック
    private func checkLocationBasedAlerts() {
        guard let currentLocation = locationManager.location else { return }
        
        for alert in activeAlerts {
            guard alert.notificationDistance > 0,
                  let alertId = alert.alertId,
                  let station = alert.station,
                  !notifiedAlerts.contains(alertId) else { continue }
            
            let stationLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
            let distance = currentLocation.distance(from: stationLocation)
            
            // 設定距離以内に入っていて、まだ通知していない場合
            if distance <= alert.notificationDistance && !notifiedAlerts.contains(alertId) {
                Task {
                    await sendNotification(for: alert, reason: "距離ベース（\(Int(distance))m）")
                    notifiedAlerts.insert(alertId)
                }
            }
        }
    }
    
    /// 駅数ベースのアラートをチェック（スヌーズ機能含む）
    private func checkStationBasedAlerts() async {
        guard let currentLocation = locationManager.location else { return }
        
        for alert in activeAlerts {
            // 駅数ベースの通知が有効な場合
            if alert.notificationStationsBefore > 0 || alert.isSnoozeEnabled {
                await checkStationBasedAlert(alert, currentLocation: currentLocation)
            }
        }
    }
    
    /// 個別の駅数ベースアラートをチェック
    private func checkStationBasedAlert(_ alert: Alert, currentLocation: CLLocation) async {
        guard let station = alert.station,
              let stationName = station.name,
              let lineName = alert.lineName else { return }
        
        // 現在の駅数を計算
        let stationCountResult = await stationCountCalculator.calculateStationCount(
            from: currentLocation,
            to: stationName,
            on: lineName
        )
        
        switch stationCountResult {
        case .success(let count):
            // スヌーズ機能が有効な場合
            if alert.isSnoozeEnabled {
                do {
                    try await SnoozeNotificationManager.shared.updateSnoozeNotification(
                        for: alert,
                        currentStationCount: count
                    )
                } catch {
                    // スヌーズ通知の更新エラー
                }
            }
            
            // 通常の駅数ベース通知
            if alert.notificationStationsBefore > 0,
               count == Int(alert.notificationStationsBefore),
               let alertId = alert.alertId,
               !notifiedAlerts.contains(alertId) {
                await sendNotification(for: alert, reason: "駅数ベース（\(count)駅前）")
                notifiedAlerts.insert(alertId)
            }
            
        case .failure(let error):
            // 駅数計算エラー
            monitoringError = error
        }
    }
    
    /// 通知を送信
    private func sendNotification(for alert: Alert, reason: String) async {
        let stationName = alert.station?.name ?? alert.stationName ?? "駅"
        let characterStyle = alert.characterStyleEnum
        
        // 時間ベースのアラートの場合、NotificationManagerを使用してスケジュール
        if alert.notificationTime > 0, let arrivalTime = alert.arrivalTime {
            do {
                if let station = alert.station {
                    let targetLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
                    try await notificationManager.scheduleTrainAlert(
                        for: stationName,
                        arrivalTime: arrivalTime,
                        currentLocation: locationManager.location,
                        targetLocation: targetLocation,
                        characterStyle: characterStyle,
                        alertId: alert.alertId?.uuidString
                    )
                    // 時間ベースの通知をスケジュール
                }
            } catch {
                // 通知スケジュールエラー
                monitoringError = error
            }
        }
        
        // 距離ベースのアラートの場合
        if alert.notificationDistance > 0, let station = alert.station {
            do {
                let targetLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
                try await notificationManager.scheduleLocationBasedAlert(
                    for: stationName,
                    targetLocation: targetLocation,
                    radius: alert.notificationDistance,
                    alertId: alert.alertId?.uuidString
                )
                // 位置ベースの通知をスケジュール
            } catch {
                // 通知スケジュールエラー
                monitoringError = error
            }
        }
        
        // アラートが近い場合は即座に通知も送信
        let shouldSendImmediate: Bool
        if let arrivalTime = alert.arrivalTime {
            shouldSendImmediate = arrivalTime.timeIntervalSinceNow <= 60 // 1分以内
        } else {
            shouldSendImmediate = reason.contains("距離ベース")
        }
        
        if shouldSendImmediate {
            // 通知内容を作成
            let title = "🚃 もうすぐ\(stationName)駅です！"
            let body = generateNotificationMessage(for: alert, stationName: stationName)
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .defaultCritical
            content.categoryIdentifier = NotificationCategory.trainAlert.identifier
            
            // ユーザー情報を追加
            if let alertId = alert.alertId {
                content.userInfo = [
                    "alertId": alertId.uuidString,
                    "stationName": stationName,
                    "reason": reason
                ]
            }
            
            // 即座に通知を送信
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // nilで即座に送信
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                lastNotificationTime = Date()
                // 即座の通知を送信
            } catch {
                // 通知送信エラー
                monitoringError = error
            }
        }
        
        // 履歴に追加（NotificationHistoryManagerを使用）
        var userInfo: [AnyHashable: Any] = [
            "stationName": stationName,
            "reason": reason
        ]
        
        if let alertId = alert.alertId {
            userInfo["alertId"] = alertId.uuidString
        }
        
        // 通知タイプを判定
        let notificationType: String
        if reason.contains("時間ベース") {
            notificationType = "trainAlert"
        } else if reason.contains("距離ベース") {
            notificationType = "locationAlert"
        } else {
            notificationType = "trainAlert"
        }
        
        // 履歴の保存はNotificationManagerに任せる（重複を防ぐため）
        // NotificationManagerのwillPresent/didReceiveで自動的に保存される
        // 通知送信
    }
    
    /// キャラクタースタイルに応じたメッセージを生成
    private func generateNotificationMessage(for alert: Alert, stationName: String) -> String {
        // AI生成メッセージが有効で、APIキーが設定されているか確認
        if UserDefaults.standard.bool(forKey: "useAIGeneratedMessages"),
           let apiKey = try? KeychainManager.shared.getOpenAIAPIKey(),
           !apiKey.isEmpty {
            // AI生成を試みる（同期的に実行するため、タスクを作成）
            let semaphore = DispatchSemaphore(value: 0)
            var aiMessage: String?
            
            Task {
                do {
                    aiMessage = try await generateAIMessage(for: alert, stationName: stationName)
                } catch {
                    // AI生成エラー
                }
                semaphore.signal()
            }
            
            // タイムアウト付きで待機（最大3秒）
            if semaphore.wait(timeout: .now() + 3) == .success,
               let message = aiMessage {
                return message
            }
        }
        
        // フォールバック：固定メッセージを使用
        return generateFallbackMessage(for: alert, stationName: stationName)
    }
    
    /// OpenAI APIを使用してメッセージを生成
    private func generateAIMessage(for alert: Alert, stationName: String) async throws -> String {
        let openAI = OpenAIClient.shared
        let characterStyle = alert.characterStyleEnum
        
        // 到着時刻の文字列を生成（例: "あと5分"）
        let arrivalTimeString: String
        if let arrivalTime = alert.arrivalTime {
            let timeInterval = arrivalTime.timeIntervalSinceNow
            if timeInterval > 0 {
                let minutes = Int(timeInterval / 60)
                arrivalTimeString = "あと\(minutes)分"
            } else {
                arrivalTimeString = "まもなく"
            }
        } else {
            arrivalTimeString = "まもなく"
        }
        
        // OpenAIClient の generateNotificationMessage を使用
        let generatedMessage = try await openAI.generateNotificationMessage(
            for: stationName,
            arrivalTime: arrivalTimeString,
            characterStyle: characterStyle
        )
        
        return generatedMessage
    }
    
    /// フォールバックメッセージを生成（固定メッセージ）
    private func generateFallbackMessage(for alert: Alert, stationName: String) -> String {
        let characterStyle = alert.characterStyleEnum
        
        switch characterStyle {
        case .healing:
            return "もうすぐ\(stationName)駅に到着します。ゆっくりと準備してくださいね。"
        case .gyaru:
            return "\(stationName)駅もうすぐだよ〜！準備して〜！急いで〜！"
        case .butler:
            return "\(stationName)駅への到着が近づいております。お降りのご準備をお願いいたします。"
        case .sporty:
            return "\(stationName)駅まであと少し！降車準備！ファイト〜！"
        case .tsundere:
            return "べ、別に\(stationName)駅のこと教えてあげてるわけじゃないんだからね...！準備しなさいよね...！"
        case .kansai:
            return "\(stationName)駅やで〜！そろそろ準備せなあかんで〜！"
        }
    }
    
    /// アラートをリセット（再度通知可能にする）
    func resetAlert(_ alert: Alert) {
        if let alertId = alert.alertId {
            notifiedAlerts.remove(alertId)
        }
    }
    
    /// すべての通知済みフラグをクリア
    func clearAllNotifiedFlags() {
        notifiedAlerts.removeAll()
    }
}

// MARK: - CLLocationManagerDelegate
extension AlertMonitoringService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // LocationManagerが既にハンドリングしているため、ここでは何もしない
    }
}
