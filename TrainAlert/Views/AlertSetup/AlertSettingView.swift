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
        // キャラクタースタイルに応じたAI生成風プレビューメッセージ
        let style = setupData.characterStyle ?? .healing
        
        switch style {
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
