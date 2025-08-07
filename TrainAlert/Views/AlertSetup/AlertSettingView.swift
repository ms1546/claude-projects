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
                    
                    // Notification Time Setting
                    notificationTimeSection
                    
                    // Notification Distance Setting
                    notificationDistanceSection
                    
                    // Snooze Interval Setting
                    snoozeIntervalSection
                    
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
                        .foregroundColor(.softBlue)
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
                .progressViewStyle(LinearProgressViewStyle(tint: .softBlue))
                .frame(height: 4)
                .clipShape(Capsule())
        }
    }
    
    private var selectedStationInfo: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "train.side.front.car")
                    .font(.title2)
                    .foregroundColor(.softBlue)
                
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
                .foregroundColor(.softBlue)
            }
            .padding(16)
        }
    }
    
    private var notificationTimeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "通知タイミング",
                subtitle: "駅到着の何分前に通知するかを設定"
            )
            
            Card {
                VStack(spacing: 16) {
                    HStack {
                        Text("通知時間")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(notificationTimeDisplayText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.softBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("到着時")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                            Text("60分前")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Slider(
                            value: $tempNotificationTime,
                            in: 0...60,
                            step: 1
                        ) {
                            Text("通知時間")
                        }
                        .tint(.softBlue)
                    }
                }
                .padding(16)
            }
        }
    }
    
    private var notificationDistanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "通知距離",
                subtitle: "駅からの距離による通知設定"
            )
            
            Card {
                VStack(spacing: 16) {
                    HStack {
                        Text("通知距離")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(notificationDistanceDisplayText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.softBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("50m")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                            Text("10km")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Slider(
                            value: $tempNotificationDistance,
                            in: 50...10000,
                            step: 50
                        ) {
                            Text("通知距離")
                        }
                        .tint(.softBlue)
                    }
                }
                .padding(16)
            }
        }
    }
    
    private var snoozeIntervalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "スヌーズ間隔",
                subtitle: "再通知までの間隔を設定"
            )
            
            Card {
                VStack(spacing: 16) {
                    HStack {
                        Text("スヌーズ間隔")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(snoozeIntervalDisplayText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.softBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1分")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                            Text("30分")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        Slider(
                            value: $tempSnoozeInterval,
                            in: 1...30,
                            step: 1
                        ) {
                            Text("スヌーズ間隔")
                        }
                        .tint(.softBlue)
                    }
                }
                .padding(16)
            }
        }
    }
    
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
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    private var snoozeIntervalDisplayText: String {
        return "\(Int(tempSnoozeInterval))分"
    }
    
    private var isFormValid: Bool {
        let time = Int(tempNotificationTime)
        let distance = tempNotificationDistance
        let snooze = Int(tempSnoozeInterval)
        
        return setupData.selectedStation != nil &&
               time >= 0 && time <= 60 &&
               distance >= 50 && distance <= 10000 &&
               snooze >= 1 && snooze <= 30
    }
    
    // MARK: - Methods
    
    private func saveChanges() {
        setupData.setNotificationTime(Int(tempNotificationTime))
        setupData.setNotificationDistance(tempNotificationDistance)
        setupData.setSnoozeInterval(Int(tempSnoozeInterval))
        
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
        setupData.selectedStation = Station(
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
