//
//  AlertSetupViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreLocation
import Foundation
import SwiftUI
import UserNotifications

@MainActor
class AlertSetupViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentStep: AlertSetupStep = .stationSearch
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false
    @Published var setupData = AlertSetupData()
    
    private var coreDataManager = CoreDataManager.shared
    private var editingAlert: Alert?
    @Published var isEditMode: Bool = false
    
    // MARK: - Enums
    
    enum AlertSetupStep: Int, CaseIterable {
        case stationSearch = 0
        case alertSettings = 1
        case characterSelection = 2
        case review = 3
        
        var title: String {
            switch self {
            case .stationSearch:
                return "駅を選択"
            case .alertSettings:
                return "通知設定"
            case .characterSelection:
                return "キャラクター選択"
            case .review:
                return "確認"
            }
        }
        
        var progress: Double {
            Double(rawValue + 1) / Double(AlertSetupStep.allCases.count)
        }
    }
    
    // MARK: - Methods
    
    func selectStation(_ station: StationModel) {
        setupData.selectedStation = station
        goToNextStep()
    }
    
    func updateNotificationTime(_ minutes: Int) {
        setupData.notificationTime = minutes
    }
    
    func updateNotificationDistance(_ meters: Double) {
        setupData.notificationDistance = meters
    }
    
    func updateSnoozeInterval(_ minutes: Int) {
        setupData.snoozeInterval = minutes
    }
    
    func updateCharacterStyle(_ style: CharacterStyle) {
        setupData.characterStyle = style
    }
    
    // MARK: - Navigation
    
    var canGoToNextStep: Bool {
        switch currentStep {
        case .stationSearch:
            return setupData.isStationSelected
        case .alertSettings:
            return setupData.isNotificationTimeValid && 
                   setupData.isNotificationDistanceValid && 
                   setupData.isSnoozeIntervalValid
        case .characterSelection:
            return true
        case .review:
            return setupData.isFormValid
        }
    }
    
    func goToNextStep() {
        let nextStepIndex = currentStep.rawValue + 1
        if let nextStep = AlertSetupStep(rawValue: nextStepIndex) {
            currentStep = nextStep
        }
    }
    
    func goToPreviousStep() {
        let previousStepIndex = currentStep.rawValue - 1
        if let previousStep = AlertSetupStep(rawValue: previousStepIndex) {
            currentStep = previousStep
        }
    }
    
    func goToStep(_ step: AlertSetupStep) {
        currentStep = step
    }
    
    var progressTitle: String {
        switch currentStep {
        case .stationSearch:
            return "降車駅を選択してください"
        case .alertSettings:
            return "通知設定を調整してください"
        case .characterSelection:
            return "キャラクターを選んでください"
        case .review:
            return "設定内容を確認してください"
        }
    }
    
    // MARK: - Alert Creation
    
    func createAlert() async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // 通知権限を確認
            let notificationManager = NotificationManager.shared
            try await notificationManager.requestAuthorization()
            let isAuthorized = notificationManager.isPermissionGranted
            
            guard isAuthorized else {
                throw AlertSetupError.notificationPermissionDenied
            }
            
            // Validate form
            guard setupData.isFormValid else {
                throw AlertSetupError.invalidForm
            }
            
            guard let station = setupData.selectedStation else {
                throw AlertSetupError.stationNotSelected
            }
            
            // 編集モードの場合は更新、そうでなければ新規作成
            let savedAlert: Alert
            if isEditMode {
                savedAlert = try await updateAlertInCoreData()
            } else {
                savedAlert = try await saveAlertToCoreData(station: station)
            }
            
            // Schedule notifications
            if savedAlert.arrivalTime != nil {
                try await notificationManager.scheduleNotifications(for: savedAlert)
            }
            
            isLoading = false
            isComplete = true
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func saveAlertToCoreData(station: StationModel) async throws -> Alert {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Alert, Error>) in
            let context = coreDataManager.viewContext
            
            do {
                // 駅情報をCore Dataに保存または取得
                let stationEntity = try Station.findOrCreate(
                    stationId: station.id,
                    name: station.name,
                    latitude: station.latitude,
                    longitude: station.longitude,
                    lines: station.lines,
                    in: context
                )
                
                // アラートを作成
                let alert = Alert(context: context)
                alert.alertId = UUID()
                alert.station = stationEntity
                alert.stationName = station.name
                alert.notificationTime = Int16(setupData.notificationTime)
                alert.notificationDistance = setupData.notificationDistance
                alert.snoozeInterval = Int16(setupData.snoozeInterval)
                alert.characterStyle = setupData.characterStyle.rawValue
                alert.isActive = true
                alert.createdAt = Date()
                // Updated date removed as Alert doesn't have updatedAt property
                
                // 保存
                try context.save()
                continuation.resume(returning: alert)
            } catch {
                continuation.resume(throwing: AlertSetupError.coreDataError(error))
            }
        }
    }
    
    // MARK: - RouteAlert Creation
    
    func createRouteAlert(
        departureStation: String,
        arrivalStation: String,
        arrivalTime: Date,
        trainLine: String,
        notificationTime: Int,
        notificationDistance: Double,
        snoozeInterval: Int,
        characterStyle: CharacterStyle,
        routeData: RouteInfo? = nil,
        selectedTrainTime: Date? = nil,
        notificationStationsBefore: Int? = nil,
        isRepeating: Bool = false,
        repeatDays: Set<WeekDay> = []
    ) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // 通知権限を確認
            let notificationManager = NotificationManager.shared
            try await notificationManager.requestAuthorization()
            let isAuthorized = notificationManager.isPermissionGranted
            
            guard isAuthorized else {
                throw AlertSetupError.notificationPermissionDenied
            }
            
            let savedAlert = try await saveRouteAlertToCoreData(
                departureStation: departureStation,
                arrivalStation: arrivalStation,
                arrivalTime: arrivalTime,
                trainLine: trainLine,
                notificationTime: notificationTime,
                notificationDistance: notificationDistance,
                snoozeInterval: snoozeInterval,
                characterStyle: characterStyle,
                routeData: routeData,
                selectedTrainTime: selectedTrainTime,
                notificationStationsBefore: notificationStationsBefore,
                isRepeating: isRepeating,
                repeatDays: repeatDays
            )
            
            // Schedule notifications
            if savedAlert.arrivalTime != nil {
                try await notificationManager.scheduleNotifications(for: savedAlert)
            }
            
            isLoading = false
            isComplete = true
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func saveRouteAlertToCoreData(
        departureStation: String,
        arrivalStation: String,
        arrivalTime: Date,
        trainLine: String,
        notificationTime: Int,
        notificationDistance: Double,
        snoozeInterval: Int,
        characterStyle: CharacterStyle,
        routeData: RouteInfo? = nil,
        selectedTrainTime: Date? = nil,
        notificationStationsBefore: Int? = nil,
        isRepeating: Bool = false,
        repeatDays: Set<WeekDay> = []
    ) async throws -> Alert {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Alert, Error>) in
            let context = coreDataManager.viewContext
            
            do {
                // RouteAlertを作成
                let routeAlert = RouteAlert(context: context)
                routeAlert.routeId = UUID()
                routeAlert.departureStation = departureStation
                routeAlert.arrivalStation = arrivalStation
                routeAlert.departureTime = selectedTrainTime ?? arrivalTime.addingTimeInterval(-3_600) // デフォルトは1時間前
                routeAlert.arrivalTime = arrivalTime
                // routeAlert.lineName = trainLine // RouteAlert doesn't have lineName property
                routeAlert.isActive = true
                routeAlert.createdAt = Date()
                // routeAlert.updatedAt = Date() // RouteAlert doesn't have updatedAt property
                
                // 経路データを保存
                if let routeData = routeData {
                    routeAlert.routeData = try? JSONEncoder().encode(routeData)
                }
                
                // アラートを作成
                let alert = Alert(context: context)
                alert.alertId = UUID()
                alert.stationName = arrivalStation
                alert.departureStation = departureStation
                alert.arrivalTime = arrivalTime
                // alert.lineName = trainLine // Alert doesn't have lineName property
                alert.notificationTime = Int16(notificationTime)
                alert.notificationDistance = notificationDistance
                alert.snoozeInterval = Int16(snoozeInterval)
                alert.characterStyle = characterStyle.rawValue
                alert.isActive = true
                alert.createdAt = Date()
                // Updated date removed as Alert doesn't have updatedAt property
                // alert.routeAlert = routeAlert // Alert doesn't have routeAlert property, it's set from RouteAlert side
                
                // 駅数ベースの通知設定
                if let stationsBefore = notificationStationsBefore, stationsBefore > 0 {
                    alert.notificationType = "station"
                    alert.notificationStationsBefore = Int16(stationsBefore)
                }
                
                // 繰り返し設定
                // alert.isRepeatingEnabled = isRepeating // isRepeatingEnabled is read-only, use repeatPattern instead
                if isRepeating && !repeatDays.isEmpty {
                    // WeekDayをビットマスクに変換
                    var bitmask: Int32 = 0
                    for day in repeatDays {
                        bitmask |= (1 << day.rawValue)
                    }
                    // alert.repeatDays = bitmask // Alert doesn't have repeatDays property
                }
                
                // RouteAlertとの関連付け
                // routeAlert.alert = alert // RouteAlert doesn't have alert property
                
                // 保存
                try context.save()
                continuation.resume(returning: alert)
            } catch {
                continuation.resume(throwing: AlertSetupError.coreDataError(error))
            }
        }
    }
    
    // MARK: - TimetableAlert Creation
    func createTimetableAlert(
        station: StationModel,
        trainInfo: TimetableTrainInfo,
        notificationTime: Int,
        notificationDistance: Double,
        snoozeInterval: Int,
        characterStyle: CharacterStyle,
        notificationStationsBefore: Int? = nil,
        isRepeating: Bool = false,
        repeatDays: Set<WeekDay> = []
    ) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // 通知権限を確認
            let notificationManager = NotificationManager.shared
            try await notificationManager.requestAuthorization()
            let isAuthorized = notificationManager.isPermissionGranted
            
            guard isAuthorized else {
                throw AlertSetupError.notificationPermissionDenied
            }
            
            let savedAlert = try await saveTimetableAlertToCoreData(
                station: station,
                trainInfo: trainInfo,
                notificationTime: notificationTime,
                notificationDistance: notificationDistance,
                snoozeInterval: snoozeInterval,
                characterStyle: characterStyle,
                notificationStationsBefore: notificationStationsBefore,
                isRepeating: isRepeating,
                repeatDays: repeatDays
            )
            
            // Schedule notifications
            if savedAlert.arrivalTime != nil {
                try await notificationManager.scheduleNotifications(for: savedAlert)
            }
            
            isLoading = false
            isComplete = true
            return true
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func saveTimetableAlertToCoreData(
        station: StationModel,
        trainInfo: TimetableTrainInfo,
        notificationTime: Int,
        notificationDistance: Double,
        snoozeInterval: Int,
        characterStyle: CharacterStyle,
        notificationStationsBefore: Int? = nil,
        isRepeating: Bool = false,
        repeatDays: Set<WeekDay> = []
    ) async throws -> Alert {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Alert, Error>) in
            let context = coreDataManager.viewContext
            
            do {
                // 駅情報をCore Dataに保存または取得
                let stationEntity = try Station.findOrCreate(
                    stationId: station.id,
                    name: station.name,
                    latitude: station.latitude,
                    longitude: station.longitude,
                    lines: station.lines,
                    in: context
                )
                
                // アラートを作成
                let alert = Alert(context: context)
                alert.alertId = UUID()
                alert.station = stationEntity
                alert.stationName = station.name
                alert.departureStation = trainInfo.departureStation
                alert.arrivalTime = trainInfo.arrivalTime
                alert.lineName = trainInfo.trainType
                alert.notificationTime = Int16(notificationTime)
                alert.notificationDistance = notificationDistance
                alert.snoozeInterval = Int16(snoozeInterval)
                alert.characterStyle = characterStyle.rawValue
                alert.isActive = true
                alert.createdAt = Date()
                // Updated date removed as Alert doesn't have updatedAt property
                
                // 駅数ベースの通知設定
                if let stationsBefore = notificationStationsBefore, stationsBefore > 0 {
                    alert.notificationType = "station"
                    alert.notificationStationsBefore = Int16(stationsBefore)
                }
                
                // 繰り返し設定
                // alert.isRepeatingEnabled = isRepeating // isRepeatingEnabled is read-only, use repeatPattern instead
                if isRepeating && !repeatDays.isEmpty {
                    // WeekDayをビットマスクに変換
                    var bitmask: Int32 = 0
                    for day in repeatDays {
                        bitmask |= (1 << day.rawValue)
                    }
                    // alert.repeatDays = bitmask // Alert doesn't have repeatDays property
                }
                
                // 保存
                try context.save()
                continuation.resume(returning: alert)
            } catch {
                continuation.resume(throwing: AlertSetupError.coreDataError(error))
            }
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    func resetFlow() {
        setupData.reset()
        currentStep = .stationSearch
        isLoading = false
        errorMessage = nil
        isComplete = false
    }
    
    // MARK: - Edit Mode Methods
    
    /// 既存のアラートを読み込んで編集モードを初期化
    func loadExistingAlert(_ alert: Alert) {
        editingAlert = alert
        isEditMode = true
        
        // 駅情報を読み込み
        if let station = alert.station {
            let stationModel = StationModel(
                id: station.stationId ?? "",
                name: station.name ?? "",
                latitude: station.latitude,
                longitude: station.longitude,
                lines: station.lines ?? []
            )
            setupData.selectedStation = stationModel
        }
        
        // 通知設定を読み込み
        setupData.notificationTime = Int(alert.notificationTime)
        setupData.notificationDistance = alert.notificationDistance
        setupData.snoozeInterval = Int(alert.snoozeInterval)
        
        // 注: 以下のプロパティはAlertSetupDataには存在しないため、
        // 編集時はAlert自体から直接参照する
        // - notificationStationsBefore (駅数ベース通知)
        // - departureStation, arrivalTime, trainLine (経路情報)
        // - isRepeating, repeatDays (繰り返し設定)
        
        // キャラクタースタイルを逆マッピング
        let style: CharacterStyle = {
            switch alert.characterStyle {
            case "friendly":
                return .gyaru  // デフォルトとしてgyaruを使用
            case "polite":
                return .butler
            case "motivational":
                return .kansai  // デフォルトとしてkansaiを使用
            case "funny":
                return .tsundere
            default:
                return .gyaru
            }
        }()
        setupData.characterStyle = style
        
        // 編集時はレビューステップから開始
        currentStep = .review
    }
    
    /// 既存のアラートを更新
    private func updateAlertInCoreData() async throws -> Alert {
        guard let editingAlert = editingAlert,
              let station = setupData.selectedStation else {
            throw AlertSetupError.invalidForm
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Alert, Error>) in
            let context = coreDataManager.viewContext
            
            do {
                // 駅情報を更新
                let stationEntity = try Station.findOrCreate(
                    stationId: station.id,
                    name: station.name,
                    latitude: station.latitude,
                    longitude: station.longitude,
                    lines: station.lines,
                    in: context
                )
                editingAlert.station = stationEntity
                editingAlert.stationName = station.name
                
                // アラート設定を更新
                editingAlert.notificationTime = Int16(setupData.notificationTime)
                editingAlert.notificationDistance = setupData.notificationDistance
                editingAlert.snoozeInterval = Int16(setupData.snoozeInterval)
                editingAlert.characterStyle = setupData.characterStyle.rawValue
                // editingAlert.updatedAt = Date() // Alert doesn't have updatedAt property
                
                // 保存
                try context.save()
                continuation.resume(returning: editingAlert)
            } catch {
                continuation.resume(throwing: AlertSetupError.coreDataError(error))
            }
        }
    }
}

// MARK: - Error Types

enum AlertSetupError: LocalizedError {
    case invalidForm
    case stationNotSelected
    case invalidNotificationSettings
    case notificationPermissionDenied
    case coreDataError(Error)
    case networkError(Error)
    case invalidStationData
    
    var errorDescription: String? {
        switch self {
        case .invalidForm:
            return "入力内容に不正があります。すべての項目を正しく入力してください。"
        case .stationNotSelected:
            return "駅が選択されていません。"
        case .invalidNotificationSettings:
            return "通知設定が無効です。設定を確認してください。"
        case .notificationPermissionDenied:
            return "通知の許可が必要です。設定アプリから通知を許可してください。"
        case .coreDataError(let error):
            return "データの保存に失敗しました: \(error.localizedDescription)"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .invalidStationData:
            return "駅情報が不正です。別の駅を選択してください。"
        }
    }
}

// MARK: - Preview

extension AlertSetupViewModel {
    static func preview() -> AlertSetupViewModel {
        let viewModel = AlertSetupViewModel()
        
        // Sample station
        let previewStation = StationModel(
            id: "preview-001",
            name: "プレビュー駅",
            latitude: 35.6762,
            longitude: 139.6503,
            lines: []
        )
        
        viewModel.setupData.selectedStation = previewStation
        viewModel.setupData.notificationTime = 5
        viewModel.setupData.notificationDistance = 500
        viewModel.setupData.snoozeInterval = 5
        viewModel.setupData.characterStyle = .gyaru
        viewModel.currentStep = .review
        
        return viewModel
    }
}
