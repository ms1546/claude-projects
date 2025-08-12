//
//  TimetableAlertSetupView.swift
//  TrainAlert
//
//  時刻表ベースの目覚まし設定画面
//

import SwiftUI

struct TimetableAlertSetupView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = TimetableAlertSetupViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Properties
    let route: RouteSearchResult
    let onComplete: (Alert) -> Void
    
    // MARK: - State
    @State private var notificationMinutes = 5
    @State private var isRepeating = false
    @State private var selectedDays: Set<Int> = []
    @State private var alertMessage = ""
    @State private var useAIMessage = true
    @State private var showingSaveError = false
    
    private let minuteOptions = [3, 5, 10, 15, 20, 30]
    private let weekdays = [
        (1, "月"), (2, "火"), (3, "水"), (4, "木"),
        (5, "金"), (6, "土"), (0, "日")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 経路情報カード
                    routeInfoCard
                    
                    // 通知設定
                    notificationSettingsSection
                    
                    // 繰り返し設定
                    repeatSettingsSection
                    
                    // メッセージ設定
                    messageSettingsSection
                    
                    // 保存ボタン
                    saveButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("目覚まし設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .alert("保存エラー", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "目覚ましの保存に失敗しました")
            }
            .onAppear {
                viewModel.setupWithDependencies(
                    locationManager: locationManager,
                    notificationManager: notificationManager
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var routeInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // タイトル
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(.trainSoftBlue)
                Text("選択した経路")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }
            
            // 時刻情報
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(route.departureTime, style: .time)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(route.departureStation.title)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.textSecondary)
                    Text("\(route.duration)分")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text(route.arrivalTime, style: .time)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(route.arrivalStation.title)
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
            }
            
            // 経路詳細
            if route.sections.count > 1 {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(route.sections.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: route.sections[index].railway.lineColor ?? "#999999"))
                                .frame(width: 10, height: 10)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.sections[index].railway.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(route.sections[index].departureStation.title) → \(route.sections[index].arrivalStation.title)")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text("\(route.sections[index].stopCount)駅")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        if index < route.sections.count - 1 {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.circle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("乗り換え")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.leading, 22)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var notificationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("通知タイミング", systemImage: "bell")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            Text("到着時刻の何分前に通知を受け取りますか？")
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(minuteOptions, id: \.self) { minutes in
                        Button(action: { notificationMinutes = minutes }) {
                            Text("\(minutes)分前")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(notificationMinutes == minutes ? .white : .textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(notificationMinutes == minutes ? Color.trainSoftBlue : Color(.systemGray5))
                                )
                        }
                    }
                }
            }
            
            // 到着予定時刻と通知時刻の表示
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("到着予定")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(route.arrivalTime, style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("通知時刻")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(route.arrivalTime.addingTimeInterval(-Double(notificationMinutes * 60)), style: .time)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.trainSoftBlue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var repeatSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isRepeating) {
                Label("繰り返し", systemImage: "repeat")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }
            .tint(.trainSoftBlue)
            
            if isRepeating {
                Text("目覚ましを繰り返す曜日を選択してください")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                HStack(spacing: 8) {
                    ForEach(weekdays, id: \.0) { day in
                        Button(action: { toggleDay(day.0) }) {
                            Text(day.1)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedDays.contains(day.0) ? .white : .textPrimary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(selectedDays.contains(day.0) ? Color.trainSoftBlue : Color(.systemGray5))
                                )
                        }
                    }
                }
            }
        }
    }
    
    private var messageSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("通知メッセージ", systemImage: "text.bubble")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Toggle("AIメッセージ", isOn: $useAIMessage)
                    .labelsHidden()
                    .tint(.trainSoftBlue)
            }
            
            if useAIMessage {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.trainSoftBlue)
                    Text("AIが毎回違うメッセージを生成します")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            } else {
                TextField("通知メッセージを入力", text: $alertMessage, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...5)
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: saveAlert) {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle")
                }
                Text("目覚ましを作成")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.trainSoftBlue)
            )
        }
        .disabled(viewModel.isSaving)
    }
    
    // MARK: - Helper Methods
    
    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
    
    private func saveAlert() {
        Task {
            let alert = await viewModel.createTimetableAlert(
                route: route,
                notificationMinutes: notificationMinutes,
                isRepeating: isRepeating,
                repeatDays: Array(selectedDays),
                useAIMessage: useAIMessage,
                customMessage: useAIMessage ? nil : alertMessage
            )
            
            if let alert = alert {
                onComplete(alert)
                dismiss()
            } else {
                showingSaveError = true
            }
        }
    }
}

// MARK: - Supporting Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#if DEBUG
struct TimetableAlertSetupView_Previews: PreviewProvider {
    static var previews: some View {
        let mockRoute = MockODPTData.searchRoutes(from: "東京", to: "新宿")[0]
        
        TimetableAlertSetupView(route: mockRoute) { alert in
            print("Alert created: \(alert)")
        }
        .environmentObject(LocationManager())
        .environmentObject(NotificationManager.shared)
    }
}
#endif
