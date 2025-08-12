//
//  HomeView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import MapKit

struct HomeView: View {
    
    // MARK: - Dependencies
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var appState: AppState
    
    // MARK: - State
    @State private var showingAlertSetup = false
    @State private var selectedAlert: Alert?
    @State private var showingLocationPermission = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                List {
                    // Header Section
                    headerSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    
                    // Quick Actions
                    quickActionsSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    
                    // All Alerts (Active and Inactive)
                    if !viewModel.allAlerts.isEmpty {
                        allAlertsSection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    
                    // Map View
                    if locationManager.authorizationStatus == .authorizedWhenInUse ||
                       locationManager.authorizationStatus == .authorizedAlways {
                        mapSection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    
                    // Empty State
                    if viewModel.allAlerts.isEmpty {
                        emptyStateSection
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(.systemBackground))
            }
            .navigationTitle("TrainAlert")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAlertSetup = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAlertSetup) {
                AlertSetupCoordinator()
                    .environmentObject(locationManager)
                    .environmentObject(appState)
            }
            .alert("位置情報の許可が必要です", isPresented: $showingLocationPermission) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("降車駅に近づいたことをお知らせするために、位置情報の使用許可が必要です。")
            }
            .onAppear {
                viewModel.setupWithDependencies(
                    locationManager: locationManager,
                    notificationManager: notificationManager,
                    coreDataManager: appState.coreDataManager
                )
                checkLocationPermission()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHomeView"))) { _ in
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top)
            
            Text("電車寝過ごし防止アプリ")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                title: "新規アラート",
                icon: "plus.circle",
                color: .blue
            ) {
                showingAlertSetup = true
            }
            
            QuickActionButton(
                title: "位置情報",
                icon: "location.circle",
                color: .green
            ) {
                checkLocationPermission()
            }
            
            QuickActionButton(
                title: "通知設定",
                icon: "bell.circle",
                color: .orange
            ) {
                Task {
                    _ = try? await notificationManager.requestAuthorization()
                }
            }
        }
    }
    
    private var allAlertsSection: some View {
        Group {
            // Active Alerts
            if !viewModel.activeAlerts.isEmpty {
                Section {
                    ForEach(viewModel.activeAlerts) { alert in
                        HomeAlertCard(alert: alert) {
                            viewModel.toggleAlert(alert)
                        } onDelete: {
                            viewModel.deleteAlert(alert)
                        }
                    }
                } header: {
                    Text("アクティブなアラート")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
            }
            
            // Inactive Alerts
            let inactiveAlerts = viewModel.allAlerts.filter { !$0.isActive }
            if !inactiveAlerts.isEmpty {
                Section {
                    ForEach(inactiveAlerts) { alert in
                        HomeAlertCard(alert: alert) {
                            viewModel.toggleAlert(alert)
                        } onDelete: {
                            viewModel.deleteAlert(alert)
                        }
                        .opacity(0.6)  // 非アクティブは薄く表示
                    }
                } header: {
                    Text("非アクティブなアラート")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .textCase(nil)
                }
            }
        }
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("現在地")
                .font(.headline)
                .padding(.horizontal, 4)
            
            Map(coordinateRegion: $mapRegion, showsUserLocation: true)
                .frame(height: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("アラートがありません")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("降車駅のアラートを設定して、\n寝過ごしを防ぎましょう")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAlertSetup = true }) {
                Label("アラートを作成", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
            .padding(.top)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Helper Methods
    
    private func checkLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAuthorization()
        case .denied, .restricted:
            showingLocationPermission = true
        default:
            break
        }
    }
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// Custom AlertCard for HomeView
struct HomeAlertCard: View {
    let alert: Alert
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.stationName ?? "未設定")
                    .font(.headline)
                
                Text(alert.lineName ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alert.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("削除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(LocationManager())
            .environmentObject(NotificationManager.shared)
            .environmentObject(AppState())
    }
}
#endif
