//
//  AlertSetupData.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreLocation
import Foundation

/// アラート設定フロー中のデータを保持するモデル
class AlertSetupData: ObservableObject {
    // MARK: - Properties
    
    /// 選択された駅
    @Published var selectedStation: StationModel?
    
    /// 通知時間（分前）
    @Published var notificationTime: Int = 5
    
    /// 通知距離（メートル）
    @Published var notificationDistance: Double = 500
    
    /// スヌーズ間隔（分）
    @Published var snoozeInterval: Int = 5
    
    /// キャラクタースタイル
    @Published var characterStyle: CharacterStyle = .gyaru
    
    /// スヌーズ機能の有効/無効
    @Published var isSnoozeEnabled: Bool = false
    
    /// スヌーズ開始駅数
    @Published var snoozeStartStations: Int = 3
    
    // MARK: - Validation Properties
    
    var isStationSelected: Bool {
        selectedStation != nil
    }
    
    var isNotificationTimeValid: Bool {
        notificationTime >= 0 && notificationTime <= 60
    }
    
    var isNotificationDistanceValid: Bool {
        notificationDistance >= 50 && notificationDistance <= 10_000
    }
    
    var isSnoozeIntervalValid: Bool {
        snoozeInterval >= 1 && snoozeInterval <= 30
    }
    
    var isFormValid: Bool {
        isStationSelected && 
        isNotificationTimeValid && 
        isNotificationDistanceValid && 
        isSnoozeIntervalValid
    }
    
    // MARK: - Display Properties
    
    var notificationTimeDisplayString: String {
        if notificationTime == 0 {
            return "到着時"
        } else {
            return "\(notificationTime)分前"
        }
    }
    
    var notificationDistanceDisplayString: String {
        if notificationDistance < 1_000 {
            return String(format: "%.0fm", notificationDistance)
        } else {
            return String(format: "%.1fkm", notificationDistance / 1_000)
        }
    }
    
    var snoozeIntervalDisplayString: String {
        "\(snoozeInterval)分"
    }
    
    // MARK: - Methods
    
    /// データを初期状態にリセット
    func reset() {
        selectedStation = nil
        notificationTime = 5
        notificationDistance = 500
        snoozeInterval = 5
        characterStyle = .gyaru
        isSnoozeEnabled = false
        snoozeStartStations = 3
    }
    
    /// 通知時間を設定
    /// - Parameter minutes: 分数（0-60）
    func setNotificationTime(_ minutes: Int) {
        notificationTime = max(0, min(60, minutes))
    }
    
    /// 通知距離を設定
    /// - Parameter meters: メートル（50-10000）
    func setNotificationDistance(_ meters: Double) {
        notificationDistance = max(50, min(10_000, meters))
    }
    
    /// スヌーズ間隔を設定
    /// - Parameter minutes: 分数（1-30）
    func setSnoozeInterval(_ minutes: Int) {
        snoozeInterval = max(1, min(30, minutes))
    }
    
    /// 設定データをアラートに変換（コピー用）
    func toAlertSettings() -> AlertSettings {
        AlertSettings(
            station: selectedStation,
            notificationTime: notificationTime,
            notificationDistance: notificationDistance,
            snoozeInterval: snoozeInterval,
            characterStyle: characterStyle,
            isSnoozeEnabled: isSnoozeEnabled,
            snoozeStartStations: snoozeStartStations
        )
    }
}

/// アラート設定の構造体
struct AlertSettings {
    let station: StationModel?
    let notificationTime: Int
    let notificationDistance: Double
    let snoozeInterval: Int
    let characterStyle: CharacterStyle
    let isSnoozeEnabled: Bool
    let snoozeStartStations: Int
    
    var isValid: Bool {
        station != nil &&
        notificationTime >= 0 && notificationTime <= 60 &&
        notificationDistance >= 50 && notificationDistance <= 10_000 &&
        snoozeInterval >= 1 && snoozeInterval <= 30 &&
        snoozeStartStations >= 1 && snoozeStartStations <= 5
    }
}
