//
//  TrainAlertApp.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import OSLog

@main
struct TrainAlertApp: App {
    
    // MARK: - Properties
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    // MARK: - App Scene
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAppReady {
                    ContentView()
                        .environmentObject(appState.locationManager)
                        .environmentObject(appState.notificationManager)
                        .environmentObject(appState)
                } else {
                    SplashScreen()
                        .onAppear {
                            Task {
                                await appState.initializeApp()
                            }
                        }
                }
            }
        }
    }
}

// MARK: - App State Management

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isAppReady = false
    @Published var initializationProgress: Double = 0.0
    
    private let performanceMonitor = PerformanceMonitor.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TrainAlert", category: "AppState")
    
    // Managers
    let locationManager = LocationManager()
    let notificationManager = NotificationManager.shared
    let coreDataManager = CoreDataManager.shared
    
    // MARK: - Initialization
    
    func initializeApp() async {
        logger.info("Starting app initialization")
        
        // Phase 1: Core Data Setup
        await updateProgress(0.2)
        CoreDataManager.enableCoreData()
        await coreDataManager.setupCoreData()
        
        // Phase 2: Essential Services
        await updateProgress(0.4)
        await initializeEssentialServices()
        
        // Phase 3: UI Preparation
        await updateProgress(0.7)
        await prepareUI()
        
        // Phase 4: Complete
        await updateProgress(1.0)
        
        // Small delay to show completion
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isAppReady = true
        logger.info("App initialization completed")
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(_ progress: Double) async {
        initializationProgress = progress
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    private func initializeEssentialServices() async {
        // Initialize notification manager
        _ = try? await notificationManager.requestAuthorization()
        
        // Setup location manager if permissions granted
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startSignificantLocationUpdates()
        }
    }
    
    private func prepareUI() async {
        // Preload any critical UI resources
        _ = UIColor.uiSoftBlue
        _ = UIColor.uiCharcoalGray
    }
}

// MARK: - Core Data Manager Extension

extension CoreDataManager {
    func setupCoreData() async {
        // Trigger lazy initialization
        _ = persistentContainer
        // logger.info("Core Data setup completed")
    }
}
