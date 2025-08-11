//
//  HistoryView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import CoreData

struct HistoryView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showingFilterSheet = false
    @State private var showingSortSheet = false
    @State private var showingCustomDatePicker = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var searchText = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Content
                if viewModel.isLoading && viewModel.historyItems.isEmpty {
                    loadingView
                } else if viewModel.historyItems.isEmpty {
                    emptyStateView
                } else if viewModel.filteredHistoryItems.isEmpty {
                    noResultsView
                } else {
                    historyList
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarMenu
                }
                
                if viewModel.isInSelectionMode {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            viewModel.toggleSelectionMode()
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert("履歴の削除", isPresented: $viewModel.showingDeleteAlert) {
                Button("削除", role: .destructive) {
                    viewModel.confirmDelete()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この履歴を削除しますか？この操作は取り消せません。")
            }
            .sheet(isPresented: $showingFilterSheet) {
                filterSheet
            }
            .sheet(isPresented: $showingSortSheet) {
                sortSheet
            }
            .sheet(isPresented: $viewModel.showingExportSheet) {
                exportSheet
            }
            .sheet(isPresented: $showingCustomDatePicker) {
                customDatePickerSheet
            }
        }
        .background(Color.backgroundPrimary)
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.textSecondary)
                
                TextField("履歴を検索", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .onChange(of: searchText) { newValue in
                        viewModel.searchHistory(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button("クリア") {
                        searchText = ""
                        viewModel.clearSearch()
                    }
                    .font(.bodySmall)
                    .foregroundColor(.trainSoftBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Filter and Sort Buttons
            HStack(spacing: 12) {
                // Filter Button
                Button(action: { showingFilterSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(viewModel.selectedFilter.displayName)
                    }
                    .font(.labelSmall)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Sort Button
                Button(action: { showingSortSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.selectedSortOption.icon)
                        Text(viewModel.selectedSortOption.displayName)
                    }
                    .font(.labelSmall)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Results Count
                Text("\(viewModel.filteredCount)件")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.backgroundSecondary)
    }
    
    // MARK: - History List
    
    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedDateKeys, id: \.self) { dateKey in
                    historySection(for: dateKey)
                }
                
                // Load more button
                if viewModel.canLoadMore {
                    Button("さらに読み込む") {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                    .font(.labelMedium)
                    .foregroundColor(.trainSoftBlue)
                    .padding()
                    .disabled(viewModel.isLoading)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func historySection(for dateKey: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text(formatDateKey(dateKey))
                    .font(.labelMedium)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                if let items = viewModel.groupedHistoryItems[dateKey] {
                    Text("\(items.count)件")
                        .font(.caption)
                        .foregroundColor(.textInactive)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 20)
            
            // History Items
            if let historyItems = viewModel.groupedHistoryItems[dateKey] {
                ForEach(historyItems, id: \.id) { history in
                    HistoryItemView(
                        history: history,
                        isSelected: viewModel.selectedItems.contains(history.id),
                        isInSelectionMode: viewModel.isInSelectionMode,
                        onTap: {
                            if viewModel.isInSelectionMode {
                                viewModel.toggleItemSelection(history)
                            }
                        },
                        onDelete: {
                            viewModel.deleteHistoryItem(history)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Toolbar Menu
    
    private var toolbarMenu: some View {
        Menu {
            Button(action: { viewModel.toggleSelectionMode() }) {
                Label("選択", systemImage: "checkmark.circle")
            }
            
            Button(action: { viewModel.showingExportSheet = true }) {
                Label("エクスポート", systemImage: "square.and.arrow.up")
            }
            .disabled(!viewModel.canExport)
            
            if viewModel.isInSelectionMode {
                Divider()
                
                Button(action: { viewModel.selectAll() }) {
                    Label("すべて選択", systemImage: "checkmark.circle.fill")
                }
                
                Button(action: { viewModel.clearSelection() }) {
                    Label("選択解除", systemImage: "circle")
                }
                
                if viewModel.canDelete {
                    Divider()
                    
                    Button(role: .destructive, action: { viewModel.deleteSelectedItems() }) {
                        Label("選択項目を削除", systemImage: "trash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundColor(.trainSoftBlue)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            LoadingIndicator()
            
            Text("履歴を読み込んでいます...")
                .font(.bodyMedium)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.trainLightGray)
            
            VStack(spacing: 8) {
                Text("履歴がありません")
                    .font(.displaySmall)
                    .foregroundColor(.textPrimary)
                
                Text("アラートが実行されると、ここに履歴が表示されます")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.trainLightGray)
            
            VStack(spacing: 8) {
                Text("検索結果なし")
                    .font(.displaySmall)
                    .foregroundColor(.textPrimary)
                
                Text("「\(searchText)」に一致する履歴が見つかりませんでした")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("検索をクリア") {
                searchText = ""
                viewModel.clearSearch()
            }
            .font(.labelMedium)
            .foregroundColor(.trainSoftBlue)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(HistoryViewModel.HistoryFilter.allCases, id: \.displayName) { filter in
                    Button(action: {
                        viewModel.updateFilter(filter)
                        showingFilterSheet = false
                    }) {
                        HStack {
                            Text(filter.displayName)
                                .font(.bodyMedium)
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            if viewModel.selectedFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.trainSoftBlue)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                
                Divider()
                
                Button("カスタム期間") {
                    showingFilterSheet = false
                    showingCustomDatePicker = true
                }
                .font(.bodyMedium)
                .foregroundColor(.trainSoftBlue)
                .padding(.vertical, 12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showingFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Sort Sheet
    
    private var sortSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(HistoryViewModel.SortOption.allCases, id: \.displayName) { option in
                    Button(action: {
                        viewModel.updateSortOption(option)
                        showingSortSheet = false
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.textSecondary)
                                .frame(width: 20)
                            
                            Text(option.displayName)
                                .font(.bodyMedium)
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            if viewModel.selectedSortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.trainSoftBlue)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showingSortSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Custom Date Picker Sheet
    
    private var customDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("開始日")
                        .font(.labelMedium)
                        .foregroundColor(.textPrimary)
                    
                    DatePicker("開始日", selection: $customStartDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("終了日")
                        .font(.labelMedium)
                        .foregroundColor(.textPrimary)
                    
                    DatePicker("終了日", selection: $customEndDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("期間を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        showingCustomDatePicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("適用") {
                        let filter = HistoryViewModel.HistoryFilter.custom(customStartDate, customEndDate)
                        viewModel.updateFilter(filter)
                        showingCustomDatePicker = false
                    }
                }
            }
        }
    }
    
    // MARK: - Export Sheet
    
    private var exportSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("履歴をCSV形式でエクスポートします")
                    .font(.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("エクスポートする内容:")
                        .font(.labelMedium)
                        .foregroundColor(.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 日時")
                        Text("• 駅名")
                        Text("• 通知メッセージ")
                        Text("• キャラクタースタイル")
                    }
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                Button("エクスポート") {
                    let csvContent = viewModel.exportHistoryAsCSV()
                    shareCsvContent(csvContent)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("エクスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        viewModel.showingExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var sortedDateKeys: [String] {
        viewModel.groupedHistoryItems.keys.sorted(by: >)
    }
    
    private func formatDateKey(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateKey) else {
            return dateKey
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "ja_JP")
        
        if Calendar.current.isDateInToday(date) {
            return "今日"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨日"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            displayFormatter.dateFormat = "EEEE"
            return displayFormatter.string(from: date)
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            displayFormatter.dateFormat = "M月d日(EEEE)"
            return displayFormatter.string(from: date)
        } else {
            displayFormatter.dateFormat = "yyyy年M月d日(EEEE)"
            return displayFormatter.string(from: date)
        }
    }
    
    private func shareCsvContent(_ content: String) {
        // Create a temporary file for the CSV content
        let fileName = "TrainAlert_履歴_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(av, animated: true)
            }
        } catch {
            // Handle error - could show an alert
            // Failed to create temporary CSV file
        }
        
        viewModel.showingExportSheet = false
    }
}

// MARK: - History Item View

struct HistoryItemView: View {
    
    let history: History
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Card(
            style: isSelected ? .gradient : .default,
            shadowStyle: isSelected ? .medium : .subtle
        ) {
            HStack(spacing: 12) {
                // Selection Indicator
                if isInSelectionMode {
                    Button(action: onTap) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isSelected ? .trainSoftBlue : .trainLightGray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(history.stationName ?? "不明な駅")
                            .font(.labelMedium)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text(history.notifiedAtRelativeString)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Text(history.messagePreview)
                        .font(.bodySmall)
                        .foregroundColor(.textSecondary)
                        .lineLimit(2)
                    
                    HStack {
                        if let characterStyle = history.characterStyle {
                            Text(characterStyle)
                                .font(.caption)
                                .foregroundColor(.trainSoftBlue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.trainSoftBlue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Spacer()
                        
                        Text(formatTime(history.notifiedAt))
                            .font(.numbersMedium)
                            .foregroundColor(.textInactive)
                    }
                }
                
                // Delete Button (only when not in selection mode)
                if !isInSelectionMode {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.error)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("削除") {
                onDelete()
            }
            .tint(.error)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isInSelectionMode {
                onTap()
            }
        }
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "--:--" }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .preferredColorScheme(.dark)
            .previewDisplayName("History View")
    }
}
#endif
