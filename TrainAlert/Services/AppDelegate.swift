//
//  AppDelegate.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import UIKit
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
        CoreDataManager.shared.save()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh
        scheduleBackgroundRefresh()
        
        // Save context before backgrounding
        CoreDataManager.shared.save()
        
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
                await performDataMaintenance()
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
        navBarAppearance.backgroundColor = UIColor.charcoalGray
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
            
            group.addTask {
                await CoreDataManager.shared.initializeIfNeeded()
            }
            
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
        
        // Refresh only active alerts and critical data
        let coreData = CoreDataManager.shared
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Cleanup old history entries
                await coreData.performBackgroundTask { context in
                    let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "History")
                    request.predicate = NSPredicate(format: "notifiedAt < %@", cutoffDate as NSDate)
                    
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                    try? context.execute(deleteRequest)
                }
            }
        }
        
        performanceMonitor.endTimer(for: "App Data Refresh")
    }
    
    private func refreshLocationData() async {
        // Only start location updates if we have active alerts
        let activeAlerts = CoreDataManager.shared.fetchActiveAlerts()
        guard !activeAlerts.isEmpty else { return }
        
        locationManager.startUpdatingLocation()
        
        // Give location manager some time to get a reading
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        
        locationManager.stopUpdatingLocation()
    }
    
    private func performDataMaintenance() async {
        performanceMonitor.startTimer(for: "Data Maintenance")
        
        let coreData = CoreDataManager.shared
        
        await coreData.performBackgroundTask { context in
            // Clean up old data
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            // Delete old history entries
            let historyRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "History")
            historyRequest.predicate = NSPredicate(format: "notifiedAt < %@", thirtyDaysAgo as NSDate)
            let historyDelete = NSBatchDeleteRequest(fetchRequest: historyRequest)
            try? context.execute(historyDelete)
            
            // Delete inactive old alerts
            let alertRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Alert")
            alertRequest.predicate = NSPredicate(format: "isActive == NO AND createdAt < %@", thirtyDaysAgo as NSDate)
            let alertDelete = NSBatchDeleteRequest(fetchRequest: alertRequest)
            try? context.execute(alertDelete)
        }
        
        performanceMonitor.endTimer(for: "Data Maintenance")
    }
}

// MARK: - Extensions

extension CoreDataManager {
    func initializeIfNeeded() async {
        // Ensure Core Data is initialized on a background thread
        await withCheckedContinuation { continuation in
            performBackgroundTask { _ in
                continuation.resume()
            }
        }
    }
    
    func fetchActiveAlerts() -> [Alert] {
        let request = Alert.activeAlertsFetchRequest()
        do {
            return try viewContext.fetch(request)
        } catch {
            return []
        }
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
