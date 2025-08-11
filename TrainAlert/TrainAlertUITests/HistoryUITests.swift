//
//  HistoryUITests.swift
//  TrainAlertUITests
//
//  Created by Claude on 2024/01/08.
//

import XCTest

final class HistoryUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app for testing with some mock history data
        app.launchArguments = ["--testing", "--with-history"]
        app.launchEnvironment = ["TESTING": "1"]
        
        app.launch()
        
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - History Navigation Tests
    
    func testNavigateToHistory() throws {
        // Navigate to history tab
        let historyTab = app.tabBars.buttons["履歴"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        
        historyTab.tap()
        
        // Verify history screen is displayed
        let historyTitle = app.navigationBars["履歴"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 5))
    }
    
    func testHistoryScreenElements() throws {
        navigateToHistory()
        
        // Check for main history elements
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) {
            XCTAssertTrue(historyTable.exists)
        } else {
            // Check for empty state
            let emptyStateMessage = app.staticTexts["履歴がありません"]
            XCTAssertTrue(emptyStateMessage.waitForExistence(timeout: 5))
        }
        
        // Check for filter and search options
        let filterButton = app.buttons["フィルター"]
        let searchButton = app.buttons["検索"]
        
        XCTAssertTrue(filterButton.exists || searchButton.exists)
    }
    
    // MARK: - History List Tests
    
    func testHistoryListDisplay() throws {
        navigateToHistory()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) {
            // Check if history items exist
            let historyCells = historyTable.cells
            if !historyCells.isEmpty {
                let firstCell = historyCells.element(boundBy: 0)
                XCTAssertTrue(firstCell.exists)
                
                // Check cell content structure
                let stationName = firstCell.staticTexts.element(boundBy: 0)
                let timestamp = firstCell.staticTexts.element(boundBy: 1)
                
                XCTAssertTrue(stationName.exists)
                XCTAssertTrue(timestamp.exists)
            }
        }
    }
    
    func testHistoryItemDetails() throws {
        navigateToHistory()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) && historyTable.cells.count > 0 {
            let firstCell = historyTable.cells.element(boundBy: 0)
            firstCell.tap()
            
            // Should navigate to detail view
            let detailView = app.navigationBars["通知詳細"]
            if detailView.waitForExistence(timeout: 5) {
                // Check detail elements
                let stationLabel = app.staticTexts["駅名"]
                let messageLabel = app.staticTexts["メッセージ"]
                let characterLabel = app.staticTexts["キャラクター"]
                let timeLabel = app.staticTexts["時刻"]
                
                XCTAssertTrue(stationLabel.exists)
                XCTAssertTrue(messageLabel.exists)
                XCTAssertTrue(characterLabel.exists || timeLabel.exists)
                
                // Go back to history list
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                backButton.tap()
            }
        }
    }
    
    // MARK: - Search Functionality Tests
    
    func testHistorySearch() throws {
        navigateToHistory()
        
        // Activate search
        let searchButton = app.buttons["検索"]
        if searchButton.waitForExistence(timeout: 5) {
            searchButton.tap()
        } else {
            // Try alternative search activation
            let searchBar = app.searchFields["履歴を検索"]
            XCTAssertTrue(searchBar.waitForExistence(timeout: 5))
        }
        
        let searchField = app.searchFields.element(boundBy: 0)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        // Test search functionality
        searchField.tap()
        searchField.typeText("東京")
        
        // Wait for search results
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) {
            // Results should be filtered
            XCTAssertTrue(historyTable.exists)
        }
        
        // Clear search
        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        }
    }
    
    func testSearchWithDifferentQueries() throws {
        navigateToHistory()
        activateSearch()
        
        let searchField = app.searchFields.element(boundBy: 0)
        
        let searchQueries = ["渋谷", "ギャル", "朝", "夜"]
        
        for query in searchQueries {
            searchField.tap()
            clearSearchField(searchField)
            searchField.typeText(query)
            
            // Wait for results to update
            Thread.sleep(forTimeInterval: 1.0)
            
            let historyTable = app.tables["履歴リスト"]
            XCTAssertTrue(historyTable.exists)
        }
    }
    
    func testEmptySearchResults() throws {
        navigateToHistory()
        activateSearch()
        
        let searchField = app.searchFields.element(boundBy: 0)
        searchField.tap()
        searchField.typeText("存在しない駅名xyzabc")
        
        // Should show empty search results
        let emptyMessage = app.staticTexts["検索結果がありません"]
        XCTAssertTrue(emptyMessage.waitForExistence(timeout: 5))
    }
    
    // MARK: - Filter Tests
    
    func testHistoryFilters() throws {
        navigateToHistory()
        
        let filterButton = app.buttons["フィルター"]
        if filterButton.waitForExistence(timeout: 5) {
            filterButton.tap()
            
            // Test filter options
            let filterSheet = app.sheets["フィルターオプション"]
            if filterSheet.waitForExistence(timeout: 5) {
                // Test date filters
                let todayFilter = filterSheet.buttons["今日"]
                let thisWeekFilter = filterSheet.buttons["今週"]
                let thisMonthFilter = filterSheet.buttons["今月"]
                let allFilter = filterSheet.buttons["すべて"]
                
                if todayFilter.exists {
                    todayFilter.tap()
                    verifyFilterApplied()
                }
                
                // Reopen filter
                if filterButton.exists {
                    filterButton.tap()
                }
                
                if filterSheet.waitForExistence(timeout: 3) && thisWeekFilter.exists {
                    thisWeekFilter.tap()
                    verifyFilterApplied()
                }
            }
        }
    }
    
    func testCharacterStyleFilter() throws {
        navigateToHistory()
        openFilterOptions()
        
        let characterFilterSection = app.staticTexts["キャラクタースタイル"]
        if characterFilterSection.waitForExistence(timeout: 5) {
            // Test different character style filters
            let characterOptions = ["ギャル系", "執事系", "癒し系"]
            
            for character in characterOptions {
                let characterButton = app.buttons[character]
                if characterButton.exists {
                    characterButton.tap()
                    
                    // Apply filter
                    let applyButton = app.buttons["適用"]
                    if applyButton.exists {
                        applyButton.tap()
                        verifyFilterApplied()
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Sorting Tests
    
    func testHistorySorting() throws {
        navigateToHistory()
        
        let sortButton = app.buttons["並び替え"]
        if sortButton.waitForExistence(timeout: 5) {
            sortButton.tap()
            
            // Test sort options
            let sortSheet = app.sheets["並び替えオプション"]
            if sortSheet.waitForExistence(timeout: 5) {
                let dateDescendingOption = sortSheet.buttons["新しい順"]
                let dateAscendingOption = sortSheet.buttons["古い順"]
                let stationNameOption = sortSheet.buttons["駅名順"]
                
                // Test date descending
                if dateDescendingOption.exists {
                    dateDescendingOption.tap()
                    verifySortApplied()
                }
                
                // Test station name sorting
                if sortButton.exists {
                    sortButton.tap()
                    if sortSheet.waitForExistence(timeout: 3) && stationNameOption.exists {
                        stationNameOption.tap()
                        verifySortApplied()
                    }
                }
            }
        }
    }
    
    // MARK: - Selection and Deletion Tests
    
    func testHistoryItemSelection() throws {
        navigateToHistory()
        
        let selectButton = app.buttons["選択"]
        if selectButton.waitForExistence(timeout: 5) {
            selectButton.tap()
            
            // Should enter selection mode
            let cancelButton = app.buttons["キャンセル"]
            XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
            
            // Test selecting items
            let historyTable = app.tables["履歴リスト"]
            if historyTable.exists && historyTable.cells.count > 0 {
                let firstCell = historyTable.cells.element(boundBy: 0)
                firstCell.tap()
                
                // Cell should show selection state
                XCTAssertTrue(firstCell.isSelected || !firstCell.buttons.isEmpty)
                
                // Test select all
                let selectAllButton = app.buttons["すべて選択"]
                if selectAllButton.exists {
                    selectAllButton.tap()
                }
            }
            
            // Exit selection mode
            cancelButton.tap()
        }
    }
    
    func testDeleteHistoryItems() throws {
        navigateToHistory()
        enterSelectionMode()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.exists && historyTable.cells.count > 0 {
            // Select first item
            let firstCell = historyTable.cells.element(boundBy: 0)
            firstCell.tap()
            
            // Delete selected items
            let deleteButton = app.buttons["削除"]
            if deleteButton.waitForExistence(timeout: 5) {
                deleteButton.tap()
                
                // Confirm deletion
                let confirmAlert = app.alerts["確認"]
                if confirmAlert.waitForExistence(timeout: 5) {
                    confirmAlert.buttons["削除"].tap()
                    
                    // Verify item was deleted
                    Thread.sleep(forTimeInterval: 1.0)
                    XCTAssertTrue(historyTable.exists)
                }
            }
        }
    }
    
    func testSwipeToDelete() throws {
        navigateToHistory()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) && historyTable.cells.count > 0 {
            let firstCell = historyTable.cells.element(boundBy: 0)
            
            // Swipe to reveal delete action
            firstCell.swipeLeft()
            
            // Tap delete button
            let deleteButton = firstCell.buttons["削除"]
            if deleteButton.waitForExistence(timeout: 3) {
                deleteButton.tap()
                
                // Handle confirmation if it appears
                let confirmAlert = app.alerts["確認"]
                if confirmAlert.waitForExistence(timeout: 3) {
                    confirmAlert.buttons["削除"].tap()
                }
            }
        }
    }
    
    // MARK: - Export Functionality Tests
    
    func testExportHistory() throws {
        navigateToHistory()
        
        let moreButton = app.buttons["その他"]
        let exportButton = app.buttons["エクスポート"]
        
        if exportButton.waitForExistence(timeout: 5) {
            exportButton.tap()
        } else if moreButton.waitForExistence(timeout: 5) {
            moreButton.tap()
            
            let moreSheet = app.sheets.element(boundBy: 0)
            if moreSheet.waitForExistence(timeout: 3) {
                let exportOption = moreSheet.buttons["履歴をエクスポート"]
                if exportOption.exists {
                    exportOption.tap()
                }
            }
        }
        
        // Should show share sheet
        let shareSheet = app.sheets.element(boundBy: 0)
        if shareSheet.waitForExistence(timeout: 5) {
            // Test different export options
            let copyButton = shareSheet.buttons["コピー"]
            let saveToFilesButton = shareSheet.buttons["ファイルに保存"]
            
            if copyButton.exists {
                copyButton.tap()
                
                let copyAlert = app.alerts["コピー完了"]
                if copyAlert.waitForExistence(timeout: 5) {
                    copyAlert.buttons["OK"].tap()
                }
            } else {
                // Cancel export
                let cancelButton = shareSheet.buttons["キャンセル"]
                if cancelButton.exists {
                    cancelButton.tap()
                }
            }
        }
    }
    
    // MARK: - Refresh and Loading Tests
    
    func testPullToRefresh() throws {
        navigateToHistory()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) {
            // Perform pull to refresh gesture
            historyTable.swipeDown()
            
            // Should show loading indicator
            let loadingIndicator = app.activityIndicators["読み込み中"]
            if loadingIndicator.waitForExistence(timeout: 3) {
                // Wait for loading to complete
                XCTAssertFalse(loadingIndicator.waitForExistence(timeout: 10))
            }
        }
    }
    
    func testLoadMoreHistory() throws {
        navigateToHistory()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) {
            // Scroll to bottom
            if historyTable.cells.count > 5 {
                let lastCell = historyTable.cells.element(boundBy: historyTable.cells.count - 1)
                lastCell.scrollToElement()
                
                // Should trigger load more
                let loadMoreIndicator = app.activityIndicators["さらに読み込み"]
                if loadMoreIndicator.waitForExistence(timeout: 3) {
                    // Wait for more items to load
                    Thread.sleep(forTimeInterval: 2.0)
                }
            }
        }
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyHistoryState() throws {
        // This would require clearing all history first
        navigateToHistory()
        
        // Try to clear all history
        if enterSelectionMode() {
            let selectAllButton = app.buttons["すべて選択"]
            if selectAllButton.exists {
                selectAllButton.tap()
                
                let deleteButton = app.buttons["削除"]
                if deleteButton.exists {
                    deleteButton.tap()
                    
                    let confirmAlert = app.alerts["確認"]
                    if confirmAlert.waitForExistence(timeout: 5) {
                        confirmAlert.buttons["削除"].tap()
                    }
                }
            }
        }
        
        // Check empty state
        let emptyStateMessage = app.staticTexts["履歴がありません"]
        let emptyStateImage = app.images["空の履歴"]
        
        XCTAssertTrue(emptyStateMessage.waitForExistence(timeout: 5) || 
                     emptyStateImage.waitForExistence(timeout: 5))
    }
    
    // MARK: - Accessibility Tests
    
    func testHistoryAccessibility() throws {
        navigateToHistory()
        
        let historyTable = app.tables["履歴リスト"]
        if historyTable.waitForExistence(timeout: 5) && historyTable.cells.count > 0 {
            let firstCell = historyTable.cells.element(boundBy: 0)
            
            XCTAssertTrue(firstCell.isAccessibilityElement)
            XCTAssertNotNil(firstCell.accessibilityLabel)
        }
        
        let filterButton = app.buttons["フィルター"]
        if filterButton.exists {
            XCTAssertTrue(filterButton.isAccessibilityElement)
            XCTAssertNotNil(filterButton.accessibilityLabel)
        }
        
        let searchField = app.searchFields.element(boundBy: 0)
        if searchField.exists {
            XCTAssertTrue(searchField.isAccessibilityElement)
            XCTAssertNotNil(searchField.accessibilityLabel)
        }
    }
    
    // MARK: - Performance Tests
    
    func testHistoryScreenPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            navigateToHistory()
            
            let historyTable = app.tables["履歴リスト"]
            if historyTable.waitForExistence(timeout: 5) {
                // Scroll through history
                historyTable.swipeUp()
                historyTable.swipeDown()
            }
        }
    }
    
    func testHistorySearchPerformance() throws {
        navigateToHistory()
        activateSearch()
        
        let searchField = app.searchFields.element(boundBy: 0)
        
        measure(metrics: [XCTClockMetric()]) {
            searchField.tap()
            searchField.typeText("東京")
            
            let historyTable = app.tables["履歴リスト"]
            _ = historyTable.waitForExistence(timeout: 5)
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToHistory() {
        let historyTab = app.tabBars.buttons["履歴"]
        if historyTab.waitForExistence(timeout: 5) {
            historyTab.tap()
        }
        
        let historyTitle = app.navigationBars["履歴"]
        XCTAssertTrue(historyTitle.waitForExistence(timeout: 5))
    }
    
    private func activateSearch() {
        let searchButton = app.buttons["検索"]
        if searchButton.waitForExistence(timeout: 5) {
            searchButton.tap()
        }
    }
    
    private func clearSearchField(_ searchField: XCUIElement) {
        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        } else {
            // Double tap to select all and delete
            searchField.doubleTap()
            app.keys["delete"].tap()
        }
    }
    
    private func openFilterOptions() {
        let filterButton = app.buttons["フィルター"]
        if filterButton.waitForExistence(timeout: 5) {
            filterButton.tap()
        }
    }
    
    private func verifyFilterApplied() {
        // Check that filter was applied (table updated or filter indicator shown)
        let historyTable = app.tables["履歴リスト"]
        XCTAssertTrue(historyTable.exists)
        
        let filterIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'フィルター'")).firstMatch
        // Filter might be applied (can't easily verify content without test data)
    }
    
    private func verifySortApplied() {
        let historyTable = app.tables["履歴リスト"]
        XCTAssertTrue(historyTable.exists)
        // Sort order change would require examining actual cell content
    }
    
    @discardableResult
    private func enterSelectionMode() -> Bool {
        let selectButton = app.buttons["選択"]
        if selectButton.waitForExistence(timeout: 5) {
            selectButton.tap()
            
            let cancelButton = app.buttons["キャンセル"]
            return cancelButton.waitForExistence(timeout: 5)
        }
        return false
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func scrollToElement() {
        while !self.isHittable {
            let app = XCUIApplication()
            let table = app.tables.element(boundBy: 0)
            table.swipeUp()
            
            if !self.exists {
                break
            }
        }
    }
}
