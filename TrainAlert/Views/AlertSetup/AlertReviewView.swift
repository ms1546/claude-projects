//
//  AlertReviewView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct AlertReviewView: View {
    // MARK: - Properties
    
    @ObservedObject var setupData: AlertSetupData
    let onCreateAlert: () -> Void
    let onBack: () -> Void
    let isEditMode: Bool
    
    // MARK: - State
    
    @State private var isCreatingAlert = false
    @State private var showConfirmation = false
    
    var body: some View {
        Group {
            if isEditMode {
                // 編集モードではNavigationViewは不要（AlertSetupCoordinatorの一部として表示されるため）
                ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Summary Sections
                    notificationSettingsSection
                    characterStyleSection
                    
                    // Final Message
                    finalMessageSection
                    
                    // Navigation Buttons
                    navigationButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                }
                .background(Color.backgroundPrimary)
                .navigationBarHidden(true)
            } else {
                // 通常モードではNavigationViewが必要
                NavigationView {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            headerView
                            
                            // Summary Sections
                            stationSummarySection
                            notificationSettingsSection
                            characterStyleSection
                            
                            // Final Message
                            finalMessageSection
                            
                            // Navigation Buttons
                            navigationButtons
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .background(Color.backgroundPrimary)
                    .navigationBarHidden(true)
                }
            }
        }
        .alert(isEditMode ? "トントンを更新しますか？" : "トントンを作成しますか？", isPresented: $showConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button(isEditMode ? "更新する" : "作成する") {
                createAlert()
            }
        } message: {
            Text(isEditMode ? "設定した内容でトントンを更新します。" : "設定した内容でトントンを作成します。")
        }
        .onAppear {
            print("🔧 AlertReviewView表示")
            print("🔧 isEditMode: \(isEditMode)")
            print("🔧 selectedStation: \(setupData.selectedStation?.name ?? "nil")")
        }
    }
    
    // MARK: - Views
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.trainSoftBlue)
                }
                
                Spacer()
                
                Text("確認")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Placeholder for alignment
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.trainLightGray.opacity(0.3))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.success)
                        .frame(width: geometry.size.width)
                }
            }
            .frame(height: 4)
            
            // Progress indicator
            LinearProgressView(value: 1.0, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .success))
                .frame(height: 4)
                .clipShape(Capsule())
        }
    }
    
    private var stationSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("通知される駅", systemImage: "train.side.front.car")
            
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title2)
                        .foregroundColor(.trainSoftBlue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setupData.selectedStation?.name ?? "未選択")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        if let lines = setupData.selectedStation?.lines, !lines.isEmpty {
                            Text(lines.joined(separator: " • "))
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("通知設定", systemImage: "bell.badge")
            
            Card {
                VStack(spacing: 16) {
                    // Station Info
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.title3)
                            .foregroundColor(.trainSoftBlue)
                            .frame(width: 24)
                        
                        Text("通知される駅")
                            .font(.body)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(setupData.selectedStation?.name ?? "未選択")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.textPrimary)
                            
                            if let lines = setupData.selectedStation?.lines, !lines.isEmpty {
                                Text(lines.joined(separator: " • "))
                                    .font(.caption2)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    
                    Divider()
                        .background(Color.textSecondary.opacity(0.3))
                    
                    // Notification Time
                    settingRow(
                        icon: "clock",
                        title: "通知タイミング",
                        value: setupData.notificationTimeDisplayString
                    )
                    
                    Divider()
                    
                    // Notification Distance
                    settingRow(
                        icon: "location.north.line",
                        title: "通知距離",
                        value: setupData.notificationDistanceDisplayString
                    )
                    
                    Divider()
                    
                    // Snooze Interval
                    settingRow(
                        icon: "moon.zzz",
                        title: "スヌーズ間隔",
                        value: setupData.snoozeIntervalDisplayString
                    )
                }
            }
        }
    }
    
    private var characterStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("キャラクター", systemImage: "sparkles")
            
            Card {
                HStack(spacing: 12) {
                    Text(setupData.characterStyle.emoji)
                        .font(.largeTitle)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setupData.characterStyle.displayName)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Text(setupData.characterStyle.description)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var finalMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("メッセージプレビュー", systemImage: "bubble.left")
            
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(setupData.characterStyle.emoji)
                            .font(.title2)
                        Text(setupData.characterStyle.displayName)
                            .font(.footnote)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Text(getPreviewMessage())
                        .font(.body)
                        .foregroundColor(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                isEditMode ? "トントンを更新" : "トントンを作成"
            ) {
                    showConfirmation = true
            }
            .disabled(isCreatingAlert || !setupData.isFormValid)
            
            SecondaryButton("戻る") {
                onBack()
            }
            .disabled(isCreatingAlert)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.trainSoftBlue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
        }
    }
    
    private func settingRow(icon: String, title: String, value: String) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.trainSoftBlue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
        }
    }
    
    // MARK: - Methods
    
    private func getPreviewMessage() -> String {
        guard let station = setupData.selectedStation else {
            return "駅が選択されていません"
        }
        
        let baseMessage = "もうすぐ\(station.name)だよ！"
        
        switch setupData.characterStyle {
        case .healing:
            return baseMessage + "降りる準備をしてね😊"
        case .gyaru:
            return "マジもうすぐ\(station.name)やん～！降りる準備しときなよ〜💕"
        case .butler:
            return "お客様、間もなく\(station.name)に到着いたします。お降りのご準備を。"
        case .sporty:
            return baseMessage + "さあ、降りる準備だ！ファイト🔥"
        case .tsundere:
            return "もう\(station.name)よ！あんたのために教えてあげてるんだからね！"
        case .kansai:
            return "もうすぐ\(station.name)やで！そろそろ降りる準備せえや！"
        }
    }
    
    private func createAlert() {
        isCreatingAlert = true
        onCreateAlert()
    }
}

// MARK: - Preview

#if DEBUG
struct AlertReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let setupData = AlertSetupData()
        setupData.selectedStation = StationModel(
            id: "preview-001",
            name: "渋谷駅",
            latitude: 35.6590,
            longitude: 139.7040,
            lines: ["JR山手線", "東急東横線"]
        )
        setupData.notificationTime = 5
        setupData.notificationDistance = 500
        setupData.snoozeInterval = 5
        setupData.characterStyle = .gyaru
        
        return AlertReviewView(
            setupData: setupData,
            onCreateAlert: { },
            onBack: { },
            isEditMode: false
        )
        .preferredColorScheme(.dark)
    }
}
#endif
