//
//  BackgroundLogger.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import OSLog
import UIKit

/// Log levels for background operations
enum LogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4
    
    var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

/// Log categories for different components
enum LogCategory: String, CaseIterable {
    case location = "Location"
    case notification = "Notification"
    case background = "Background"
    case power = "Power"
    case crash = "Crash"
    case network = "Network"
    case general = "General"
    
    var subsystem: String {
        return "com.trainalert.app"
    }
}

/// Comprehensive logging system optimized for background operations
class BackgroundLogger {
    
    // MARK: - Singleton
    static let shared = BackgroundLogger()
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.trainalert.logging", qos: .utility)
    private var loggers: [LogCategory: Logger] = [:]
    
    // Log file management
    private let maxLogFileSize: Int = 5 * 1024 * 1024 // 5MB
    private let maxLogFiles: Int = 5
    private var currentLogFile: URL?
    private var logFileHandle: FileHandle?
    
    // Performance tracking
    private var performanceMetrics: [String: [TimeInterval]] = [:]
    private let metricsQueue = DispatchQueue(label: "com.trainalert.metrics", qos: .utility)
    
    // Settings
    private var minimumLogLevel: LogLevel = .info
    private var isFileLoggingEnabled: Bool = true
    private var isConsoleLoggingEnabled: Bool = true
    
    // MARK: - Initialization
    
    private init() {
        setupLoggers()
        setupLogFileSystem()
        setupPerformanceTracking()
    }
    
    private func setupLoggers() {
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: category.subsystem, category: category.rawValue)
        }
    }
    
    private func setupLogFileSystem() {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return
        }
        
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        // Create logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }
        
        // Set up current log file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let logFileName = "trainalert-\(dateFormatter.string(from: Date())).log"
        currentLogFile = logsDirectory.appendingPathComponent(logFileName)
        
        // Create log file and get handle
        if let logFile = currentLogFile {
            fileManager.createFile(atPath: logFile.path, contents: nil, attributes: nil)
            logFileHandle = try? FileHandle(forWritingTo: logFile)
        }
        
        // Clean up old log files
        cleanupOldLogFiles()
    }
    
    private func setupPerformanceTracking() {
        // Start battery level monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logBatteryLevel()
        }
        
        // Start memory pressure monitoring
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.log("Memory warning received", level: .warning, category: .general)
        }
    }
    
    // MARK: - Public Logging Methods
    
    /// Log message with specified level and category
    func log(_ message: String, level: LogLevel = .info, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue >= minimumLogLevel.rawValue else { return }
        
        logQueue.async { [weak self] in
            self?.performLog(message, level: level, category: category, file: file, function: function, line: line)
        }
    }
    
    /// Log debug message
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Log info message
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log warning message
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log error message
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log critical message
    func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Performance Tracking
    
    /// Start performance measurement
    func startPerformanceMeasurement(_ identifier: String) {
        metricsQueue.async { [weak self] in
            if self?.performanceMetrics[identifier] == nil {
                self?.performanceMetrics[identifier] = []
            }
            self?.performanceMetrics[identifier]?.append(Date().timeIntervalSince1970)
        }
    }
    
    /// End performance measurement and log result
    func endPerformanceMeasurement(_ identifier: String) {
        metricsQueue.async { [weak self] in
            guard let startTime = self?.performanceMetrics[identifier]?.popLast() else {
                self?.warning("No start time found for performance measurement: \identifier", category: .general)
                return
            }
            
            let duration = Date().timeIntervalSince1970 - startTime
            self?.info("Performance [\(identifier)]: \(String(format: "%.3f", duration))s", category: .general)
        }
    }
    
    /// Log location update performance
    func logLocationUpdate(accuracy: Double, batteryLevel: Float, timestamp: Date) {
        info("Location update - Accuracy: \(String(format: "%.1f", accuracy))m, Battery: \(String(format: "%.1f", batteryLevel * 100))%, Time: \(timestamp)", category: .location)
    }
    
    /// Log notification delivery attempt
    func logNotificationAttempt(identifier: String, method: String, success: Bool, error: Error? = nil) {
        if success {
            info("Notification delivered successfully - ID: \(identifier), Method: \(method)", category: .notification)
        } else {
            error("Notification delivery failed - ID: \(identifier), Method: \(method), Error: \(error?.localizedDescription ?? "Unknown")", category: .notification)
        }
    }
    
    /// Log background task execution
    func logBackgroundTask(identifier: String, started: Bool, remainingTime: TimeInterval? = nil) {
        if started {
            info("Background task started - ID: \(identifier)", category: .background)
        } else {
            let timeInfo = remainingTime != nil ? ", Remaining: \(String(format: "%.1f", remainingTime!))s" : ""
            info("Background task ended - ID: \(identifier)\(timeInfo)", category: .background)
        }
    }
    
    /// Log power state changes
    func logPowerStateChange(isLowPowerMode: Bool, batteryLevel: Float) {
        info("Power state change - Low Power Mode: \(isLowPowerMode), Battery: \(String(format: "%.1f", batteryLevel * 100))%", category: .power)
    }
    
    // MARK: - Private Methods
    
    private func performLog(_ message: String, level: LogLevel, category: LogCategory, file: String, function: String, line: Int) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.displayName)] [\(category.rawValue)] [\(fileName):\(line)] \(function): \(message)"
        
        // Console logging
        if isConsoleLoggingEnabled {
            if let logger = loggers[category] {
                logger.log(level: level.osLogType, "\(logMessage)")
            } else {
                print(logMessage)
            }
        }
        
        // File logging
        if isFileLoggingEnabled {
            writeToLogFile(logMessage)
        }
    }
    
    private func writeToLogFile(_ message: String) {
        guard let handle = logFileHandle else { return }
        
        let logEntry = message + "\n"
        if let data = logEntry.data(using: .utf8) {
            handle.write(data)
            handle.synchronizeFile()
            
            // Check file size and rotate if necessary
            checkLogFileSize()
        }
    }
    
    private func checkLogFileSize() {
        guard let logFile = currentLogFile,
              let attributes = try? fileManager.attributesOfItem(atPath: logFile.path),
              let fileSize = attributes[.size] as? Int else {
            return
        }
        
        if fileSize > maxLogFileSize {
            rotateLogFile()
        }
    }
    
    private func rotateLogFile() {
        // Close current file
        logFileHandle?.closeFile()
        logFileHandle = nil
        
        // Create new log file
        setupLogFileSystem()
        
        // Clean up old files
        cleanupOldLogFiles()
        
        info("Log file rotated", category: .general)
    }
    
    private func cleanupOldLogFiles() {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "log" }
                .sorted { (file1, file2) in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
            
            // Keep only the most recent files
            for fileToDelete in logFiles.dropFirst(maxLogFiles) {
                try? fileManager.removeItem(at: fileToDelete)
            }
        } catch {
            print("Error cleaning up log files: \(error)")
        }
    }
    
    private func logBatteryLevel() {
        let batteryLevel = UIDevice.current.batteryLevel
        if batteryLevel >= 0 {
            debug("Battery level: \(String(format: "%.1f", batteryLevel * 100))%", category: .power)
        }
    }
    
    // MARK: - Configuration
    
    /// Set minimum log level
    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
        info("Minimum log level set to: \(level.displayName)", category: .general)
    }
    
    /// Enable/disable file logging
    func setFileLogging(enabled: Bool) {
        isFileLoggingEnabled = enabled
        info("File logging \(enabled ? "enabled" : "disabled")", category: .general)
    }
    
    /// Enable/disable console logging
    func setConsoleLogging(enabled: Bool) {
        isConsoleLoggingEnabled = enabled
    }
    
    // MARK: - Log File Access
    
    /// Get all log files
    func getLogFiles() -> [URL] {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }
        
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        do {
            return try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .filter { $0.pathExtension == "log" }
                .sorted { (file1, file2) in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            self.error("Error getting log files: \(error.localizedDescription)", category: .general)
            return []
        }
    }
    
    /// Get log file content
    func getLogFileContent(_ url: URL) -> String? {
        return try? String(contentsOf: url, encoding: .utf8)
    }
    
    deinit {
        logFileHandle?.closeFile()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Extensions

extension BackgroundLogger {
    
    /// Log system information
    func logSystemInfo() {
        let device = UIDevice.current
        info("System Info - Device: \(device.model), iOS: \(device.systemVersion), Battery monitoring: \(device.isBatteryMonitoringEnabled)", category: .general)
    }
    
    /// Log memory usage
    func logMemoryUsage() {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024 / 1024
            debug("Memory usage: \(String(format: "%.1f", usedMB)) MB", category: .general)
        }
    }
}
