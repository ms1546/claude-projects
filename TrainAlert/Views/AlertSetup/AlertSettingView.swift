//
//  AlertSettingView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct AlertSettingView: View {
    // MARK: - Properties
    
    @ObservedObject var setupData: AlertSetupData
    let onNext: () -> Void
    let onBack: () -> Void
    
    // MARK: - State
    
    @State private var tempNotificationTime: Double
    @State private var tempNotificationDistance: Double
    @State private var tempSnoozeInterval: Double
    @State private var isSnoozeEnabled: Bool = false
    @State private var snoozeStartStations: Double = 3
    
    // MARK: - Init
    
    init(setupData: AlertSetupData, onNext: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.setupData = setupData
        self.onNext = onNext
        self.onBack = onBack
        
        self._tempNotificationTime = State(initialValue: Double(setupData.notificationTime))
        self._tempNotificationDistance = State(initialValue: setupData.notificationDistance)
        self._tempSnoozeInterval = State(initialValue: Double(setupData.snoozeInterval))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Selected Station Info
                    selectedStationInfo
                    
                    // Unified Notification Settings
                    unifiedNotificationSettings
                    
                    // Navigation Buttons
                    navigationButtons
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.backgroundPrimary)
            .navigationBarHidden(true)
        }
        .onDisappear {
            // Save changes when view disappears
            saveChanges()
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
                
                Text("通知設定")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 32, height: 32)
            }
            
            // Progress indicator
            ProgressView(value: 2, total: 4)
                .progressViewStyle(LinearProgressViewStyle(tint: .trainSoftBlue))
                .frame(height: 4)
                .clipShape(Capsule())
        }
    }
    
    private var unifiedNotificationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "通知設定",
                subtitle: "アラートの通知方法を設定します"
            )
            
            Card {
                VStack(spacing: 24) {
                    // 通知タイミング
                    VStack(spacing: 12) {
                        HStack {
                            Label("通知タイミング", systemImage: "clock")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            Text(notificationTimeDisplayText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.trainSoftBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("到着時")
                                    .font(.caption2)
                                    .foregroundColor(.textSecondary)
                                
                                Spacer()
                                
                                Text("60分前")
                                    .font(.caption2)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Slider(
                                value: $tempNotificationTime,
                                in: 0...60,
                                step: 1
                            )
                            .tint(.trainSoftBlue)
                        }
                    }
                    
                    Divider()
                    
                    // スヌーズ機能
                    VStack(spacing: 16) {
                        HStack {
                            Label("駅ごと通知（スヌーズ）", systemImage: "bell.badge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $isSnoozeEnabled)
                                .labelsHidden()
                                .tint(.trainSoftBlue)
                        }
                        
                        if isSnoozeEnabled {
                            VStack(spacing: 12) {
                                // 開始駅数の設定
                                HStack {
                                    Text("通知開始")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(snoozeStartStations))駅前から")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.trainSoftBlue)
                                }
                                
                                Slider(
                                    value: $snoozeStartStations,
                                    in: 1...5,
                                    step: 1
                                )
                                .tint(.trainSoftBlue)
                                
                                // 通知される駅のプレビュー（コンパクト版）
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("通知される駅")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.textSecondary)
                                        .padding(.top, 4)
                                    
                                    ForEach((1...Int(snoozeStartStations)).reversed(), id: \.self) { station in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(station == 1 ? Color.orange : Color.trainSoftBlue)
                                                .frame(width: 6, height: 6)
                                            
                                            Text(getSnoozePreviewText(for: station))
                                                .font(.caption2)
                                                .foregroundColor(station == 1 ? .orange : .textSecondary)
                                            
                                            Spacer()
                                            
                                            Text(getEstimatedTimeText(for: station))
                                                .font(.caption2)
                                                .foregroundColor(.textSecondary.opacity(0.7))
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.backgroundSecondary)
                                )
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeInOut(duration: 0.3), value: isSnoozeEnabled)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
    
    private var selectedStationInfo: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "train.side.front.car")
                    .font(.title2)
                    .foregroundColor(.trainSoftBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(setupData.selectedStation?.name ?? "駅名")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    if let lines = setupData.selectedStation?.lines, !lines.isEmpty {
                        Text(lines.joined(separator: " • "))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
                
                Button("変更") {
                    onBack()
                }
                .font(.caption)
                .foregroundColor(.trainSoftBlue)
            }
            .padding(16)
        }
    }
    
    // Legacy sections - kept for reference but not used
    /*
    private var notificationTimeSection: some View { ... }
    private var notificationDistanceSection: some View { ... }
    private var snoozeIntervalSection: some View { ... }
    private var snoozeFeatureSection: some View { ... }
    */
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(
                "次へ",
                size: .fullWidth,
                isEnabled: isFormValid
            ) {
                saveChanges()
                onNext()
            }
            
            SecondaryButton(
                "戻る",
                size: .fullWidth
            ) {
                onBack()
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var notificationTimeDisplayText: String {
        let time = Int(tempNotificationTime)
        return time == 0 ? "到着時" : "\(time)分前"
    }
    
    private var notificationDistanceDisplayText: String {
        let distance = tempNotificationDistance
        if distance < 1_000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1_000)
        }
    }
    
    private var snoozeIntervalDisplayText: String {
        "\(Int(tempSnoozeInterval))分"
    }
    
    private var isFormValid: Bool {
        let time = Int(tempNotificationTime)
        let distance = tempNotificationDistance
        let snooze = Int(tempSnoozeInterval)
        
        return setupData.selectedStation != nil &&
               time >= 0 && time <= 60 &&
               distance >= 50 && distance <= 10_000 &&
               snooze >= 1 && snooze <= 30
    }
    
    private func getSnoozePreviewText(for stationsRemaining: Int) -> String {
        switch stationsRemaining {
        case 1:
            return "次の駅で降車です！"
        case 2:
            return "あと2駅で到着です"
        case 3:
            return "あと3駅で到着です"
        case 4:
            return "あと4駅で到着です"
        case 5:
            return "あと5駅で到着です"
        default:
            return "あと\(stationsRemaining)駅で到着です"
        }
    }
    
    private func getEstimatedTimeText(for stationsRemaining: Int) -> String {
        // 現在地から通知対象駅までの駅数（総駅数から引く）
        let stationsFromCurrent = Int(snoozeStartStations) - stationsRemaining
        
        // 推定時間（1駅あたり2-3分として計算）
        let minTime = stationsFromCurrent * 2
        let maxTime = stationsFromCurrent * 3
        
        if stationsFromCurrent == 0 {
            return "通知開始時"
        } else if minTime == maxTime {
            return "約\(minTime)分後"
        } else {
            return "約\(minTime)〜\(maxTime)分後"
        }
    }
    
    // MARK: - Methods
    
    private func saveChanges() {
        setupData.setNotificationTime(Int(tempNotificationTime))
        setupData.setNotificationDistance(tempNotificationDistance)
        setupData.setSnoozeInterval(Int(tempSnoozeInterval))
        setupData.isSnoozeEnabled = isSnoozeEnabled
        setupData.snoozeStartStations = Int(snoozeStartStations)
        
        // Haptic feedback for value changes
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preview

#if DEBUG
struct AlertSettingView_Previews: PreviewProvider {
    static var previews: some View {
        let setupData = AlertSetupData()
        setupData.selectedStation = StationModel(
            id: "test",
            name: "渋谷駅",
            latitude: 35.6580,
            longitude: 139.7016,
            lines: ["JR山手線", "東急東横線"]
        )
        
        return AlertSettingView(
            setupData: setupData,
            onNext: {},
            onBack: {}
        )
        .preferredColorScheme(.dark)
    }
}
#endif
