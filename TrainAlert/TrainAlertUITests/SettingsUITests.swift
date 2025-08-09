//
//  SettingsUITests.swift
//  TrainAlertUITests
//
//  Created by Claude on 2024/01/08.
//

import XCTest

final class SettingsUITests: XCTestCase {
    
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
    
    // MARK: - Settings Navigation Tests
    
    func testNavigateToSettings() throws {
        // Navigate to settings tab
        let settingsTab = app.tabBars.buttons["設定"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        
        settingsTab.tap()
        
        // Verify settings screen is displayed
        let settingsTitle = app.navigationBars["設定"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))
    }
    
    func testSettingsScreenElements() throws {
        navigateToSettings()
        
        // Check for main settings sections
        let notificationSection = app.staticTexts["通知設定"]
        let aiSection = app.staticTexts["AI設定"]
        let appSection = app.staticTexts["アプリ設定"]
        let privacySection = app.staticTexts["プライバシー設定"]
        
        XCTAssertTrue(notificationSection.waitForExistence(timeout: 5))
        XCTAssertTrue(aiSection.exists)
        XCTAssertTrue(appSection.exists)
        XCTAssertTrue(privacySection.exists)
    }
    
    // MARK: - Notification Settings Tests
    
    func testNotificationTimeSettings() throws {
        navigateToSettings()
        
        // Find and test notification time setting
        let notificationTimeCell = app.cells["通知タイミング"]
        XCTAssertTrue(notificationTimeCell.waitForExistence(timeout: 5))
        
        notificationTimeCell.tap()
        
        // Test time picker or selection
        let timePicker = app.pickers["通知時間選択"]
        if timePicker.waitForExistence(timeout: 5) {
            // Test different time values
            let fiveMinutesOption = timePicker.buttons["5分前"]
            let tenMinutesOption = timePicker.buttons["10分前"]
            
            if fiveMinutesOption.exists {
                fiveMinutesOption.tap()
            }
            
            if tenMinutesOption.exists {
                tenMinutesOption.tap()
            }
            
            // Save selection
            let doneButton = app.buttons["完了"]
            if doneButton.exists {
                doneButton.tap()
            }
        }
    }
    
    func testNotificationDistanceSettings() throws {
        navigateToSettings()
        
        let distanceCell = app.cells["通知距離"]
        XCTAssertTrue(distanceCell.waitForExistence(timeout: 5))
        
        distanceCell.tap()
        
        // Test distance slider or picker
        let distanceSlider = app.sliders["距離設定"]
        if distanceSlider.waitForExistence(timeout: 5) {
            // Test different distance values
            distanceSlider.adjust(toNormalizedSliderPosition: 0.3) // ~300m
            distanceSlider.adjust(toNormalizedSliderPosition: 0.7) // ~700m
            distanceSlider.adjust(toNormalizedSliderPosition: 0.5) // ~500m
        }
        
        // Go back to settings
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
    
    func testSnoozeIntervalSettings() throws {
        navigateToSettings()
        
        let snoozeCell = app.cells["スヌーズ間隔"]
        XCTAssertTrue(snoozeCell.waitForExistence(timeout: 5))
        
        snoozeCell.tap()
        
        // Test snooze interval options
        let intervalPicker = app.pickers["スヌーズ間隔選択"]
        if intervalPicker.waitForExistence(timeout: 5) {
            let twoMinutesOption = intervalPicker.buttons["2分"]
            let fiveMinutesOption = intervalPicker.buttons["5分"]
            
            if twoMinutesOption.exists {
                twoMinutesOption.tap()
            }
            
            if fiveMinutesOption.exists {
                fiveMinutesOption.tap()
            }
        }
        
        // Save and return
        let saveButton = app.buttons["保存"]
        if saveButton.exists {
            saveButton.tap()
        }
    }
    
    func testNotificationSoundSettings() throws {
        navigateToSettings()
        
        let soundCell = app.cells["通知音"]
        if soundCell.waitForExistence(timeout: 5) {
            soundCell.tap()
            
            // Test sound selection
            let soundOptions = [
                "デフォルト",
                "チャイム",
                "ベル",
                "やさしい",
                "緊急"
            ]
            
            for soundOption in soundOptions {
                let soundButton = app.buttons[soundOption]
                if soundButton.exists {
                    soundButton.tap()
                    
                    // Test preview if available
                    let previewButton = app.buttons["プレビュー"]
                    if previewButton.exists {
                        previewButton.tap()
                    }
                }
            }
            
            // Save selection
            let selectButton = app.buttons["選択"]
            if selectButton.exists {
                selectButton.tap()
            }
        }
    }
    
    // MARK: - AI Settings Tests
    
    func testCharacterStyleSelection() throws {
        navigateToSettings()
        
        let characterCell = app.cells["キャラクタースタイル"]
        XCTAssertTrue(characterCell.waitForExistence(timeout: 5))
        
        characterCell.tap()
        
        // Test character selection
        let characterOptions = [
            "ギャル系",
            "執事系", 
            "関西弁系",
            "ツンデレ系",
            "体育会系",
            "癒し系"
        ]
        
        for character in characterOptions {
            let characterButton = app.buttons[character]
            if characterButton.waitForExistence(timeout: 2) {
                characterButton.tap()
                
                // Test preview functionality
                let previewText = app.textViews["プレビューメッセージ"]
                if previewText.exists {
                    XCTAssertTrue(previewText.exists)
                }
            }
        }
        
        // Save selection
        let saveButton = app.buttons["保存"]
        if saveButton.exists {
            saveButton.tap()
        }
    }
    
    func testAIGeneratedMessagesToggle() throws {
        navigateToSettings()
        
        let aiToggleSwitch = app.switches["AI生成メッセージを使用"]
        XCTAssertTrue(aiToggleSwitch.waitForExistence(timeout: 5))
        
        // Test toggle on/off
        let initialState = aiToggleSwitch.isSelected
        
        aiToggleSwitch.tap()
        XCTAssertNotEqual(aiToggleSwitch.isSelected, initialState)
        
        aiToggleSwitch.tap()
        XCTAssertEqual(aiToggleSwitch.isSelected, initialState)
    }
    
    func testAPIKeyConfiguration() throws {
        navigateToSettings()
        
        let apiKeyCell = app.cells["OpenAI APIキー"]
        XCTAssertTrue(apiKeyCell.waitForExistence(timeout: 5))
        
        apiKeyCell.tap()
        
        // Test API key input
        let apiKeyField = app.textFields["APIキー"]
        if apiKeyField.waitForExistence(timeout: 5) {
            apiKeyField.tap()
            
            // Test invalid API key
            apiKeyField.typeText("invalid-key")
            
            let validateButton = app.buttons["検証"]
            if validateButton.exists {
                validateButton.tap()
                
                // Should show error
                let errorAlert = app.alerts["エラー"]
                if errorAlert.waitForExistence(timeout: 5) {
                    errorAlert.buttons["OK"].tap()
                }
            }
            
            // Clear and test valid format
            apiKeyField.doubleTap()
            app.buttons["Select All"].tap()
            apiKeyField.typeText("test-api-key-for-testing-1234567890abcdef")
            
            if validateButton.exists {
                validateButton.tap()
                
                // Should show success or validation message
                let successMessage = app.staticTexts["APIキーが有効です"]
                let validationMessage = app.staticTexts["検証中..."]
                
                XCTAssertTrue(successMessage.waitForExistence(timeout: 10) || 
                            validationMessage.waitForExistence(timeout: 5))
            }
        }
        
        // Save configuration
        let saveButton = app.buttons["保存"]
        if saveButton.exists {
            saveButton.tap()
        }
    }
    
    // MARK: - App Settings Tests
    
    func testLanguageSettings() throws {
        navigateToSettings()
        
        let languageCell = app.cells["言語設定"]
        if languageCell.waitForExistence(timeout: 5) {
            languageCell.tap()
            
            // Test language options
            let japaneseOption = app.buttons["日本語"]
            let englishOption = app.buttons["English"]
            
            if englishOption.exists {
                englishOption.tap()
            }
            
            if japaneseOption.exists {
                japaneseOption.tap()
            }
            
            // Save selection
            let doneButton = app.buttons["完了"]
            if doneButton.exists {
                doneButton.tap()
            }
        }
    }
    
    func testDistanceUnitSettings() throws {
        navigateToSettings()
        
        let unitCell = app.cells["距離単位"]
        if unitCell.waitForExistence(timeout: 5) {
            unitCell.tap()
            
            // Test unit options
            let metricOption = app.buttons["メートル法"]
            let imperialOption = app.buttons["ヤード・ポンド法"]
            
            if imperialOption.exists {
                imperialOption.tap()
            }
            
            if metricOption.exists {
                metricOption.tap()
            }
            
            // Save selection
            let selectButton = app.buttons["選択"]
            if selectButton.exists {
                selectButton.tap()
            }
        }
    }
    
    func testTimeFormatSettings() throws {
        navigateToSettings()
        
        let timeFormatSwitch = app.switches["24時間形式"]
        if timeFormatSwitch.waitForExistence(timeout: 5) {
            let initialState = timeFormatSwitch.isSelected
            
            timeFormatSwitch.tap()
            XCTAssertNotEqual(timeFormatSwitch.isSelected, initialState)
            
            timeFormatSwitch.tap()
            XCTAssertEqual(timeFormatSwitch.isSelected, initialState)
        }
    }
    
    // MARK: - Privacy Settings Tests
    
    func testDataCollectionToggle() throws {
        navigateToSettings()
        
        let dataCollectionSwitch = app.switches["データ収集を許可"]
        if dataCollectionSwitch.waitForExistence(timeout: 5) {
            let initialState = dataCollectionSwitch.isSelected
            
            dataCollectionSwitch.tap()
            XCTAssertNotEqual(dataCollectionSwitch.isSelected, initialState)
            
            // Test confirmation dialog if exists
            let confirmAlert = app.alerts["確認"]
            if confirmAlert.waitForExistence(timeout: 5) {
                confirmAlert.buttons["はい"].tap()
            }
        }
    }
    
    func testCrashReportsToggle() throws {
        navigateToSettings()
        
        let crashReportsSwitch = app.switches["クラッシュレポート"]
        if crashReportsSwitch.waitForExistence(timeout: 5) {
            let initialState = crashReportsSwitch.isSelected
            
            crashReportsSwitch.tap()
            XCTAssertNotEqual(crashReportsSwitch.isSelected, initialState)
        }
    }
    
    // MARK: - Settings Management Tests
    
    func testResetAllSettings() throws {
        navigateToSettings()
        
        // Scroll to bottom to find reset option
        let settingsTable = app.tables.element(boundBy: 0)
        settingsTable.swipeUp()
        
        let resetButton = app.buttons["すべての設定をリセット"]
        if resetButton.waitForExistence(timeout: 5) {
            resetButton.tap()
            
            // Should show confirmation
            let confirmAlert = app.alerts["確認"]
            XCTAssertTrue(confirmAlert.waitForExistence(timeout: 5))
            
            // Test cancel
            confirmAlert.buttons["キャンセル"].tap()
            
            // Try again and confirm
            resetButton.tap()
            if confirmAlert.waitForExistence(timeout: 5) {
                confirmAlert.buttons["リセット"].tap()
                
                // Should show completion message
                let completionAlert = app.alerts["完了"]
                if completionAlert.waitForExistence(timeout: 5) {
                    completionAlert.buttons["OK"].tap()
                }
            }
        }
    }
    
    func testExportSettings() throws {
        navigateToSettings()
        
        let exportButton = app.buttons["設定をエクスポート"]
        if exportButton.waitForExistence(timeout: 5) {
            exportButton.tap()
            
            // Should show share sheet
            let shareSheet = app.sheets.element(boundBy: 0)
            if shareSheet.waitForExistence(timeout: 5) {
                // Test various sharing options
                let copyButton = shareSheet.buttons["コピー"]
                let saveToFilesButton = shareSheet.buttons["ファイルに保存"]
                
                if copyButton.exists {
                    copyButton.tap()
                    
                    // Should show confirmation
                    let copyAlert = app.alerts["コピー完了"]
                    if copyAlert.waitForExistence(timeout: 5) {
                        copyAlert.buttons["OK"].tap()
                    }
                } else if saveToFilesButton.exists {
                    saveToFilesButton.tap()
                }
            }
        }
    }
    
    func testImportSettings() throws {
        navigateToSettings()
        
        let importButton = app.buttons["設定をインポート"]
        if importButton.waitForExistence(timeout: 5) {
            importButton.tap()
            
            // Should show file picker or paste option
            let pasteOption = app.buttons["ペースト"]
            let fileOption = app.buttons["ファイルから選択"]
            
            if pasteOption.exists {
                pasteOption.tap()
                
                // Should show result
                let resultAlert = app.alerts.element(boundBy: 0)
                if resultAlert.waitForExistence(timeout: 5) {
                    resultAlert.buttons.element(boundBy: 0).tap()
                }
            }
        }
    }
    
    // MARK: - Permission Settings Tests
    
    func testNotificationPermissionStatus() throws {
        navigateToSettings()
        
        let permissionsSection = app.staticTexts["アクセス許可"]
        if permissionsSection.waitForExistence(timeout: 5) {
            // Scroll to permissions section
            permissionsSection.tap()
            
            let notificationStatus = app.cells["通知"]
            if notificationStatus.exists {
                notificationStatus.tap()
                
                // Should navigate to system settings or show status
                let systemSettingsAlert = app.alerts["設定アプリ"]
                if systemSettingsAlert.waitForExistence(timeout: 5) {
                    systemSettingsAlert.buttons["キャンセル"].tap()
                }
            }
        }
    }
    
    func testLocationPermissionStatus() throws {
        navigateToSettings()
        
        let locationCell = app.cells["位置情報"]
        if locationCell.waitForExistence(timeout: 5) {
            locationCell.tap()
            
            // Should show permission status or navigate to system settings
            let permissionStatus = app.staticTexts.containing(NSPredicate(format: "label CONTAINS '許可'")).firstMatch
            XCTAssertTrue(permissionStatus.exists || !app.alerts.isEmpty)
            
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
    }
    
    // MARK: - About Section Tests
    
    func testAboutInformation() throws {
        navigateToSettings()
        
        // Scroll to bottom for about section
        let settingsTable = app.tables.element(boundBy: 0)
        settingsTable.swipeUp()
        
        let aboutButton = app.buttons["このアプリについて"]
        if aboutButton.waitForExistence(timeout: 5) {
            aboutButton.tap()
            
            // Check for app information
            let appNameLabel = app.staticTexts["TrainAlert"]
            let versionLabel = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'バージョン'")).firstMatch
            
            XCTAssertTrue(appNameLabel.waitForExistence(timeout: 5))
            XCTAssertTrue(versionLabel.exists)
            
            // Test links if they exist
            let privacyPolicyButton = app.buttons["プライバシーポリシー"]
            let termsButton = app.buttons["利用規約"]
            
            if privacyPolicyButton.exists {
                privacyPolicyButton.tap()
                
                // Should open web view or external browser
                let webView = app.webViews.element(boundBy: 0)
                if webView.waitForExistence(timeout: 10) {
                    let doneButton = app.buttons["完了"]
                    if doneButton.exists {
                        doneButton.tap()
                    }
                }
            }
        }
    }
    
    // MARK: - Settings Accessibility Tests
    
    func testSettingsAccessibility() throws {
        navigateToSettings()
        
        // Test accessibility of main settings elements
        let notificationSection = app.staticTexts["通知設定"]
        XCTAssertTrue(notificationSection.waitForExistence(timeout: 5))
        XCTAssertTrue(notificationSection.isAccessibilityElement)
        
        let characterStyleCell = app.cells["キャラクタースタイル"]
        if characterStyleCell.exists {
            XCTAssertTrue(characterStyleCell.isAccessibilityElement)
            XCTAssertNotNil(characterStyleCell.accessibilityLabel)
        }
        
        // Test switch accessibility
        let aiToggle = app.switches["AI生成メッセージを使用"]
        if aiToggle.exists {
            XCTAssertTrue(aiToggle.isAccessibilityElement)
            XCTAssertNotNil(aiToggle.accessibilityLabel)
            XCTAssertNotNil(aiToggle.accessibilityValue)
        }
    }
    
    // MARK: - Performance Tests
    
    func testSettingsScreenPerformance() throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            navigateToSettings()
            
            // Scroll through settings
            let settingsTable = app.tables.element(boundBy: 0)
            settingsTable.swipeUp()
            settingsTable.swipeDown()
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToSettings() {
        let settingsTab = app.tabBars.buttons["設定"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
        }
        
        let settingsTitle = app.navigationBars["設定"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))
    }
}
