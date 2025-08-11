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
    
    // MARK: - State
    
    @State private var isCreatingAlert = false
    @State private var showConfirmation = false
    
    var body: some View {
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
        .alert("アラートを作成しますか？", isPresented: $showConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("作成する") {
                createAlert()
            }
        } message: {
            Text("設定した内容でアラートを作成します。")
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
                .padding(.trailing, 8)
                
                Spacer()
                
                Text("設定確認")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 32, height: 32)
            }
            
            // Progress indicator
            ProgressView(value: 4, total: 4)
                .progressViewStyle(LinearProgressViewStyle(tint: .success))
                .frame(height: 4)
                .clipShape(Capsule())
        }
    }
    
    private var stationSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("降車駅", systemImage: "train.side.front.car")
            
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
                .padding(16)
            }
        }
    }
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("通知設定", systemImage: "bell")
            
            Card {
                VStack(spacing: 16) {
                    // Notification Time
                    settingRow(
                        label: "通知タイミング",
                        value: setupData.notificationTimeDisplayString,
                        icon: "clock"
                    )
                    
                    Divider()
                        .background(Color.textSecondary.opacity(0.3))
                    
                    // Notification Distance
                    settingRow(
                        label: "通知距離",
                        value: setupData.notificationDistanceDisplayString,
                        icon: "location"
                    )
                    
                    Divider()
                        .background(Color.textSecondary.opacity(0.3))
                    
                    // Snooze Interval
                    settingRow(
                        label: "スヌーズ間隔",
                        value: setupData.snoozeIntervalDisplayString,
                        icon: "repeat"
                    )
                }
                .padding(16)
            }
        }
    }
    
    private var characterStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("通知スタイル", systemImage: "person.crop.circle")
            
            Card {
                HStack(spacing: 12) {
                    characterIcon
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(setupData.characterStyle.displayName)
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Text(setupData.characterStyle.tone)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
        }
    }
    
    private var finalMessageSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                    
                    Text("設定完了")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }
                
                Text("上記の設定でアラートを作成します。必要に応じて後から設定を変更することも可能です。")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                "アラートを作成",
                size: .fullWidth,
                isEnabled: setupData.isFormValid && !isCreatingAlert, isLoading: isCreatingAlert
            ) {
                showConfirmation = true
            }
            
            SecondaryButton(
                "戻って編集",
                size: .fullWidth,
                isEnabled: !isCreatingAlert
            ) {
                onBack()
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(.trainSoftBlue)
            
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
        }
    }
    
    private func settingRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.trainSoftBlue)
                .frame(width: 24)
            
            Text(label)
                .font(.body)
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
        }
    }
    
    private var characterIcon: some View {
        Group {
            switch setupData.characterStyle {
            case .gyaru:
                Text("💅")
                    .font(.system(size: 32))
            case .butler:
                Text("🤵")
                    .font(.system(size: 32))
            case .kansai:
                Text("🗣️")
                    .font(.system(size: 32))
            case .tsundere:
                Text("😤")
                    .font(.system(size: 32))
            case .sporty:
                Text("💪")
                    .font(.system(size: 32))
            case .healing:
                Text("🌸")
                    .font(.system(size: 32))
            }
        }
        .frame(width: 40, height: 40)
    }
    
    // MARK: - Methods
    
    private func createAlert() {
        guard setupData.isFormValid else { return }
        
        isCreatingAlert = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isCreatingAlert = false
            self.onCreateAlert()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AlertReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let setupData = AlertSetupData()
        // setupData.selectedStation = StationModel(id: "test", name: "テスト駅", latitude: 35.681236, longitude: 139.767125, lines: ["山手線"])
        setupData.notificationTime = 5
        setupData.notificationDistance = 500
        setupData.snoozeInterval = 5
        setupData.characterStyle = .gyaru
        
        return AlertReviewView(
            setupData: setupData,
            onCreateAlert: {},
            onBack: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
