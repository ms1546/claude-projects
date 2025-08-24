//
//  HistoryView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreData
import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showingExportSheet = false
    @State private var showingFilterSheet = false
    @State private var selectedHistory: History?
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.hasHistory {
                    historyList
                } else {
                    emptyView
                }
                
                if viewModel.isLoading {
                    LoadingIndicator()
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingFilterSheet) {
                filterSheet
            }
            .sheet(isPresented: $showingExportSheet) {
                exportSheet
            }
            .sheet(item: $selectedHistory) { history in
                historyDetailSheet(history: history)
            }
            .alert("履歴を削除", isPresented: $viewModel.showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    viewModel.confirmDelete()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この履歴を削除してもよろしいですか？")
            }
        }
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // 検索バー
                if !viewModel.isInSelectionMode {
                    searchBar
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                // フィルター情報
                if viewModel.selectedFilter != .all || !viewModel.searchText.isEmpty {
                    filterInfoBar
                }
                
                // グループ化された履歴
                ForEach(Array(viewModel.groupedHistoryItems.keys).sorted(by: >), id: \.self) { dateKey in
                    Section {
                        ForEach(viewModel.groupedHistoryItems[dateKey] ?? []) { history in
                            historyRow(history: history)
                                .onAppear {
                                    // ページネーション
                                    if isLastItem(history) {
                                        Task {
                                            await viewModel.loadMore()
                                        }
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(dateKey: dateKey)
                    }
                }
                
                if viewModel.canLoadMore && viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("履歴がありません")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("トントンが発火すると\nここに履歴が表示されます")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("履歴を検索", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Filter Info Bar
    
    private var filterInfoBar: some View {
        HStack {
            Label {
                Text("\(viewModel.filteredCount)件の履歴")
                    .font(.caption)
            } icon: {
                Image(systemName: "line.horizontal.3.decrease.circle")
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Button("クリア") {
                viewModel.updateFilter(.all)
                viewModel.clearSearch()
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(dateKey: String) -> some View {
        HStack {
            Text(dateKey)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.isInSelectionMode {
                let sectionHistories = viewModel.groupedHistoryItems[dateKey] ?? []
                let selectedCount = sectionHistories.filter { viewModel.selectedItems.contains($0.id) }.count
                Text("\(selectedCount)/\(sectionHistories.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - History Row
    
    private func historyRow(history: History) -> some View {
        Button(action: {
            if viewModel.isInSelectionMode {
                viewModel.toggleItemSelection(history)
            } else {
                selectedHistory = history
            }
        }) {
            HStack(spacing: 12) {
                // 選択モードのチェックボックス
                if viewModel.isInSelectionMode {
                    Image(systemName: viewModel.selectedItems.contains(history.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 22))
                }
                
                // アイコン
                Image(systemName: "bell.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                
                // 情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(history.stationName ?? "不明な駅")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let style = history.characterStyle {
                            Text("• \(CharacterStyle(rawValue: style)?.displayName ?? style)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(history.messagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(history.notifiedAtRelativeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 削除ボタン（選択モードでない場合）
                if !viewModel.isInSelectionMode {
                    Button(action: {
                        viewModel.deleteHistoryItem(history)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isInSelectionMode {
                Button("完了") {
                    viewModel.toggleSelectionMode()
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isInSelectionMode {
                Menu {
                    Button {
                        viewModel.selectAll()
                    } label: {
                        Label("すべて選択", systemImage: "checkmark.circle")
                    }
                    
                    Button {
                        viewModel.clearSelection()
                    } label: {
                        Label("選択を解除", systemImage: "circle")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        viewModel.deleteSelectedItems()
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    .disabled(viewModel.selectedItems.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            } else {
                Menu {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Label("フィルター", systemImage: "line.horizontal.3.decrease.circle")
                    }
                    
                    Button {
                        viewModel.toggleSelectionMode()
                    } label: {
                        Label("選択", systemImage: "checkmark.circle")
                    }
                    .disabled(!viewModel.hasHistory)
                    
                    Divider()
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("エクスポート", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!viewModel.canExport)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationView {
            Form {
                Section("期間") {
                    ForEach(HistoryViewModel.HistoryFilter.allCases, id: \.displayName) { filter in
                        Button(action: {
                            viewModel.updateFilter(filter)
                            showingFilterSheet = false
                        }) {
                            HStack {
                                Text(filter.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedFilter.displayName == filter.displayName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                
                Section("並び順") {
                    ForEach(HistoryViewModel.SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            viewModel.updateSortOption(option)
                            showingFilterSheet = false
                        }) {
                            HStack {
                                Label(option.displayName, systemImage: option.icon)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        showingFilterSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Export Sheet
    
    private var exportSheet: some View {
        let csvContent = viewModel.exportHistoryAsCSV()
        let fileName = "TrainAlert_History_\(Date().formatted(.iso8601)).csv"
        
        return ShareLink(
            item: csvContent,
            subject: Text("トレ眠 - 履歴データ"),
            message: Text("トレ眠の履歴データ（CSV形式）")
        ) {
            VStack(spacing: 16) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
                
                Text("履歴をエクスポート")
                    .font(.headline)
                
                Text("\(viewModel.filteredCount)件の履歴")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    // MARK: - History Detail Sheet
    
    private func historyDetailSheet(history: History) -> some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 駅情報
                    VStack(alignment: .leading, spacing: 8) {
                        Label("駅", systemImage: "tram.fill")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(history.stationName ?? "不明な駅")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // 通知メッセージ
                    VStack(alignment: .leading, spacing: 8) {
                        Label("通知メッセージ", systemImage: "message.fill")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(history.message ?? "メッセージなし")
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // 詳細情報
                    VStack(alignment: .leading, spacing: 12) {
                        Label("詳細情報", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("通知日時")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(history.notifiedAtDetailString)
                                .fontWeight(.medium)
                        }
                        
                        if let style = history.characterStyle,
                           let characterStyle = CharacterStyle(rawValue: style) {
                            HStack {
                                Text("キャラクター")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(characterStyle.displayName)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("履歴詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        selectedHistory = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isLastItem(_ history: History) -> Bool {
        guard let lastItem = viewModel.filteredHistoryItems.last else { return false }
        return history.id == lastItem.id
    }
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
#endif
