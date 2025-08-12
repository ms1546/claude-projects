//
//  SettingsView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreLocation
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        NavigationView {
            List {
                // Location Settings Section
                locationSettingsSection
                
                // Notification Settings Section
                notificationSettingsSection
                
                // AI Settings Section
                aiSettingsSection
                
                // App Settings Section
                appSettingsSection
                
                // Privacy Settings Section
                privacySettingsSection
                
                // About Section
                aboutSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // LocationManagerの権限状態を強制更新
            locationManager.updateAuthorizationStatus()
            viewModel.checkLocationPermissions()
            viewModel.checkNotificationPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // アプリがアクティブになったときに権限を再チェック
            locationManager.updateAuthorizationStatus()
            viewModel.checkLocationPermissions()
            viewModel.checkNotificationPermissions()
        }
        .confirmationDialog("設定をリセット", isPresented: $viewModel.showingResetConfirmation) {
            Button("リセット", role: .destructive) {
                viewModel.resetAllSettings()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての設定をデフォルトに戻します。この操作は取り消せません。")
        }
    }
    
    // MARK: - Location Settings Section
    
    private var locationSettingsSection: some View {
        Section(header: Text("位置情報")) {
            // Permission Status
            HStack {
                Label("位置情報の利用", systemImage: "location.fill")
                Spacer()
                Text(locationPermissionText)
                    .foregroundColor(locationPermissionColor)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.locationPermissionStatus == .notDetermined {
                    // LocationManagerの共有インスタンスを直接使用
                    locationManager.requestAuthorization()
                    
                    // シミュレータで権限ダイアログが表示されない場合の対策
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        viewModel.checkLocationPermissions()
                        if viewModel.locationPermissionStatus == .notDetermined {
                            viewModel.openAppSettings()
                        }
                    }
                } else if viewModel.locationPermissionStatus != .authorizedAlways && 
                         viewModel.locationPermissionStatus != .authorizedWhenInUse {
                    viewModel.openAppSettings()
                }
            }
            
            // Location Accuracy
            Picker("位置情報の精度", selection: $viewModel.locationAccuracy) {
                ForEach(viewModel.locationAccuracyOptions, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }
            .onChange(of: viewModel.locationAccuracy) { newValue in
                updateLocationAccuracy(newValue)
            }
            
            // Background Update
            Toggle(isOn: $viewModel.backgroundUpdateEnabled) {
                Label("バックグラウンド更新", systemImage: "arrow.clockwise")
            }
            .onChange(of: viewModel.backgroundUpdateEnabled) { enabled in
                updateBackgroundLocationUpdates(enabled)
            }
            
            // Update Interval
            if viewModel.backgroundUpdateEnabled {
                Picker("更新頻度", selection: $viewModel.backgroundUpdateInterval) {
                    ForEach(viewModel.availableBackgroundUpdateIntervals, id: \.self) { interval in
                        Text("\(interval)分間隔").tag(interval)
                    }
                }
                .onChange(of: viewModel.backgroundUpdateInterval) { newInterval in
                    updateBackgroundInterval(newInterval)
                }
            }
        }
    }
    
    // MARK: - Notification Settings Section
    
    private var notificationSettingsSection: some View {
        Section(header: Text("通知設定")) {
            // Permission Status
            HStack {
                Label("通知の許可", systemImage: "bell.fill")
                Spacer()
                Text(notificationPermissionText)
                    .foregroundColor(notificationPermissionColor)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.notificationPermissionStatus == .notDetermined {
                    Task {
                        await viewModel.requestNotificationPermissions()
                    }
                } else if viewModel.notificationPermissionStatus != .authorized {
                    viewModel.openAppSettings()
                }
            }
            
            // Default Notification Time
            Picker("デフォルト通知時間", selection: $viewModel.defaultNotificationTime) {
                ForEach(viewModel.availableNotificationTimes, id: \.self) { time in
                    Text("\(time)分前").tag(time)
                }
            }
            
            // Default Notification Distance
            Picker("デフォルト通知距離", selection: $viewModel.defaultNotificationDistance) {
                ForEach(viewModel.availableNotificationDistances, id: \.self) { distance in
                    if distance < 1_000 {
                        Text("\(distance)m").tag(distance)
                    } else {
                        Text(String(format: "%.1fkm", Double(distance) / 1_000)).tag(distance)
                    }
                }
            }
            
            // Notification Sound
            Picker("通知音", selection: $viewModel.selectedNotificationSound) {
                ForEach(viewModel.availableNotificationSounds, id: \.self) { sound in
                    Text(viewModel.getNotificationSoundDisplayName(sound)).tag(sound)
                }
            }
            
            // Vibration
            Toggle(isOn: $viewModel.vibrationEnabled) {
                Label("バイブレーション", systemImage: "waveform")
            }
            
            // Notification Preview
            Toggle(isOn: $viewModel.notificationPreviewEnabled) {
                Label("通知プレビュー", systemImage: "eye")
            }
            
            // Snooze Interval
            Picker("スヌーズ間隔", selection: $viewModel.defaultSnoozeInterval) {
                ForEach(viewModel.availableSnoozeIntervals, id: \.self) { interval in
                    Text("\(interval)分").tag(interval)
                }
            }
        }
    }
    
    // MARK: - AI Settings Section
    
    private var aiSettingsSection: some View {
        Section(header: Text("AI設定")) {
            // AI Message Toggle
            Toggle(isOn: $viewModel.useAIGeneratedMessages) {
                Label("AI生成メッセージ", systemImage: "brain")
            }
            
            // Character Style
            if viewModel.useAIGeneratedMessages {
                Picker("キャラクタースタイル", selection: $viewModel.selectedCharacterStyle) {
                    ForEach(CharacterStyle.allCases, id: \.rawValue) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                
                // API Key
                NavigationLink(destination: APIKeySettingView(apiKey: $viewModel.openAIAPIKey, isValid: $viewModel.isAPIKeyValid)) {
                    HStack {
                        Label("OpenAI APIキー", systemImage: "key.fill")
                        Spacer()
                        if viewModel.isAPIKeyValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text("未設定")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section(header: Text("アプリ設定")) {
            // Language
            Picker("言語", selection: $viewModel.selectedLanguage) {
                Text("日本語").tag("ja")
                Text("English").tag("en")
            }
            
            // Distance Unit
            Picker("距離単位", selection: $viewModel.distanceUnit) {
                Text("メートル法 (km/m)").tag("metric")
                Text("ヤード・ポンド法 (mi/ft)").tag("imperial")
            }
            
            // Time Format
            Toggle(isOn: $viewModel.use24HourFormat) {
                Label("24時間表示", systemImage: "clock")
            }
        }
    }
    
    // MARK: - Privacy Settings Section
    
    private var privacySettingsSection: some View {
        Section(header: Text("プライバシー")) {
            Toggle(isOn: $viewModel.dataCollectionEnabled) {
                Label("使用状況データの収集", systemImage: "chart.bar.fill")
            }
            
            Toggle(isOn: $viewModel.crashReportsEnabled) {
                Label("クラッシュレポートの送信", systemImage: "exclamationmark.triangle.fill")
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section(header: Text("情報")) {
            HStack {
                Text("バージョン")
                Spacer()
                Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                viewModel.showingResetConfirmation = true
            }) {
                Label("すべての設定をリセット", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var locationPermissionText: String {
        switch viewModel.locationPermissionStatus {
        case .notDetermined:
            return "タップして許可"
        case .restricted, .denied:
            return "許可されていません"
        case .authorizedAlways:
            return "常に許可"
        case .authorizedWhenInUse:
            return "使用中のみ"
        @unknown default:
            return "不明"
        }
    }
    
    private var locationPermissionColor: Color {
        switch viewModel.locationPermissionStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var notificationPermissionText: String {
        switch viewModel.notificationPermissionStatus {
        case .notDetermined:
            return "タップして許可"
        case .denied:
            return "許可されていません"
        case .authorized:
            return "許可済み"
        case .provisional:
            return "仮許可"
        case .ephemeral:
            return "一時的"
        @unknown default:
            return "不明"
        }
    }
    
    private var notificationPermissionColor: Color {
        switch viewModel.notificationPermissionStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .ephemeral:
            return .yellow
        @unknown default:
            return .gray
        }
    }
    
    // MARK: - Update Methods
    
    private func updateLocationAccuracy(_ accuracy: String) {
        switch accuracy {
        case "high":
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        case "balanced":
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        case "battery":
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        default:
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
    }
    
    private func updateBackgroundLocationUpdates(_ enabled: Bool) {
        if enabled {
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.stopMonitoringSignificantLocationChanges()
        }
    }
    
    private func updateBackgroundInterval(_ interval: Int) {
        // This would be used by the background task scheduler
        // For now, we'll just store the preference
    }
}

// MARK: - API Key Setting View

struct APIKeySettingView: View {
    @Binding var apiKey: String
    @Binding var isValid: Bool
    @State private var isValidating = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("OpenAI APIキー")) {
                SecureField("APIキーを入力", text: $apiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Section {
                Button(action: validateAPIKey) {
                    if isValidating {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("検証中...")
                        }
                    } else {
                        Text("APIキーを検証")
                    }
                }
                .disabled(apiKey.isEmpty || isValidating)
                
                if isValid {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("有効なAPIキーです")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Section(footer: Text("APIキーはOpenAIのダッシュボードから取得できます。")) {
                Link("OpenAIダッシュボードを開く", destination: URL(string: "https://platform.openai.com/api-keys")!)
            }
        }
        .navigationTitle("APIキー設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完了") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func validateAPIKey() {
        isValidating = true
        errorMessage = nil
        
        // Simulate API validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedKey.count > 20 && trimmedKey.hasPrefix("sk-") {
                isValid = true
                errorMessage = nil
            } else {
                isValid = false
                errorMessage = "無効なAPIキー形式です"
            }
            isValidating = false
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(LocationManager())
            .environmentObject(NotificationManager())
    }
}
#endif
