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
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - State
    
    @State private var isRefreshing = false
    @State private var showingAlertSetup = false
    @State private var selectedRecentStation: StationData?
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Header with current status
                        headerSection
                        
                        // Active alerts or empty state
                        if viewModel.hasActiveAlerts {
                            activeAlertsSection
                        } else {
                            emptyStateSection
                        }
                        
                        // Recent stations
                        if !viewModel.recentStations.isEmpty {
                            recentStationsSection
                        }
                        
                        // Map view
                        if viewModel.locationStatus.canShowLocation {
                            mapSection
                        }
                        
                        // Bottom padding for floating action button
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .refreshable {
                    await viewModel.refresh()
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingActionButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("TrainAlert")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .onAppear {
                setupInitialState()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alertSetup(isPresented: $showingAlertSetup) {
                Task {
                    await viewModel.refresh()
                }
            }
            .sheet(item: $selectedRecentStation) { station in
                QuickAlertSetupView(station: station)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Date and location status
            HStack {
                Text(DateFormatter.homeHeaderDateFormatter.string(from: viewModel.refreshDate))
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: locationStatusIcon)
                        .font(.system(size: 12))
                        .foregroundColor(locationStatusColor)
                    
                    Text(viewModel.locationStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            // Permission requests if needed
            if !viewModel.locationStatus.canShowLocation {
                permissionRequestCard
            }
        }
    }
    
    private var locationStatusIcon: String {
        switch viewModel.locationStatus {
        case .authorized:
            return "location.fill"
        case .denied:
            return "location.slash"
        case .notRequested:
            return "location"
        case .unknown:
            return "location.circle"
        }
    }
    
    private var locationStatusColor: Color {
        switch viewModel.locationStatus {
        case .authorized:
            return .success
        case .denied:
            return .error
        case .notRequested:
            return .warning
        case .unknown:
            return .lightGray
        }
    }
    
    private var permissionRequestCard: some View {
        Card.outlined {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "location.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.softBlue)
                    
                    Text("位置情報の許可")
                        .font(.labelMedium)
                        .foregroundColor(.textPrimary)
                }
                
                Text("アラート機能を使用するには位置情報の許可が必要です。")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                    .bodyLayout()
                
                PrimaryButton("許可する", size: .small) {
                    Task {
                        await viewModel.requestPermissions()
                    }
                }
            }
        }
    }
    
    // MARK: - Active Alerts Section
    
    private var activeAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("アクティブなアラート")
                .font(.displayMedium)
                .foregroundColor(.textPrimary)
                .headingLayout()
            
            ForEach(viewModel.activeAlerts, id: \.id) { alert in
                AlertCardView(
                    alert: alert,
                    onToggle: { viewModel.toggleAlert(alert) },
                    onDelete: { viewModel.deleteAlert(alert) }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        EmptyStateView(
            icon: "bell.slash",
            title: "アラートが設定されていません",
            message: "電車の乗り過ごしを防ぐために、目的地のアラートを設定しましょう。",
            actionTitle: "アラートを設定",
            action: { showingAlertSetup = true }
        )
    }
    
    // MARK: - Recent Stations Section
    
    private var recentStationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近使った駅")
                .font(.displayMedium)
                .foregroundColor(.textPrimary)
                .headingLayout()
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.recentStations, id: \.id) { station in
                    RecentStationCard(
                        station: station,
                        currentLocation: viewModel.currentLocation
                    ) {
                        selectedRecentStation = station
                    }
                }
            }
        }
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("現在地")
                .font(.displayMedium)
                .foregroundColor(.textPrimary)
                .headingLayout()
            
            MapView(
                location: viewModel.currentLocation,
                alerts: viewModel.activeAlerts
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Controls
    
    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.refresh()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.softBlue)
        }
        .disabled(viewModel.isLoading)
    }
    
    private var floatingActionButton: some View {
        Button {
            showingAlertSetup = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.softBlue)
                .clipShape(Circle())
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
        .scaleEffect(showingAlertSetup ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: showingAlertSetup)
        .accessibilityLabel("新しいアラートを設定")
        .accessibilityHint("ダブルタップして新しいアラートの設定を開始")
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        Task {
            await viewModel.requestPermissions()
            await viewModel.refresh()
        }
        
        viewModel.startLocationUpdates()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                await viewModel.refresh()
            }
        case .background:
            // Keep location updates running in background
            break
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Supporting Views

/// Alert card for displaying active alerts
struct AlertCardView: View {
    let alert: Alert
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Card.elevated {
            VStack(alignment: .leading, spacing: 12) {
                // Station and status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.station?.name ?? "不明な駅")
                            .font(.displaySmall)
                            .foregroundColor(.textPrimary)
                            .headingLayout()
                        
                        Text("\(alert.notificationTimeDisplayString) • \(alert.notificationDistanceDisplayString)")
                            .font(.bodySmall)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Image(systemName: alert.isActive ? "bell.fill" : "bell.slash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(alert.isActive ? .success : .lightGray)
                        
                        Text(alert.isActive ? "アクティブ" : "一時停止")
                            .font(.caption)
                            .foregroundColor(alert.isActive ? .success : .lightGray)
                    }
                }
                
                // Character style
                Text(alert.characterStyleEnum.displayName)
                    .font(.caption)
                    .foregroundColor(.softBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.softBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Actions
                HStack(spacing: 12) {
                    Button(alert.isActive ? "一時停止" : "再開") {
                        onToggle()
                    }
                    .font(.labelSmall)
                    .foregroundColor(.softBlue)
                    
                    Spacer()
                    
                    Button("削除") {
                        onDelete()
                    }
                    .font(.labelSmall)
                    .foregroundColor(.error)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(alert.station?.name ?? "")のアラート、\(alert.isActive ? "アクティブ" : "一時停止中")")
    }
}

/// Empty state view when no alerts are active
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        Card.transparent {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.lightGray)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.displayMedium)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .headingLayout()
                    
                    Text(message)
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .bodyLayout()
                }
                
                PrimaryButton.gradient(actionTitle) {
                    action()
                }
            }
            .padding(.vertical, 40)
        }
    }
}

/// Recent station card
struct RecentStationCard: View {
    let station: StationData
    let currentLocation: CLLocation?
    let action: () -> Void
    
    private var distanceText: String? {
        guard let currentLocation = currentLocation else { return nil }
        let distance = currentLocation.distance(from: station.location)
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    var body: some View {
        Button(action: action) {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(station.name)
                            .font(.labelLarge)
                            .foregroundColor(.textPrimary)
                        
                        if let distance = distanceText {
                            Text("現在地から \(distance)")
                                .font(.bodySmall)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.softBlue)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(station.name)のクイックアラート設定")
        .accessibilityHint("ダブルタップして素早くアラートを設定")
    }
}

/// Simple map view showing current location and active alerts
struct MapView: UIViewRepresentable {
    let location: CLLocation?
    let alerts: [Alert]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        if let location = location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            uiView.setRegion(region, animated: true)
        }
        
        // Remove existing annotations
        uiView.removeAnnotations(uiView.annotations)
        
        // Add alert annotations
        for alert in alerts {
            guard let station = alert.station else { continue }
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(
                latitude: station.latitude,
                longitude: station.longitude
            )
            annotation.title = station.name
            annotation.subtitle = alert.isActive ? "アクティブ" : "一時停止中"
            uiView.addAnnotation(annotation)
        }
    }
}

// MARK: - Placeholder Views

/// Placeholder for quick alert setup view
struct QuickAlertSetupView: View {
    let station: StationData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("\(station.name)駅")
                    .font(.displayLarge)
                    .foregroundColor(.textPrimary)
                
                Text("クイックアラート設定")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                
                Text("この画面は今後実装されます")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("クイック設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let homeHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.dark)
            .previewDisplayName("HomeView - Dark")
    }
}
#endif
