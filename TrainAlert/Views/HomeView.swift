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
    @State private var showingRouteSearch = false
    @State private var showingTimetableSearch = false
    @State private var selectedAlert: Alert?
    @State private var showingLocationPermission = false
    @State private var showingAlertEdit = false
    @State private var editingAlert: Alert?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()

                if viewModel.allAlerts.isEmpty {
                    // トントンがない場合はScrollView
                    ScrollView {
                        emptyStateSection
                    }
                } else {
                    // トントンがある場合はList（スワイプ対応）
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
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteAlert(alert)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        editingAlert = alert
                                        showingAlertEdit = true
                                    } label: {
                                        Label("編集", systemImage: "pencil")
                                    }
                                    .tint(.trainSoftBlue)
                                }
                            }
                            .animation(.default, value: viewModel.allAlerts)
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .background(Color.backgroundPrimary)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAlertSetup) {
                StationSearchForAlertView {
                    // トントン作成完了時にシートを閉じる
                    showingAlertSetup = false
                }
                .environmentObject(locationManager)
            }
            .sheet(isPresented: $showingRouteSearch) {
                RouteSearchView()
                    .environmentObject(locationManager)
            }
            .sheet(isPresented: $showingTimetableSearch) {
                TimetableSearchView()
                    .environmentObject(locationManager)
            }
            .sheet(isPresented: $showingAlertEdit) {
                if let alert = editingAlert {
                    AlertSetupFlow(editingAlert: alert) {
                        // 編集完了時にシートを閉じる
                        showingAlertEdit = false
                        editingAlert = nil
                    }
                    .environmentObject(locationManager)
                }
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
                
                // RouteAlertの遅延情報監視を開始
                Task {
                    let context = CoreDataManager.shared.viewContext
                    do {
                        let activeRouteAlerts = try RouteAlert.fetchActiveRouteAlerts(context: context)
                        DelayNotificationManager.shared.startPeriodicUpdates(for: activeRouteAlerts)
                    } catch {
                        print("Failed to fetch active route alerts: \(error)")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHomeView"))) { _ in
                Task {
                    await viewModel.refresh()
                }
            }
            .onDisappear {
                // 遅延情報の監視を停止
                DelayNotificationManager.shared.stopPeriodicUpdates()
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
                // 既存のトントンがある場合は上部に作成ボタン
                HStack {
                    Text("トントン")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { showingAlertSetup = true }) {
                            Label("駅から設定", systemImage: "location.circle")
                        }
                        Button(action: { showingRouteSearch = true }) {
                            Label("経路から設定", systemImage: "arrow.triangle.turn.up.right.circle")
                        }
                        Button(action: { showingTimetableSearch = true }) {
                            Label("時刻表から設定", systemImage: "tram.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.trainSoftBlue)
                            .frame(width: 44, height: 44)
                            .background(Color.trainSoftBlue.opacity(0.2))
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
                Text("トントン")
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
            
            // トントン作成オプション
            VStack(spacing: 16) {
                // 駅から設定
                Button(action: { showingAlertSetup = true }) {
                    HStack(spacing: 16) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.trainSoftBlue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("駅から設定")
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                            Text("降車駅を選んで通知設定")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 経路から設定
                Button(action: { showingRouteSearch = true }) {
                    HStack(spacing: 16) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.trainSoftBlue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("経路から設定")
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                            Text("経路を検索して通知設定")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 時刻表から設定
                Button(action: { showingTimetableSearch = true }) {
                    HStack(spacing: 16) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.trainSoftBlue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("時刻表から設定")
                                .font(.headline)
                                .foregroundColor(.textPrimary)
                            Text("具体的な列車を選んで通知設定")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .background(Color.backgroundCard)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
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
            .background(Color.trainLightGray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// Custom トントンCard for HomeView
struct HomeAlertCard: View {
    let alert: Alert
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    // Time formatter
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    
    // 通知設定のテキストを取得（距離ベース、時間ベース、駅数ベースの全対応）
    private func notificationText(for alert: Alert) -> String {
        // 通知タイプで判定
        if let notificationType = alert.notificationType {
            if notificationType == "station" && alert.notificationStationsBefore > 0 {
                // 駅数ベース
                return "\(alert.notificationStationsBefore)駅前"
            }
        }
        
        // notificationDistanceが0より大きければ距離ベース
        if alert.notificationDistance > 0 {
            if alert.notificationDistance >= 1_000 {
                return String(format: "%.1fkm", alert.notificationDistance / 1_000)
            } else {
                return String(format: "%.0fm", alert.notificationDistance)
            }
        } else {
            // 従来の時間ベース
            return "\(alert.notificationTime)分前"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // 左側のインジケーター
            RoundedRectangle(cornerRadius: 2)
                .fill(alert.isActive ? Color.trainSoftBlue : Color.trainLightGray.opacity(0.3))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 8) {
                // 経路情報または駅名
                if let departureStation = alert.departureStation {
                    // 経路表示
                    HStack(spacing: 8) {
                        Text(departureStation)
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Text(alert.station?.name ?? alert.stationName ?? "未設定")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }
                } else {
                    // 駅名のみ
                    Text(alert.station?.name ?? alert.stationName ?? "未設定")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)
                }
                
                // 到着時刻と路線情報
                HStack(spacing: 16) {
                    if let arrivalTime = alert.arrivalTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                            Text(formatTime(arrivalTime))
                                .font(.footnote)
                                .fontWeight(.medium)
                                .foregroundColor(.textSecondary)
                            Text("到着")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    if let lines = alert.station?.lines, !lines.isEmpty {
                        Text(lines.map { $0.railwayDisplayName }.joined(separator: " • "))
                            .font(.footnote)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    } else if let lineName = alert.lineName {
                        Text(lineName.railwayDisplayName)
                            .font(.footnote)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // 設定情報
                HStack(spacing: 16) {
                    Label(notificationText(for: alert), systemImage: "bell")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    // 繰り返し設定の表示
                    if alert.isRepeatingEnabled {
                        Label(alert.repeatSettingDescription(), systemImage: "repeat")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    // 次回通知予定
                    if let nextNotification = alert.nextNotificationDescription() {
                        Text(nextNotification)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
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
                .fill(Color.backgroundCard)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.trainLightGray.opacity(0.2), lineWidth: 1)
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
