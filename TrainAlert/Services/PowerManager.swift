//
//  PowerManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import UIKit
import Combine

/// Power management configuration
struct PowerConfiguration {
    let batteryThresholds: BatteryThresholds
    let adaptiveBehavior: AdaptiveBehavior
    let emergencySettings: EmergencySettings
    
    struct BatteryThresholds {
        let critical: Float = 0.10    // 10%
        let low: Float = 0.20         // 20%
        let medium: Float = 0.50      // 50%
        let high: Float = 0.80        // 80%
    }
    
    struct AdaptiveBehavior {
        let enableLocationAccuracyReduction: Bool = true
        let enableNotificationThrottling: Bool = true
        let enableBackgroundTaskOptimization: Bool = true
        let enableNetworkRequestBatching: Bool = true
    }
    
    struct EmergencySettings {
        let enableEmergencyMode: Bool = true
        let emergencyBatteryLevel: Float = 0.05  // 5%
        let emergencyLocationAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers
        let emergencyUpdateInterval: TimeInterval = 600  // 10 minutes
    }
    
    static let `default` = PowerConfiguration(
        batteryThresholds: BatteryThresholds(),
        adaptiveBehavior: AdaptiveBehavior(),
        emergencySettings: EmergencySettings()
    )
}

/// Battery level categories
enum BatteryLevel: String, CaseIterable {
    case critical = "critical"    // < 10%
    case low = "low"             // 10-20%
    case medium = "medium"       // 20-50%
    case high = "high"           // 50-80%
    case full = "full"           // > 80%
    case unknown = "unknown"     // Battery monitoring disabled
    
    init(batteryLevel: Float, thresholds: PowerConfiguration.BatteryThresholds) {
        if batteryLevel < 0 {
            self = .unknown
        } else if batteryLevel < thresholds.critical {
            self = .critical
        } else if batteryLevel < thresholds.low {
            self = .low
        } else if batteryLevel < thresholds.medium {
            self = .medium
        } else if batteryLevel < thresholds.high {
            self = .high
        } else {
            self = .full
        }
    }
    
    var description: String {
        switch self {
        case .critical: return "Critical (< 10%)"
        case .low: return "Low (10-20%)"
        case .medium: return "Medium (20-50%)"
        case .high: return "High (50-80%)"
        case .full: return "Full (> 80%)"
        case .unknown: return "Unknown"
        }
    }
}

/// Power optimization recommendations
struct PowerOptimization {
    let locationAccuracy: LocationAccuracyTier
    let updateInterval: TimeInterval
    let backgroundTaskLimit: Int
    let notificationBatching: Bool
    let networkRequestBatching: Bool
    let reason: String
    
    static func recommendation(for batteryLevel: BatteryLevel, isLowPowerMode: Bool, isCharging: Bool) -> PowerOptimization {
        switch (batteryLevel, isLowPowerMode, isCharging) {
        case (.critical, _, false):
            return PowerOptimization(
                locationAccuracy: .minimal,
                updateInterval: 600, // 10 minutes
                backgroundTaskLimit: 1,
                notificationBatching: true,
                networkRequestBatching: true,
                reason: "Critical battery level - extreme power saving"
            )
            
        case (.low, true, false):
            return PowerOptimization(
                locationAccuracy: .low,
                updateInterval: 300, // 5 minutes
                backgroundTaskLimit: 2,
                notificationBatching: true,
                networkRequestBatching: true,
                reason: "Low battery with Low Power Mode enabled"
            )
            
        case (.low, false, false):
            return PowerOptimization(
                locationAccuracy: .balanced,
                updateInterval: 120, // 2 minutes
                backgroundTaskLimit: 3,
                notificationBatching: false,
                networkRequestBatching: true,
                reason: "Low battery level"
            )
            
        case (.medium, true, _):
            return PowerOptimization(
                locationAccuracy: .balanced,
                updateInterval: 90, // 1.5 minutes
                backgroundTaskLimit: 4,
                notificationBatching: false,
                networkRequestBatching: false,
                reason: "Medium battery with Low Power Mode enabled"
            )
            
        case (_, _, true):
            return PowerOptimization(
                locationAccuracy: .high,
                updateInterval: 30, // 30 seconds
                backgroundTaskLimit: 6,
                notificationBatching: false,
                networkRequestBatching: false,
                reason: "Device is charging"
            )
            
        default:
            return PowerOptimization(
                locationAccuracy: .balanced,
                updateInterval: 60, // 1 minute
                backgroundTaskLimit: 5,
                notificationBatching: false,
                networkRequestBatching: false,
                reason: "Standard power management"
            )
        }
    }
}

/// Power management delegate
protocol PowerManagerDelegate: AnyObject {
    func powerManager(_ manager: PowerManager, didChangeBatteryLevel level: BatteryLevel)
    func powerManager(_ manager: PowerManager, didChangeLowPowerMode enabled: Bool)
    func powerManager(_ manager: PowerManager, didChangeChargingState isCharging: Bool)
    func powerManager(_ manager: PowerManager, didUpdateOptimization optimization: PowerOptimization)
    func powerManager(_ manager: PowerManager, didEnterEmergencyMode enabled: Bool)
}

/// Comprehensive power management system
class PowerManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var batteryLevel: Float = -1.0
    @Published var batteryCategory: BatteryLevel = .unknown
    @Published var isLowPowerModeEnabled: Bool = false
    @Published var isCharging: Bool = false
    @Published var currentOptimization: PowerOptimization
    @Published var isEmergencyMode: Bool = false
    @Published var isMonitoring: Bool = false
    
    // MARK: - Properties
    private let logger = BackgroundLogger.shared
    private let crashReporter = CrashReporter.shared
    private let configuration: PowerConfiguration
    
    weak var delegate: PowerManagerDelegate?
    
    private var cancellables = Set<AnyCancellable>()
    private var batteryTimer: Timer?
    private var powerOptimizationHistory: [(Date, PowerOptimization)] = []
    
    // Tracking properties
    private var lastBatteryUpdate = Date()
    private var batteryDrainRate: Float = 0.0 // % per hour
    private var averagePowerConsumption: Float = 0.0
    
    // MARK: - Initialization
    
    init(configuration: PowerConfiguration = .default) {
        self.configuration = configuration
        
        // Initialize with default optimization
        self.currentOptimization = PowerOptimization.recommendation(
            for: .unknown,
            isLowPowerMode: false,
            isCharging: false
        )
        
        setupBatteryMonitoring()
        setupPowerStateObservers()
    }
    
    // MARK: - Public Methods
    
    /// Start power monitoring
    func startMonitoring() {
        guard !isMonitoring else {
            logger.warning("Power monitoring already started", category: .power)
            return
        }
        
        enableBatteryMonitoring()
        updatePowerState()
        startBatteryTracking()
        
        isMonitoring = true
        logger.info("Power monitoring started", category: .power)
    }
    
    /// Stop power monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        disableBatteryMonitoring()
        stopBatteryTracking()
        
        isMonitoring = false
        logger.info("Power monitoring stopped", category: .power)
    }
    
    /// Get current power optimization recommendations
    func getCurrentOptimization() -> PowerOptimization {
        return currentOptimization
    }
    
    /// Get battery drain rate (% per hour)
    func getBatteryDrainRate() -> Float {
        return batteryDrainRate
    }
    
    /// Get estimated battery life remaining
    func getEstimatedBatteryLife() -> TimeInterval? {
        guard batteryLevel > 0, batteryDrainRate > 0 else { return nil }
        
        let remainingBattery = batteryLevel
        let hoursRemaining = remainingBattery / batteryDrainRate
        return TimeInterval(hoursRemaining * 3600) // Convert to seconds
    }
    
    /// Check if device should enter emergency mode
    func shouldEnterEmergencyMode() -> Bool {
        return batteryLevel > 0 &&
               batteryLevel < configuration.emergencySettings.emergencyBatteryLevel &&
               !isCharging &&
               configuration.emergencySettings.enableEmergencyMode
    }
    
    /// Manually trigger emergency mode
    func enableEmergencyMode(_ enabled: Bool) {
        guard enabled != isEmergencyMode else { return }
        
        isEmergencyMode = enabled
        
        if enabled {
            logger.warning("Emergency power mode enabled", category: .power)
            applyEmergencyOptimizations()
        } else {
            logger.info("Emergency power mode disabled", category: .power)
            updateOptimizations()
        }
        
        delegate?.powerManager(self, didEnterEmergencyMode: enabled)
        crashReporter.setCustomData("emergency_mode", enabled)
    }
    
    /// Get power optimization history
    func getOptimizationHistory() -> [(Date, PowerOptimization)] {
        return powerOptimizationHistory
    }
    
    /// Get power consumption statistics
    func getPowerStatistics() -> PowerStatistics {
        return PowerStatistics(
            batteryLevel: batteryLevel,
            batteryCategory: batteryCategory,
            drainRate: batteryDrainRate,
            averageConsumption: averagePowerConsumption,
            isLowPowerMode: isLowPowerModeEnabled,
            isCharging: isCharging,
            isEmergencyMode: isEmergencyMode,
            optimizationChanges: powerOptimizationHistory.count,
            lastUpdate: lastBatteryUpdate
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBatteryMonitoring() {
        let device = UIDevice.current
        
        // Enable battery monitoring if not already enabled
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }
        
        // Initial values
        batteryLevel = device.batteryLevel
        batteryCategory = BatteryLevel(batteryLevel: batteryLevel, thresholds: configuration.batteryThresholds)
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // Determine charging state
        switch device.batteryState {
        case .charging, .full:
            isCharging = true
        case .unplugged:
            isCharging = false
        case .unknown:
            isCharging = false
        @unknown default:
            isCharging = false
        }
    }
    
    private func setupPowerStateObservers() {
        // Battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleBatteryLevelChange()
            }
            .store(in: &cancellables)
        
        // Battery state changes (charging/unplugged)
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleBatteryStateChange()
            }
            .store(in: &cancellables)
        
        // Low power mode changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.handleLowPowerModeChange()
            }
            .store(in: &cancellables)
    }
    
    private func enableBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        logger.info("Battery monitoring enabled", category: .power)
    }
    
    private func disableBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        logger.info("Battery monitoring disabled", category: .power)
    }
    
    private func startBatteryTracking() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.trackBatteryConsumption()
        }
    }
    
    private func stopBatteryTracking() {
        batteryTimer?.invalidate()
        batteryTimer = nil
    }
    
    private func handleBatteryLevelChange() {
        let device = UIDevice.current
        let newBatteryLevel = device.batteryLevel
        let newBatteryCategory = BatteryLevel(batteryLevel: newBatteryLevel, thresholds: configuration.batteryThresholds)
        
        logger.info("Battery level changed: \(String(format: "%.1f", newBatteryLevel * 100))% (\(newBatteryCategory.rawValue))", category: .power)
        
        batteryLevel = newBatteryLevel
        
        if batteryCategory != newBatteryCategory {
            batteryCategory = newBatteryCategory
            delegate?.powerManager(self, didChangeBatteryLevel: newBatteryCategory)
            updateOptimizations()
        }
        
        // Check for emergency mode
        if shouldEnterEmergencyMode() && !isEmergencyMode {
            enableEmergencyMode(true)
        } else if isEmergencyMode && (!shouldEnterEmergencyMode() || isCharging) {
            enableEmergencyMode(false)
        }
    }
    
    private func handleBatteryStateChange() {
        let device = UIDevice.current
        let wasCharging = isCharging
        
        switch device.batteryState {
        case .charging, .full:
            isCharging = true
        case .unplugged:
            isCharging = false
        case .unknown:
            isCharging = false
        @unknown default:
            isCharging = false
        }
        
        if wasCharging != isCharging {
            logger.info("Charging state changed: \(isCharging ? "charging" : "not charging")", category: .power)
            delegate?.powerManager(self, didChangeChargingState: isCharging)
            updateOptimizations()
            
            // Disable emergency mode if charging
            if isCharging && isEmergencyMode {
                enableEmergencyMode(false)
            }
        }
    }
    
    private func handleLowPowerModeChange() {
        let newLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerModeEnabled != newLowPowerMode {
            isLowPowerModeEnabled = newLowPowerMode
            logger.info("Low Power Mode changed: \(newLowPowerMode ? "enabled" : "disabled")", category: .power)
            delegate?.powerManager(self, didChangeLowPowerMode: newLowPowerMode)
            updateOptimizations()
        }
    }
    
    private func updatePowerState() {
        handleBatteryLevelChange()
        handleBatteryStateChange()
        handleLowPowerModeChange()
    }
    
    private func updateOptimizations() {
        guard !isEmergencyMode else { return }
        
        let newOptimization = PowerOptimization.recommendation(
            for: batteryCategory,
            isLowPowerMode: isLowPowerModeEnabled,
            isCharging: isCharging
        )
        
        if newOptimization.locationAccuracy != currentOptimization.locationAccuracy ||
           newOptimization.updateInterval != currentOptimization.updateInterval {
            
            currentOptimization = newOptimization
            powerOptimizationHistory.append((Date(), newOptimization))
            
            // Keep only last 50 optimization changes
            if powerOptimizationHistory.count > 50 {
                powerOptimizationHistory.removeFirst()
            }
            
            logger.info("Power optimization updated: \(newOptimization.reason)", category: .power)
            delegate?.powerManager(self, didUpdateOptimization: newOptimization)
        }
    }
    
    private func applyEmergencyOptimizations() {
        let emergencyOptimization = PowerOptimization(
            locationAccuracy: .minimal,
            updateInterval: configuration.emergencySettings.emergencyUpdateInterval,
            backgroundTaskLimit: 1,
            notificationBatching: true,
            networkRequestBatching: true,
            reason: "Emergency mode - extreme power saving"
        )
        
        currentOptimization = emergencyOptimization
        powerOptimizationHistory.append((Date(), emergencyOptimization))
        
        delegate?.powerManager(self, didUpdateOptimization: emergencyOptimization)
    }
    
    private func trackBatteryConsumption() {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastBatteryUpdate) / 3600.0 // Convert to hours
        
        guard timeDelta > 0, batteryLevel > 0 else { return }
        
        // Calculate drain rate (simplified - would need previous battery level)
        let device = UIDevice.current
        let currentBatteryLevel = device.batteryLevel
        
        if batteryLevel != currentBatteryLevel && timeDelta > 0 {
            let batteryDelta = batteryLevel - currentBatteryLevel
            if batteryDelta > 0 { // Battery decreased
                batteryDrainRate = batteryDelta / Float(timeDelta)
                logger.debug("Battery drain rate: \(String(format: "%.2f", batteryDrainRate * 100))%/hour", category: .power)
            }
        }
        
        lastBatteryUpdate = now
        
        // Update average power consumption (simplified calculation)
        averagePowerConsumption = (averagePowerConsumption * 0.9) + (batteryDrainRate * 0.1)
    }
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
    }
}

// MARK: - Power Statistics

struct PowerStatistics {
    let batteryLevel: Float
    let batteryCategory: BatteryLevel
    let drainRate: Float
    let averageConsumption: Float
    let isLowPowerMode: Bool
    let isCharging: Bool
    let isEmergencyMode: Bool
    let optimizationChanges: Int
    let lastUpdate: Date
    
    var formattedBatteryLevel: String {
        guard batteryLevel >= 0 else { return "Unknown" }
        return String(format: "%.1f%%", batteryLevel * 100)
    }
    
    var formattedDrainRate: String {
        guard drainRate > 0 else { return "Unknown" }
        return String(format: "%.2f%%/hour", drainRate * 100)
    }
    
    var estimatedTimeRemaining: String? {
        guard batteryLevel > 0, drainRate > 0 else { return nil }
        
        let hoursRemaining = batteryLevel / drainRate
        
        if hoursRemaining < 1 {
            let minutes = Int(hoursRemaining * 60)
            return "\(minutes)m"
        } else if hoursRemaining < 24 {
            let hours = Int(hoursRemaining)
            let minutes = Int((hoursRemaining - Float(hours)) * 60)
            return "\(hours)h \(minutes)m"
        } else {
            let days = Int(hoursRemaining / 24)
            let hours = Int(hoursRemaining.truncatingRemainder(dividingBy: 24))
            return "\(days)d \(hours)h"
        }
    }
}
