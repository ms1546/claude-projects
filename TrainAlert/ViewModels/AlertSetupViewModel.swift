//
//  AlertSetupViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreData
import Combine
import CoreLocation

@MainActor
class AlertSetupViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published var setupData = AlertSetupData()
    @Published var currentStep: AlertSetupStep = .stationSearch
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false
    
    private let coreDataManager: CoreDataManager
    private let notificationManager: NotificationManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Enums
    
    enum AlertSetupStep: Int, CaseIterable {
        case stationSearch = 0
        case alertSettings = 1
        case characterSelection = 2
        case review = 3
        
        var title: String {
            switch self {
            case .stationSearch:
                return "駅選択"
            case .alertSettings:
                return "通知設定"
            case .characterSelection:
                return "キャラクター選択"
            case .review:
                return "確認"
            }
        }
        
        var progress: Double {
            return Double(rawValue + 1) / Double(AlertSetupStep.allCases.count)
        }
    }
    
    // MARK: - Init
    
    init(coreDataManager: CoreDataManager = .shared, notificationManager: NotificationManager = .shared) {
        self.coreDataManager = coreDataManager
        self.notificationManager = notificationManager
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Monitor form validation changes
        setupData.$selectedStation
            .combineLatest(
                setupData.$notificationTime,
                setupData.$notificationDistance,
                setupData.$snoozeInterval
            )
            .map { station, time, distance, snooze in
                return station != nil &&
                       time >= 0 && time <= 60 &&
                       distance >= 50 && distance <= 10000 &&
                       snooze >= 1 && snooze <= 30
            }
            .sink { [weak self] isValid in
                // Could be used for additional validation logic
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Navigation Methods
    
    func goToNextStep() {
        guard canProceedToNext() else { return }
        
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
    
    func canProceedToNext() -> Bool {
        switch currentStep {
        case .stationSearch:
            return setupData.isStationSelected
        case .alertSettings:
            return setupData.isNotificationTimeValid &&
                   setupData.isNotificationDistanceValid &&
                   setupData.isSnoozeIntervalValid
        case .characterSelection:
            return true // Character style is always valid as it has a default
        case .review:
            return setupData.isFormValid
        }
    }
    
    // MARK: - Alert Creation
    
    func createAlert() async throws -> Bool {
        guard setupData.isFormValid else {
            throw AlertSetupError.invalidForm
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create alert in Core Data
            let alert = try await createAlertInCoreData()
            
            // Schedule notifications if needed
            try await scheduleNotifications(for: alert)
            
            // Mark setup as complete
            isComplete = true
            isLoading = false
            
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            throw error
        }
    }
    
    private func createAlertInCoreData() async throws -> Alert {
        return try await withCheckedThrowingContinuation { continuation in
            coreDataManager.persistentContainer.performBackgroundTask { context in
                do {
                    // Create alert
                    let alert = Alert(context: context)
                    alert.alertId = UUID()
                    alert.createdAt = Date()
                    alert.isActive = true
                    alert.notificationTime = Int16(self.setupData.notificationTime)
                    alert.notificationDistance = self.setupData.notificationDistance
                    alert.snoozeInterval = Int16(self.setupData.snoozeInterval)
                    alert.characterStyle = self.setupData.characterStyle.rawValue
                    
                    // Create or find station
                    if let selectedStation = self.setupData.selectedStation {
                        let stationEntity = self.findOrCreateStation(selectedStation, in: context)
                        alert.station = stationEntity
                    }
                    
                    // Save context
                    try context.save()
                    
                    // Return alert ID to main context
                    let alertId = alert.objectID
                    
                    DispatchQueue.main.async {
                        do {
                            guard let mainAlert = try self.coreDataManager.viewContext.existingObject(with: alertId) as? Alert else {
                                let error = NSError(
                                    domain: "AlertSetup",
                                    code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to convert to Alert object"]
                                )
                                continuation.resume(throwing: AlertSetupError.coreDataError(error))
                                return
                            }
                            continuation.resume(returning: mainAlert)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func findOrCreateStation(_ station: StationModel, in context: NSManagedObjectContext) -> Station {
        // Try to find existing station
        let fetchRequest: NSFetchRequest<Station> = Station.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "stationId == %@", station.id)
        fetchRequest.fetchLimit = 1
        
        if let existingStation = try? context.fetch(fetchRequest).first {
            return existingStation
        }
        
        // Create new station
        let newStation = Station(context: context)
        newStation.stationId = station.id
        newStation.name = station.name
        newStation.latitude = station.latitude
        newStation.longitude = station.longitude
        // Set lines using the computed property
        newStation.lineNames = station.lines
        
        return newStation
    }
    
    private func scheduleNotifications(for alert: Alert) async throws {
        // Request notification permission first
        try await notificationManager.requestAuthorization()
        
        // Check if permission is granted
        if !notificationManager.isPermissionGranted {
            throw AlertSetupError.notificationPermissionDenied
        }
        
        // Schedule notifications based on alert settings
        guard let station = alert.station,
              let stationName = station.name else {
            throw AlertSetupError.invalidStationData
        }
        
        let targetLocation = CLLocation(latitude: station.latitude, longitude: station.longitude)
        try await notificationManager.scheduleLocationBasedAlert(
            for: stationName,
            targetLocation: targetLocation,
            radius: alert.notificationDistance
        )
    }
    
    // MARK: - Form Management
    
    func resetForm() {
        setupData.reset()
        currentStep = .stationSearch
        isComplete = false
        errorMessage = nil
        isLoading = false
    }
    
    func validateCurrentStep() -> Bool {
        return canProceedToNext()
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Station Selection
    
    func selectStation(_ station: StationModel) {
        setupData.selectedStation = station
        
        // Automatically proceed to next step
        if canProceedToNext() {
            goToNextStep()
        }
    }
    
    // MARK: - Settings Updates
    
    func updateNotificationSettings(time: Int? = nil, distance: Double? = nil, snooze: Int? = nil) {
        if let time = time {
            setupData.setNotificationTime(time)
        }
        
        if let distance = distance {
            setupData.setNotificationDistance(distance)
        }
        
        if let snooze = snooze {
            setupData.setSnoozeInterval(snooze)
        }
    }
    
    func updateCharacterStyle(_ style: CharacterStyle) {
        setupData.characterStyle = style
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
            return "通知の許可が必要です。設定アプリで許可してください。"
        case .coreDataError(let error):
            return "データの保存に失敗しました: \(error.localizedDescription)"
        case .networkError(let error):
            return "ネットワークエラーが発生しました: \(error.localizedDescription)"
        case .invalidStationData:
            return "駅データが無効です。駅を再選択してください。"
        }
    }
}

// MARK: - Extensions

extension AlertSetupViewModel {
    
    /// テスト用のプレビューデータを設定
    func setupPreviewData() {
        let previewStation = StationModel(
            id: "preview_station",
            name: "渋谷駅",
            latitude: 35.6580,
            longitude: 139.7016,
            lines: ["JR山手線", "東急東横線", "京王井の頭線"]
        )
        
        setupData.selectedStation = previewStation
        setupData.notificationTime = 5
        setupData.notificationDistance = 500
        setupData.snoozeInterval = 5
        setupData.characterStyle = .gyaru
        currentStep = .review
    }
}
