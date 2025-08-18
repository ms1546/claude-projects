//
//  TrainSelectionView.swift
//  TrainAlert
//
//  列車選択・アラート設定画面
//

import CoreData
import CoreLocation
import SwiftUI

struct TrainSelectionView: View {
    let train: ODPTTrainTimetableObject
    let departureStation: ODPTStation
    let railway: String
    let direction: String?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var selectedArrivalStation: ODPTStation?
    @State private var estimatedArrivalTime: Date?
    @State private var notificationMinutes: Int = 5
    @State private var characterStyle: CharacterStyle = .healing
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var showingStationSearch = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // AI設定の状態を監視
    @AppStorage("useAIGeneratedMessages") private var useAIGeneratedMessages = false
    @State private var hasValidAPIKey = false
    
    private let notificationOptions = [1, 3, 5, 10, 15, 20, 30]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 列車情報カード
                        trainInfoCard
                        
                        // 到着駅選択
                        arrivalStationCard
                        
                        // 通知設定
                        notificationSettingsCard
                        
                        // キャラクター設定
                        characterSettingsCard
                        
                        // 通知プレビュー
                        if selectedArrivalStation != nil && estimatedArrivalTime != nil {
                            notificationPreviewCard
                        }
                        
                        // AI生成メッセージの注意文
                        if useAIGeneratedMessages && !hasValidAPIKey {
                            aiKeyWarningCard
                        }
                        
                        // 保存ボタン
                        PrimaryButton(
                            "目覚ましを設定",
                            isEnabled: !isSaving && selectedArrivalStation != nil && estimatedArrivalTime != nil,
                            action: saveAlert
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("列車を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(Color.trainSoftBlue)
                }
            }
            .sheet(isPresented: $showingStationSearch) {
                ArrivalStationSearchView(
                    departureStation: departureStation,
                    train: train,
                    railway: railway,
                    direction: direction
                ) { station, arrivalTime in
                        selectedArrivalStation = station
                        estimatedArrivalTime = arrivalTime
                        showingStationSearch = false
                }
            }
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
    }
    
    // MARK: - Train Info Card
    
    private var trainInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("列車情報")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // 出発時刻・駅
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading) {
                        Text(train.departureTime)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color.textPrimary)
                        Text(departureStation.stationTitle?.ja ?? departureStation.title)
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    Spacer()
                }
                
                // 列車種別・行き先
                HStack(spacing: 16) {
                    if let trainType = train.trainTypeTitle?.ja {
                        Label(trainType, systemImage: "tram")
                            .font(.subheadline)
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    if let destination = train.destinationStationTitle?.ja {
                        Label("\(destination)行", systemImage: "arrow.right.circle")
                            .font(.subheadline)
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                // プラットフォーム
                if let platform = train.platformNumber {
                    Label("\(platform)番線", systemImage: "signpost.right")
                        .font(.caption)
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
    
    // MARK: - Arrival Station Card
    
    private var arrivalStationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color.warmOrange)
                    .font(.system(size: 18))
                Text("到着駅")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            Button(action: { showingStationSearch = true }) {
                HStack {
                    if let station = selectedArrivalStation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.stationTitle?.ja ?? station.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.textPrimary)
                            
                            if let arrivalTime = estimatedArrivalTime {
                                Text("到着予定: \(formatTime(arrivalTime))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                    } else {
                        Text("到着駅を選択してください")
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.backgroundSecondary)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
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
            
            Text("到着何分前に通知しますか？")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(notificationOptions, id: \.self) { minutes in
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
                }
            }
            
            if let arrivalTime = estimatedArrivalTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(Color.textSecondary)
                    Text("通知予定時刻: \(formatTime(arrivalTime.addingTimeInterval(TimeInterval(-notificationMinutes * 60))))")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.top, 4)
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
            
            VStack(alignment: .leading, spacing: 12) {
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
                
                if let station = selectedArrivalStation {
                    Text("🚃 もうすぐ\(station.stationTitle?.ja ?? station.title)駅です！")
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                    
                    Text(getPreviewMessage())
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let arrivalTime = estimatedArrivalTime {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                            Text("到着予定: \(formatTime(arrivalTime))")
                                .font(.caption)
                        }
                        .foregroundColor(Color.textSecondary)
                    }
                }
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
        guard let arrivalStation = selectedArrivalStation,
              let arrivalTime = estimatedArrivalTime else { return }
        
        isSaving = true
        
        Task {
            do {
                // アラートエンティティを作成
                let alert = Alert(context: viewContext)
                alert.alertId = UUID()
                alert.isActive = true
                alert.characterStyle = characterStyle.rawValue
                alert.notificationType = "time"
                alert.notificationTime = Int16(notificationMinutes)
                alert.notificationDistance = 0
                alert.createdAt = Date()
                
                // 時刻表ベースの情報を保存
                alert.departureStation = departureStation.stationTitle?.ja ?? departureStation.title
                alert.arrivalTime = arrivalTime
                // TODO: trainNumberプロパティを追加する必要あり
                // alert.trainNumber = train.trainNumber
                
                // 到着駅の情報を作成または取得
                let stationName = arrivalStation.stationTitle?.ja ?? arrivalStation.title
                let stationId = arrivalStation.sameAs
                
                let fetchRequest = Station.fetchRequest(stationId: stationId)
                let existingStation = try? viewContext.fetch(fetchRequest).first
                
                let station: Station
                if let existing = existingStation {
                    station = existing
                } else {
                    station = Station(context: viewContext)
                    station.stationId = stationId
                    station.name = stationName
                    station.latitude = 35.6812  // TODO: 実際の座標を取得
                    station.longitude = 139.7671
                    // 路線名を適切に設定（日本語タイトルがなければIDをそのまま使用）
                    let railwayName = departureStation.railwayTitle?.ja ?? getRailwayJapaneseName(from: departureStation.railway)
                    station.lines = [railwayName]
                    station.isFavorite = false
                    station.createdAt = Date()
                }
                
                station.lastUsedAt = Date()
                alert.station = station
                
                try viewContext.save()
                
                // 通知をスケジュール
                try await notificationManager.scheduleTrainAlert(
                    for: stationName,
                    arrivalTime: arrivalTime,
                    currentLocation: nil,
                    targetLocation: CLLocation(latitude: station.latitude, longitude: station.longitude),
                    characterStyle: characterStyle
                )
                
                await MainActor.run {
                    isSaving = false
                    
                    // 成功のHaptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    
                    // HomeViewを更新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeView"), object: nil)
                    
                    // 目覚まし監視サービスを更新
                    AlertMonitoringService.shared.reloadAlerts()
                    
                    // 時刻表画面も閉じるための通知
                    NotificationCenter.default.post(name: NSNotification.Name("DismissTimetableSearch"), object: nil)
                    
                    // 画面を閉じる
                    dismiss()
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
    
    private func checkAPIKeyStatus() {
        if useAIGeneratedMessages {
            if let apiKey = try? KeychainManager.shared.getOpenAIAPIKey(),
               !apiKey.isEmpty {
                hasValidAPIKey = true
            } else {
                hasValidAPIKey = false
            }
        }
    }
    
    // 路線IDから日本語名を取得するヘルパーメソッド
    private func getRailwayJapaneseName(from railwayId: String) -> String {
        let components = railwayId.split(separator: ":").map { String($0) }
        guard components.count >= 2 else { return railwayId }
        
        let operatorAndLine = components[1].split(separator: ".").map { String($0) }
        guard operatorAndLine.count >= 2 else { return railwayId }
        
        let operatorName = operatorAndLine[0]
        let lineName = operatorAndLine[1]
        
        // オペレーター名の日本語化
        let operatorJa: String
        switch operatorName {
        case "TokyoMetro":
            operatorJa = "東京メトロ"
        case "JR-East":
            operatorJa = "JR東日本"
        case "Toei":
            operatorJa = "都営"
        case "Tokyu":
            operatorJa = "東急"
        case "Keio":
            operatorJa = "京王"
        case "Odakyu":
            operatorJa = "小田急"
        case "Seibu":
            operatorJa = "西武"
        case "Tobu":
            operatorJa = "東武"
        default:
            operatorJa = operatorName
        }
        
        // 路線名の日本語化
        let lineJa: String
        switch lineName {
        case "Hanzomon":
            lineJa = "半蔵門線"
        case "Ginza":
            lineJa = "銀座線"
        case "Marunouchi":
            lineJa = "丸ノ内線"
        case "Hibiya":
            lineJa = "日比谷線"
        case "Tozai":
            lineJa = "東西線"
        case "Chiyoda":
            lineJa = "千代田線"
        case "Yurakucho":
            lineJa = "有楽町線"
        case "Namboku":
            lineJa = "南北線"
        case "Fukutoshin":
            lineJa = "副都心線"
        case "Yamanote":
            lineJa = "山手線"
        case "Chuo", "ChuoRapid":
            lineJa = "中央線"
        case "Keihin-TohokuNegishi":
            lineJa = "京浜東北線"
        case "Sobu":
            lineJa = "総武線"
        case "Saikyo":
            lineJa = "埼京線"
        default:
            lineJa = lineName + "線"
        }
        
        return operatorJa + lineJa
    }
}

// MARK: - Arrival Station Search View

private struct ArrivalStationSearchView: View {
    let departureStation: ODPTStation
    let train: ODPTTrainTimetableObject
    let railway: String
    let direction: String?
    let onSelect: (ODPTStation, Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var stations: [ODPTStation] = []
    @State private var estimatedTimes: [String: Date] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingIndicator(text: "到着駅を取得中...")
                } else if stations.isEmpty {
                    emptyStateView
                } else {
                    stationList
                }
            }
            .navigationTitle("到着駅を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(Color.trainSoftBlue)
                }
            }
            .onAppear {
                loadPossibleArrivalStations()
            }
            .onChange(of: direction) { _ in
                isLoading = true
                stations = []
                estimatedTimes = [:]
                loadPossibleArrivalStations()
            }
        }
    }
    
    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(stations, id: \.sameAs) { station in
                    Button(action: {
                        if let arrivalTime = estimatedTimes[station.sameAs] {
                            onSelect(station, arrivalTime)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.stationTitle?.ja ?? station.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.textPrimary)
                                
                                if let time = estimatedTimes[station.sameAs] {
                                    Text("到着予定: \(formatTime(time))")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(Color.warmOrange)
            
            Text("到着駅情報を取得できませんでした")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            Text("ネットワーク接続を確認するか、\nしばらく経ってから再度お試しください")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { dismiss() }) {
                Text("閉じる")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.trainSoftBlue)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadPossibleArrivalStations() {
        Task {
            do {
                let apiClient = ODPTAPIClient.shared
                
                print("Loading stations for railway: \(railway)")
                
                // 路線の全駅を順序付きで取得
                let allStationsOnLine = try await apiClient.getStationsOnRailway(railwayId: railway)
                
                print("Received \(allStationsOnLine.count) stations")
                
                if allStationsOnLine.isEmpty {
                    print("ERROR: No stations found for railway \(railway)")
                    throw ODPTAPIError.invalidResponse
                }
                
                // 出発駅のインデックスを見つける
                let departureIndex = allStationsOnLine.firstIndex { station in
                    station.sameAs == departureStation.sameAs
                } ?? -1
                
                // デバッグ情報
                print("=== Direction Analysis ===")
                print("Direction parameter: \(direction ?? "nil")")
                print("Train destination: \(train.destinationStationTitle?.ja ?? "不明")")
                print("Departure station: \(departureStation.stationTitle?.ja ?? departureStation.title)")
                print("Departure index: \(departureIndex)")
                
                // 進行方向に基づいてフィルタリング
                var arrivalStations: [ODPTStation] = []
                
                if departureIndex >= 0 {
                    // direction情報から進行方向を判定（優先）
                    if let dir = direction {
                        print("Using direction info: \(dir)")
                        
                        // 方向文字列から終点駅を抽出
                        var isForward = true  // デフォルトは順方向
                        
                        // 方向文字列に含まれる駅名を探す
                        for (index, station) in allStationsOnLine.enumerated() {
                            let stationName = station.stationTitle?.ja ?? station.title
                            if dir.contains(stationName) {
                                print("Found direction station: \(stationName) at index \(index)")
                                // 方向駅のインデックスと出発駅のインデックスを比較
                                isForward = index > departureIndex
                                break
                            }
                        }
                        
                        if isForward {
                            // 順方向：出発駅より後の駅
                            arrivalStations = Array(allStationsOnLine[(departureIndex + 1)...])
                            print("Forward direction: showing stations after departure")
                        } else {
                            // 逆方向：出発駅より前の駅
                            if departureIndex > 0 {
                                arrivalStations = Array(allStationsOnLine[0..<departureIndex]).reversed()
                                print("Reverse direction: showing stations before departure")
                            }
                        }
                    } else {
                        // direction情報がない場合は列車の行き先から判定
                        let destinationName = train.destinationStationTitle?.ja ?? ""
                        print("No direction info, using train destination: \(destinationName)")
                        
                        let destinationIndex = allStationsOnLine.firstIndex { station in
                            let stationName = station.stationTitle?.ja ?? station.title
                            return destinationName.contains(stationName) || stationName == destinationName
                        }
                        
                        if let destIndex = destinationIndex {
                            print("Found destination at index: \(destIndex)")
                            // 出発駅と行き先駅の位置関係から到着可能駅を決定
                            if destIndex > departureIndex {
                                // 行き先が後方：出発駅より後の駅
                                arrivalStations = Array(allStationsOnLine[(departureIndex + 1)...min(destIndex, allStationsOnLine.count - 1)])
                            } else if destIndex < departureIndex {
                                // 行き先が前方：出発駅より前の駅
                                arrivalStations = Array(allStationsOnLine[max(0, destIndex)...(departureIndex - 1)]).reversed()
                            }
                        } else {
                            // 行き先が不明な場合は出発駅以外の全駅
                            print("Destination not found, showing all stations")
                            arrivalStations = allStationsOnLine.filter { $0.sameAs != departureStation.sameAs }
                        }
                    }
                } else {
                    // 出発駅が見つからない場合は全駅（出発駅以外）
                    arrivalStations = allStationsOnLine.filter { $0.sameAs != departureStation.sameAs }
                }
                
                // 到着時刻を推定（駅間を3-5分で計算）
                let baseTime = parseTime(train.departureTime) ?? Date()
                var times: [String: Date] = [:]
                for (index, station) in arrivalStations.enumerated() {
                    let minutesPerStation = railway.contains("TokyoMetro") ? 3 : 4 // メトロは3分、JRは4分
                    let arrivalTime = baseTime.addingTimeInterval(TimeInterval((index + 1) * minutesPerStation * 60))
                    times[station.sameAs] = arrivalTime
                }
                
                print("=== Result ===")
                print("Total arrival stations: \(arrivalStations.count)")
                if !arrivalStations.isEmpty {
                    print("First station: \(arrivalStations.first?.stationTitle?.ja ?? "不明")")
                    print("Last station: \(arrivalStations.last?.stationTitle?.ja ?? "不明")")
                }
                
                await MainActor.run {
                    self.stations = arrivalStations
                    self.estimatedTimes = times
                    self.isLoading = false
                }
            } catch {
                print("APIから駅データの取得に失敗: \(error)")
                // APIエラー時のフォールバック
                await MainActor.run {
                    self.isLoading = false
                    // エラーメッセージを表示
                    self.stations = []
                }
            }
        }
    }
    
    
    private func parseTime(_ timeString: String) -> Date? {
        // 時刻文字列から今日の日付でDateを作成
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        dateComponents.second = 0
        
        return Calendar.current.date(from: dateComponents)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct TrainSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TrainSelectionView(
            train: ODPTTrainTimetableObject(
                departureTime: "10:30",
                trainType: "odpt.TrainType:JR-East.Local",
                trainTypeTitle: ODPTMultilingualTitle(ja: "各駅停車", en: "Local"),
                trainNumber: "1030M",
                trainName: nil,
                destinationStation: ["odpt.Station:JR-East.Yamanote.Osaki"],
                destinationStationTitle: ODPTMultilingualTitle(ja: "大崎", en: "Osaki"),
                isLast: false,
                isOrigin: false,
                platformNumber: "1",
                note: nil
            ),
            departureStation: ODPTStation(
                id: "test",
                sameAs: "odpt.Station:JR-East.Yamanote.Tokyo",
                date: nil,
                title: "東京",
                stationTitle: ODPTMultilingualTitle(ja: "東京", en: "Tokyo"),
                railway: "odpt.Railway:JR-East.Yamanote",
                railwayTitle: ODPTMultilingualTitle(ja: "JR山手線", en: "JR Yamanote Line"),
                operator: "odpt.Operator:JR-East",
                operatorTitle: ODPTMultilingualTitle(ja: "JR東日本", en: "JR East"),
                stationCode: "JY01",
                connectingRailway: nil
            ),
            railway: "odpt.Railway:JR-East.Yamanote",
            direction: "odpt.RailDirection:JR-East.Osaki"
        )
        .environmentObject(NotificationManager.shared)
    }
}

