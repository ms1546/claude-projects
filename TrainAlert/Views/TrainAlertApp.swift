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
    
    // Lazy initialization for heavy dependencies
    @StateObject private var appState = AppState()
    
    // MARK: - App Scene
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAppReady {
                    ContentView()
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
    
    // Lazy managers - only initialized when needed
    private var _locationManager: LocationManager?
    private var _coreDataManager: CoreDataManager?
    
    var locationManager: LocationManager {
        if _locationManager == nil {
            performanceMonitor.startTimer(for: "LocationManager Lazy Init")
            _locationManager = LocationManager()
            performanceMonitor.endTimer(for: "LocationManager Lazy Init")
        }
        return _locationManager!
    }
    
    var coreDataManager: CoreDataManager {
        if _coreDataManager == nil {
            performanceMonitor.startTimer(for: "CoreDataManager Lazy Init")
            _coreDataManager = CoreDataManager.shared
            performanceMonitor.endTimer(for: "CoreDataManager Lazy Init")
        }
        return _coreDataManager!
    }
    
    // MARK: - Initialization
    
    func initializeApp() async {
        performanceMonitor.startTimer(for: PerformanceMonitor.LaunchPhase.fullLaunch.rawValue)
        logger.info("Starting app initialization")
        
        // Phase 1: Core Data Setup (if needed)
        await updateProgress(0.2)
        performanceMonitor.startTimer(for: PerformanceMonitor.LaunchPhase.coreDataSetup.rawValue)
        
        // Only initialize Core Data if we have existing data
        if hasExistingData() {
            _ = coreDataManager // This triggers lazy initialization
        }
        
        performanceMonitor.trackLaunchPhase(.coreDataSetup)
        
        // Phase 2: Essential Services
        await updateProgress(0.4)
        await initializeEssentialServices()
        
        // Phase 3: UI Preparation
        await updateProgress(0.7)
        performanceMonitor.startTimer(for: PerformanceMonitor.LaunchPhase.viewLoading.rawValue)
        await prepareUI()
        performanceMonitor.trackLaunchPhase(.viewLoading)
        
        // Phase 4: Complete
        await updateProgress(1.0)
        performanceMonitor.completeAppLaunchTracking()
        
        isAppReady = true
        logger.info("App initialization completed")
        
        // Schedule non-critical initializations
        Task.detached {
            await self.initializeNonCriticalServices()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateProgress(_ progress: Double) async {
        initializationProgress = progress
        // Small delay to show progress visually
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    private func hasExistingData() -> Bool {
        // Quick check if persistent store exists
        guard let storeURL = CoreDataManager.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            return false
        }
        return FileManager.default.fileExists(atPath: storeURL.path)
    }
    
    private func initializeEssentialServices() async {
        // Only initialize notification manager as it's needed immediately
        _ = NotificationManager.shared
        
        // Don't initialize location manager unless we have active alerts
        let hasActiveAlerts = await checkForActiveAlerts()
        if hasActiveAlerts {
            _ = locationManager // Trigger lazy initialization
        }
    }
    
    private func checkForActiveAlerts() async -> Bool {
        guard hasExistingData() else { return false }
        
        return await withCheckedContinuation { continuation in
            coreDataManager.performBackgroundTask { context in
                let request = Alert.activeAlertsFetchRequest()
                request.fetchLimit = 1
                
                do {
                    let count = try context.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func prepareUI() async {
        // Preload any critical UI resources
        // This is where you'd load images, fonts, etc. if needed
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Preload design system colors
                _ = UIColor.softBlue
                _ = UIColor.charcoalGray
            }
        }
    }
    
    private func initializeNonCriticalServices() async {
        logger.info("Initializing non-critical services")
        
        // Initialize services that aren't needed immediately
        await withTaskGroup(of: Void.self) { group {
            
            // Initialize OpenAI client only if needed
            group.addTask {
                if await self.shouldInitializeOpenAI() {
                    _ = OpenAIClient.shared
                }
            }
            
            // Initialize other background services
            group.addTask {
                _ = BackgroundTaskManager.shared
            }
        }
        
        logger.info("Non-critical services initialized")
    }
    
    private func shouldInitializeOpenAI() async -> Bool {
        // Only initialize OpenAI client if user has alerts with AI features enabled
        guard hasExistingData() else { return false }
        
        return await withCheckedContinuation { continuation in
            coreDataManager.performBackgroundTask { context in
                let request = Alert.fetchRequest()
                request.predicate = NSPredicate(format: "isActive == YES AND characterStyle != nil")
                request.fetchLimit = 1
                
                do {
                    let count = try context.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
