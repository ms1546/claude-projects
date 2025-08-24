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
    
    // スヌーズ設定の状態
    @State private var isSnoozeEnabled = false
    @State private var snoozeStartStations: Int = 3
    @State private var snoozeStartStationsDouble: Double = 3.0  // Slider用
    @State private var maxSnoozeStations: Int = 3  // 実際の駅数に基づいて更新（初期値を安全な値に）
    
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
                    
                    // 通知される駅（駅数ベースまたはスヌーズ有効時）
                    if notificationType == "station" || isSnoozeEnabled {
                        notificationStationCard
                    }
                    
                    // スヌーズ設定
                    snoozeSettingsCard
                    
                    // ハイブリッド通知設定
                    hybridNotificationCard
                    
                    // 繰り返し設定
                    repeatSettingsCard
                    
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
                        isEnabled: !isSaving && isValidNotificationSetting(),
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
        // トントン成功メッセージは表示せず、直接ホームに戻る
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
            
            // スヌーズ設定の初期化
            let validSnoozeValue = min(snoozeStartStations, max(1, maxSnoozeStations))
            snoozeStartStations = validSnoozeValue
            snoozeStartStationsDouble = Double(validSnoozeValue)
            
            // 初期のmaxSnoozeStationsを設定
            if actualStations.isEmpty {
                // 最小限の駅数で初期化
                actualStations = [
                    (name: route.departureStation, time: route.departureTime),
                    (name: route.arrivalStation, time: route.arrivalTime)
                ]
                updateMaxSnoozeStations()
            }
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
            
            // 列車情報と遅延状況
            if let trainNumber = route.trainNumber {
                HStack(spacing: 12) {
                    // 列車番号
                    HStack(spacing: 6) {
                        Image(systemName: "tram.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trainNumber)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.textPrimary)
                        if let trainType = route.trainType {
                            Text("(\(trainType))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 遅延情報
                    DelayStatusView(
                        trainNumber: trainNumber,
                        railwayId: route.sections.first?.railway
                    )
                }
                .padding(.bottom, 8)
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
                            updateMaxSnoozeStations()
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
                            updateMaxSnoozeStations()
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
                // スヌーズの最大駅数を更新
                updateMaxSnoozeStations()
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
    
    // MARK: - Snooze Settings Card
    
    private var snoozeSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("スヌーズ設定")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            // スヌーズのオン/オフ
            Toggle(isOn: $isSnoozeEnabled) {
                Text("駅ごと通知（スヌーズ）")
                    .font(.subheadline)
                    .foregroundColor(Color.textPrimary)
            }
            .tint(.trainSoftBlue)
            .onChange(of: isSnoozeEnabled) { newValue in
                if newValue {
                    // スヌーズが有効になった時、値を同期
                    let validValue = min(snoozeStartStations, max(1, maxSnoozeStations))
                    snoozeStartStations = validValue
                    snoozeStartStationsDouble = Double(validValue)
                }
            }
            
            if isSnoozeEnabled {
                VStack(spacing: 12) {
                    // 駅数が少なすぎる場合の警告
                    if maxSnoozeStations < 1 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("経路が短すぎるため、スヌーズ機能を利用できません")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        // 開始駅数の設定
                        HStack {
                            Text("通知開始")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                            
                            Spacer()
                            
                            Text("\(snoozeStartStations)駅前から")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.trainSoftBlue)
                        }
                        
                        if maxSnoozeStations >= 1 {
                            HStack {
                                Text("1駅前")
                                    .font(.caption2)
                                    .foregroundColor(Color.textSecondary)
                                
                                Slider(
                                    value: $snoozeStartStationsDouble,
                                    in: 1...Double(maxSnoozeStations),
                                    step: 1
                                )
                                .tint(.trainSoftBlue)
                                .onChange(of: snoozeStartStationsDouble) { newValue in
                                    snoozeStartStations = min(Int(newValue), maxSnoozeStations)
                                }
                                
                                Text("\(maxSnoozeStations)駅前")
                                    .font(.caption2)
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                    
                        // 駅数ベースの通知設定の場合、その制限を説明
                        if notificationType == "station" && maxSnoozeStations < notificationStations {
                            Text("通知設定（\(notificationStations)駅前）より前から段階的に通知します")
                                .font(.caption2)
                                .foregroundColor(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("各駅で段階的に通知し、寝過ごしを防ぎます")
                                .font(.caption2)
                                .foregroundColor(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: isSnoozeEnabled)
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private func getSnoozePreviewText(for stationsRemaining: Int) -> String {
        // キャラクタースタイルに応じたAI生成風プレビューメッセージ
        switch characterStyle {
        case .healing:
            switch stationsRemaining {
            case 1:
                return "もうすぐ降車駅に到着しますね✨ お荷物の確認をして、ゆっくりとご準備くださいませ。素敵な一日になりますように💫"
            case 2:
                return "あと2駅で到着です☺️ そろそろお支度を始めましょうか。今日もあなたらしく、無理せずにいきましょうね🌸"
            case 3:
                return "降車駅まであと3駅です😌 まだ少しお時間がありますので、ゆったりとお過ごしください。必要な時にまたお知らせしますね"
            case 4:
                return "あと4駅の地点を通過中です🚃 今はリラックスタイムです。お疲れが出ていませんか？もう少しの間、ゆっくりしていてくださいね"
            default:
                return "降車駅まで\(stationsRemaining)駅です😊 まだ余裕がありますので、車窓の景色でも楽しんでいてください。時間になったらお知らせしますね"
            }
        case .gyaru:
            switch stationsRemaining {
            case 1:
                return "ヤバっ！マジで次降りるよ〜！💦 荷物チェックして〜！降り遅れたらマジ終わるから気をつけて〜！がんばっ💪✨"
            case 2:
                return "あと2駅だよ〜！そろそろ準備始めよ〜？✨ てか眠くない？大丈夫？もうちょいだから頑張ろ〜！ファイト〜！"
            case 3:
                return "あと3駅〜！まだちょい時間あるけど〜、そろそろ心の準備しとこ？😘 でもまだ焦らなくて大丈夫だよ〜♪"
            case 4:
                return "4駅前通過〜！まだ全然余裕じゃん！😎 でも油断は禁物だよ〜？また近くなったら教えるから安心して〜♡"
            default:
                return "まだ\(stationsRemaining)駅もあるじゃ〜ん！めっちゃ余裕〜♪ 今はゆっくりしてて〜！でも寝過ぎないでよ？😝"
            }
        case .butler:
            switch stationsRemaining {
            case 1:
                return "お客様、次の駅でお降りでございます。お忘れ物がないよう、今一度お手回り品のご確認をお願いいたします。本日もご利用ありがとうございました"
            case 2:
                return "あと2駅でございます。そろそろお支度を始められてはいかがでしょうか。お荷物の整理など、ゆっくりとご準備くださいませ"
            case 3:
                return "降車駅まであと3駅でございます。まだお時間に余裕がございますが、念のためお知らせいたしました。引き続きごゆっくりお過ごしください"
            case 4:
                return "現在、降車駅の4駅手前を走行中でございます。まだ十分にお時間がございますので、どうぞお寛ぎくださいませ"
            default:
                return "お客様の降車駅まで、あと\(stationsRemaining)駅でございます。まだお時間に余裕がございますので、ごゆるりとお過ごしくださいませ"
            }
        case .sporty:
            switch stationsRemaining {
            case 1:
                return "ラストスパートだ！次で降車！💪 荷物チェックOK？立ち上がる準備はできてる？最後まで気を抜かずにいこう！ファイト！🔥"
            case 2:
                return "残り2駅！ウォーミングアップ開始の時間だ！🏃 軽くストレッチして、降車の準備を始めよう！あと少しだ、頑張ろう！"
            case 3:
                return "あと3駅でゴール！そろそろ準備運動かな？💯 まだ少し時間はあるけど、心の準備は大事だよ！一緒に頑張ろう！"
            case 4:
                return "4駅前通過！まだ余裕のペース配分だね👍 今は体力温存タイム！でも油断は禁物、集中力キープでいこう！"
            default:
                return "ゴールまで残り\(stationsRemaining)駅！今はまだリラックスタイムだ😄 でもメンタルは常に準備OK状態でいこうね！ナイスファイト！"
            }
        case .tsundere:
            switch stationsRemaining {
            case 1:
                return "つ、次で降りるんだからね！ちゃんと準備してる？💢 べ、別にあなたが降り遅れても知らないんだから...でも、ちゃんと降りなさいよ！"
            case 2:
                return "あと2駅よ...そろそろ準備したら？😤 まさか寝ぼけてるんじゃないでしょうね？し、心配なんかしてないけど...一応確認しただけよ！"
            case 3:
                return "降車駅まであと3駅ね...まだ時間はあるけど💭 油断してると危ないわよ？べ、別にあなたのためじゃなくて、私の仕事だから言ってるだけなんだから！"
            case 4:
                return "4駅前...まだ余裕があるわね😌 でも調子に乗って寝過ごさないでよ？あ、あなたがどうなろうと知ったことじゃないけど...一応ね"
            default:
                return "まだ\(stationsRemaining)駅もあるのね...まあ、ゆっくりしてなさい😏 で、でも！寝過ごしたりしないでよ？私、何度も起こさないからね！"
            }
        case .kansai:
            switch stationsRemaining {
            case 1:
                return "おっ！次やで〜！降りる準備せなアカンで〜！😄 荷物忘れたらアカンから、もう一回確認しときや〜！ほな、気ぃつけて降りてや〜！"
            case 2:
                return "あと2駅やな〜！ぼちぼち準備始めよか〜？🎵 まだちょい時間あるけど、そろそろ起きときや〜！寝過ごしたら知らんで〜！"
            case 3:
                return "降りるとこまであと3駅やで〜！😊 まだ余裕あるけど、そろそろ心の準備しとき〜！でもまあ、焦らんでもええで〜"
            case 4:
                return "4駅前通過中や〜！まだまだ時間あるな〜👌 今はのんびりしててもええけど、また近なったら教えたるから安心しぃ〜！"
            default:
                return "あと\(stationsRemaining)駅もあるやん！めっちゃ余裕やな〜😁 今はゆっくりしてたらええで〜！でも寝すぎたらアカンで？ほどほどにな〜！"
            }
        }
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
        // 駅数ベースの場合、通知駅が出発駅でないことを確認
        if notificationType == "station" {
            if !actualStations.isEmpty {
                let notificationIndex = actualStations.count - notificationStations - 1
                if notificationIndex <= 0 {
                    errorMessage = "出発駅での通知はできません"
                    showError = true
                    return
                }
            }
        }
        
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
                
                // スヌーズ設定を保存
                alert.isSnoozeEnabled = isSnoozeEnabled
                alert.snoozeStartStations = Int16(snoozeStartStations)
                
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
                    // Using existing station
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
                    
                    // Created new station
                }
                
                // 最終使用日時を更新
                station.lastUsedAt = Date()
                
                // アラートとの関連付け
                alert.station = station
                // Station relationship established successfully
                
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
                // Core Data保存成功
                
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
                        // 繰り返し通知スケジュール成功
                    } else {
                        // 単発の通知をスケジュール
                        try await notificationManager.scheduleTrainAlert(
                            for: route.arrivalStation,
                            arrivalTime: route.arrivalTime,
                            currentLocation: nil,
                            targetLocation: CLLocation(latitude: station.latitude, longitude: station.longitude),
                            characterStyle: characterStyle
                        )
                        // 通知スケジュール成功
                    }
                    
                    // スヌーズ通知の初期化
                    if isSnoozeEnabled {
                        do {
                            try await SnoozeNotificationManager.shared.scheduleSnoozeNotifications(
                                for: alert,
                                currentStationCount: Int(snoozeStartStations),
                                railway: route.sections.first?.railway
                            )
                            // スヌーズ通知スケジュール成功
                        } catch {
                            // スヌーズ通知のスケジュールに失敗
                        }
                    }
                } catch {
                    // 通知のスケジュールに失敗
                }
                
                await MainActor.run {
                    isSaving = false
                    // トントン設定完了
                    
                    // 成功のHaptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // HomeViewを更新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeView"), object: nil)
                    
                    // トントン監視サービスを更新
                    AlertMonitoringService.shared.reloadAlerts()
                    
                    // ハイブリッド通知の監視を開始（RouteAlertではなく通常のAlertで代用）
                    if HybridNotificationManager.shared.isEnabled {
                        // RouteAlertの代わりに、保存した情報から仮のRouteAlertオブジェクトを作成
                        let tempRouteAlert = RouteAlert(context: viewContext)
                        tempRouteAlert.routeId = alert.alertId
                        tempRouteAlert.departureStation = route.departureStation
                        tempRouteAlert.arrivalStation = route.arrivalStation
                        tempRouteAlert.departureTime = route.departureTime
                        tempRouteAlert.arrivalTime = route.arrivalTime
                        tempRouteAlert.trainNumber = route.trainNumber
                        tempRouteAlert.trainType = route.trainType
                        tempRouteAlert.notificationMinutes = Int16(notificationMinutes)
                        tempRouteAlert.isActive = true
                        
                        // 位置情報サービスが有効な場合のみ監視を開始
                        if let locationManager = LocationManager.shared {
                            HybridNotificationManager.shared.startMonitoring(
                                for: tempRouteAlert,
                                locationManager: locationManager,
                                notificationManager: notificationManager
                            )
                            
                            // GPS精度管理も開始
                            LocationAccuracyManager.shared.startManaging(locationManager: locationManager)
                            
                            // GPSフォールバック監視も開始
                            GPSFallbackHandler.shared.startMonitoring(
                                locationManager: locationManager,
                                routeAlert: tempRouteAlert
                            )
                        }
                    }
                    
                    // 少し遅延させてから経路検索画面を閉じる
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("CloseRouteSearch"), object: nil)
                    }
                }
            } catch {
                // トントン保存エラー
                
                await MainActor.run {
                    isSaving = false
                    errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isValidNotificationSetting() -> Bool {
        if notificationType == "time" {
            return !availableNotificationOptions.isEmpty
        } else {
            // 駅数ベースの場合、通知駅が出発駅でないことを確認
            if !actualStations.isEmpty {
                let notificationIndex = actualStations.count - notificationStations - 1
                return notificationIndex > 0 && notificationIndex < actualStations.count
            }
            return false
        }
    }
    
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
            
            // スヌーズが有効な場合の説明
            if isSnoozeEnabled && !isLoadingStations && !actualStations.isEmpty {
                // スヌーズ通知の駅リスト
                let totalStations = actualStations.count
                if totalStations > 2 {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach((1...min(snoozeStartStations, totalStations - 2)).reversed(), id: \.self) { stationsRemaining in
                            let stationIndex = totalStations - stationsRemaining - 1
                            if stationIndex >= 0 && stationIndex < totalStations {
                                let station = actualStations[stationIndex]
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(stationsRemaining == 1 ? Color.orange : Color.trainSoftBlue)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(getDisplayStationName(station.name))
                                        .font(.subheadline)
                                        .foregroundColor(stationsRemaining == 1 ? .orange : .textPrimary)
                                    
                                    Text("（\(getSnoozePreviewText(for: stationsRemaining))）")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                    
                                    Spacer()
                                    
                                    if let time = station.time {
                                        Text(formatTime(time))
                                            .font(.caption)
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.backgroundSecondary)
                    .cornerRadius(10)
                } else {
                    Text("経路が短すぎるため、スヌーズ通知を設定できません")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            // 通知駅の情報を表示（駅数ベースの通知）
            else if notificationType == "station" && isLoadingStations {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .trainSoftBlue))
                    Text("駅情報を取得中...")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if notificationType == "station" && !actualStations.isEmpty {
                // 通知駅のインデックスを計算（到着駅から数えて何駅前か）
                let notificationIndex = actualStations.count - notificationStations - 1
                
                if notificationIndex >= 0 && notificationIndex < actualStations.count {
                    let notificationStation = actualStations[notificationIndex]
                    
                    // 通知駅が出発駅の場合はエラー表示
                    if notificationIndex == 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("通知できません")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("出発駅での通知はできません。駅数を減らすか、時間ベースの通知をご利用ください。")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(Color.trainSoftBlue)
                            Text("\(getDisplayStationName(notificationStation.name))駅で通知")
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
                    }
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
        .onChange(of: isSnoozeEnabled) { enabled in
            if enabled {
                loadActualStations()
            }
        }
        .onAppear {
            if notificationType == "station" || isSnoozeEnabled {
                loadActualStations()
            }
        }
    }
    
    private func loadActualStations() {
        // まずrouteのsectionsから駅リストを構築
        if !route.sections.isEmpty {
            // [DEBUG] loadActualStations: Building from sections
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
            
            // [DEBUG] stations from sections
            actualStations = stations
            updateMaxSnoozeStations()
            
            // trainNumberがある場合は、より詳細な情報を取得
            if let trainNumber = route.trainNumber,
               !trainNumber.isEmpty {
                // [DEBUG] trainNumber found, loading detailed stations
                loadDetailedStations(trainNumber: trainNumber)
            } else {
                // [DEBUG] No trainNumber, using sections data only
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
            updateMaxSnoozeStations()
            return
        }
        
        loadDetailedStations(trainNumber: trainNumber)
    }
    
    private func loadDetailedStations(trainNumber: String) {
        // routeのsectionsから路線情報を取得
        let railway: String
        if let firstSection = route.sections.first {
            railway = firstSection.railway
        } else {
            // sectionsがない場合は既存のactualStationsを使用
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
                    // [DEBUG] getStopStations returned stations
                    actualStations = actualStopStations.map { station in
                        // [STATION NAME DEBUG] Mapping station
                        (name: station.stationName, time: parseTimeString(station.departureTime ?? station.arrivalTime))
                    }
                    updateMaxSnoozeStations()
                    isLoadingStations = false
                    
                    // デバッグ: 通知駅の確認
                    let notificationIndex = actualStations.count - notificationStations - 1
                    // [DEBUG] Notification calculation
                }
            } catch {
                await MainActor.run {
                    // エラー時は既存のactualStationsを維持
                    // 詳細な駅情報の取得に失敗
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
    
    // MARK: - Hybrid Notification Card
    
    private var hybridNotificationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("ハイブリッド通知")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                
                Spacer()
                
                // 設定画面へのリンク
                NavigationLink(destination: HybridStatusView()) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.textSecondary)
                        .font(.system(size: 16))
                }
            }
            
            VStack(spacing: 12) {
                // ハイブリッド通知の有効/無効
                HStack {
                    Label("位置情報連携", systemImage: "location.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Toggle("", isOn: .constant(HybridNotificationManager.shared.isEnabled))
                        .labelsHidden()
                        .tint(.trainSoftBlue)
                        .disabled(true) // 読み取り専用表示
                }
                
                if HybridNotificationManager.shared.isEnabled {
                    // 現在のモード表示
                    HStack {
                        Text("優先モード")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: HybridNotificationManager.shared.currentMode.icon)
                                .font(.caption)
                            Text(HybridNotificationManager.shared.currentMode.displayName)
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.trainSoftBlue)
                    }
                    
                    // GPS精度表示
                    HStack {
                        Text("GPS精度")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(LocationAccuracyManager.shared.accuracyLevel.color)
                                .frame(width: 8, height: 8)
                            Text(LocationAccuracyManager.shared.accuracyLevel.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(.textPrimary)
                        }
                    }
                    
                    Text("時刻表と位置情報を組み合わせて、より正確な通知タイミングを実現します")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(Color.backgroundCard)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Repeat Settings Helpers
    
    private func getNextNotificationDate() -> Date? {
        guard isRepeating, repeatPattern != .none else { return nil }
        return repeatPattern.nextNotificationDate(
            baseTime: route.arrivalTime,
            customDays: Array(customDays)
        )
    }
    
    private func updateMaxSnoozeStations() {
        // 実際の駅数から最大スヌーズ駅数を計算
        // 出発駅を除いた駅数が最大値（到着駅の1駅前まで通知可能）
        let availableStations = max(1, actualStations.count - 2)
        
        // 通知設定が駅数ベースの場合、その設定値を上限とする
        if notificationType == "station" {
            maxSnoozeStations = min(notificationStations, availableStations)
        } else {
            maxSnoozeStations = min(5, availableStations)  // 最大5駅前まで
        }
        
        // 現在の設定値が最大値を超えている場合は調整
        if snoozeStartStations > maxSnoozeStations {
            snoozeStartStations = max(1, maxSnoozeStations)
            snoozeStartStationsDouble = Double(max(1, maxSnoozeStations))
        }
    }
    
    private func getDisplayStationName(_ stationName: String) -> String {
        // 既に日本語名の場合はそのまま返す（日本語文字を含むかチェック）
        let japaneseCharacterSet = CharacterSet(charactersIn: "あ-んア-ン一-龠")
        if stationName.rangeOfCharacter(from: japaneseCharacterSet) != nil {
            return stationName
        }
        
        // 英語名の場合は日本語名に変換を試みる
        let romanizer = StationNameRomanizer.shared
        if let japaneseName = romanizer.toJapanese(stationName) {
            // [STATION NAME DISPLAY] Converted to Japanese name
            return japaneseName
        }
        
        // 変換できない場合は元の名前を返す
        // [STATION NAME DISPLAY] No conversion found
        return stationName
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
