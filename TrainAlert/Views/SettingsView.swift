//
//  SettingsView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    
    // MARK: - Dependencies
    
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var showingAPIKeySheet = false
    @State private var showingCharacterPicker = false
    @State private var showingImportSheet = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Notification Settings Section
                        notificationSettingsSection
                        
                        // AI Settings Section
                        aiSettingsSection
                        
                        // App Settings Section
                        appSettingsSection
                        
                        // Privacy & Data Section
                        privacySection
                        
                        // About Section
                        aboutSection
                        
                        // Advanced Section
                        advancedSection
                        
                        // Bottom padding
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(.softBlue)
                }
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
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeySettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingCharacterPicker) {
                CharacterStylePickerView(viewModel: viewModel)
            }
            .confirmationDialog(
                "設定をリセット",
                isPresented: $viewModel.showingResetConfirmation
            ) {
                Button("リセット", role: .destructive) {
                    viewModel.resetAllSettings()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("すべての設定がデフォルト値に戻ります。この操作は取り消せません。")
            }
            .onAppear {
                viewModel.checkNotificationPermissions()
            }
        }
    }
    
    // MARK: - Notification Settings Section
    
    private var notificationSettingsSection: some View {
        SettingsSection(
            title: "通知設定",
            icon: "bell.fill",
            iconColor: .warmOrange
        ) {
            VStack(spacing: 16) {
                // Notification permission status
                if viewModel.notificationPermissionStatus != .authorized {
                    permissionRequestCard
                }
                
                // Default notification time
                SettingRow(
                    title: "デフォルト通知時間",
                    subtitle: "駅到着前の通知タイミング",
                    value: viewModel.notificationTimeDisplayString
                ) {
                    Menu(viewModel.notificationTimeDisplayString) {
                        ForEach(viewModel.availableNotificationTimes, id: \.self) { time in
                            Button("\(time)分前") {
                                viewModel.defaultNotificationTime = time
                            }
                        }
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Default notification distance
                SettingRow(
                    title: "デフォルト通知距離",
                    subtitle: "駅からの距離による通知",
                    value: viewModel.notificationDistanceDisplayString
                ) {
                    Menu(viewModel.notificationDistanceDisplayString) {
                        ForEach(viewModel.availableNotificationDistances, id: \.self) { distance in
                            Button(distance < 1000 ? "\(distance)m" : String(format: "%.1fkm", Double(distance) / 1000)) {
                                viewModel.defaultNotificationDistance = distance
                            }
                        }
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Snooze interval
                SettingRow(
                    title: "スヌーズ間隔",
                    subtitle: "再通知までの時間間隔",
                    value: viewModel.snoozeIntervalDisplayString
                ) {
                    Menu(viewModel.snoozeIntervalDisplayString) {
                        ForEach(viewModel.availableSnoozeIntervals, id: \.self) { interval in
                            Button("\(interval)分間隔") {
                                viewModel.defaultSnoozeInterval = interval
                            }
                        }
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Notification sound
                SettingRow(
                    title: "通知音",
                    subtitle: "アラート音の種類",
                    value: viewModel.getNotificationSoundDisplayName(viewModel.selectedNotificationSound)
                ) {
                    Menu(viewModel.getNotificationSoundDisplayName(viewModel.selectedNotificationSound)) {
                        ForEach(viewModel.availableNotificationSounds, id: \.self) { sound in
                            Button(viewModel.getNotificationSoundDisplayName(sound)) {
                                viewModel.selectedNotificationSound = sound
                            }
                        }
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Vibration intensity
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("バイブレーション強度")
                            .font(.labelMedium)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%%", viewModel.vibrationIntensity * 100))
                            .font(.numbersMedium)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Slider(
                        value: $viewModel.vibrationIntensity,
                        in: 0.0...1.0,
                        step: 0.1
                    ) {
                        Text("強度")
                    }
                    .tint(.softBlue)
                }
            }
        }
    }
    
    private var permissionRequestCard: some View {
        Card.outlined {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.warning)
                    
                    Text("通知が無効になっています")
                        .font(.labelMedium)
                        .foregroundColor(.textPrimary)
                }
                
                Text("アラート機能を使用するには通知の許可が必要です。")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                    .bodyLayout()
                
                HStack(spacing: 12) {
                    PrimaryButton("許可する", size: .small) {
                        Task {
                            await viewModel.requestNotificationPermissions()
                        }
                    }
                    
                    SecondaryButton("設定を開く", size: .small) {
                        viewModel.openAppSettings()
                    }
                }
            }
        }
    }
    
    // MARK: - AI Settings Section
    
    private var aiSettingsSection: some View {
        SettingsSection(
            title: "AI設定",
            icon: "brain.head.profile",
            iconColor: .softBlue
        ) {
            VStack(spacing: 16) {
                // OpenAI API Key
                SettingRow(
                    title: "OpenAI APIキー",
                    subtitle: viewModel.isAPIKeyValid ? "設定済み" : "未設定",
                    systemIcon: viewModel.isAPIKeyValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    iconColor: viewModel.isAPIKeyValid ? .success : .warning
                ) {
                    Button("設定") {
                        showingAPIKeySheet = true
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Use AI generated messages toggle
                SettingRow(
                    title: "AI生成メッセージ",
                    subtitle: "キャラクターによるメッセージ生成"
                ) {
                    Toggle("", isOn: $viewModel.useAIGeneratedMessages)
                        .tint(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Character style
                SettingRow(
                    title: "デフォルトキャラクター",
                    subtitle: viewModel.selectedCharacterStyleEnum.displayName,
                    value: viewModel.selectedCharacterStyleEnum.tone
                ) {
                    Button("変更") {
                        showingCharacterPicker = true
                    }
                    .foregroundColor(.softBlue)
                }
            }
        }
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        SettingsSection(
            title: "アプリ設定",
            icon: "gearshape.fill",
            iconColor: .lightGray
        ) {
            VStack(spacing: 16) {
                // Language setting
                SettingRow(
                    title: "言語",
                    subtitle: "アプリの表示言語",
                    value: viewModel.getLanguageDisplayName(viewModel.selectedLanguage)
                ) {
                    Menu(viewModel.getLanguageDisplayName(viewModel.selectedLanguage)) {
                        Button("日本語") {
                            viewModel.selectedLanguage = "ja"
                        }
                        Button("English") {
                            viewModel.selectedLanguage = "en"
                        }
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Distance unit
                SettingRow(
                    title: "距離単位",
                    subtitle: "距離表示の単位",
                    value: viewModel.getDistanceUnitDisplayName(viewModel.distanceUnit)
                ) {
                    Menu(viewModel.getDistanceUnitDisplayName(viewModel.distanceUnit)) {
                        Button("メートル法 (km/m)") {
                            viewModel.distanceUnit = "metric"
                        }
                        Button("ヤード・ポンド法 (mi/ft)") {
                            viewModel.distanceUnit = "imperial"
                        }
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // 24-hour format
                SettingRow(
                    title: "24時間表示",
                    subtitle: "時刻の表示形式"
                ) {
                    Toggle("", isOn: $viewModel.use24HourFormat)
                        .tint(.softBlue)
                }
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        SettingsSection(
            title: "プライバシー・データ",
            icon: "lock.shield.fill",
            iconColor: .mintGreen
        ) {
            VStack(spacing: 16) {
                // Data collection
                SettingRow(
                    title: "データ収集",
                    subtitle: "アプリ改善のためのデータ収集"
                ) {
                    Toggle("", isOn: $viewModel.dataCollectionEnabled)
                        .tint(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Crash reports
                SettingRow(
                    title: "クラッシュレポート",
                    subtitle: "エラー情報の自動送信"
                ) {
                    Toggle("", isOn: $viewModel.crashReportsEnabled)
                        .tint(.softBlue)
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        SettingsSection(
            title: "アプリについて",
            icon: "info.circle.fill",
            iconColor: .darkGray
        ) {
            VStack(spacing: 16) {
                // App version
                SettingRow(
                    title: "バージョン",
                    subtitle: "アプリのバージョン情報",
                    value: "\(viewModel.appVersion) (\(viewModel.buildNumber))"
                ) {
                    EmptyView()
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Terms of service
                SettingRow(
                    title: "利用規約",
                    subtitle: "サービス利用に関する規約"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.lightGray)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Privacy policy
                SettingRow(
                    title: "プライバシーポリシー",
                    subtitle: "個人情報の取り扱いについて"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.lightGray)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Contact
                SettingRow(
                    title: "お問い合わせ",
                    subtitle: "サポート・フィードバック"
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.lightGray)
                }
            }
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        SettingsSection(
            title: "詳細設定",
            icon: "wrench.and.screwdriver.fill",
            iconColor: .error
        ) {
            VStack(spacing: 16) {
                // Export settings
                SettingRow(
                    title: "設定をエクスポート",
                    subtitle: "現在の設定をファイルで保存"
                ) {
                    Button("エクスポート") {
                        let settings = viewModel.exportSettings()
                        viewModel.showingExportShare = true
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Import settings
                SettingRow(
                    title: "設定をインポート",
                    subtitle: "保存した設定ファイルから復元"
                ) {
                    Button("インポート") {
                        showingImportSheet = true
                    }
                    .foregroundColor(.softBlue)
                }
                
                Divider()
                    .foregroundColor(.lightGray.opacity(0.3))
                
                // Reset all settings
                SettingRow(
                    title: "設定をリセット",
                    subtitle: "すべての設定をデフォルトに戻す"
                ) {
                    Button("リセット") {
                        viewModel.showingResetConfirmation = true
                    }
                    .foregroundColor(.error)
                }
            }
        }
    }
}

// MARK: - Settings Section Component

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.displayMedium)
                    .foregroundColor(.textPrimary)
                    .headingLayout()
            }
            
            // Section content
            Card.elevated {
                content()
            }
        }
    }
}

// MARK: - Setting Row Component

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let value: String?
    let systemIcon: String?
    let iconColor: Color?
    let content: () -> Content
    
    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        systemIcon: String? = nil,
        iconColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.systemIcon = systemIcon
        self.iconColor = iconColor
        self.content = content
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon if provided
            if let systemIcon = systemIcon {
                Image(systemName: systemIcon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor ?? .lightGray)
                    .frame(width: 20, height: 20)
            }
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.labelMedium)
                    .foregroundColor(.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                }
                
                if let value = value {
                    Text(value)
                        .font(.caption)
                        .foregroundColor(.darkGray)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Control content
            content()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - API Key Settings View

struct APIKeySettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyInput: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header info
                        VStack(spacing: 12) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.softBlue)
                            
                            Text("OpenAI APIキー")
                                .font(.displayMedium)
                                .foregroundColor(.textPrimary)
                                .headingLayout()
                            
                            Text("AI生成メッセージ機能を使用するには、OpenAI APIキーが必要です。")
                                .font(.bodyMedium)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .bodyLayout()
                        }
                        .padding(.top, 20)
                        
                        // API Key input
                        Card.elevated {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("APIキー")
                                    .font(.labelMedium)
                                    .foregroundColor(.textPrimary)
                                
                                SecureField("sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", text: $apiKeyInput)
                                    .font(.numbersMedium)
                                    .foregroundColor(.textPrimary)
                                    .padding()
                                    .background(Color.backgroundSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                if viewModel.isAPIKeyValid {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.success)
                                        Text("有効なAPIキーです")
                                            .font(.bodySmall)
                                            .foregroundColor(.success)
                                    }
                                }
                            }
                        }
                        
                        // Actions
                        VStack(spacing: 12) {
                            PrimaryButton("保存して検証") {
                                viewModel.openAIAPIKey = apiKeyInput
                                Task {
                                    await viewModel.validateAPIKey()
                                }
                            }
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .opacity(viewModel.isTestingAPIKey ? 0.6 : 1.0)
                            
                            if !viewModel.openAIAPIKey.isEmpty {
                                SecondaryButton("APIキーを削除") {
                                    viewModel.clearAPIKey()
                                    apiKeyInput = ""
                                }
                            }
                        }
                        
                        // Instructions
                        Card.outlined {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("APIキーの取得方法")
                                    .font(.labelMedium)
                                    .foregroundColor(.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. OpenAIのWebサイトにアクセス")
                                    Text("2. アカウントを作成またはログイン")
                                    Text("3. API Keysページでキーを生成")
                                    Text("4. 生成されたキーをコピーして貼り付け")
                                }
                                .font(.bodySmall)
                                .foregroundColor(.textSecondary)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("APIキー設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.softBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(.softBlue)
                    .disabled(!viewModel.isAPIKeyValid)
                }
            }
            .onAppear {
                apiKeyInput = viewModel.openAIAPIKey
            }
        }
    }
}

// MARK: - Character Style Picker View

struct CharacterStylePickerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(CharacterStyle.allCases, id: \.rawValue) { style in
                            CharacterStyleCard(
                                style: style,
                                isSelected: viewModel.selectedCharacterStyleEnum == style
                            ) {
                                viewModel.selectedCharacterStyle = style.rawValue
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("キャラクター選択")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(.softBlue)
                }
            }
        }
    }
}

struct CharacterStyleCard: View {
    let style: CharacterStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Card(
                style: isSelected ? .gradient : .default,
                shadowStyle: isSelected ? .medium : .subtle
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(style.displayName)
                            .font(.displaySmall)
                            .foregroundColor(.textPrimary)
                            .headingLayout()
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.success)
                        }
                    }
                    
                    Text(style.tone)
                        .font(.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .bodyLayout()
                    
                    // Sample message
                    Text("\"もうすぐ新宿駅だよ〜！起きなって〜！\"")
                        .font(.bodySmall)
                        .foregroundColor(.softBlue)
                        .padding(.top, 8)
                        .italic()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .preferredColorScheme(.dark)
            .previewDisplayName("SettingsView - Dark")
    }
}
#endif
