//
//  AppDelegate.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import UIKit
import CoreData
import BackgroundTasks
import UserNotifications
import CoreLocation
import OSLog

class AppDelegate: NSObject, UIApplicationDelegate {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "AppDelegate")
    private let performanceMonitor = PerformanceMonitor.shared
    
    // Lazy initialization for heavy services
    lazy var locationManager: LocationManager = {
        performanceMonitor.startTimer(for: "LocationManager Init")
        let manager = LocationManager()
        performanceMonitor.endTimer(for: "LocationManager Init")
        return manager
    }()
    
    lazy var notificationManager: NotificationManager = {
        performanceMonitor.startTimer(for: "NotificationManager Init")
        let manager = NotificationManager.shared
        performanceMonitor.endTimer(for: "NotificationManager Init")
        return manager
    }()
    
    // MARK: - App Lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Set up global exception handler for debugging
        NSSetUncaughtExceptionHandler { exception in
            print("🔴 Uncaught exception: \(exception)")
            print("🔴 Stack trace: \(exception.callStackSymbols)")
            print("🔴 Reason: \(exception.reason ?? "Unknown")")
            print("🔴 User Info: \(exception.userInfo ?? [:])")
        }
        
        performanceMonitor.startAppLaunchTracking()
        performanceMonitor.startTimer(for: PerformanceMonitor.LaunchPhase.initialization.rawValue)
        
        // Configure app appearance early
        configureAppearance()
        
        // Register background tasks
        registerBackgroundTasks()
        
        performanceMonitor.trackLaunchPhase(.initialization)
        
        // Setup critical services asynchronously
        Task {
            await setupCriticalServices()
        }
        
        logger.info("App finished launching")
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        performanceMonitor.logMemoryUsage(context: "Did Become Active")
        
        // Check for memory leaks
        if performanceMonitor.checkMemoryLeak() {
            logger.warning("Memory leak detected when app became active")
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Save any pending data
        // CoreDataManager.shared.save() // Temporarily disabled
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh
        scheduleBackgroundRefresh()
        
        // Save context before backgrounding
        // CoreDataManager.shared.save() // Temporarily disabled
        
        performanceMonitor.logMemoryUsage(context: "Did Enter Background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Refresh data when returning to foreground
        Task {
            await refreshAppData()
        }
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        performanceMonitor.startTimer(for: "Background Tasks Registration")
        
        // Register location monitoring task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainalert.location-refresh",
            using: nil
        ) { [weak self] task in
            self?.handleLocationRefreshTask(task: task as! BGAppRefreshTask)
        }
        
        // Register data processing task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainalert.data-processing",
            using: nil
        ) { [weak self] task in
            self?.handleDataProcessingTask(task: task as! BGProcessingTask)
        }
        
        performanceMonitor.endTimer(for: "Background Tasks Registration")
        logger.info("Background tasks registered")
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.trainalert.location-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }
    
    private func handleLocationRefreshTask(task: BGAppRefreshTask) {
        logger.info("Handling background location refresh task")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Perform minimal location update
                await refreshLocationData()
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Background location refresh failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
        
        // Schedule next refresh
        scheduleBackgroundRefresh()
    }
    
    private func handleDataProcessingTask(task: BGProcessingTask) {
        logger.info("Handling background data processing task")
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Perform data cleanup and optimization
                performDataMaintenance()
                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Background data processing failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    // MARK: - Service Setup
    
    private func configureAppearance() {
        performanceMonitor.startTimer(for: "Appearance Configuration")
        
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor.uiCharcoalGray
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        
        performanceMonitor.endTimer(for: "Appearance Configuration")
    }
    
    private func setupCriticalServices() async {
        performanceMonitor.startTimer(for: PerformanceMonitor.LaunchPhase.servicesSetup.rawValue)
        
        // Setup services in parallel where possible
        await withTaskGroup(of: Void.self) { group in
            
            group.addTask { [weak self] in
                await self?.setupNotifications()
            }
            
            // Core Data initialization disabled temporarily
            // group.addTask {
            //     await CoreDataManager.shared.initializeIfNeeded()
            // }
            
            // Don't initialize location manager unless needed
            // It will be lazily loaded when first accessed
        }
        
        performanceMonitor.trackLaunchPhase(.servicesSetup)
        logger.info("Critical services setup completed")
    }
    
    private func setupNotifications() async {
        do {
            _ = try await notificationManager.requestAuthorization()
            await notificationManager.configureCriticalAlerts()
            logger.info("Notifications setup completed")
        } catch {
            logger.error("Failed to setup notifications: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Data Management
    
    private func refreshAppData() async {
        performanceMonitor.startTimer(for: "App Data Refresh")
        
        // Core Data operations disabled temporarily
        // Will be re-enabled after Core Data setup is fixed
        
        performanceMonitor.endTimer(for: "App Data Refresh")
    }
    
    private func refreshLocationData() async {
        // Location updates disabled temporarily until Core Data is fixed
        return
    }
    
    private func performDataMaintenance() {
        performanceMonitor.startTimer(for: "Data Maintenance")
        
        // Data maintenance disabled temporarily until Core Data is fixed
        
        performanceMonitor.endTimer(for: "Data Maintenance")
    }
}

// MARK: - Extensions

extension CoreDataManager {
    func initializeIfNeeded() async {
        // Disabled temporarily
    }
    
    func fetchActiveAlerts() -> [Alert] {
        // Return empty array until Core Data is fixed
        return []
    }
}

extension NotificationManager {
    func configureCriticalAlerts() async {
        // Configure critical alert categories
        let arrivalCategory = UNNotificationCategory(
            identifier: "TRAIN_ARRIVAL",
            actions: [
                UNNotificationAction(
                    identifier: "SNOOZE",
                    title: "スヌーズ",
                    options: []
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "停止",
                    options: [.destructive]
                )
            ],
            intentIdentifiers: []
        )
        
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([arrivalCategory])
    }
}
