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
        
        print("🔔 アラート監視を開始しました")
    }
    
    /// 監視を停止
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
        
        print("🔕 アラート監視を停止しました")
    }
    
    /// アクティブなアラートを再読み込み
    func reloadAlerts() {
        loadActiveAlerts()
        if isMonitoring {
            checkAllAlerts()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLocationUpdates() {
        // 位置情報の更新を監視
        locationManager.$location
            .sink { [weak self] location in
                guard let self = self, let _ = location, self.isMonitoring else { return }
                // 位置が更新されたらアラートをチェック
                self.checkLocationBasedAlerts()
            }
            .store(in: &cancellables)
    }
    
    private func loadActiveAlerts() {
        let request = Alert.activeAlertsFetchRequest()
        do {
            activeAlerts = try viewContext.fetch(request)
            print("📍 アクティブなアラート: \(activeAlerts.count)件")
        } catch {
            print("❌ アラートの読み込みエラー: \(error)")
            monitoringError = error
        }
    }
    
    private func checkAllAlerts() {
        Task {
            await checkTimeBasedAlerts()
            checkLocationBasedAlerts()
            // 駅数ベースのアラートは現在地トラッキングが必要なため、将来実装
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
                
                // 通知時刻を過ぎていて、到着時刻はまだの場合
                if now >= notificationTime && now < arrivalTime {
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
            
            // 設定距離以内に入った場合
            if distance <= alert.notificationDistance {
                Task {
                    await sendNotification(for: alert, reason: "距離ベース（\(Int(distance))m）")
                    notifiedAlerts.insert(alertId)
                }
            }
        }
    }
    
    /// 通知を送信
    private func sendNotification(for alert: Alert, reason: String) async {
        let stationName = alert.station?.name ?? alert.stationName ?? "駅"
        let characterStyle = alert.characterStyleEnum
        
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
            
            // 履歴に追加
            let history = alert.addHistory(message: "\(reason)で通知: \(body)")
            try? viewContext.save()
            
            print("✅ 通知を送信しました: \(stationName) - \(reason)")
        } catch {
            print("❌ 通知送信エラー: \(error)")
            monitoringError = error
        }
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
                    print("⚠️ AI生成エラー: \(error)")
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
