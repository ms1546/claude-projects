//
//  TimetableAlertSetupView.swift
//  TrainAlert
//
//  時刻表ベースのアラート設定画面
//

import CoreData
import CoreLocation
import SwiftUI

struct TimetableAlertSetupView: View {
    let route: RouteSearchResult
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var notificationMinutes: Int = 5
    @State private var characterStyle: CharacterStyle = .healing
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    private let notificationOptions = [1, 3, 5, 10, 15, 20, 30]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 経路情報カード
                routeInfoCard
                
                // 通知設定
                notificationSettingsCard
                
                // キャラクター設定
                characterSettingsCard
                
                // 通知プレビュー
                notificationPreviewCard
                
                // 保存ボタン
                PrimaryButton(
                    "アラートを設定",
                    isEnabled: !isSaving,
                    action: saveAlert
                )
                .padding(.horizontal)
                .padding(.top)
            }
            .padding(.vertical)
        }
        .navigationTitle("アラート設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("保存完了", isPresented: $showingSaveSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("アラートを設定しました")
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました")
        }
    }
    
    // MARK: - Route Info Card
    
    private var routeInfoCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("経路情報", systemImage: "tram.fill")
                    .font(.headline)
                
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        // 出発
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(formatTime(route.departureTime))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(route.departureStation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 縦線
                        HStack {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(width: 2)
                                .padding(.leading, 11)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let trainType = route.trainType {
                                    Text(trainType)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("約\(calculateDuration())分")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .frame(height: 40)
                        
                        // 到着
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text(formatTime(route.arrivalTime))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(route.arrivalStation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 列車番号
                    if let trainNumber = route.trainNumber {
                        VStack(alignment: .trailing) {
                            Text("列車番号")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(trainNumber)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    // MARK: - Notification Settings Card
    
    private var notificationSettingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("通知設定", systemImage: "bell.fill")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("到着何分前に通知しますか？")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(notificationOptions, id: \.self) { minutes in
                                notificationOptionButton(minutes: minutes)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("通知予定時刻: \(formatNotificationTime())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private func notificationOptionButton(minutes: Int) -> some View {
        Button(action: {
            withAnimation {
                notificationMinutes = minutes
            }
        }) {
            Text("\(minutes)分前")
                .font(.subheadline)
                .fontWeight(notificationMinutes == minutes ? .bold : .regular)
                .foregroundColor(notificationMinutes == minutes ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(notificationMinutes == minutes ? Color.accentColor : Color(UIColor.secondarySystemBackground))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Character Settings Card
    
    private var characterSettingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("通知メッセージ", systemImage: "message.fill")
                    .font(.headline)
                
                Text("メッセージのスタイルを選択")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(CharacterStyle.allCases, id: \.self) { style in
                    characterStyleOption(style)
                }
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private func characterStyleOption(_ style: CharacterStyle) -> some View {
        Button(action: {
            withAnimation {
                characterStyle = style
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(style.displayName)
                        .font(.subheadline)
                        .fontWeight(characterStyle == style ? .bold : .regular)
                    Text(style.sampleMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if characterStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Notification Preview
    
    private var notificationPreviewCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("通知プレビュー", systemImage: "bell.badge")
                    .font(.headline)
                
                // 通知サンプル
                VStack(alignment: .leading, spacing: 12) {
                    // ヘッダー
                    HStack {
                        Image(systemName: "app.badge.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                        Text("トレ眠")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("今")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // タイトル
                    Text("🚃 もうすぐ\(route.arrivalStation)駅です！")
                        .font(.headline)
                    
                    // メッセージ本文
                    Text(getPreviewMessage())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // 到着予定時刻
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("到着予定: \(formatTime(route.arrivalTime))")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .padding(.horizontal)
    }
    
    private func getPreviewMessage() -> String {
        let baseMessage = "あと約\(notificationMinutes)分で到着予定です。"
        
        switch characterStyle {
        case .healing:
            return baseMessage + "ゆっくりと準備してくださいね。"
        case .gyaru:
            return baseMessage + "準備して〜！急いで〜！"
        case .butler:
            return baseMessage + "お降りのご準備をお願いいたします。"
        case .sporty:
            return baseMessage + "降車準備！ファイト〜！"
        case .tsundere:
            return baseMessage + "準備しなさいよね...！"
        case .kansai:
            return baseMessage + "準備せなあかんで〜！"
        }
    }
    
    // MARK: - Actions
    
    private func saveAlert() {
        isSaving = true
        
        Task {
            do {
                // RouteAlertエンティティを作成
                let routeAlert = RouteAlert.create(
                    from: route,
                    notificationMinutes: Int16(notificationMinutes),
                    in: viewContext
                )
                
                // キャラクタースタイルを保存（RouteAlertに追加するか、別途保存）
                // 一時的にUserDefaultsに保存
                UserDefaults.standard.set(characterStyle.rawValue, forKey: "defaultCharacterStyle")
                
                try viewContext.save()
                
                // 通知をスケジュール
                // 到着駅の位置情報は暫定的にnil（将来的に駅の座標を取得）
                do {
                    try await notificationManager.scheduleTrainAlert(
                        for: route.arrivalStation,
                        arrivalTime: route.arrivalTime,
                        currentLocation: nil,
                        targetLocation: CLLocation(latitude: 35.6812, longitude: 139.7671), // 暫定的に東京駅の座標
                        characterStyle: characterStyle
                    )
                } catch {
                    // エラーログ（本番環境では適切なロギングシステムを使用）
                    #if DEBUG
                    print("通知のスケジュールに失敗: \(error)")
                    #endif
                }
                
                await MainActor.run {
                    isSaving = false
                    showingSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    
    private func formatNotificationTime() -> String {
        let notificationTime = route.arrivalTime.addingTimeInterval(TimeInterval(-notificationMinutes * 60))
        return formatTime(notificationTime)
    }
    
    private func calculateDuration() -> Int {
        let duration = route.arrivalTime.timeIntervalSince(route.departureTime)
        return Int(duration / 60)
    }
}

// MARK: - Preview

struct TimetableAlertSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TimetableAlertSetupView(
                route: RouteSearchResult(
                    departureStation: "東京",
                    arrivalStation: "新宿",
                    departureTime: Date(),
                    arrivalTime: Date().addingTimeInterval(30 * 60),
                    trainType: "快速",
                    trainNumber: "1234M",
                    transferCount: 0,
                    sections: []
                )
            )
        }
        .environmentObject(NotificationManager.shared)
    }
}
