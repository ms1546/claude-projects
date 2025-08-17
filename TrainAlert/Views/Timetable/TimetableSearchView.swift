//
//  TimetableSearchView.swift
//  TrainAlert
//
//  時刻表検索・表示画面
//

import SwiftUI

struct TimetableSearchView: View {
    @StateObject private var viewModel = TimetableSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStation: ODPTStation?
    @State private var selectedDirection: String?
    @State private var showingStationSearch = false
    @State private var selectedTrainForAlert: ODPTTrainTimetableObject?
    @State private var showingTrainSelection = false
    
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
                        }
                    } else {
                        instructionView
                    }
                }
            }
            .navigationTitle("時刻表から設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundColor(Color.trainSoftBlue)
                }
            }
            .sheet(isPresented: $showingStationSearch) {
                TimetableStationSearchView(
                    title: "出発駅を選択"
                ) { station in
                        selectedStation = station
                        showingStationSearch = false
                        Task {
                            await viewModel.loadTimetable(for: station)
                        }
                }
            }
            .sheet(isPresented: $showingTrainSelection) {
                if let train = selectedTrainForAlert,
                   let station = selectedStation {
                    TrainSelectionView(
                        train: train,
                        departureStation: station,
                        railway: viewModel.selectedRailway ?? "",
                        direction: selectedDirection
                    )
                    .onDisappear {
                        selectedTrainForAlert = nil
                    }
                } else {
                    // エラーフォールバック画面
                    NavigationView {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text("列車情報の読み込みに失敗しました")
                                .font(.headline)
                            Button("閉じる") {
                                showingTrainSelection = false
                                selectedTrainForAlert = nil
                            }
                            .padding()
                        }
                        .navigationTitle("エラー")
                        .navigationBarTitleDisplayMode(.inline)
                    }
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
                            Text(station.railwayTitle?.ja ?? station.railway.railwayDisplayName)
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
                .onAppear {
                    // 現在時刻に近い電車までスクロール
                    if let nearestTrain = viewModel.nearestTrain {
                        withAnimation {
                            proxy.scrollTo(nearestTrain.departureTime, anchor: .top)
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
    }
    
    private func trainRow(_ train: ODPTTrainTimetableObject) -> some View {
        let isNearCurrent = viewModel.isNearCurrentTime(train)
        let isPastTime = viewModel.isPastTime(train)
        
        return Button(action: {
            selectedTrainForAlert = train
            showingTrainSelection = true
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
            .opacity(isPastTime ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isPastTime)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(Color.trainSoftBlue)
                }
            }
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
                                
                                Text(station.railwayTitle?.ja ?? station.railway.railwayDisplayName)
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
    
    // 親ビューのヘルパーメソッドと同じ実装
}

// MARK: - Preview

struct TimetableSearchView_Previews: PreviewProvider {
    static var previews: some View {
        TimetableSearchView()
    }
}
