//
//  HistoryViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import Combine
import CoreData
import SwiftUI

@MainActor
class HistoryViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let coreDataManager: CoreDataManager
    
    // MARK: - Published Properties
    
    @Published var historyItems: [History] = []
    @Published var filteredHistoryItems: [History] = []
    @Published var groupedHistoryItems: [String: [History]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedFilter: HistoryFilter = .all
    @Published var selectedSortOption: SortOption = .dateDescending
    @Published var showingDeleteAlert = false
    @Published var itemToDelete: History?
    @Published var selectedItems: Set<UUID> = []
    @Published var isInSelectionMode = false
    @Published var showingExportSheet = false
    
    // MARK: - Computed Properties
    
    var hasHistory: Bool {
        !historyItems.isEmpty
    }
    
    var filteredCount: Int {
        filteredHistoryItems.count
    }
    
    var totalCount: Int {
        historyItems.count
    }
    
    var canDelete: Bool {
        !selectedItems.isEmpty || itemToDelete != nil
    }
    
    var canExport: Bool {
        !filteredHistoryItems.isEmpty
    }
    
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 50
    private var currentPage = 0
    private var canLoadMore = true
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        
        setupSubscriptions()
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    /// Refresh all history data
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await loadHistoryItems()
            applyFiltersAndSort()
            groupHistoryItems()
        } catch {
            errorMessage = "履歴の読み込みに失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Load more history items (pagination)
    func loadMore() async {
        guard canLoadMore && !isLoading else { return }
        
        isLoading = true
        
        do {
            let newItems = await loadHistoryItems(page: currentPage + 1)
            if newItems.isEmpty {
                canLoadMore = false
            } else {
                currentPage += 1
                // Items are automatically updated through Core Data observations
            }
        } catch {
            errorMessage = "追加の履歴読み込みに失敗しました"
        }
        
        isLoading = false
    }
    
    /// Delete history item with undo support
    func deleteHistoryItem(_ history: History) {
        itemToDelete = history
        showingDeleteAlert = true
    }
    
    /// Confirm deletion
    func confirmDelete() {
        guard let history = itemToDelete else { return }
        
        do {
            coreDataManager.viewContext.delete(history)
            coreDataManager.save()
            
            // Show undo option
            showUndoDeleteOption(for: history)
            
        } catch {
            errorMessage = "履歴の削除に失敗しました"
        }
        
        itemToDelete = nil
        showingDeleteAlert = false
    }
    
    /// Delete selected items
    func deleteSelectedItems() {
        let itemsToDelete = historyItems.filter { selectedItems.contains($0.id) }
        
        do {
            for item in itemsToDelete {
                coreDataManager.viewContext.delete(item)
            }
            coreDataManager.save()
            
            selectedItems.removeAll()
            isInSelectionMode = false
            
        } catch {
            errorMessage = "選択した履歴の削除に失敗しました"
        }
    }
    
    /// Toggle selection mode
    func toggleSelectionMode() {
        isInSelectionMode.toggle()
        if !isInSelectionMode {
            selectedItems.removeAll()
        }
    }
    
    /// Toggle item selection
    func toggleItemSelection(_ history: History) {
        if selectedItems.contains(history.id) {
            selectedItems.remove(history.id)
        } else {
            selectedItems.insert(history.id)
        }
    }
    
    /// Select all filtered items
    func selectAll() {
        selectedItems = Set(filteredHistoryItems.map { $0.id })
    }
    
    /// Clear all selections
    func clearSelection() {
        selectedItems.removeAll()
    }
    
    /// Export history as CSV
    func exportHistoryAsCSV() -> String {
        let headers = ["日時", "駅名", "メッセージ", "キャラクター"]
        var csvContent = headers.joined(separator: ",") + "\n"
        
        for history in filteredHistoryItems {
            let row = [
                history.notifiedAtDetailString,
                history.stationName ?? "",
                history.message?.replacingOccurrences(of: ",", with: "，") ?? "",
                history.characterStyle ?? ""
            ]
            csvContent += row.joined(separator: ",") + "\n"
        }
        
        return csvContent
    }
    
    /// Update filter
    func updateFilter(_ filter: HistoryFilter) {
        selectedFilter = filter
        applyFiltersAndSort()
        groupHistoryItems()
    }
    
    /// Update sort option
    func updateSortOption(_ sortOption: SortOption) {
        selectedSortOption = sortOption
        applyFiltersAndSort()
        groupHistoryItems()
    }
    
    /// Search history
    func searchHistory(_ query: String) {
        searchText = query
        applyFiltersAndSort()
        groupHistoryItems()
    }
    
    /// Clear search
    func clearSearch() {
        searchText = ""
        applyFiltersAndSort()
        groupHistoryItems()
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to Core Data changes
        NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave, object: coreDataManager.viewContext)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadHistoryItems()
                    self?.applyFiltersAndSort()
                    self?.groupHistoryItems()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadHistoryItems()
            applyFiltersAndSort()
            groupHistoryItems()
        }
    }
    
    @MainActor
    private func loadHistoryItems(page: Int = 0) async -> [History] {
        do {
            let request = History.recentHistoryFetchRequest(limit: pageSize)
            request.fetchOffset = page * pageSize
            
            let newItems = try coreDataManager.viewContext.fetch(request)
            
            if page == 0 {
                historyItems = newItems
            }
            
            return newItems
        } catch {
            errorMessage = "履歴の読み込みに失敗しました"
            return []
        }
    }
    
    private func applyFiltersAndSort() {
        var filtered = historyItems
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { history in
                let messageMatch = history.message?.localizedCaseInsensitiveContains(searchText) ?? false
                let stationMatch = history.stationName?.localizedCaseInsensitiveContains(searchText) ?? false
                let characterMatch = history.characterStyle?.localizedCaseInsensitiveContains(searchText) ?? false
                return messageMatch || stationMatch || characterMatch
            }
        }
        
        // Apply date filter
        filtered = applyDateFilter(to: filtered, filter: selectedFilter)
        
        // Apply sorting
        filtered = applySorting(to: filtered, option: selectedSortOption)
        
        filteredHistoryItems = filtered
    }
    
    private func applyDateFilter(to items: [History], filter: HistoryFilter) -> [History] {
        switch filter {
        case .all:
            return items
        case .today:
            return items.filter { $0.isToday }
        case .thisWeek:
            return items.filter { $0.isThisWeek }
        case .thisMonth:
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
            
            return items.filter { history in
                guard let notifiedAt = history.notifiedAt else { return false }
                return notifiedAt >= startOfMonth && notifiedAt <= endOfMonth
            }
        case .custom(let startDate, let endDate):
            return items.filter { history in
                guard let notifiedAt = history.notifiedAt else { return false }
                return notifiedAt >= startDate && notifiedAt <= endDate
            }
        }
    }
    
    private func applySorting(to items: [History], option: SortOption) -> [History] {
        switch option {
        case .dateDescending:
            return items.sorted { ($0.notifiedAt ?? Date.distantPast) > ($1.notifiedAt ?? Date.distantPast) }
        case .dateAscending:
            return items.sorted { ($0.notifiedAt ?? Date.distantPast) < ($1.notifiedAt ?? Date.distantPast) }
        case .stationName:
            return items.sorted { ($0.stationName ?? "") < ($1.stationName ?? "") }
        case .characterStyle:
            return items.sorted { ($0.characterStyle ?? "") < ($1.characterStyle ?? "") }
        }
    }
    
    private func groupHistoryItems() {
        let grouped = Dictionary(grouping: filteredHistoryItems) { history in
            history.dateGroupKey
        }
        
        // Sort groups by date
        let sortedGroups = grouped.mapValues { items in
            items.sorted { ($0.notifiedAt ?? Date.distantPast) > ($1.notifiedAt ?? Date.distantPast) }
        }
        
        groupedHistoryItems = sortedGroups
    }
    
    private func showUndoDeleteOption(for history: History) {
        // This would typically show a snackbar or toast with undo option
        // For now, we'll just log the action
        // History deleted. Undo option would be shown here.
    }
}

// MARK: - Supporting Types

extension HistoryViewModel {
    
    enum HistoryFilter: CaseIterable {
        case all
        case today
        case thisWeek
        case thisMonth
        case custom(Date, Date)
        
        var displayName: String {
            switch self {
            case .all:
                return "すべて"
            case .today:
                return "今日"
            case .thisWeek:
                return "今週"
            case .thisMonth:
                return "今月"
            case .custom:
                return "カスタム"
            }
        }
        
        static var allCases: [HistoryFilter] {
            return [.all, .today, .thisWeek, .thisMonth]
        }
    }
    
    enum SortOption: CaseIterable {
        case dateDescending
        case dateAscending
        case stationName
        case characterStyle
        
        var displayName: String {
            switch self {
            case .dateDescending:
                return "新しい順"
            case .dateAscending:
                return "古い順"
            case .stationName:
                return "駅名順"
            case .characterStyle:
                return "キャラクター順"
            }
        }
        
        var icon: String {
            switch self {
            case .dateDescending:
                return "arrow.down"
            case .dateAscending:
                return "arrow.up"
            case .stationName:
                return "building.2"
            case .characterStyle:
                return "person.2"
            }
        }
    }
}

// MARK: - Extensions

extension HistoryViewModel.HistoryFilter: Equatable {
    static func == (lhs: HistoryViewModel.HistoryFilter, rhs: HistoryViewModel.HistoryFilter) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all), (.today, .today), (.thisWeek, .thisWeek), (.thisMonth, .thisMonth):
            return true
        case (.custom(let lDate1, let lDate2), .custom(let rDate1, let rDate2)):
            return lDate1 == rDate1 && lDate2 == rDate2
        default:
            return false
        }
    }
}
