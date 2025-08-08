//
//  CrashReporter.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import UIKit
import os.signpost

/// Crash report information
struct CrashReport {
    let timestamp: Date
    let crashType: CrashType
    let stackTrace: [String]
    let deviceInfo: DeviceInfo
    let appState: AppState
    let customData: [String: Any]
    
    var reportID: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return "crash-\(formatter.string(from: timestamp))-\(UUID().uuidString.prefix(8))"
    }
}

/// Types of crashes/errors tracked
enum CrashType: String, CaseIterable {
    case uncaughtException = "uncaught_exception"
    case signal = "signal"
    case backgroundTaskTimeout = "bg_task_timeout"
    case locationServiceFailure = "location_failure"
    case notificationFailure = "notification_failure"
    case memoryPressure = "memory_pressure"
    case networkTimeout = "network_timeout"
    case coreDataError = "core_data_error"
    case unknown = "unknown"
    
    var severity: String {
        switch self {
        case .uncaughtException, .signal:
            return "critical"
        case .backgroundTaskTimeout, .locationServiceFailure, .notificationFailure:
            return "high"
        case .memoryPressure, .networkTimeout, .coreDataError:
            return "medium"
        case .unknown:
            return "low"
        }
    }
}

/// Device information for crash reports
struct DeviceInfo {
    let model: String
    let systemVersion: String
    let batteryLevel: Float
    let isLowPowerModeEnabled: Bool
    let memoryUsage: UInt64
    let diskSpace: UInt64
    let networkType: String
    
    init() {
        let device = UIDevice.current
        self.model = device.model
        self.systemVersion = device.systemVersion
        self.batteryLevel = device.batteryLevel
        self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        // Get memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        self.memoryUsage = kerr == KERN_SUCCESS ? info.resident_size : 0
        
        // Get disk space
        do {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            if let path = paths.first {
                let url = URL(fileURLWithPath: path)
                let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
                self.diskSpace = UInt64(values.volumeAvailableCapacity ?? 0)
            } else {
                self.diskSpace = 0
            }
        } catch {
            self.diskSpace = 0
        }
        
        // Network type (simplified)
        self.networkType = "unknown" // Would need network framework for detailed info
    }
}

/// Application state information
struct AppState {
    let isInBackground: Bool
    let isLocationUpdateActive: Bool
    let isNotificationPermissionGranted: Bool
    let activeBackgroundTasks: [String]
    let locationAccuracy: String
    let batteryOptimizationLevel: String
    
    init() {
        self.isInBackground = UIApplication.shared.applicationState != .active
        self.isLocationUpdateActive = false // Would be set by location manager
        self.isNotificationPermissionGranted = false // Would be checked
        self.activeBackgroundTasks = [] // Would be tracked by background task manager
        self.locationAccuracy = "unknown"
        self.batteryOptimizationLevel = "unknown"
    }
}

/// Comprehensive crash detection and reporting system
class CrashReporter {
    
    // MARK: - Singleton
    static let shared = CrashReporter()
    
    // MARK: - Properties
    private let logger = BackgroundLogger.shared
    private let fileManager = FileManager.default
    private let reportQueue = DispatchQueue(label: "com.trainalert.crash-reporter", qos: .utility)
    
    private var crashReportsDirectory: URL?
    private var isInstalled = false
    private var customData: [String: Any] = [:]
    
    // Signal handling
    private let signalsToHandle: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP]
    private var previousSignalHandlers: [Int32: sig_t] = [:]
    
    // Background task monitoring
    private var backgroundTaskTimeouts: [UIBackgroundTaskIdentifier: Date] = [:]
    private let backgroundTaskQueue = DispatchQueue(label: "com.trainalert.bg-task-monitor")
    
    // MARK: - Initialization
    
    private init() {
        setupCrashReportsDirectory()
    }
    
    // MARK: - Installation
    
    /// Install crash reporter
    func install() {
        guard !isInstalled else {
            logger.warning("Crash reporter already installed", category: .crash)
            return
        }
        
        installSignalHandlers()
        installExceptionHandler()
        setupNotificationObservers()
        
        isInstalled = true
        logger.info("Crash reporter installed successfully", category: .crash)
        
        // Check for any previous crash reports
        processPendingCrashReports()
    }
    
    /// Uninstall crash reporter
    func uninstall() {
        guard isInstalled else { return }
        
        restoreSignalHandlers()
        NSSetUncaughtExceptionHandler(nil)
        NotificationCenter.default.removeObserver(self)
        
        isInstalled = false
        logger.info("Crash reporter uninstalled", category: .crash)
    }
    
    // MARK: - Private Setup Methods
    
    private func setupCrashReportsDirectory() {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get documents directory for crash reports", category: .crash)
            return
        }
        
        crashReportsDirectory = documentsPath.appendingPathComponent("CrashReports")
        
        if let directory = crashReportsDirectory,
           !fileManager.fileExists(atPath: directory.path) {
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                logger.info("Created crash reports directory", category: .crash)
            } catch {
                logger.error("Failed to create crash reports directory: \(error.localizedDescription)", category: .crash)
            }
        }
    }
    
    private func installSignalHandlers() {
        for signal in signalsToHandle {
            let previousHandler = Foundation.signal(signal) { signalNumber in
                CrashReporter.shared.handleSignal(signalNumber)
            }
            previousSignalHandlers[signal] = previousHandler
        }
    }
    
    private func restoreSignalHandlers() {
        for (signal, handler) in previousSignalHandlers {
            Foundation.signal(signal, handler)
        }
        previousSignalHandlers.removeAll()
    }
    
    private func installExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppTermination()
        }
    }
    
    // MARK: - Crash Handling
    
    private func handleSignal(_ signal: Int32) {
        let crashReport = createCrashReport(
            type: .signal,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: ["signal": signal]
        )
        
        saveCrashReport(crashReport)
        logger.critical("Signal \(signal) received", category: .crash)
        
        // Restore original handler and re-raise
        if let originalHandler = previousSignalHandlers[signal] {
            Foundation.signal(signal, originalHandler)
        }
        raise(signal)
    }
    
    private func handleException(_ exception: NSException) {
        let crashReport = createCrashReport(
            type: .uncaughtException,
            stackTrace: exception.callStackSymbols,
            additionalInfo: [
                "name": exception.name.rawValue,
                "reason": exception.reason ?? "Unknown",
                "userInfo": exception.userInfo ?? [:]
            ]
        )
        
        saveCrashReport(crashReport)
        logger.critical("Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "Unknown")", category: .crash)
    }
    
    private func handleMemoryPressure() {
        logger.warning("Memory pressure detected", category: .crash)
        
        let crashReport = createCrashReport(
            type: .memoryPressure,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: [
                "available_memory": getAvailableMemory(),
                "memory_usage": DeviceInfo().memoryUsage
            ]
        )
        
        saveCrashReport(crashReport)
    }
    
    private func handleAppBackground() {
        logger.info("App entering background", category: .crash)
        setCustomData("last_background_time", Date())
    }
    
    private func handleAppTermination() {
        logger.info("App terminating", category: .crash)
        
        // Save any pending data
        let terminationReport = createCrashReport(
            type: .unknown,
            stackTrace: [],
            additionalInfo: ["termination_type": "normal"]
        )
        
        saveCrashReport(terminationReport)
    }
    
    // MARK: - Background Task Monitoring
    
    /// Monitor background task for timeout
    func monitorBackgroundTask(_ identifier: UIBackgroundTaskIdentifier, timeout: TimeInterval = 30) {
        backgroundTaskQueue.async { [weak self] in
            let startTime = Date()
            self?.backgroundTaskTimeouts[identifier] = startTime
            
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.backgroundTaskQueue.async {
                    if let _ = self?.backgroundTaskTimeouts[identifier] {
                        // Task is still running after timeout
                        self?.handleBackgroundTaskTimeout(identifier, startTime: startTime)
                    }
                }
            }
        }
    }
    
    /// Mark background task as completed
    func backgroundTaskCompleted(_ identifier: UIBackgroundTaskIdentifier) {
        backgroundTaskQueue.async { [weak self] in
            self?.backgroundTaskTimeouts.removeValue(forKey: identifier)
        }
    }
    
    private func handleBackgroundTaskTimeout(_ identifier: UIBackgroundTaskIdentifier, startTime: Date) {
        let duration = Date().timeIntervalSince(startTime)
        
        let crashReport = createCrashReport(
            type: .backgroundTaskTimeout,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: [
                "task_identifier": String(identifier.rawValue),
                "duration": duration,
                "remaining_time": UIApplication.shared.backgroundTimeRemaining
            ]
        )
        
        saveCrashReport(crashReport)
        logger.error("Background task timeout - ID: \(identifier.rawValue), Duration: \(duration)s", category: .crash)
    }
    
    // MARK: - Service-Specific Error Handling
    
    /// Report location service failure
    func reportLocationServiceFailure(_ error: Error, context: [String: Any] = [:]) {
        var additionalInfo = context
        additionalInfo["error"] = error.localizedDescription
        
        let crashReport = createCrashReport(
            type: .locationServiceFailure,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: additionalInfo
        )
        
        saveCrashReport(crashReport)
        logger.error("Location service failure: \(error.localizedDescription)", category: .crash)
    }
    
    /// Report notification delivery failure
    func reportNotificationFailure(_ error: Error, notificationId: String, context: [String: Any] = [:]) {
        var additionalInfo = context
        additionalInfo["error"] = error.localizedDescription
        additionalInfo["notification_id"] = notificationId
        
        let crashReport = createCrashReport(
            type: .notificationFailure,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: additionalInfo
        )
        
        saveCrashReport(crashReport)
        logger.error("Notification delivery failure: \(error.localizedDescription)", category: .crash)
    }
    
    /// Report Core Data error
    func reportCoreDataError(_ error: Error, context: [String: Any] = [:]) {
        var additionalInfo = context
        additionalInfo["error"] = error.localizedDescription
        
        let crashReport = createCrashReport(
            type: .coreDataError,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: additionalInfo
        )
        
        saveCrashReport(crashReport)
        logger.error("Core Data error: \(error.localizedDescription)", category: .crash)
    }
    
    /// Report network timeout
    func reportNetworkTimeout(_ error: Error, url: String, timeout: TimeInterval, context: [String: Any] = [:]) {
        var additionalInfo = context
        additionalInfo["error"] = error.localizedDescription
        additionalInfo["url"] = url
        additionalInfo["timeout"] = timeout
        
        let crashReport = createCrashReport(
            type: .networkTimeout,
            stackTrace: getCurrentStackTrace(),
            additionalInfo: additionalInfo
        )
        
        saveCrashReport(crashReport)
        logger.error("Network timeout: \(url) after \(timeout)s", category: .crash)
    }
    
    // MARK: - Report Management
    
    private func createCrashReport(type: CrashType, stackTrace: [String], additionalInfo: [String: Any] = [:]) -> CrashReport {
        var customDataCopy = customData
        for (key, value) in additionalInfo {
            customDataCopy[key] = value
        }
        
        return CrashReport(
            timestamp: Date(),
            crashType: type,
            stackTrace: stackTrace,
            deviceInfo: DeviceInfo(),
            appState: AppState(),
            customData: customDataCopy
        )
    }
    
    private func saveCrashReport(_ report: CrashReport) {
        reportQueue.async { [weak self] in
            guard let self = self,
                  let directory = self.crashReportsDirectory else {
                return
            }
            
            let reportFile = directory.appendingPathComponent("\(report.reportID).json")
            
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = .prettyPrinted
                
                let data = try encoder.encode(report)
                try data.write(to: reportFile)
                
                self.logger.info("Crash report saved: \(report.reportID)", category: .crash)
                
                // Clean up old reports
                self.cleanupOldReports()
                
            } catch {
                self.logger.error("Failed to save crash report: \(error.localizedDescription)", category: .crash)
            }
        }
    }
    
    private func processPendingCrashReports() {
        reportQueue.async { [weak self] in
            guard let self = self else { return }
            
            let reports = self.getCrashReports()
            if reports.count > 0 {
                self.logger.info("Found \(reports.count) pending crash reports", category: .crash)
                
                // In a real implementation, you might send these to a crash reporting service
                for report in reports {
                    self.logger.info("Pending crash report: \(report.reportID) - \(report.crashType.rawValue)", category: .crash)
                }
            }
        }
    }
    
    private func cleanupOldReports() {
        guard let directory = crashReportsDirectory else { return }
        
        do {
            let reportFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "json" }
                .sorted { (file1, file2) in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only the most recent 50 reports
            for fileToDelete in reportFiles.dropFirst(50) {
                try? fileManager.removeItem(at: fileToDelete)
            }
        } catch {
            logger.error("Error cleaning up crash reports: \(error.localizedDescription)", category: .crash)
        }
    }
    
    // MARK: - Public Methods
    
    /// Set custom data to be included in crash reports
    func setCustomData(_ key: String, _ value: Any) {
        reportQueue.async { [weak self] in
            self?.customData[key] = value
        }
    }
    
    /// Remove custom data
    func removeCustomData(_ key: String) {
        reportQueue.async { [weak self] in
            self?.customData.removeValue(forKey: key)
        }
    }
    
    /// Get all crash reports
    func getCrashReports() -> [CrashReport] {
        guard let directory = crashReportsDirectory else { return [] }
        
        do {
            let reportFiles = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "json" }
            
            var reports: [CrashReport] = []
            
            for file in reportFiles {
                if let data = try? Data(contentsOf: file) {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    if let report = try? decoder.decode(CrashReport.self, from: data) {
                        reports.append(report)
                    }
                }
            }
            
            return reports.sorted { $0.timestamp > $1.timestamp }
        } catch {
            logger.error("Error reading crash reports: \(error.localizedDescription)", category: .crash)
            return []
        }
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentStackTrace() -> [String] {
        return Thread.callStackSymbols
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    deinit {
        if isInstalled {
            uninstall()
        }
    }
}

// MARK: - CrashReport Codable Extension

extension CrashReport: Codable {
    enum CodingKeys: String, CodingKey {
        case timestamp, crashType, stackTrace, deviceInfo, appState, customData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(crashType.rawValue, forKey: .crashType)
        try container.encode(stackTrace, forKey: .stackTrace)
        try container.encode(deviceInfo, forKey: .deviceInfo)
        try container.encode(appState, forKey: .appState)
        
        // Handle custom data serialization
        if let jsonData = try? JSONSerialization.data(withJSONObject: customData, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .customData)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        let crashTypeString = try container.decode(String.self, forKey: .crashType)
        crashType = CrashType(rawValue: crashTypeString) ?? .unknown
        
        stackTrace = try container.decode([String].self, forKey: .stackTrace)
        deviceInfo = try container.decode(DeviceInfo.self, forKey: .deviceInfo)
        appState = try container.decode(AppState.self, forKey: .appState)
        
        // Handle custom data deserialization
        if let jsonString = try? container.decode(String.self, forKey: .customData),
           let jsonData = jsonString.data(using: .utf8),
           let customDataDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            customData = customDataDict
        } else {
            customData = [:]
        }
    }
}

extension DeviceInfo: Codable {}
extension AppState: Codable {}
