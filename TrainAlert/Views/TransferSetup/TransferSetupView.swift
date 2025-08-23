//
//  TransferSetupView.swift
//  TrainAlert
//
//  乗り換え経路設定画面
//

import CoreLocation
import SwiftUI

struct TransferSetupView: View {
    @StateObject private var viewModel = TransferSetupViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingStationSearch = false
    @State private var editingSectionIndex: Int?
    @State private var showingDatePicker = false
    @State private var showingNotificationSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 区間リスト
                    if viewModel.sections.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(viewModel.sections.indices, id: \.self) { index in
                                    sectionCard(at: index)
                                }
                                
                                // 区間追加ボタン
                                if viewModel.sections.count < 5 { // 最大5区間まで
                                    addSectionButton
                                }
                            }
                            .padding()
                        }
                    }
                    
                    // 底部のアクションボタン
                    if !viewModel.sections.isEmpty {
                        bottomActionBar
                    }
                }
            }
            .navigationTitle("乗り換え経路設定")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.canCreateAlert {
                        Button("次へ") {
                            showingNotificationSettings = true
                        }
                        .fontWeight(.medium)
                    }
                }
            }
            .sheet(isPresented: $showingStationSearch) {
                StationSearchSheet(
                    sectionIndex: editingSectionIndex
                )                    { station, index in
                        viewModel.updateStation(at: index, station: station)
                    }
            }
            .sheet(isPresented: $showingDatePicker) {
                DateTimePickerSheet(
                    selectedDate: $viewModel.departureTime
                )                    {
                        viewModel.updateDepartureTime()
                    }
            }
            .sheet(isPresented: $showingNotificationSettings) {
                TransferNotificationSettingsView(
                    transferRoute: viewModel.createTransferRoute()
                )                    {
                        // アラート作成完了
                        dismiss()
                    }
            }
            .alert("エラー", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "エラーが発生しました")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "train.side.front.car")
                .font(.system(size: 60))
                .foregroundColor(Color.textSecondary.opacity(0.5))
            
            Text("乗り換え経路を設定しましょう")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            Text("複数の区間を追加して\n乗り換えが必要な経路を作成できます")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { 
                editingSectionIndex = 0
                viewModel.addSection()
                showingStationSearch = true
            }) {
                Label("最初の区間を追加", systemImage: "plus.circle.fill")
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.trainSoftBlue)
                    .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Section Card
    
    private func sectionCard(at index: Int) -> some View {
        let section = viewModel.sections[index]
        
        return VStack(spacing: 0) {
            // セクションヘッダー
            HStack {
                Label("区間 \(index + 1)", systemImage: "number.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                
                Spacer()
                
                if viewModel.sections.count > 1 {
                    Button(action: { viewModel.removeSection(at: index) }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(Color.error)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // 駅情報
            HStack(spacing: 16) {
                // 出発駅
                stationButton(
                    title: "出発",
                    stationName: section.departureStation,
                    icon: "location.circle"
                )                    {
                        editingSectionIndex = index
                        showingStationSearch = true
                    }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(Color.textSecondary)
                
                // 到着駅
                stationButton(
                    title: "到着",
                    stationName: section.arrivalStation,
                    icon: "location.circle.fill"
                )                    {
                        editingSectionIndex = index
                        showingStationSearch = true
                    }
            }
            .padding()
            
            // 乗り換え情報（最後の区間以外）
            if index < viewModel.sections.count - 1 {
                transferInfo(from: index, to: index + 1)
            }
        }
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private func stationButton(
        title: String,
        stationName: String?,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
                
                Text(stationName ?? "選択してください")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(stationName != nil ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.backgroundCard)
            .cornerRadius(8)
        }
    }
    
    // MARK: - Transfer Info
    
    private func transferInfo(from: Int, to: Int) -> some View {
        HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(Color.warmOrange)
            
            Text("乗り換え")
                .font(.caption)
                .foregroundColor(Color.textPrimary)
            
            if let transferStation = viewModel.getTransferStation(between: from, and: to) {
                Text("(\(transferStation)駅)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.textPrimary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.warmOrange.opacity(0.1))
    }
    
    // MARK: - Add Section Button
    
    private var addSectionButton: some View {
        Button(action: {
            let newIndex = viewModel.sections.count
            viewModel.addSection()
            editingSectionIndex = newIndex
            showingStationSearch = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("区間を追加")
                    .fontWeight(.medium)
            }
            .foregroundColor(Color.trainSoftBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.trainSoftBlue.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            // 出発時刻設定
            Button(action: { showingDatePicker = true }) {
                HStack {
                    Image(systemName: "clock")
                    Text("出発時刻: \(viewModel.departureTimeString)")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(Color.textPrimary)
                .padding()
                .background(Color.backgroundSecondary)
                .cornerRadius(8)
            }
            
            // 総所要時間表示
            if let duration = viewModel.totalDurationString {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(Color.textSecondary)
                    Text("総所要時間: \(duration)")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(
            Color.backgroundSecondary
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
        )
    }
}

// MARK: - Station Search Sheet

struct StationSearchSheet: View {
    let sectionIndex: Int?
    let onSelect: (String, Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    // 仮の駅リスト（実際にはAPIから取得）
    let mockStations = ["東京", "新宿", "渋谷", "池袋", "品川", "横浜", "大宮", "千葉"]
    
    var filteredStations: [String] {
        if searchText.isEmpty {
            return mockStations
        }
        return mockStations.filter { $0.contains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            List(filteredStations, id: \.self) { station in
                Button(action: {
                    if let index = sectionIndex {
                        onSelect(station, index)
                    }
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "tram.fill")
                            .foregroundColor(Color.trainSoftBlue)
                        Text(station)
                            .foregroundColor(Color.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .searchable(text: $searchText, prompt: "駅名を検索")
            .navigationTitle("駅を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - DateTime Picker Sheet

struct DateTimePickerSheet: View {
    @Binding var selectedDate: Date
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "出発時刻",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("出発時刻を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Preview

struct TransferSetupView_Previews: PreviewProvider {
    static var previews: some View {
        TransferSetupView()
            .environmentObject(LocationManager())
    }
}

