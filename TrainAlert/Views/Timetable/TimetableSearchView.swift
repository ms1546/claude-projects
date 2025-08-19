//
//  TimetableSearchView.swift
//  TrainAlert
//
//  時刻表検索・表示画面
//

import Foundation
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
    @State private var isDataReady = false  // データが完全に準備できているか
    @State private var dataClearTask: DispatchWorkItem?  // データクリアタスクの管理
    
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
                        // データ準備中フラグを立てる
                        isDataPreparing = true
                        isDataReady = false
                        Task {
                            await viewModel.loadTimetable(for: station)
                            await MainActor.run {
                                // 最初の方向を自動選択
                                if selectedDirection == nil, let firstDirection = viewModel.directions.first {
                                    selectedDirection = firstDirection
                                }
                                // データ準備完了
                                isDataPreparing = false
                                // データの完全性をチェック
                                isDataReady = checkDataReadiness()
                            }
                        }
                }
            }
            .sheet(isPresented: $showingTrainSelection, onDismiss: {
                // sheet閉じた後の処理
                
                // 前回のクリアタスクをキャンセル
                dataClearTask?.cancel()
                
                // 新しいクリアタスクを作成
                let newTask = DispatchWorkItem {
                    // sheet表示中でなければデータをクリア
                    if !self.showingTrainSelection {
                        self.sheetTrainData = nil
                        self.selectedTrainData = nil
                    }
                }
                dataClearTask = newTask
                
                // 少し遅延してから実行
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: newTask)
            }) {
                // sheet表示時にデータの存在を確認（初回表示時の対策）
                if let data = sheetTrainData ?? selectedTrainData {
                    TrainSelectionView(
                        train: data.train,
                        departureStation: data.station,
                        railway: data.railway,
                        direction: data.direction
                    )
                        .onAppear {
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
            .onChange(of: showingTrainSelection) { newValue in
                if newValue {
                    // sheet表示時に他のアラートが表示されていれば閉じる
                    if viewModel.showError {
                        viewModel.showError = false
                    }
                    if showingStationSearch {
                        showingStationSearch = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissTimetableSearch"))) { _ in
                dismiss()
            }
            .onChange(of: viewModel.directions) { newDirections in
                // sheet表示中は状態変更を避ける
                guard !showingTrainSelection else { return }
                
                // 方向が更新されたら自動選択
                if selectedDirection == nil, let firstDirection = newDirections.first {
                    selectedDirection = firstDirection
                }
                // データの完全性をチェック
                isDataReady = checkDataReadiness()
            }
            .onChange(of: viewModel.displayedTrains.count) { _ in
                // sheet表示中は状態変更を避ける
                guard !showingTrainSelection else { return }
                
                // 表示される電車の数が更新されたらデータの完全性をチェック
                isDataReady = checkDataReadiness()
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
                DirectionTabView(
                    directions: viewModel.directions,
                    selectedDirection: $selectedDirection,
                    getDirectionTitle: viewModel.getDirectionTitle,
                    onSelect: { direction in
                        viewModel.selectDirection(direction)
                        // 方向が選択されたらデータ準備完了とみなす
                        if isDataPreparing && !viewModel.isLoading {
                            isDataPreparing = false
                        }
                        // データの完全性をチェック
                        isDataReady = checkDataReadiness()
                    }
                )
            }
            
            // 時刻表リスト
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.displayedTrains, id: \.departureTime) { train in
                            TrainRowView(
                                train: train,
                                isNearCurrent: viewModel.isNearCurrentTime(train),
                                isPastTime: viewModel.isPastTime(train),
                                isLoading: viewModel.isLoading,
                                isDataPreparing: isDataPreparing,
                                isDataReady: isDataReady,
                                onSelect: {
                                    handleTrainSelection(train)
                                }
                            )
                            .id(train.departureTime)
                        }
                    }
                    .padding(.vertical)
                }
                .disabled(isDataPreparing || viewModel.isLoading || !isDataReady)
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
    
    private func handleTrainSelection(_ train: ODPTTrainTimetableObject) {
        // データのロード中、準備中、または準備未完了の場合は何もしない
        guard !viewModel.isLoading && !isDataPreparing && !showingTrainSelection && isDataReady else {
            return
        }
        
        // 駅が選択されていることを確認
        guard let station = selectedStation else {
            return
        }
        
        // 必要なデータを構造体にまとめる
        let railwayId = station.railway
        let currentDirection = selectedDirection ?? viewModel.directions.first
        
        // 前回のクリアタスクがあればキャンセル
        dataClearTask?.cancel()
        dataClearTask = nil
        
        // 選択データを作成
        let newTrainData = TrainSelectionData(
            train: train,
            station: station,
            railway: railwayId,
            direction: currentDirection
        )
        
        // データを同期的に設定（重要：非同期にしない）
        self.sheetTrainData = newTrainData
        self.selectedTrainData = newTrainData
        
        // SwiftUIの更新サイクルを確実に待つ（初回は少し長めに）
        let delay = showingTrainSelection ? 0.1 : 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 追加の安全チェック
            guard self.sheetTrainData != nil else {
                self.viewModel.errorMessage = "データの設定に失敗しました。もう一度お試しください。"
                self.viewModel.showError = true
                return
            }
            
            // 既にsheetが表示されている場合は何もしない
            guard !self.showingTrainSelection else {
                return
            }
            
            // sheet表示をトリガー
            self.showingTrainSelection = true
        }
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
    
    // MARK: - Data Readiness Check
    
    /// データが完全に準備できているかチェック
    private func checkDataReadiness() -> Bool {
        // 必要な条件をすべてチェック
        let hasStation = selectedStation != nil
        let hasDirections = !viewModel.directions.isEmpty
        let hasSelectedDirection = selectedDirection != nil
        let hasTrains = !viewModel.displayedTrains.isEmpty
        let notLoading = !viewModel.isLoading && !isDataPreparing
        
        let isReady = hasStation && hasDirections && hasSelectedDirection && hasTrains && notLoading
        
        
        return isReady
    }
}

// MARK: - Preview

struct TimetableSearchView_Previews: PreviewProvider {
    static var previews: some View {
        TimetableSearchView()
    }
}

