//
//  TimetableSearchView.swift
//  TrainAlert
//
//  時刻表検索・表示画面
//

import SwiftUI

// 選択データを保持する構造体
struct TrainSelectionData: Equatable {
    let train: ODPTTrainTimetableObject
    let station: ODPTStation
    let railway: String
    let direction: String?
    
    static func == (lhs: TrainSelectionData, rhs: TrainSelectionData) -> Bool {
        lhs.train.departureTime == rhs.train.departureTime &&
               lhs.station.sameAs == rhs.station.sameAs &&
               lhs.railway == rhs.railway &&
               lhs.direction == rhs.direction
    }
}

struct TimetableSearchView: View {
    @StateObject private var viewModel = TimetableSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStation: ODPTStation?
    @State private var selectedDirection: String?
    @State private var showingStationSearch = false
    @State private var selectedTrainData: TrainSelectionData?
    @State private var sheetTrainData: TrainSelectionData?  // sheet表示用の永続的なデータ
    @State private var showingTrainSelection = false
    @State private var isDataPreparing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 駅選択セクション
                    stationSelectionSection
                        .padding()
                        .background(Color.backgroundSecondary)
                    
                    // 時刻表表示
                    if selectedStation != nil {
                        if viewModel.isLoading {
                            LoadingIndicator(text: "時刻表を取得中...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if viewModel.timetables.isEmpty {
                            emptyStateView
                        } else {
                            timetableContent
                                .overlay(
                                    // ローディング中のオーバーレイ
                                    (viewModel.isLoading || isDataPreparing) ? 
                                    Color.black.opacity(0.3)
                                        .overlay(
                                            VStack(spacing: 10) {
                                                ProgressView()
                                                    .scaleEffect(1.2)
                                                Text("データ更新中...")
                                                    .font(.caption)
                                                    .foregroundColor(.white)
                                            }
                                            .padding(20)
                                            .background(Color.black.opacity(0.8))
                                            .cornerRadius(10)
                                        )
                                        .ignoresSafeArea()
                                    : nil
                                )
                        }
                    } else {
                        instructionView
                    }
                }
            }
            .navigationTitle("時刻表から設定")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing:
                Button(action: {
                    dismiss()
                }) {
                    Text("閉じる")
                        .foregroundColor(Color.trainSoftBlue)
                }
            )
            .sheet(isPresented: $showingStationSearch) {
                TimetableStationSearchView(
                    title: "出発駅を選択"
                ) { station in
                        // 駅が変更された場合のみ方向選択をクリア
                        if selectedStation?.sameAs != station.sameAs {
                            selectedDirection = nil
                        }
                        selectedStation = station
                        showingStationSearch = false
                        print("駅選択: \(station.stationTitle?.ja ?? station.title), railway = \(station.railway)")
                        // データ準備中フラグを立てる
                        isDataPreparing = true
                        Task {
                            await viewModel.loadTimetable(for: station)
                            await MainActor.run {
                                // 最初の方向を自動選択
                                if selectedDirection == nil, let firstDirection = viewModel.directions.first {
                                    selectedDirection = firstDirection
                                }
                                // データ準備完了
                                isDataPreparing = false
                            }
                        }
                }
            }
            .sheet(isPresented: $showingTrainSelection) {
                let _ = print("Sheet is being presented, sheetTrainData = \(sheetTrainData != nil ? "exists" : "nil")")
                
                // sheet用の永続的なデータを使用
                if let data = sheetTrainData {
                    TrainSelectionView(
                        train: data.train,
                        departureStation: data.station,
                        railway: data.railway,
                        direction: data.direction
                    )
                        .onAppear {
                            print("Sheet displayed successfully with:")
                            print("  Train: \(data.train.departureTime)")
                            print("  Station: \(data.station.stationTitle?.ja ?? data.station.title)")
                            print("  Railway: \(data.railway)")
                            print("  Direction: \(data.direction ?? "nil")")
                        }
                        .onDisappear {
                            // sheet閉じた後にデータをクリア
                            sheetTrainData = nil
                            selectedTrainData = nil
                        }
                } else {
                    // エラー表示
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("エラー: 必要なデータが不足しています")
                            .font(.headline)
                        
                        Text("もう一度電車を選択してください")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("閉じる") {
                            showingTrainSelection = false
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.trainSoftBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .alert("エラー", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "不明なエラーが発生しました")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissTimetableSearch"))) { _ in
                dismiss()
            }
            .onChange(of: viewModel.directions) { newDirections in
                // 方向が更新されたら自動選択
                if selectedDirection == nil, let firstDirection = newDirections.first {
                    selectedDirection = firstDirection
                }
            }
        }
    }
    
    // MARK: - Station Selection Section
    
    private var stationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("出発駅", systemImage: "location.circle")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            Button(action: { showingStationSearch = true }) {
                HStack {
                    if let station = selectedStation {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.stationTitle?.ja ?? station.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.textPrimary)
                            Text(station.railwayTitle?.ja ?? getRailwayDisplayName(station.railway))
                                .font(.system(size: 12))
                                .foregroundColor(Color.textSecondary)
                        }
                    } else {
                        Text("駅を選択してください")
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.backgroundCard)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Timetable Content
    
    private var timetableContent: some View {
        VStack(spacing: 0) {
            // 方向選択タブ
            if viewModel.directions.count > 1 {
                directionTabs
            }
            
            // 時刻表リスト
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.displayedTrains, id: \.departureTime) { train in
                            trainRow(train)
                                .id(train.departureTime)
                        }
                    }
                    .padding(.vertical)
                }
                .disabled(isDataPreparing || viewModel.isLoading)
                .onAppear {
                    // 現在時刻に近い電車までスクロール
                    if let nearestTrain = viewModel.nearestTrain {
                        withAnimation {
                            proxy.scrollTo(nearestTrain.departureTime, anchor: .top)
                        }
                    }
                }
                .onChange(of: selectedDirection) { _ in
                    // 方向切り替え時に最も近い電車までスクロール
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let nearestTrain = viewModel.nearestTrain {
                            withAnimation {
                                proxy.scrollTo(nearestTrain.departureTime, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var directionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.directions, id: \.self) { direction in
                    Button(action: {
                        withAnimation {
                            selectedDirection = direction
                            viewModel.selectDirection(direction)
                            // 方向が選択されたらデータ準備完了とみなす
                            if isDataPreparing && !viewModel.isLoading {
                                isDataPreparing = false
                            }
                        }
                    }) {
                        Text(viewModel.getDirectionTitle(for: direction))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(
                                selectedDirection == direction ? .white : Color.textPrimary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        selectedDirection == direction ?
                                        Color.trainSoftBlue : Color.backgroundCard
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.backgroundSecondary)
        .onAppear {
            // 初回表示時に最初の方向を選択
            if selectedDirection == nil, let firstDirection = viewModel.directions.first {
                selectedDirection = firstDirection
            }
        }
    }
    
    private func trainRow(_ train: ODPTTrainTimetableObject) -> some View {
        let isNearCurrent = viewModel.isNearCurrentTime(train)
        let isPastTime = viewModel.isPastTime(train)
        let isDisabled = isPastTime || viewModel.isLoading || isDataPreparing
        
        return Button(action: {
            // データのロード中は何もしない
            guard !viewModel.isLoading && !isDataPreparing else {
                print("Data is still loading/preparing, ignoring tap")
                return
            }
            
            // 駅が選択されていることを確認
            guard let station = selectedStation else {
                print("No station selected")
                return
            }
            
            // 必要なデータを構造体にまとめる
            let railwayId = station.railway
            let currentDirection = selectedDirection ?? viewModel.directions.first
            
            // デバッグ情報
            print("Creating TrainSelectionData:")
            print("  Train: \(train.departureTime)")
            print("  Station: \(station.stationTitle?.ja ?? station.title)")
            print("  Railway: \(railwayId)")
            print("  Direction: \(currentDirection ?? "nil")")
            print("  isNearCurrent: \(isNearCurrent)")
            
            // 選択データを先に設定（同期的に）
            let newTrainData = TrainSelectionData(
                train: train,
                station: station,
                railway: railwayId,
                direction: currentDirection
            )
            
            // 即座にデータを設定
            selectedTrainData = newTrainData
            sheetTrainData = newTrainData  // sheet用のデータも設定
            
            print("Successfully set train data")
            print("  Train: \(newTrainData.train.departureTime)")
            print("  Station: \(newTrainData.station.stationTitle?.ja ?? newTrainData.station.title)")
            print("  Railway: \(newTrainData.railway)")
            print("  Direction: \(newTrainData.direction ?? "nil")")
            
            // SwiftUIの更新サイクルを待ってからsheetを表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // データが確実に存在することを再度確認
                if sheetTrainData != nil {
                    print("Sheet presentation triggered - data confirmed")
                    showingTrainSelection = true
                } else {
                    print("ERROR: sheetTrainData is nil when trying to show sheet")
                    viewModel.errorMessage = "データの設定に失敗しました。もう一度お試しください。"
                    viewModel.showError = true
                }
            }
        }) {
            HStack(spacing: 16) {
                // 時刻
                VStack(spacing: 2) {
                    Text(train.departureTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(isPastTime ? Color.textSecondary.opacity(0.5) : Color.textPrimary)
                    
                    if isNearCurrent {
                        Text("もうすぐ")
                            .font(.caption2)
                            .foregroundColor(Color.warmOrange)
                    }
                }
                .frame(width: 80)
                
                // 列車情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        // 列車種別
                        if let trainTypeTitle = train.trainTypeTitle?.ja {
                            Text(trainTypeTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(getTrainTypeColor(train.trainType))
                        }
                        
                        // 行き先
                        if let destination = train.destinationStationTitle?.ja {
                            Text(destination + "行")
                                .font(.system(size: 14))
                                .foregroundColor(Color.textPrimary)
                        }
                    }
                    
                    // プラットフォーム
                    if let platform = train.platformNumber {
                        Label("\(platform)番線", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Spacer()
                
                // 選択インジケーター
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isNearCurrent ? Color.warmOrange.opacity(0.1) : Color.clear)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    // MARK: - Empty States
    
    private var instructionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tram.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.trainLightGray)
            
            Text("出発駅を選択してください")
                .font(.headline)
                .foregroundColor(Color.textSecondary)
            
            Text("選択した駅の時刻表から\n具体的な列車を選んで通知設定できます")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(Color.trainLightGray)
            
            Text("時刻表データがありません")
                .font(.headline)
                .foregroundColor(Color.textSecondary)
            
            Text("この駅の時刻表データが取得できませんでした")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func getRailwayDisplayName(_ railway: String) -> String {
        let components = railway.split(separator: ":").map { String($0) }
        guard components.count >= 2 else { return railway }
        
        let operatorAndLine = components[1].split(separator: ".").map { String($0) }
        guard operatorAndLine.count >= 2 else { return railway }
        
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
    
    private func getTrainTypeColor(_ trainType: String?) -> Color {
        guard let type = trainType?.lowercased() else { return Color.textPrimary }
        
        if type.contains("rapid") || type.contains("快速") {
            return Color.warmOrange
        } else if type.contains("express") || type.contains("急行") {
            return Color.red
        } else if type.contains("limited") || type.contains("特急") {
            return Color.purple
        } else {
            return Color.trainSoftBlue
        }
    }
}

// MARK: - Station Search View

private struct TimetableStationSearchView: View {
    let title: String
    let onSelect: (ODPTStation) -> Void
    
    @StateObject private var viewModel = StationSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 検索フィールド
                    searchField
                        .padding()
                        .background(Color.backgroundSecondary)
                    
                    // 検索結果
                    if viewModel.isSearching {
                        LoadingIndicator(text: "駅を検索中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.stations.isEmpty && !searchText.isEmpty {
                        emptySearchResult
                    } else {
                        stationList
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button(action: {
                    dismiss()
                }) {
                    Text("キャンセル")
                        .foregroundColor(Color.trainSoftBlue)
                }
            )
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textSecondary)
            
            TextField("駅名を入力", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.textPrimary)
                .onChange(of: searchText) { newValue in
                    viewModel.searchStations(query: newValue)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.backgroundCard)
        .cornerRadius(12)
    }
    
    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.stations, id: \.sameAs) { station in
                    Button(action: { onSelect(station) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.stationTitle?.ja ?? station.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.textPrimary)
                                
                                Text(station.railwayTitle?.ja ?? getRailwayDisplayName(station.railway))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.textSecondary)
                            }
                            
                            Spacer()
                            
                            if let code = station.stationCode {
                                Text(code)
                                    .font(.caption)
                                    .foregroundColor(Color.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.backgroundSecondary)
                                    .cornerRadius(6)
                            }
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
    
    private var emptySearchResult: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Color.trainLightGray)
            
            Text("駅が見つかりませんでした")
                .font(.headline)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // ヘルパーメソッド
    private func getRailwayDisplayName(_ railway: String) -> String {
        let components = railway.split(separator: ":").map { String($0) }
        guard components.count >= 2 else { return railway }
        
        let operatorAndLine = components[1].split(separator: ".").map { String($0) }
        guard operatorAndLine.count >= 2 else { return railway }
        
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

// MARK: - Preview

struct TimetableSearchView_Previews: PreviewProvider {
    static var previews: some View {
        TimetableSearchView()
    }
}
