//
//  HomeView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import MapKit
import SwiftUI

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

                if viewModel.allAlerts.isEmpty {
                    // 目覚ましがない場合はScrollView
                    ScrollView {
                        emptyStateSection
                    }
                } else {
                    // 目覚ましがある場合はList（スワイプ対応）
                    VStack(spacing: 0) {
                        quickActionsSection
                        
                        List {
                            ForEach(viewModel.allAlerts) { alert in
                                HomeAlertCard(alert: alert) {
                                    viewModel.toggleAlert(alert)
                                } onDelete: {
                                    viewModel.deleteAlert(alert)
                                }
                                .opacity(alert.isActive ? 1.0 : 0.6)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteAlert(alert)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationBarHidden(true)
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
        EmptyView()
    }

    private var quickActionsSection: some View {
        VStack(spacing: 0) {
            if !viewModel.allAlerts.isEmpty {
                // 既存の目覚ましがある場合は上部に作成ボタン
                HStack {
                    Text("目覚まし")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { showingAlertSetup = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.trainSoftBlue)
                            .frame(width: 44, height: 44)
                            .background(Color.trainSoftBlue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
        }
    }

    private var allAlertsSection: some View {
        EmptyView()
    }

    private var mapSection: some View {
        EmptyView()
    }

    private var emptyStateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // シンプルなテキストベースのUI
            VStack(alignment: .leading, spacing: 12) {
                Text("目覚まし")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Text("降車駅で通知を受け取ろう")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
            
            // 大きな作成ボタン
            Button(action: { showingAlertSetup = true }) {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 48))
                        .fontWeight(.light)
                        .foregroundColor(.trainSoftBlue)
                    
                    Text("目覚ましを作成")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            
            // 補助機能へのリンク
            HStack(spacing: 24) {
                Button(action: checkLocationPermission) {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.footnote)
                        Text("位置情報")
                            .font(.footnote)
                    }
                    .foregroundColor(.textSecondary)
                }
                
                Button(action: {
                    Task {
                        _ = try? await notificationManager.requestAuthorization()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.footnote)
                        Text("通知")
                            .font(.footnote)
                    }
                    .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            Spacer()
        }
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

struct SubActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
        HStack(spacing: 16) {
            // 左側のインジケーター
            RoundedRectangle(cornerRadius: 2)
                .fill(alert.isActive ? Color.trainSoftBlue : Color.gray.opacity(0.3))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 8) {
                // 駅名
                Text(alert.station?.name ?? alert.stationName ?? "未設定")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                // 路線情報
                if let lines = alert.station?.lines {
                    Text(lines)
                        .font(.footnote)
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                } else if let lineName = alert.lineName {
                    Text(lineName)
                        .font(.footnote)
                        .foregroundColor(.textSecondary)
                }
                
                // 設定情報
                HStack(spacing: 16) {
                    Label("\(alert.notificationTime)分前", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Label(String(format: "%.1fkm", alert.notificationDistance / 1_000), systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            // トグルスイッチ
            Toggle("", isOn: Binding(
                get: { alert.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(.trainSoftBlue)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
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

