//
//  StationAlertSetupView.swift
//  TrainAlert
//
//  駅単体のアラート設定画面（時刻表ベースの設定画面と統一）
//

import CoreData
import CoreLocation
import SwiftUI

struct StationAlertSetupView: View {
    let station: Station
    var onAlertCreated: (() -> Void)?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var notificationDistance: Double = 500
    @State private var characterStyle: CharacterStyle = .healing
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // AI設定の状態を監視
    @AppStorage("useAIGeneratedMessages") private var useAIGeneratedMessages = false
    @State private var hasValidAPIKey = false
    
    // 距離の選択肢（メートル）
    private let distanceOptions: [(distance: Double, label: String)] = [
        (100, "100m"),
        (300, "300m"),
        (500, "500m"),
        (1_000, "1km"),
        (2_000, "2km")
    ]
    
    var body: some View {
        ZStack {
            // 背景色
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // 駅情報カード
                    stationInfoCard
                    
                    // 通知設定
                    notificationSettingsCard
                    
                    // キャラクター設定
                    characterSettingsCard
                    
                    // 通知プレビュー
                    notificationPreviewCard
                    
                    // AI生成メッセージの注意文
                    if useAIGeneratedMessages && !hasValidAPIKey {
                        aiKeyWarningCard
                    }
                    
                    // 保存ボタン
                    PrimaryButton(
                        "トントンを設定",
                        isEnabled: !isSaving,
                        action: saveAlert
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("トントン設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("エラー", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました")
        }
        .onAppear {
            checkAPIKeyStatus()
        }
    }
    
    // MARK: - Station Info Card
    
    private var stationInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("駅情報")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(station.name ?? "未設定")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.textPrimary)
                
                if let lines = station.lines, !lines.isEmpty {
                    Text(lines.joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    // MARK: - Notification Settings Card
    
    private var notificationSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("通知設定")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("駅からどのくらいの距離で通知しますか？")
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(distanceOptions, id: \.distance) { option in
                            notificationOptionButton(distance: option.distance, label: option.label)
                        }
                    }
                }
                
                // 地下鉄での精度低下の警告
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("地下鉄では位置情報の精度が低下する場合があります")
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func notificationOptionButton(distance: Double, label: String) -> some View {
        Button(action: {
            withAnimation {
                notificationDistance = distance
            }
        }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(notificationDistance == distance ? .bold : .regular)
                
                // 電車の平均速度（約40km/h）での目安時間を表示
                Text(estimatedTimeText(for: distance))
                    .font(.caption2)
                    .foregroundColor(notificationDistance == distance ? .white.opacity(0.8) : Color.textSecondary)
            }
            .foregroundColor(notificationDistance == distance ? .white : Color.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(notificationDistance == distance ? Color.trainSoftBlue : Color.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 電車の平均速度（約40km/h）から目安時間を計算
    private func estimatedTimeText(for distance: Double) -> String {
        let speedKmh = 40.0 // 電車の平均速度（km/h）
        let speedMs = speedKmh * 1_000 / 3_600 // m/s に変換
        let seconds = distance / speedMs
        
        if seconds < 60 {
            return "約\(Int(seconds))秒"
        } else {
            let minutes = Int(seconds / 60)
            return "約\(minutes)分"
        }
    }
    
    // MARK: - Character Settings Card
    
    private var characterSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "message.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("通知メッセージ")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            Text("メッセージのスタイルを選択")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)
            
            ForEach(CharacterStyle.allCases, id: \.self) { style in
                characterStyleOption(style)
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
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
                        .foregroundColor(Color.textPrimary)
                    Text(style.sampleMessage)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if characterStyle == style {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.trainSoftBlue)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Notification Preview
    
    private var notificationPreviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("通知プレビュー")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            // 通知サンプル
            VStack(alignment: .leading, spacing: 12) {
                // ヘッダー
                HStack {
                    Image(systemName: "app.badge.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    Text("駅トントン")
                        .fontWeight(.semibold)
                        .foregroundColor(Color.textPrimary)
                    Spacer()
                    Text("今")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                
                // タイトル
                Text("🚃 もうすぐ\(station.name ?? "")駅です！")
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)
                
                // メッセージ本文
                Text(getPreviewMessage())
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.backgroundSecondary)
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func getPreviewMessage() -> String {
        let distanceText = notificationDistance >= 1_000 ? 
            String(format: "%.1fkm", notificationDistance / 1_000) : 
            String(format: "%.0fm", notificationDistance)
        let baseMessage = "駅まであと\(distanceText)です。"
        
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
    
    // MARK: - AI Key Warning Card
    
    private var aiKeyWarningCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI生成メッセージについて")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                
                Text("OpenAI APIキーが設定されていません。デフォルトのメッセージが使用されます。")
                    .font(.system(size: 12))
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func saveAlert() {
        isSaving = true
        
        Task {
            do {
                // バックグラウンドコンテキストで処理
                let backgroundContext = CoreDataManager.shared.persistentContainer.newBackgroundContext()
                
                try await backgroundContext.perform {
                    // 駅をバックグラウンドコンテキストで取得
                    let fetchRequest = Station.fetchRequest(stationId: station.stationId ?? "")
                    guard let bgStation = try? backgroundContext.fetch(fetchRequest).first else { return }
                    
                    let alert = Alert(context: backgroundContext)
                    alert.alertId = UUID()
                    alert.isActive = true
                    alert.characterStyle = characterStyle.rawValue
                    alert.notificationTime = 0 // 距離ベースなので0に設定
                    alert.notificationDistance = notificationDistance
                    alert.createdAt = Date()
                    alert.station = bgStation
                    
                    // 最終使用日時を更新
                    bgStation.lastUsedAt = Date()
                    
                    try backgroundContext.save()
                }
                
                print("✅ Core Data保存成功")
                
                // 通知をスケジュール
                do {
                    try await notificationManager.requestAuthorization()
                    print("✅ 通知権限取得成功")
                } catch {
                    print("⚠️ 通知権限の取得に失敗: \(error)")
                }
                
                await MainActor.run {
                    isSaving = false
                    print("✅ トントン設定完了")
                    
                    // 成功のHaptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // HomeViewを更新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeView"), object: nil)
                    
                    // トントン監視サービスを更新
                    AlertMonitoringService.shared.reloadAlerts()
                    
                    // コールバックを呼び出して全体を閉じる
                    onAlertCreated?()
                    
                    // 画面を閉じる
                    dismiss()
                }
            } catch {
                print("❌ トントン保存エラー: \(error)")
                
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // APIキーの状態をチェック
    private func checkAPIKeyStatus() {
        if useAIGeneratedMessages {
            // KeychainからAPIキーを取得して有効性を確認
            if let apiKey = try? KeychainManager.shared.getOpenAIAPIKey(),
               !apiKey.isEmpty {
                hasValidAPIKey = true
            } else {
                hasValidAPIKey = false
            }
        }
    }
}

// MARK: - Preview

struct StationAlertSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StationAlertSetupView(
                station: {
                    let station = Station(context: CoreDataManager.shared.viewContext)
                    station.name = "新宿"
                    station.lines = ["JR山手線", "JR中央線"]
                    return station
                }()
            )
        }
        .environmentObject(NotificationManager.shared)
    }
}
