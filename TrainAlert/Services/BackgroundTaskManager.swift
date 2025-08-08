//
//  BackgroundTaskManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import BackgroundTasks
import UIKit

/// Background task identifiers
enum BackgroundTaskIdentifier: String, CaseIterable {
    case locationUpdate = "com.trainalert.background.location-update"
    case notificationDelivery = "com.trainalert.background.notification-delivery"
    case dataSync = "com.trainalert.background.data-sync"
    case healthCheck = "com.trainalert.background.health-check"
    
    var displayName: String {
        switch self {
        case .locationUpdate: return "Location Update"
        case .notificationDelivery: return "Notification Delivery"
        case .dataSync: return "Data Synchronization"
        case .healthCheck: return "Health Check"
        }
    }
}

/// Background task execution context
struct BackgroundTaskContext {
    let identifier: BackgroundTaskIdentifier
    let startTime: Date
    let maxExecutionTime: TimeInterval
    let priority: TaskPriority
    let metadata: [String: Any]
    
    enum TaskPriority {
        case low, medium, high, critical
        
        var timeAllocation: TimeInterval {
            switch self {
            case .low: return 10.0      // 10 seconds
            case .medium: return 20.0   // 20 seconds
            case .high: return 30.0     // 30 seconds
            case .critical: return 60.0 // 60 seconds
            }
        }
    }
}

/// Background task execution result
enum BackgroundTaskResult {
    case success(metadata: [String: Any] = [:])
    case failure(error: Error, metadata: [String: Any] = [:])
    case timeout(remainingTime: TimeInterval)
    case cancelled
    
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Background task handler protocol
protocol BackgroundTaskHandler {
    func executeTask(context: BackgroundTaskContext) async -> BackgroundTaskResult
    func handleTaskTimeout(context: BackgroundTaskContext)
    func canExecuteTask(context: BackgroundTaskContext) -> Bool
}

/// Background task execution statistics
struct BackgroundTaskStatistics {
    let identifier: BackgroundTaskIdentifier
    var totalExecutions: Int = 0
    var successfulExecutions: Int = 0
    var failedExecutions: Int = 0
    var timeoutExecutions: Int = 0
    var averageExecutionTime: TimeInterval = 0.0
    var lastExecutionTime: Date?
    var lastResult: BackgroundTaskResult?
    
    var successRate: Double {
        guard totalExecutions > 0 else { return 0.0 }
        return Double(successfulExecutions) / Double(totalExecutions)
    }
    
    mutating func recordExecution(duration: TimeInterval, result: BackgroundTaskResult) {
        totalExecutions += 1
        lastExecutionTime = Date()
        lastResult = result
        
        // Update average execution time
        averageExecutionTime = ((averageExecutionTime * Double(totalExecutions - 1)) + duration) / Double(totalExecutions)
        
        // Update result counters
        switch result {
        case .success:
            successfulExecutions += 1
        case .failure:
            failedExecutions += 1
        case .timeout:
            timeoutExecutions += 1
        case .cancelled:
            break // Don't count cancelled tasks
        }
    }
}

/// Comprehensive background task management system
class BackgroundTaskManager {
    
    // MARK: - Singleton
    static let shared = BackgroundTaskManager()
    
    // MARK: - Properties
    private let logger = BackgroundLogger.shared
    private let crashReporter = CrashReporter.shared
    private let powerManager = PowerManager()
    
    private var taskHandlers: [BackgroundTaskIdentifier: BackgroundTaskHandler] = [:]
    private var activeBackgroundTasks: [UIBackgroundTaskIdentifier: BackgroundTaskContext] = [:]
    private var scheduledTasks: [BackgroundTaskIdentifier: BGTask] = [:]
    private var taskStatistics: [BackgroundTaskIdentifier: BackgroundTaskStatistics] = [:]
    
    private let taskQueue = DispatchQueue(label: "com.trainalert.background-tasks", qos: .utility)
    private let statisticsQueue = DispatchQueue(label: "com.trainalert.task-stats", qos: .utility)
    
    // Configuration
    private var isBackgroundProcessingEnabled = true
    private var maxConcurrentTasks = 3
    private var taskExecutionTimeout: TimeInterval = 25.0 // BGTask default is 30 seconds
    
    // MARK: - Initialization
    
    private init() {
        setupPowerManagerIntegration()
        initializeStatistics()
    }
    
    // MARK: - Setup Methods
    
    /// Register all background tasks with the system
    func registerBackgroundTasks() {
        for taskIdentifier in BackgroundTaskIdentifier.allCases {
            registerBackgroundTask(taskIdentifier)
        }
        
        logger.info("All background tasks registered", category: .background)
    }
    
    private func registerBackgroundTask(_ identifier: BackgroundTaskIdentifier) {
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier.rawValue,
            using: taskQueue
        ) { [weak self] task in
            self?.handleBackgroundTask(task, identifier: identifier)
        }
        
        if success {
            logger.info("Background task registered: \(identifier.displayName)", category: .background)
        } else {
            logger.error("Failed to register background task: \(identifier.displayName)", category: .background)
            crashReporter.setCustomData("bg_task_registration_failure", identifier.rawValue)
        }
    }
    
    private func setupPowerManagerIntegration() {
        powerManager.delegate = self
        powerManager.startMonitoring()
    }
    
    private func initializeStatistics() {
        for identifier in BackgroundTaskIdentifier.allCases {
            taskStatistics[identifier] = BackgroundTaskStatistics(identifier: identifier)
        }
    }
    
    // MARK: - Task Handler Management
    
    /// Register a handler for a specific background task
    func registerTaskHandler(_ handler: BackgroundTaskHandler, for identifier: BackgroundTaskIdentifier) {
        taskHandlers[identifier] = handler
        logger.info("Task handler registered for: \(identifier.displayName)", category: .background)
    }
    
    /// Unregister a task handler
    func unregisterTaskHandler(for identifier: BackgroundTaskIdentifier) {
        taskHandlers.removeValue(forKey: identifier)
        logger.info("Task handler unregistered for: \(identifier.displayName)", category: .background)
    }
    
    // MARK: - Task Scheduling
    
    /// Schedule a background app refresh task
    func scheduleBackgroundAppRefresh(identifier: BackgroundTaskIdentifier, earliestBeginDate: Date? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: identifier.rawValue)
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background app refresh scheduled: \(identifier.displayName)", category: .background)
        } catch {
            logger.error("Failed to schedule background app refresh: \(error.localizedDescription)", category: .background)
            crashReporter.reportBackgroundTaskTimeout(UIBackgroundTaskIdentifier(rawValue: 0), startTime: Date())
        }
    }
    
    /// Schedule a background processing task
    func scheduleBackgroundProcessing(identifier: BackgroundTaskIdentifier, earliestBeginDate: Date? = nil, requiresNetworkConnectivity: Bool = false) {
        let request = BGProcessingTaskRequest(identifier: identifier.rawValue)
        request.earliestBeginDate = earliestBeginDate
        request.requiresNetworkConnectivity = requiresNetworkConnectivity
        request.requiresExternalPower = false // We want to work on battery
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background processing scheduled: \(identifier.displayName)", category: .background)
        } catch {
            logger.error("Failed to schedule background processing: \(error.localizedDescription)", category: .background)
        }
    }
    
    /// Cancel all scheduled tasks
    func cancelAllScheduledTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        scheduledTasks.removeAll()
        logger.info("All scheduled background tasks cancelled", category: .background)
    }
    
    /// Cancel specific scheduled task
    func cancelScheduledTask(_ identifier: BackgroundTaskIdentifier) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier.rawValue)
        scheduledTasks.removeValue(forKey: identifier)
        logger.info("Scheduled background task cancelled: \(identifier.displayName)", category: .background)
    }
    
    // MARK: - Background Task Handling
    
    private func handleBackgroundTask(_ task: BGTask, identifier: BackgroundTaskIdentifier) {
        logger.info("Background task started: \(identifier.displayName)", category: .background)
        
        let context = BackgroundTaskContext(
            identifier: identifier,
            startTime: Date(),
            maxExecutionTime: taskExecutionTimeout,
            priority: getPriorityForTask(identifier),
            metadata: ["system_task_id": task.identifier]
        )
        
        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.handleTaskExpiration(task, context: context)
        }
        
        // Check if we should execute this task based on power state
        guard let handler = taskHandlers[identifier] else {
            logger.error("No handler registered for background task: \(identifier.displayName)", category: .background)
            task.setTaskCompleted(success: false)
            return
        }
        
        guard handler.canExecuteTask(context: context) else {
            logger.info("Background task execution declined: \(identifier.displayName)", category: .background)
            task.setTaskCompleted(success: true)
            return
        }
        
        // Monitor task execution
        crashReporter.monitorBackgroundTask(UIBackgroundTaskIdentifier(rawValue: UInt(task.identifier.hashValue)), timeout: taskExecutionTimeout)
        
        // Execute task asynchronously
        Task {
            await executeBackgroundTask(task, handler: handler, context: context)
        }
    }
    
    private func executeBackgroundTask(_ task: BGTask, handler: BackgroundTaskHandler, context: BackgroundTaskContext) async {
        let startTime = Date()
        
        do {
            let result = await handler.executeTask(context: context)
            let duration = Date().timeIntervalSince(startTime)
            
            // Record statistics
            await recordTaskStatistics(identifier: context.identifier, duration: duration, result: result)
            
            // Complete task
            task.setTaskCompleted(success: result.isSuccess)
            
            // Log result
            switch result {
            case .success(let metadata):
                logger.info("Background task completed successfully: \(context.identifier.displayName), Duration: \(String(format: "%.2f", duration))s", category: .background)
                if !metadata.isEmpty {
                    logger.debug("Task metadata: \(metadata)", category: .background)
                }
                
            case .failure(let error, let metadata):
                logger.error("Background task failed: \(context.identifier.displayName), Error: \(error.localizedDescription)", category: .background)
                if !metadata.isEmpty {
                    logger.debug("Task metadata: \(metadata)", category: .background)
                }
                
            case .timeout(let remainingTime):
                logger.warning("Background task timed out: \(context.identifier.displayName), Remaining time: \(remainingTime)s", category: .background)
                
            case .cancelled:
                logger.info("Background task cancelled: \(context.identifier.displayName)", category: .background)
            }
            
            // Schedule next execution if appropriate
            scheduleNextExecution(for: context.identifier, basedOn: result)
            
        } catch {
            logger.error("Background task execution error: \(context.identifier.displayName), Error: \(error.localizedDescription)", category: .background)
            task.setTaskCompleted(success: false)
            
            let duration = Date().timeIntervalSince(startTime)
            await recordTaskStatistics(identifier: context.identifier, duration: duration, result: .failure(error: error))
        }
        
        // Mark task as completed for crash reporter
        crashReporter.backgroundTaskCompleted(UIBackgroundTaskIdentifier(rawValue: UInt(task.identifier.hashValue)))
    }
    
    private func handleTaskExpiration(_ task: BGTask, context: BackgroundTaskContext) {
        let duration = Date().timeIntervalSince(context.startTime)
        
        logger.warning("Background task expired: \(context.identifier.displayName), Duration: \(String(format: "%.2f", duration))s", category: .background)
        
        // Notify handler about timeout
        if let handler = taskHandlers[context.identifier] {
            handler.handleTaskTimeout(context: context)
        }
        
        // Record timeout statistics
        Task {
            await recordTaskStatistics(identifier: context.identifier, duration: duration, result: .timeout(remainingTime: 0))
        }
        
        task.setTaskCompleted(success: false)
    }
    
    // MARK: - Statistics and Monitoring
    
    private func recordTaskStatistics(identifier: BackgroundTaskIdentifier, duration: TimeInterval, result: BackgroundTaskResult) async {
        await withCheckedContinuation { continuation in
            statisticsQueue.async { [weak self] in
                self?.taskStatistics[identifier]?.recordExecution(duration: duration, result: result)
                continuation.resume()
            }
        }
    }
    
    /// Get statistics for a specific task
    func getTaskStatistics(for identifier: BackgroundTaskIdentifier) -> BackgroundTaskStatistics? {
        return statisticsQueue.sync {
            return taskStatistics[identifier]
        }
    }
    
    /// Get statistics for all tasks
    func getAllTaskStatistics() -> [BackgroundTaskIdentifier: BackgroundTaskStatistics] {
        return statisticsQueue.sync {
            return taskStatistics
        }
    }
    
    /// Get currently active background tasks
    func getActiveBackgroundTasks() -> [BackgroundTaskContext] {
        return Array(activeBackgroundTasks.values)
    }
    
    // MARK: - Configuration
    
    /// Set whether background processing is enabled
    func setBackgroundProcessingEnabled(_ enabled: Bool) {
        isBackgroundProcessingEnabled = enabled
        logger.info("Background processing \(enabled ? "enabled" : "disabled")", category: .background)
        
        if !enabled {
            cancelAllScheduledTasks()
        }
    }
    
    /// Set maximum concurrent background tasks
    func setMaxConcurrentTasks(_ maxTasks: Int) {
        maxConcurrentTasks = max(1, min(maxTasks, 5)) // Clamp between 1 and 5
        logger.info("Maximum concurrent background tasks set to: \(maxConcurrentTasks)", category: .background)
    }
    
    // MARK: - Helper Methods
    
    private func getPriorityForTask(_ identifier: BackgroundTaskIdentifier) -> BackgroundTaskContext.TaskPriority {
        switch identifier {
        case .locationUpdate:
            return .high
        case .notificationDelivery:
            return .critical
        case .dataSync:
            return .medium
        case .healthCheck:
            return .low
        }
    }
    
    private func scheduleNextExecution(for identifier: BackgroundTaskIdentifier, basedOn result: BackgroundTaskResult) {
        guard isBackgroundProcessingEnabled else { return }
        
        // Determine next execution time based on result and current power state
        let powerOptimization = powerManager.getCurrentOptimization()
        var nextExecutionDelay: TimeInterval
        
        switch result {
        case .success:
            nextExecutionDelay = calculateOptimalDelay(for: identifier, optimization: powerOptimization)
        case .failure:
            nextExecutionDelay = 300 // 5 minutes for retry
        case .timeout:
            nextExecutionDelay = 600 // 10 minutes after timeout
        case .cancelled:
            return // Don't reschedule cancelled tasks
        }
        
        let nextExecutionDate = Date().addingTimeInterval(nextExecutionDelay)
        
        switch identifier {
        case .locationUpdate, .healthCheck:
            scheduleBackgroundAppRefresh(identifier: identifier, earliestBeginDate: nextExecutionDate)
        case .notificationDelivery, .dataSync:
            scheduleBackgroundProcessing(identifier: identifier, earliestBeginDate: nextExecutionDate)
        }
    }
    
    private func calculateOptimalDelay(for identifier: BackgroundTaskIdentifier, optimization: PowerOptimization) -> TimeInterval {
        let baseInterval = optimization.updateInterval
        
        switch identifier {
        case .locationUpdate:
            return baseInterval
        case .notificationDelivery:
            return baseInterval * 0.5 // More frequent
        case .dataSync:
            return baseInterval * 2 // Less frequent
        case .healthCheck:
            return baseInterval * 4 // Much less frequent
        }
    }
}

// MARK: - PowerManagerDelegate

extension BackgroundTaskManager: PowerManagerDelegate {
    func powerManager(_ manager: PowerManager, didChangeBatteryLevel level: BatteryLevel) {
        logger.info("Power manager battery level changed: \(level.rawValue)", category: .background)
        
        // Adjust task execution based on battery level
        switch level {
        case .critical:
            setMaxConcurrentTasks(1)
            taskExecutionTimeout = 15.0
        case .low:
            setMaxConcurrentTasks(2)
            taskExecutionTimeout = 20.0
        case .medium, .high, .full:
            setMaxConcurrentTasks(3)
            taskExecutionTimeout = 25.0
        case .unknown:
            break
        }
    }
    
    func powerManager(_ manager: PowerManager, didChangeLowPowerMode enabled: Bool) {
        logger.info("Power manager low power mode changed: \(enabled)", category: .background)
        
        if enabled {
            setMaxConcurrentTasks(1)
            taskExecutionTimeout = 15.0
        } else {
            setMaxConcurrentTasks(3)
            taskExecutionTimeout = 25.0
        }
    }
    
    func powerManager(_ manager: PowerManager, didChangeChargingState isCharging: Bool) {
        logger.info("Power manager charging state changed: \(isCharging)", category: .background)
        
        if isCharging {
            setMaxConcurrentTasks(5)
            taskExecutionTimeout = 30.0
        }
    }
    
    func powerManager(_ manager: PowerManager, didUpdateOptimization optimization: PowerOptimization) {
        logger.info("Power manager optimization updated: \(optimization.reason)", category: .background)
    }
    
    func powerManager(_ manager: PowerManager, didEnterEmergencyMode enabled: Bool) {
        logger.warning("Power manager emergency mode: \(enabled)", category: .background)
        
        if enabled {
            // Severely limit background processing in emergency mode
            setMaxConcurrentTasks(1)
            taskExecutionTimeout = 10.0
            
            // Cancel non-critical tasks
            cancelScheduledTask(.dataSync)
            cancelScheduledTask(.healthCheck)
        } else {
            // Restore normal operation
            setMaxConcurrentTasks(3)
            taskExecutionTimeout = 25.0
        }
    }
}
