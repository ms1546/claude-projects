//
//  PerformanceMonitor.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import QuartzCore
import OSLog
import os.signpost

/// Performance monitoring utility for tracking app performance metrics
final class PerformanceMonitor {
    
    // MARK: - Singleton
    
    static let shared = PerformanceMonitor()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "Performance")
    private let signpostLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: .pointsOfInterest)
    
    private var startTimes: [String: CFTimeInterval] = [:]
    private var memoryBaseline: UInt64 = 0
    
    // MARK: - Memory Monitoring
    
    struct MemoryInfo {
        let used: UInt64      // bytes
        let available: UInt64 // bytes
        let total: UInt64     // bytes
        
        var usedMB: Double { Double(used) / 1024.0 / 1024.0 }
        var availableMB: Double { Double(available) / 1024.0 / 1024.0 }
        var totalMB: Double { Double(total) / 1024.0 / 1024.0 }
    }
    
    // MARK: - Initialization
    
    private init() {
        memoryBaseline = getCurrentMemoryUsage()
        logger.info("Performance monitoring initialized. Memory baseline: \(self.memoryBaseline / 1024 / 1024) MB")
    }
    
    // MARK: - Time Tracking
    
    /// Start timing an operation
    func startTimer(for operation: String) {
        let startTime = CACurrentMediaTime()
        startTimes[operation] = startTime
        
        if #available(iOS 15.0, *) {
            os_signpost(.begin, log: signpostLog, name: "Operation", "%{public}s", operation)
        }
        
        logger.debug("Started timer for: \(operation)")
    }
    
    /// End timing an operation and log the duration
    @discardableResult
    func endTimer(for operation: String) -> TimeInterval {
        guard let startTime = startTimes.removeValue(forKey: operation) else {
            logger.warning("No start time found for operation: \(operation)")
            return 0
        }
        
        let duration = CACurrentMediaTime() - startTime
        
        if #available(iOS 15.0, *) {
            os_signpost(.end, log: signpostLog, name: "Operation", "%{public}s took %.3f ms", operation, duration * 1000)
        }
        
        logger.info("Operation '\(operation)' completed in \(duration * 1000, format: .fixed(precision: 3)) ms")
        
        // Alert if operation is taking too long
        if duration > 0.1 { // 100ms threshold
            logger.warning("Slow operation detected: \(operation) took \(duration * 1000, format: .fixed(precision: 3)) ms")
        }
        
        return duration
    }
    
    /// Measure the execution time of a closure
    func measure<T>(operation: String, closure: () throws -> T) rethrows -> T {
        startTimer(for: operation)
        defer { endTimer(for: operation) }
        return try closure()
    }
    
    /// Measure the execution time of an async closure
    func measure<T>(operation: String, closure: () async throws -> T) async rethrows -> T {
        startTimer(for: operation)
        defer { endTimer(for: operation) }
        return try await closure()
    }
    
    // MARK: - Memory Monitoring
    
    /// Get current memory usage in bytes
    func getCurrentMemoryUsage() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? taskInfo.resident_size : 0
    }
    
    /// Get detailed memory information
    func getMemoryInfo() -> MemoryInfo {
        let used = getCurrentMemoryUsage()
        let total = ProcessInfo.processInfo.physicalMemory
        let available = total - used
        
        return MemoryInfo(used: used, available: available, total: total)
    }
    
    /// Log current memory usage
    func logMemoryUsage(context: String = "") {
        let memInfo = getMemoryInfo()
        let contextStr = context.isEmpty ? "" : " [\(context)]"
        
        logger.info("Memory usage\(contextStr): \(memInfo.usedMB, format: .fixed(precision: 2)) MB used, \(memInfo.availableMB, format: .fixed(precision: 2)) MB available")
        
        // Alert if memory usage is high
        if memInfo.usedMB > 50.0 {
            logger.warning("High memory usage detected: \(memInfo.usedMB, format: .fixed(precision: 2)) MB")
        }
    }
    
    /// Check if there's a memory leak (usage increased significantly from baseline)
    func checkMemoryLeak(threshold: Double = 20.0) -> Bool {
        let current = getCurrentMemoryUsage()
        let currentMB = Double(current) / 1024.0 / 1024.0
        let baselineMB = Double(memoryBaseline) / 1024.0 / 1024.0
        let increase = currentMB - baselineMB
        
        if increase > threshold {
            logger.critical("Potential memory leak detected! Increase: \(increase, format: .fixed(precision: 2)) MB from baseline")
            return true
        }
        
        return false
    }
    
    // MARK: - Frame Rate Monitoring
    
    private var frameStartTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    /// Start frame rate monitoring
    func startFrameRateMonitoring() {
        frameStartTime = CACurrentMediaTime()
        frameCount = 0
        logger.debug("Started frame rate monitoring")
    }
    
    /// Record a frame for frame rate calculation
    func recordFrame() {
        frameCount += 1
    }
    
    /// End frame rate monitoring and calculate FPS
    @discardableResult
    func endFrameRateMonitoring() -> Double {
        let duration = CACurrentMediaTime() - frameStartTime
        guard duration > 0, frameCount > 0 else { return 0 }
        
        let fps = Double(frameCount) / duration
        logger.info("Frame rate: \(fps, format: .fixed(precision: 1)) FPS over \(duration, format: .fixed(precision: 2))s")
        
        if fps < 55.0 {
            logger.warning("Low frame rate detected: \(fps, format: .fixed(precision: 1)) FPS")
        }
        
        return fps
    }
    
    // MARK: - App Launch Tracking
    
    /// Track app launch phases
    enum LaunchPhase: String, CaseIterable {
        case initialization = "App Initialization"
        case coreDataSetup = "Core Data Setup"
        case servicesSetup = "Services Setup"
        case viewLoading = "Initial View Loading"
        case fullLaunch = "Full App Launch"
        
        var targetTime: TimeInterval {
            switch self {
            case .initialization: return 0.1    // 100ms
            case .coreDataSetup: return 0.3      // 300ms
            case .servicesSetup: return 0.2      // 200ms
            case .viewLoading: return 0.4        // 400ms
            case .fullLaunch: return 2.0         // 2 seconds total
            }
        }
    }
    
    /// Start tracking app launch
    func startAppLaunchTracking() {
        startTimer(for: LaunchPhase.fullLaunch.rawValue)
        logger.info("Started app launch tracking")
    }
    
    /// Track completion of a launch phase
    func trackLaunchPhase(_ phase: LaunchPhase) {
        let duration = endTimer(for: phase.rawValue)
        
        if duration > phase.targetTime {
            logger.warning("Launch phase '\(phase.rawValue)' exceeded target time: \(duration * 1000, format: .fixed(precision: 0))ms > \(phase.targetTime * 1000, format: .fixed(precision: 0))ms")
        }
        
        // Start timing next phase if not the last one
        let phases = LaunchPhase.allCases
        if let currentIndex = phases.firstIndex(of: phase),
           currentIndex < phases.count - 1 {
            let nextPhase = phases[currentIndex + 1]
            startTimer(for: nextPhase.rawValue)
        }
    }
    
    /// Complete app launch tracking
    func completeAppLaunchTracking() {
        let totalDuration = endTimer(for: LaunchPhase.fullLaunch.rawValue)
        
        if totalDuration <= 2.0 {
            logger.info("App launch completed successfully in \(totalDuration * 1000, format: .fixed(precision: 0))ms")
        } else {
            logger.error("App launch took too long: \(totalDuration * 1000, format: .fixed(precision: 0))ms (target: 2000ms)")
        }
        
        logMemoryUsage(context: "App Launch Complete")
    }
}

// MARK: - Performance Macros

#if DEBUG
/// Debug-only performance measurement macro
func performanceMeasure<T>(operation: String, closure: () throws -> T) rethrows -> T {
    return try PerformanceMonitor.shared.measure(operation: operation, closure: closure)
}

func performanceMeasureAsync<T>(operation: String, closure: () async throws -> T) async rethrows -> T {
    return try await PerformanceMonitor.shared.measure(operation: operation, closure: closure)
}
#else
func performanceMeasure<T>(operation: String, closure: () throws -> T) rethrows -> T {
    return try closure()
}

func performanceMeasureAsync<T>(operation: String, closure: () async throws -> T) async rethrows -> T {
    return try await closure()
}
#endif
