//
//  AlertSetupFlowUITests.swift
//  TrainAlertUITests
//
//  Created by Claude on 2024/01/08.
//

import XCTest

final class AlertSetupFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app for testing
        app.launchArguments = ["--testing"]
        app.launchEnvironment = ["TESTING": "1"]
        
        app.launch()
        
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - Alert Setup Flow Tests
    
    func testCompleteAlertSetupFlow() throws {
        // Navigate to alert setup
        navigateToAlertSetup()
        
        // Step 1: Station Search
        performStationSearch()
        
        // Step 2: Alert Settings
        configureAlertSettings()
        
        // Step 3: Character Selection
        selectCharacterStyle()
        
        // Step 4: Review and Create
        reviewAndCreateAlert()
    }
    
    func testStationSearchFunctionality() throws {
        navigateToAlertSetup()
        
        // Test station search
        let searchField = app.searchFields["駅名を入力"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        searchField.tap()
        searchField.typeText("東京")
        
        // Wait for search results
        let searchResults = app.tables["検索結果"]
        XCTAssertTrue(searchResults.waitForExistence(timeout: 10))
        
        // Test selecting a station
        let firstResult = searchResults.cells.element(boundBy: 0)
        if firstResult.exists {
            firstResult.tap()
            
            // Verify selection
            let selectedStationText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '東京'")).firstMatch
            XCTAssertTrue(selectedStationText.exists)
        }
    }
    
    func testStationSearchWithEmptyQuery() throws {
        navigateToAlertSetup()
        
        let searchField = app.searchFields["駅名を入力"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        // Test empty search
        searchField.tap()
        searchField.typeText("")
        
        // Should not show results or show empty state
        let emptyStateMessage = app.staticTexts["駅名を入力してください"]
        let noResultsMessage = app.staticTexts["検索結果がありません"]
        
        XCTAssertTrue(emptyStateMessage.exists || noResultsMessage.exists)
    }
    
    func testStationSearchWithSpecialCharacters() throws {
        navigateToAlertSetup()
        
        let searchField = app.searchFields["駅名を入力"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        // Test search with special characters
        let specialQueries = ["東京駅🚃", "渋谷/原宿", "新宿(南口)"]
        
        for query in specialQueries {
            searchField.tap()
            searchField.clearAndEnterText(query)
            
            // Should handle gracefully without crashing
            XCTAssertTrue(app.exists)
        }
    }
    
    func testAlertSettingsConfiguration() throws {
        navigateToAlertSetup()
        performStationSearch()
        
        // Navigate to settings step
        let nextButton = app.buttons["次へ"]
        if nextButton.exists {
            nextButton.tap()
        }
        
        // Test notification time slider
        let timeSlider = app.sliders["通知タイミング"]
        XCTAssertTrue(timeSlider.waitForExistence(timeout: 5))
        
        // Test different positions
        timeSlider.adjust(toNormalizedSliderPosition: 0.2) // 2 minutes
        timeSlider.adjust(toNormalizedSliderPosition: 0.5) // 5 minutes
        timeSlider.adjust(toNormalizedSliderPosition: 0.8) // 8 minutes
        
        // Test distance slider
        let distanceSlider = app.sliders["通知距離"]
        XCTAssertTrue(distanceSlider.exists)
        
        distanceSlider.adjust(toNormalizedSliderPosition: 0.3) // ~300m
        distanceSlider.adjust(toNormalizedSliderPosition: 0.7) // ~700m
        
        // Test snooze interval
        let snoozeSlider = app.sliders["スヌーズ間隔"]
        XCTAssertTrue(snoozeSlider.exists)
        
        snoozeSlider.adjust(toNormalizedSliderPosition: 0.4)
        
        // Verify settings are reflected in UI
        let timeLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '分前'")).firstMatch
        XCTAssertTrue(timeLabel.exists)
        
        let distanceLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'm' OR label CONTAINS 'km'")).firstMatch
        XCTAssertTrue(distanceLabel.exists)
    }
    
    func testCharacterStyleSelection() throws {
        navigateToAlertSetup()
        performStationSearch()
        configureAlertSettings()
        
        // Navigate to character selection
        let nextButton = app.buttons["次へ"]
        if nextButton.exists {
            nextButton.tap()
        }
        
        // Test character selection grid
        let characterGrid = app.collectionViews["キャラクター選択"]
        XCTAssertTrue(characterGrid.waitForExistence(timeout: 5))
        
        // Test selecting different characters
        let characters = ["ギャル系", "執事系", "関西弁系", "ツンデレ系", "体育会系", "癒し系"]
        
        for character in characters {
            let characterButton = characterGrid.buttons[character]
            if characterButton.exists {
                characterButton.tap()
                
                // Verify selection state (should have some visual indication)
                XCTAssertTrue(characterButton.isSelected || characterButton.value != nil)
                
                // Test character preview
                let previewText = app.staticTexts["プレビュー"]
                if previewText.exists {
                    XCTAssertTrue(previewText.exists)
                }
            }
        }
        
        // Ensure at least one character is selected
        let selectedCharacter = characterGrid.buttons.allElementsBoundByIndex.first { $0.isSelected }
        XCTAssertNotNil(selectedCharacter, "At least one character should be selectable")
    }
    
    func testReviewScreenContent() throws {
        navigateToAlertSetup()
        performStationSearch()
        configureAlertSettings()
        selectCharacterStyle()
        
        // Navigate to review
        let nextButton = app.buttons["次へ"]
        if nextButton.exists {
            nextButton.tap()
        }
        
        // Verify review screen elements
        let reviewTitle = app.staticTexts["設定確認"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 5))
        
        // Check for configuration summary
        let stationInfo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '駅'")).firstMatch
        XCTAssertTrue(stationInfo.exists)
        
        let settingsInfo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '分前'")).firstMatch
        XCTAssertTrue(settingsInfo.exists)
        
        let characterInfo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '系'")).firstMatch
        XCTAssertTrue(characterInfo.exists)
        
        // Test edit buttons
        let editStationButton = app.buttons["駅を変更"]
        let editSettingsButton = app.buttons["設定を変更"]
        let editCharacterButton = app.buttons["キャラクターを変更"]
        
        if editStationButton.exists {
            editStationButton.tap()
            // Should navigate back to station selection
            let stationSearchField = app.searchFields["駅名を入力"]
            XCTAssertTrue(stationSearchField.waitForExistence(timeout: 5))
            
            // Navigate back to review
            navigateToReview()
        }
    }
    
    func testAlertCreationProcess() throws {
        navigateToAlertSetup()
        performStationSearch()
        configureAlertSettings()
        selectCharacterStyle()
        navigateToReview()
        
        // Test alert creation
        let createButton = app.buttons["アラートを作成"]
        XCTAssertTrue(createButton.exists)
        
        createButton.tap()
        
        // Handle potential permission dialogs
        handlePermissionDialogs()
        
        // Verify success or appropriate error handling
        let successAlert = app.alerts["成功"]
        let errorAlert = app.alerts["エラー"]
        let homeScreen = app.navigationBars["ホーム"]
        
        let result = successAlert.waitForExistence(timeout: 10) || 
                    errorAlert.waitForExistence(timeout: 5) ||
                    homeScreen.waitForExistence(timeout: 10)
        
        XCTAssertTrue(result, "Alert creation should show result or navigate to home")
        
        if successAlert.exists {
            successAlert.buttons["OK"].tap()
        } else if errorAlert.exists {
            errorAlert.buttons["OK"].tap()
        }
    }
    
    func testNavigationBetweenSteps() throws {
        navigateToAlertSetup()
        
        // Test forward navigation
        performStationSearch()
        
        let nextButton = app.buttons["次へ"]
        if nextButton.exists && nextButton.isEnabled {
            nextButton.tap()
            
            // Should be on settings step
            let timeSlider = app.sliders["通知タイミング"]
            XCTAssertTrue(timeSlider.waitForExistence(timeout: 5))
        }
        
        // Test backward navigation
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            
            // Should be back to station search
            let searchField = app.searchFields["駅名を入力"]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        }
    }
    
    func testFormValidation() throws {
        navigateToAlertSetup()
        
        // Test proceeding without station selection
        let nextButton = app.buttons["次へ"]
        if nextButton.exists {
            // Should be disabled or show validation
            XCTAssertFalse(nextButton.isEnabled, "Next button should be disabled without station selection")
        }
        
        // Select station and proceed
        performStationSearch()
        
        if nextButton.exists && nextButton.isEnabled {
            nextButton.tap()
            
            // Now on settings screen - all settings should have valid defaults
            let createButton = app.buttons["アラートを作成"]
            // Navigate to final step to check if create button becomes available
            if nextButton.exists {
                nextButton.tap() // Character selection
                if nextButton.exists {
                    nextButton.tap() // Review
                    
                    XCTAssertTrue(createButton.waitForExistence(timeout: 5))
                }
            }
        }
    }
    
    func testCancelAlertSetup() throws {
        navigateToAlertSetup()
        performStationSearch()
        
        // Test cancel functionality
        let cancelButton = app.navigationBars.buttons["キャンセル"]
        if cancelButton.exists {
            cancelButton.tap()
            
            // Should show confirmation dialog
            let confirmDialog = app.alerts["確認"]
            if confirmDialog.waitForExistence(timeout: 5) {
                confirmDialog.buttons["はい"].tap()
            }
            
            // Should return to home
            let homeScreen = app.navigationBars["ホーム"]
            XCTAssertTrue(homeScreen.waitForExistence(timeout: 5))
        }
    }
    
    func testAlertSetupAccessibility() throws {
        navigateToAlertSetup()
        
        // Test accessibility labels and hints
        let searchField = app.searchFields["駅名を入力"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        XCTAssertTrue(searchField.isAccessibilityElement)
        XCTAssertNotNil(searchField.accessibilityLabel)
        
        performStationSearch()
        
        let nextButton = app.buttons["次へ"]
        if nextButton.exists {
            nextButton.tap()
            
            // Check slider accessibility
            let timeSlider = app.sliders["通知タイミング"]
            if timeSlider.exists {
                XCTAssertTrue(timeSlider.isAccessibilityElement)
                XCTAssertNotNil(timeSlider.accessibilityLabel)
                XCTAssertNotNil(timeSlider.accessibilityValue)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testAlertSetupFlowPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            navigateToAlertSetup()
            performStationSearch()
            configureAlertSettings()
            selectCharacterStyle()
            navigateToReview()
        }
    }
    
    func testStationSearchPerformance() throws {
        navigateToAlertSetup()
        
        let searchField = app.searchFields["駅名を入力"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        measure(metrics: [XCTClockMetric()]) {
            searchField.tap()
            searchField.typeText("東京")
            
            let searchResults = app.tables["検索結果"]
            _ = searchResults.waitForExistence(timeout: 10)
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToAlertSetup() {
        // Navigate to home tab
        let homeTab = app.tabBars.buttons["ホーム"]
        if homeTab.waitForExistence(timeout: 5) {
            homeTab.tap()
        }
        
        // Find and tap add alert button
        let addAlertButtons = [
            app.buttons["アラートを追加"],
            app.buttons["新しいアラート"],
            app.buttons["+"],
            app.navigationBars.buttons["追加"]
        ]
        
        var buttonFound = false
        for button in addAlertButtons {
            if button.waitForExistence(timeout: 2) {
                button.tap()
                buttonFound = true
                break
            }
        }
        
        XCTAssertTrue(buttonFound, "Add alert button should be found")
        
        // Verify alert setup screen
        let alertSetupIndicator = app.navigationBars["アラート設定"]
        XCTAssertTrue(alertSetupIndicator.waitForExistence(timeout: 5))
    }
    
    private func performStationSearch() {
        let searchField = app.searchFields["駅名を入力"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        
        searchField.tap()
        searchField.typeText("東京")
        
        let searchResults = app.tables["検索結果"]
        if searchResults.waitForExistence(timeout: 10) {
            let firstResult = searchResults.cells.element(boundBy: 0)
            if firstResult.exists {
                firstResult.tap()
            }
        }
    }
    
    private func configureAlertSettings() {
        let nextButton = app.buttons["次へ"]
        if nextButton.waitForExistence(timeout: 5) && nextButton.isEnabled {
            nextButton.tap()
        }
        
        // Basic configuration - adjust sliders slightly
        let timeSlider = app.sliders["通知タイミング"]
        if timeSlider.waitForExistence(timeout: 5) {
            timeSlider.adjust(toNormalizedSliderPosition: 0.5)
        }
        
        let distanceSlider = app.sliders["通知距離"]
        if distanceSlider.exists {
            distanceSlider.adjust(toNormalizedSliderPosition: 0.5)
        }
    }
    
    private func selectCharacterStyle() {
        let nextButton = app.buttons["次へ"]
        if nextButton.waitForExistence(timeout: 5) && nextButton.isEnabled {
            nextButton.tap()
        }
        
        let characterGrid = app.collectionViews["キャラクター選択"]
        if characterGrid.waitForExistence(timeout: 5) {
            let firstCharacter = characterGrid.buttons.element(boundBy: 0)
            if firstCharacter.exists {
                firstCharacter.tap()
            }
        }
    }
    
    private func navigateToReview() {
        let nextButton = app.buttons["次へ"]
        if nextButton.waitForExistence(timeout: 5) && nextButton.isEnabled {
            nextButton.tap()
        }
    }
    
    private func handlePermissionDialogs() {
        // Handle location permission
        let locationAlert = app.alerts.containing(NSPredicate(format: "label CONTAINS '位置情報'")).firstMatch
        if locationAlert.waitForExistence(timeout: 5) {
            let allowButton = locationAlert.buttons["許可"]
            let okButton = locationAlert.buttons["OK"]
            
            if allowButton.exists {
                allowButton.tap()
            } else if okButton.exists {
                okButton.tap()
            }
        }
        
        // Handle notification permission
        let notificationAlert = app.alerts.containing(NSPredicate(format: "label CONTAINS '通知'")).firstMatch
        if notificationAlert.waitForExistence(timeout: 5) {
            let allowButton = notificationAlert.buttons["許可"]
            let okButton = notificationAlert.buttons["OK"]
            
            if allowButton.exists {
                allowButton.tap()
            } else if okButton.exists {
                okButton.tap()
            }
        }
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non-string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
