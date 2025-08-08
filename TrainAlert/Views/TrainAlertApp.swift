//
//  TrainAlertApp.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import BackgroundTasks

@main
struct TrainAlertApp: App {
    // Services
    @StateObject private var locationManager = LocationManagerEnhanced()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var coreDataManager = CoreDataManager()
    @StateObject private var openAIClient = OpenAIClient.shared
    
    // Background services
    private let backgroundTaskManager = BackgroundTaskManager.shared
    private let powerManager = PowerManager.shared
    private let backgroundLogger = BackgroundLogger.shared
    private let crashReporter = CrashReporter.shared
    
    init() {
        // Register background tasks
        registerBackgroundTasks()
        
        // Setup crash reporting
        crashReporter.setupCrashHandlers()
        
        // Log app launch
        backgroundLogger.log("App launched", category: .general)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationManager)
                .environmentObject(coreDataManager)
                .environmentObject(openAIClient)
                .onAppear {
                    setupServices()
                }
        }
    }
    
    private func registerBackgroundTasks() {
        // Register all background tasks
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainalert.location.update",
            using: nil
        ) { task in
            backgroundTaskManager.handleLocationUpdateTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainalert.notification.retry",
            using: nil
        ) { task in
            backgroundTaskManager.handleNotificationRetryTask(task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainalert.data.cleanup",
            using: nil
        ) { task in
            backgroundTaskManager.handleDataCleanupTask(task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.trainalert.crash.upload",
            using: nil
        ) { task in
            backgroundTaskManager.handleCrashUploadTask(task as! BGAppRefreshTask)
        }
        
        backgroundLogger.log("Registered all background tasks", category: .general)
    }
    
    private func setupServices() {
        // Request notification permission
        notificationManager.requestAuthorization()
        
        // Request location permission
        locationManager.requestAuthorization()
        
        // Schedule background tasks
        backgroundTaskManager.scheduleAllTasks()
        
        // Monitor power state
        powerManager.startMonitoring()
        
        backgroundLogger.log("Services setup completed", category: .general)
    }
}
