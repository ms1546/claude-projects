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
    
    @State private var notificationMinutes: Int = 0  // onAppearで初期化
    @State private var notificationStations: Int = 2  // 何駅前（デフォルト2駅前）
    @State private var notificationType: String = "time"  // "time" or "station"
    @State private var characterStyle: CharacterStyle = .healing
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // 繰り返し設定の状態
    @State private var isRepeating = false
    @State private var repeatPattern: RepeatPattern = .none
    @State private var customDays: Set<Int> = []
    
    // AI設定の状態を監視
    @AppStorage("useAIGeneratedMessages") private var useAIGeneratedMessages = false
    @State private var hasValidAPIKey = false
    
    private let allNotificationOptions = [1, 3, 5, 10, 15, 20, 30]
    
    // 何駅前の選択肢（動的に決定）
    private var stationCountOptions: [Int] {
        // 現在は仮実装で1〜3駅前を表示（一般的な利用ケース）
        // TODO: 実際の経路の駅数に基づいて制限する
        // 将来的にはODPT APIから駅順情報を取得して正確な駅数を計算
        [1, 2, 3]
    }
    
    // 乗車時間に基づいてフィルタリングされた通知オプション
    private var availableNotificationOptions: [Int] {
        let duration = calculateDuration()
        return allNotificationOptions.filter { $0 < duration }
    }
    
    var body: some View {
        ZStack {
            // 背景色
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // 経路情報カード
                    routeInfoCard
                    
                    // 通知設定
                    notificationSettingsCard
                    
                    // 繰り返し設定
                    repeatSettingsCard
                    
                    // 駅数ベースの場合は停車駅プレビューを表示
                    if notificationType == "station" {
                        notificationStationCard
                    }
                    
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
                        "目覚ましを設定",
                        isEnabled: !isSaving && (notificationType == "station" || !availableNotificationOptions.isEmpty),
                        action: saveAlert
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("目覚まし設定")
        .navigationBarTitleDisplayMode(.inline)
        // 目覚まし成功メッセージは表示せず、直接ホームに戻る
        .alert("エラー", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました")
        }
        .onAppear {
            // 利用可能な通知オプションから適切なデフォルト値を設定
            if !availableNotificationOptions.isEmpty {
                // 5分があれば5分、なければ最大値を設定
                if availableNotificationOptions.contains(5) {
                    notificationMinutes = 5
                } else {
                    notificationMinutes = availableNotificationOptions.last ?? 1
                }
            }
            
            // APIキーの状態をチェック
            checkAPIKeyStatus()
        }
    }
    
    // MARK: - Route Info Card
    
    private var routeInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("経路情報")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
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
                                .foregroundColor(Color.textPrimary)
                            Text(route.departureStation)
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    
                    // 縦線
                    HStack {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(width: 2)
                                .padding(.leading, 11)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("約\(calculateDuration())分")
                                    .font(.caption)
                                    .foregroundColor(Color.textSecondary)
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
                                .foregroundColor(Color.textPrimary)
                            Text(route.arrivalStation)
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                
                Spacer()
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
            
            // 通知タイプ選択
            VStack(alignment: .leading, spacing: 12) {
                Text("通知タイミング")
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)
                
                HStack(spacing: 12) {
                    // 時間ベース
                    Button(action: {
                        withAnimation {
                            notificationType = "time"
                        }
                    }) {
                        HStack {
                            Image(systemName: "clock")
                            Text("時間で設定")
                        }
                        .font(.subheadline)
                        .foregroundColor(notificationType == "time" ? .white : Color.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(notificationType == "time" ? Color.trainSoftBlue : Color.backgroundSecondary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 駅数ベース
                    Button(action: {
                        withAnimation {
                            notificationType = "station"
                        }
                    }) {
                        HStack {
                            Image(systemName: "tram")
                            Text("駅数で設定")
                        }
                        .font(.subheadline)
                        .foregroundColor(notificationType == "station" ? .white : Color.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(notificationType == "station" ? Color.trainSoftBlue : Color.backgroundSecondary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 設定内容
                VStack(alignment: .leading, spacing: 8) {
                    if notificationType == "time" {
                        Text("到着何分前に通知しますか？")
                            .font(.subheadline)
                            .foregroundColor(Color.textSecondary)
                        
                        if availableNotificationOptions.isEmpty {
                            Text("乗車時間が短すぎるため、通知設定ができません")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.vertical, 8)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(availableNotificationOptions, id: \.self) { minutes in
                                        notificationOptionButton(minutes: minutes)
                                    }
                                }
                            }
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color.textSecondary)
                            Text("通知予定時刻: \(formatNotificationTime())")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("到着何駅前に通知しますか？")
                            .font(.subheadline)
                            .foregroundColor(Color.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(stationCountOptions, id: \.self) { count in
                                    stationCountOptionButton(count: count)
                                }
                            }
                        }
                        
                        // 注意事項
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("実際の駅数より多い設定は通知されません")
                                .font(.caption2)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.top, 4)
                        
                        HStack {
                            Image(systemName: "tram")
                                .foregroundColor(Color.textSecondary)
                            Text("\(notificationStations)駅前で通知")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
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
                .foregroundColor(notificationMinutes == minutes ? .white : Color.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(notificationMinutes == minutes ? Color.trainSoftBlue : Color.backgroundSecondary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func stationCountOptionButton(count: Int) -> some View {
        Button(action: {
            withAnimation {
                notificationStations = count
            }
        }) {
            Text("\(count)駅前")
                .font(.subheadline)
                .fontWeight(notificationStations == count ? .bold : .regular)
                .foregroundColor(notificationStations == count ? .white : Color.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(notificationStations == count ? Color.trainSoftBlue : Color.backgroundSecondary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Repeat Settings Card
    
    private var repeatSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "repeat")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("繰り返し設定")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            // 繰り返しのオン/オフ
            Toggle(isOn: $isRepeating) {
                Text("繰り返し通知")
                    .font(.subheadline)
                    .foregroundColor(Color.textPrimary)
            }
            .tint(.trainSoftBlue)
            .onChange(of: isRepeating) { newValue in
                if !newValue {
                    repeatPattern = .none
                    customDays = []
                } else if repeatPattern == .none {
                    repeatPattern = .daily
                }
            }
            
            if isRepeating {
                VStack(alignment: .leading, spacing: 12) {
                    Text("繰り返しパターン")
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                    
                    // パターン選択
                    ForEach([RepeatPattern.daily, .weekdays, .weekends, .custom], id: \.self) { pattern in
                        Button(action: {
                            withAnimation {
                                repeatPattern = pattern
                                if pattern != .custom {
                                    customDays = Set(pattern.getDays())
                                }
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pattern.displayName)
                                        .font(.subheadline)
                                        .fontWeight(repeatPattern == pattern ? .bold : .regular)
                                        .foregroundColor(Color.textPrimary)
                                    Text(pattern.description)
                                        .font(.caption)
                                        .foregroundColor(Color.textSecondary)
                                }
                                
                                Spacer()
                                
                                if repeatPattern == pattern {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.trainSoftBlue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // カスタム曜日選択
                    if repeatPattern == .custom {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("曜日を選択")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                            
                            HStack(spacing: 8) {
                                ForEach(DayOfWeek.allCases, id: \.self) { day in
                                    Button(action: {
                                        withAnimation {
                                            if customDays.contains(day.rawValue) {
                                                customDays.remove(day.rawValue)
                                            } else {
                                                customDays.insert(day.rawValue)
                                            }
                                        }
                                    }) {
                                        Text(day.shortName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(customDays.contains(day.rawValue) ? .white : Color.textPrimary)
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(customDays.contains(day.rawValue) ? Color.trainSoftBlue : Color.backgroundSecondary)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    // 次回通知予定
                    if let nextDate = getNextNotificationDate() {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                            Text(formatNextNotificationDate(nextDate))
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
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
                        Text("トレ眠")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.textPrimary)
                        Spacer()
                        Text("今")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                }
                
                // タイトル
                Text("🚃 もうすぐ\(route.arrivalStation)駅です！")
                    .font(.headline)
                    .foregroundColor(Color.textPrimary)
                
                // メッセージ本文
                Text(getPreviewMessage())
                    .font(.subheadline)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 到着予定時刻
                HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                        Text("到着予定: \(formatTime(route.arrivalTime))")
                            .font(.caption)
                }
                .foregroundColor(Color.textSecondary)
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
        let baseMessage: String
        if notificationType == "time" {
            baseMessage = "あと約\(notificationMinutes)分で到着予定です。"
        } else {
            baseMessage = "あと\(notificationStations)駅で到着予定です。"
        }
        
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
                // 一時的にAlertエンティティを使用（RouteAlertの問題を回避）
                let alert = Alert(context: viewContext)
                alert.alertId = UUID()
                alert.isActive = true
                alert.characterStyle = characterStyle.rawValue
                alert.notificationType = notificationType
                
                // 通知タイプに応じて値を設定
                if notificationType == "time" {
                    alert.notificationTime = Int16(notificationMinutes)
                    alert.notificationStationsBefore = 0
                } else {
                    alert.notificationTime = 0
                    alert.notificationStationsBefore = Int16(notificationStations)
                }
                
                alert.notificationDistance = 0 // 経路ベースでは距離は使わない
                alert.createdAt = Date()
                
                // 繰り返し設定を保存（TimetableAlert+Extensionで定義）
                // alert.repeatPattern = isRepeating ? repeatPattern : .none
                // alert.repeatCustomDays = Array(customDays)
                
                // 経路情報を保存
                alert.departureStation = route.departureStation
                alert.arrivalTime = route.arrivalTime
                
                // 到着駅の情報を保存
                // 既存の駅を検索または新規作成
                let stationName = route.arrivalStation
                let stationId = "station_\(stationName.replacingOccurrences(of: " ", with: "_"))"
                
                // 既存の駅を検索
                let fetchRequest = Station.fetchRequest(stationId: stationId)
                let existingStation = try? viewContext.fetch(fetchRequest).first
                
                let station: Station
                if let existing = existingStation {
                    station = existing
                    print("Using existing station: \(stationName)")
                } else {
                    // 新規作成
                    station = Station(context: viewContext)
                    station.stationId = stationId
                    station.name = stationName
                    // 暫定的な座標（将来的には実際の駅座標を取得）
                    station.latitude = 35.6812  // 東京駅の座標
                    station.longitude = 139.7671
                    station.lines = []
                    station.isFavorite = false
                    station.createdAt = Date()
                    station.lastUsedAt = nil
                    
                    print("Created new station: \(stationName)")
                    print("  stationId: \(stationId)")
                    print("  latitude: \(station.latitude)")
                    print("  longitude: \(station.longitude)")
                }
                
                // 最終使用日時を更新
                station.lastUsedAt = Date()
                
                // アラートとの関連付け
                alert.station = station
                print("Station relationship established successfully")
                
                // 経路情報をUserDefaultsに保存（一時的な対応）
                let routeInfo = [
                    "departureStation": route.departureStation,
                    "arrivalStation": route.arrivalStation,
                    "departureTime": route.departureTime.timeIntervalSince1970,
                    "arrivalTime": route.arrivalTime.timeIntervalSince1970
                ] as [String: Any]
                UserDefaults.standard.set(routeInfo, forKey: "lastRouteInfo")
                UserDefaults.standard.set(characterStyle.rawValue, forKey: "defaultCharacterStyle")
                
                try viewContext.save()
                print("✅ Core Data保存成功")
                print("  Alert ID: \(alert.alertId?.uuidString ?? "nil")")
                print("  Station: \(alert.station?.name ?? "nil")")
                print("  Notification: \(alert.notificationTime)分前")
                
                // 通知をスケジュール
                // 到着駅の位置情報は暫定的にnil（将来的に駅の座標を取得）
                do {
                    if isRepeating && repeatPattern != .none {
                        // 繰り返し通知をスケジュール
                        try await notificationManager.scheduleRepeatingNotification(
                            for: route.arrivalStation,
                            departureStation: route.departureStation,
                            arrivalTime: route.arrivalTime,
                            pattern: repeatPattern,
                            customDays: Array(customDays),
                            characterStyle: characterStyle,
                            notificationMinutes: notificationType == "time" ? Int(notificationMinutes) : 5,
                            alertId: alert.alertId?.uuidString ?? ""
                        )
                        print("✅ 繰り返し通知スケジュール成功")
                    } else {
                        // 単発の通知をスケジュール
                        try await notificationManager.scheduleTrainAlert(
                            for: route.arrivalStation,
                            arrivalTime: route.arrivalTime,
                            currentLocation: nil,
                            targetLocation: CLLocation(latitude: station.latitude, longitude: station.longitude),
                            characterStyle: characterStyle
                        )
                        print("✅ 通知スケジュール成功")
                    }
                } catch {
                    print("⚠️ 通知のスケジュールに失敗: \(error)")
                }
                
                await MainActor.run {
                    isSaving = false
                    print("✅ 目覚まし設定完了")
                    
                    // 成功のHaptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // HomeViewを更新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeView"), object: nil)
                    
                    // 目覚まし監視サービスを更新
                    AlertMonitoringService.shared.reloadAlerts()
                    
                    // 少し遅延させてから経路検索画面を閉じる
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("CloseRouteSearch"), object: nil)
                    }
                }
            } catch {
                print("❌ 目覚まし保存エラー: \(error)")
                print("  Error type: \(type(of: error))")
                print("  Error description: \(error.localizedDescription)")
                
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
    
    @State private var actualStations: [(name: String, time: Date?)] = []
    @State private var isLoadingStations = false
    
    private var notificationStationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("通知される駅")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            // 通知駅の情報を表示
            if isLoadingStations {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .trainSoftBlue))
                    Text("駅情報を取得中...")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if !actualStations.isEmpty {
                // 通知駅のインデックスを計算（到着駅から数えて何駅前か）
                let notificationIndex = actualStations.count - notificationStations - 1
                
                if notificationIndex >= 0 && notificationIndex < actualStations.count {
                    let notificationStation = actualStations[notificationIndex]
                
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(Color.trainSoftBlue)
                        Text("\(notificationStation.name)駅で通知")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.textPrimary)
                        
                        Spacer()
                        
                        if let time = notificationStation.time {
                            Text(formatTime(time))
                                .font(.subheadline)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.trainSoftBlue.opacity(0.1))
                    .cornerRadius(10)
                } else {
                    // エラー時の詳細表示
                    VStack(alignment: .leading, spacing: 8) {
                        Text("通知駅を計算できません")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        
                        if actualStations.count <= 2 {
                            Text("経路の詳細情報が不足しています")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        } else {
                            Text("到着駅まで\(actualStations.count - 1)駅です")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .padding()
                }
            } else {
                Text("経路情報から駅を取得できません")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .padding()
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
        .onChange(of: notificationType) { newType in
            if newType == "station" {
                loadActualStations()
            }
        }
        .onAppear {
            if notificationType == "station" {
                loadActualStations()
            }
        }
    }
    
    private func loadActualStations() {
        // まずrouteのsectionsから駅リストを構築
        if !route.sections.isEmpty {
            var stations: [(name: String, time: Date?)] = []
            var addedStations = Set<String>()
            
            // 最初の駅（出発駅）を追加
            stations.append((name: route.departureStation, time: route.departureTime))
            addedStations.insert(route.departureStation)
            
            // 各セクションから中間駅を抽出
            for (index, section) in route.sections.enumerated() {
                // セクションの出発駅（最初のセクション以外）
                if index > 0 && !addedStations.contains(section.departureStation) {
                    stations.append((name: section.departureStation, time: section.departureTime))
                    addedStations.insert(section.departureStation)
                }
                
                // セクションの到着駅（最後のセクション以外は中間駅）
                if !addedStations.contains(section.arrivalStation) {
                    stations.append((name: section.arrivalStation, time: section.arrivalTime))
                    addedStations.insert(section.arrivalStation)
                }
            }
            
            actualStations = stations
            
            // trainNumberがある場合は、より詳細な情報を取得
            if let trainNumber = route.trainNumber,
               !trainNumber.isEmpty {
                loadDetailedStations(trainNumber: trainNumber)
            }
            return
        }
        
        // sectionsもtrainNumberもない場合は簡易的な駅リストを使用
        guard let trainNumber = route.trainNumber,
              !trainNumber.isEmpty else {
            actualStations = [
                (name: route.departureStation, time: route.departureTime),
                (name: route.arrivalStation, time: route.arrivalTime)
            ]
            return
        }
        
        loadDetailedStations(trainNumber: trainNumber)
    }
    
    private func loadDetailedStations(trainNumber: String) {
        // railwayを取得（trainNumberから推測）
        let railway: String
        if trainNumber.hasPrefix("A") {
            railway = "odpt.Railway:TokyoMetro.Marunouchi"
        } else if trainNumber.hasPrefix("B") {
            railway = "odpt.Railway:TokyoMetro.Hibiya"
        } else if trainNumber.hasPrefix("C") {
            railway = "odpt.Railway:TokyoMetro.Ginza"
        } else if trainNumber.hasPrefix("F") {
            railway = "odpt.Railway:TokyoMetro.Fukutoshin"
        } else if trainNumber.hasPrefix("G") {
            railway = "odpt.Railway:TokyoMetro.Ginza"
        } else if trainNumber.hasPrefix("H") {
            railway = "odpt.Railway:TokyoMetro.Hibiya"
        } else if trainNumber.hasPrefix("M") {
            railway = "odpt.Railway:TokyoMetro.Marunouchi"
        } else if trainNumber.hasPrefix("N") {
            railway = "odpt.Railway:TokyoMetro.Namboku"
        } else if trainNumber.hasPrefix("T") {
            railway = "odpt.Railway:TokyoMetro.Tozai"
        } else if trainNumber.hasPrefix("Y") {
            railway = "odpt.Railway:TokyoMetro.Yurakucho"
        } else if trainNumber.hasPrefix("Z") {
            railway = "odpt.Railway:TokyoMetro.Hanzomon"
        } else {
            // 他の路線の場合は既存のactualStationsを使用
            return
        }
        
        isLoadingStations = true
        
        Task {
            let calculator = StationCountCalculator()
            do {
                let stopStations = try await calculator.getStopStations(
                    trainNumber: trainNumber,
                    railwayId: railway,
                    departureStation: route.departureStation,
                    arrivalStation: route.arrivalStation
                )
                
                await MainActor.run {
                    // 通過駅を除外して実際の停車駅のみを取得
                    let actualStopStations = stopStations.filter { !$0.isPassingStation }
                    actualStations = actualStopStations.map { station in
                        (name: station.stationName, time: parseTimeString(station.departureTime ?? station.arrivalTime))
                    }
                    isLoadingStations = false
                }
            } catch {
                await MainActor.run {
                    // エラー時は簡易的な駅リストを使用
                    actualStations = [
                        (name: route.departureStation, time: route.departureTime),
                        (name: route.arrivalStation, time: route.arrivalTime)
                    ]
                    isLoadingStations = false
                }
            }
        }
    }
    
    private func parseTimeString(_ timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        if let time = formatter.date(from: timeString) {
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            
            return calendar.date(from: components)
        }
        
        return nil
    }
    
    
    private func formatNotificationTime() -> String {
        let notificationTime = route.arrivalTime.addingTimeInterval(TimeInterval(-notificationMinutes * 60))
        return formatTime(notificationTime)
    }
    
    private func calculateDuration() -> Int {
        let duration = route.arrivalTime.timeIntervalSince(route.departureTime)
        return Int(duration / 60)
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
    
    // MARK: - Repeat Settings Helpers
    
    private func getNextNotificationDate() -> Date? {
        guard isRepeating, repeatPattern != .none else { return nil }
        return repeatPattern.nextNotificationDate(
            baseTime: route.arrivalTime,
            customDays: Array(customDays)
        )
    }
    
    private func formatNextNotificationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        
        return "次回: " + formatter.string(from: date)
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
                    sections: [],
                    isActualArrivalTime: true
                )
            )
        }
        .environmentObject(NotificationManager.shared)
    }
}
