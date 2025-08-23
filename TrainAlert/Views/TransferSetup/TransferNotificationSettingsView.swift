//
//  TransferNotificationSettingsView.swift
//  TrainAlert
//
//  乗り換え経路の通知設定画面
//

import SwiftUI

struct TransferNotificationSettingsView: View {
    let transferRoute: TransferRoute?
    let onComplete: () -> Void
    
    @StateObject private var viewModel = TransferNotificationSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCharacterStyle: CharacterStyle = .healing
    @State private var notificationTime: Int = 5
    @State private var enableTransferNotifications = true
    @State private var showingPreview = false
    @State private var isCreatingAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 経路サマリー
                    if let route = transferRoute {
                        routeSummaryCard(route: route)
                    }
                    
                    // 通知設定
                    notificationSettingsCard
                    
                    // キャラクター選択
                    characterSelectionCard
                    
                    // 通知プレビュー
                    if let route = transferRoute {
                        notificationPreviewCard(route: route)
                    }
                }
                .padding()
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("作成") {
                        createAlert()
                    }
                    .fontWeight(.medium)
                    .disabled(isCreatingAlert)
                }
            }
            .sheet(isPresented: $showingPreview) {
                NotificationPreviewSheet(
                    route: transferRoute!,
                    characterStyle: selectedCharacterStyle,
                    notificationTime: notificationTime
                )
            }
            .overlay(
                Group {
                    if isCreatingAlert {
                        LoadingOverlay(text: "アラートを作成中...")
                    }
                }
            )
        }
    }
    
    // MARK: - Route Summary Card
    
    private func routeSummaryCard(route: TransferRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("経路情報", systemImage: "map.fill")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.departureStation ?? "出発駅")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(formatTime(route.departureTime))
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(Color.textSecondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(route.arrivalStation ?? "到着駅")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(formatTime(route.arrivalTime))
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            
            Divider()
            
            HStack {
                Label("\(route.transferCount)回乗り換え", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                
                Spacer()
                
                Label(formatDuration(route.totalDuration), systemImage: "timer")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Notification Settings Card
    
    private var notificationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("通知設定", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            // 到着通知時間
            VStack(alignment: .leading, spacing: 8) {
                Text("到着何分前に通知")
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)
                
                Picker("通知時間", selection: $notificationTime) {
                    ForEach([1, 3, 5, 10, 15], id: \.self) { minutes in
                        Text("\(minutes)分前").tag(minutes)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 乗り換え通知
            Toggle(isOn: $enableTransferNotifications) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("乗り換え駅で通知")
                        .font(.subheadline)
                        .foregroundColor(Color.textPrimary)
                    Text("乗り換え駅に到着時に通知します")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
            }
            .tint(Color.trainSoftBlue)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Character Selection Card
    
    private var characterSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("キャラクター選択", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CharacterStyle.allCases, id: \.self) { style in
                        CharacterStyleButton(
                            style: style,
                            isSelected: selectedCharacterStyle == style
                        )                            {
                                selectedCharacterStyle = style
                            }
                    }
                }
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Notification Preview Card
    
    private func notificationPreviewCard(route: TransferRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("通知プレビュー", systemImage: "bell.fill")
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
                
                Button(action: { showingPreview = true }) {
                    Text("すべて表示")
                        .font(.caption)
                        .foregroundColor(Color.trainSoftBlue)
                }
            }
            
            // 最終到着通知のプレビュー
            NotificationPreviewRow(
                title: "到着通知",
                station: route.arrivalStation ?? "",
                message: generateNotificationMessage(
                    for: route.arrivalStation ?? "",
                    type: .arrival
                )
            )
            
            // 乗り換え通知のプレビュー（最初の1つ）
            if enableTransferNotifications,
               let firstTransfer = route.transferStations.first {
                NotificationPreviewRow(
                    title: "乗り換え通知",
                    station: firstTransfer.stationName,
                    message: generateNotificationMessage(
                        for: firstTransfer.stationName,
                        type: .transfer,
                        toLine: firstTransfer.toLine
                    )
                )
            }
        }
        .padding()
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(mins)分"
        } else {
            return "\(mins)分"
        }
    }
    
    private func generateNotificationMessage(
        for station: String,
        type: NotificationPoint.NotificationType,
        toLine: String? = nil
    ) -> String {
        switch type {
        case .arrival:
            return selectedCharacterStyle.generateDefaultMessage(for: station)
        case .transfer:
            if let line = toLine {
                return "ここで\(line)に乗り換えてください"
            } else {
                return "ここで乗り換えてください"
            }
        case .departure:
            return "もうすぐ発車します"
        }
    }
    
    private func createAlert() {
        guard let route = transferRoute else { return }
        
        isCreatingAlert = true
        
        Task {
            do {
                try await viewModel.createTransferAlert(
                    route: route,
                    notificationTime: Int16(notificationTime),
                    characterStyle: selectedCharacterStyle,
                    enableTransferNotifications: enableTransferNotifications
                )
                
                await MainActor.run {
                    isCreatingAlert = false
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    isCreatingAlert = false
                    // エラー処理
                    print("Error creating alert: \(error)")
                }
            }
        }
    }
}

// MARK: - Helper Functions

private func iconName(for style: CharacterStyle) -> String {
    switch style {
    case .gyaru:
        return "star.bubble"
    case .butler:
        return "person.fill"
    case .kansai:
        return "bubble.left.and.bubble.right"
    case .tsundere:
        return "heart.slash"
    case .sporty:
        return "figure.run"
    case .healing:
        return "heart.circle"
    }
}

// MARK: - Character Style Button

struct CharacterStyleButton: View {
    let style: CharacterStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName(for: style))
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color.textPrimary)
                
                Text(style.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : Color.textSecondary)
            }
            .frame(width: 80, height: 80)
            .background(
                isSelected ? Color.trainSoftBlue : Color.backgroundCard
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Notification Preview Row

struct NotificationPreviewRow: View {
    let title: String
    let station: String
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                
                Text("・\(station)駅")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.textPrimary)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color.textPrimary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.backgroundCard)
        .cornerRadius(8)
    }
}

// MARK: - Notification Preview Sheet

struct NotificationPreviewSheet: View {
    let route: TransferRoute
    let characterStyle: CharacterStyle
    let notificationTime: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(route.notificationPoints) { point in
                NotificationPreviewRow(
                    title: notificationTypeTitle(point.notificationType),
                    station: point.stationName,
                    message: point.message
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("通知プレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func notificationTypeTitle(_ type: NotificationPoint.NotificationType) -> String {
        switch type {
        case .arrival:
            return "到着通知"
        case .transfer:
            return "乗り換え通知"
        case .departure:
            return "出発通知"
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let text: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
        }
    }
}

