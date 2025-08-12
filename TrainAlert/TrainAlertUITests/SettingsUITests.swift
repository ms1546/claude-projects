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
    
    func testSettingsScreenSections() throws {
        navigateToSettings()
        
        // Check for all main sections
        let locationSection = app.staticTexts["位置情報"]
        let notificationSection = app.staticTexts["通知設定"]
        let aiSection = app.staticTexts["AI設定"]
        let appSection = app.staticTexts["アプリ設定"]
        let privacySection = app.staticTexts["プライバシー"]
        let infoSection = app.staticTexts["情報"]
        
        XCTAssertTrue(locationSection.waitForExistence(timeout: 5))
        XCTAssertTrue(notificationSection.exists)
        XCTAssertTrue(aiSection.exists)
        XCTAssertTrue(appSection.exists)
        XCTAssertTrue(privacySection.exists)
        XCTAssertTrue(infoSection.exists)
    }
    
    // MARK: - Location Settings Tests
    
    func testLocationPermissionRequest() throws {
        navigateToSettings()
        
        // Find location permission cell
        let locationPermissionCell = app.cells.containing(.staticText, identifier: "位置情報の利用").firstMatch
        XCTAssertTrue(locationPermissionCell.waitForExistence(timeout: 5))
        
        // Check if status is shown
        let statusText = locationPermissionCell.staticTexts.element(boundBy: 1)
        XCTAssertTrue(statusText.exists)
        
        // If permission not determined, tap to request
        if statusText.label == "タップして許可" {
            locationPermissionCell.tap()
            
            // Handle system permission dialog if it appears
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allowButton = springboard.buttons["アプリ使用中は許可"]
            if allowButton.waitForExistence(timeout: 10) {
                allowButton.tap()
            }
        }
    }
    
    func testLocationAccuracySettings() throws {
        navigateToSettings()
        
        // Find and tap location accuracy picker
        let accuracyCell = app.cells.containing(.staticText, identifier: "位置情報の精度").firstMatch
        XCTAssertTrue(accuracyCell.waitForExistence(timeout: 5))
        
        accuracyCell.tap()
        
        // Test picker options
        let accuracyPicker = app.pickers.firstMatch
        if accuracyPicker.waitForExistence(timeout: 2) {
            // iOS picker interaction
            let options = ["高精度", "バランス", "省電力"]
            for option in options {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: option)
                    sleep(1) // Allow time for UI update
                }
            }
        }
    }
    
    func testBackgroundUpdateToggle() throws {
        navigateToSettings()
        
        // Find and test background update toggle
        let backgroundToggle = app.cells.containing(.staticText, identifier: "バックグラウンド更新").switches.firstMatch
        XCTAssertTrue(backgroundToggle.waitForExistence(timeout: 5))
        
        let initialValue = backgroundToggle.value as? String == "1"
        backgroundToggle.tap()
        let newValue = backgroundToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
        
        // If enabled, check for update interval picker
        if newValue {
            let intervalCell = app.cells.containing(.staticText, identifier: "更新頻度").firstMatch
            XCTAssertTrue(intervalCell.exists)
        }
    }
    
    func testBackgroundUpdateInterval() throws {
        navigateToSettings()
        
        // Enable background updates first
        let backgroundToggle = app.cells.containing(.staticText, identifier: "バックグラウンド更新").switches.firstMatch
        if backgroundToggle.waitForExistence(timeout: 5) {
            if backgroundToggle.value as? String != "1" {
                backgroundToggle.tap()
            }
        }
        
        // Test update interval picker
        let intervalCell = app.cells.containing(.staticText, identifier: "更新頻度").firstMatch
        if intervalCell.waitForExistence(timeout: 5) {
            intervalCell.tap()
            
            let intervalPicker = app.pickers.firstMatch
            if intervalPicker.waitForExistence(timeout: 2) {
                let intervals = ["1分間隔", "3分間隔", "5分間隔", "10分間隔"]
                for interval in intervals {
                    let pickerWheel = app.pickerWheels.firstMatch
                    if pickerWheel.exists {
                        pickerWheel.adjust(toPickerWheelValue: interval)
                        sleep(1)
                    }
                }
            }
        }
    }
    
    // MARK: - Notification Settings Tests
    
    func testNotificationPermissionRequest() throws {
        navigateToSettings()
        
        // Find notification permission cell
        let notificationPermissionCell = app.cells.containing(.staticText, identifier: "通知の許可").firstMatch
        XCTAssertTrue(notificationPermissionCell.waitForExistence(timeout: 5))
        
        // Check status
        let statusText = notificationPermissionCell.staticTexts.element(boundBy: 1)
        XCTAssertTrue(statusText.exists)
        
        // If not determined, request permission
        if statusText.label == "タップして許可" {
            notificationPermissionCell.tap()
            
            // Handle system permission dialog
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allowButton = springboard.buttons["許可"]
            if allowButton.waitForExistence(timeout: 10) {
                allowButton.tap()
            }
        }
    }
    
    func testDefaultNotificationTime() throws {
        navigateToSettings()
        
        // Find and test notification time picker
        let timeCell = app.cells.containing(.staticText, identifier: "デフォルト通知時間").firstMatch
        XCTAssertTrue(timeCell.waitForExistence(timeout: 5))
        
        timeCell.tap()
        
        let timePicker = app.pickers.firstMatch
        if timePicker.waitForExistence(timeout: 2) {
            let times = ["1分前", "2分前", "3分前", "5分前", "10分前", "15分前", "20分前", "30分前"]
            for time in times {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: time)
                    sleep(1)
                }
            }
        }
    }
    
    func testDefaultNotificationDistance() throws {
        navigateToSettings()
        
        // Find and test notification distance picker
        let distanceCell = app.cells.containing(.staticText, identifier: "デフォルト通知距離").firstMatch
        XCTAssertTrue(distanceCell.waitForExistence(timeout: 5))
        
        distanceCell.tap()
        
        let distancePicker = app.pickers.firstMatch
        if distancePicker.waitForExistence(timeout: 2) {
            let distances = ["100m", "200m", "300m", "500m", "800m", "1.0km", "1.5km", "2.0km"]
            for distance in distances {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: distance)
                    sleep(1)
                }
            }
        }
    }
    
    func testNotificationSound() throws {
        navigateToSettings()
        
        // Find and test notification sound picker
        let soundCell = app.cells.containing(.staticText, identifier: "通知音").firstMatch
        XCTAssertTrue(soundCell.waitForExistence(timeout: 5))
        
        soundCell.tap()
        
        let soundPicker = app.pickers.firstMatch
        if soundPicker.waitForExistence(timeout: 2) {
            let sounds = ["デフォルト", "チャイム", "ベル", "やさしい", "緊急"]
            for sound in sounds {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: sound)
                    sleep(1)
                }
            }
        }
    }
    
    func testVibrationToggle() throws {
        navigateToSettings()
        
        // Find and test vibration toggle
        let vibrationToggle = app.cells.containing(.staticText, identifier: "バイブレーション").switches.firstMatch
        XCTAssertTrue(vibrationToggle.waitForExistence(timeout: 5))
        
        let initialValue = vibrationToggle.value as? String == "1"
        vibrationToggle.tap()
        let newValue = vibrationToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    func testNotificationPreviewToggle() throws {
        navigateToSettings()
        
        // Find and test notification preview toggle
        let previewToggle = app.cells.containing(.staticText, identifier: "通知プレビュー").switches.firstMatch
        XCTAssertTrue(previewToggle.waitForExistence(timeout: 5))
        
        let initialValue = previewToggle.value as? String == "1"
        previewToggle.tap()
        let newValue = previewToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    func testSnoozeInterval() throws {
        navigateToSettings()
        
        // Find and test snooze interval picker
        let snoozeCell = app.cells.containing(.staticText, identifier: "スヌーズ間隔").firstMatch
        XCTAssertTrue(snoozeCell.waitForExistence(timeout: 5))
        
        snoozeCell.tap()
        
        let snoozePicker = app.pickers.firstMatch
        if snoozePicker.waitForExistence(timeout: 2) {
            let intervals = ["1分", "2分", "3分", "5分", "10分", "15分"]
            for interval in intervals {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: interval)
                    sleep(1)
                }
            }
        }
    }
    
    // MARK: - AI Settings Tests
    
    func testAIGeneratedMessagesToggle() throws {
        navigateToSettings()
        
        // Find and test AI messages toggle
        let aiToggle = app.cells.containing(.staticText, identifier: "AI生成メッセージ").switches.firstMatch
        XCTAssertTrue(aiToggle.waitForExistence(timeout: 5))
        
        let initialValue = aiToggle.value as? String == "1"
        aiToggle.tap()
        let newValue = aiToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
        
        // Check if character style picker appears when enabled
        if newValue {
            let characterCell = app.cells.containing(.staticText, identifier: "キャラクタースタイル").firstMatch
            XCTAssertTrue(characterCell.exists)
        }
    }
    
    func testCharacterStyleSelection() throws {
        navigateToSettings()
        
        // Enable AI messages first
        let aiToggle = app.cells.containing(.staticText, identifier: "AI生成メッセージ").switches.firstMatch
        if aiToggle.waitForExistence(timeout: 5) {
            if aiToggle.value as? String != "1" {
                aiToggle.tap()
            }
        }
        
        // Test character style picker
        let characterCell = app.cells.containing(.staticText, identifier: "キャラクタースタイル").firstMatch
        if characterCell.waitForExistence(timeout: 5) {
            characterCell.tap()
            
            let characterPicker = app.pickers.firstMatch
            if characterPicker.waitForExistence(timeout: 2) {
                let styles = ["ギャル系", "執事系", "関西弁系", "ツンデレ系", "体育会系", "癒し系"]
                for style in styles {
                    let pickerWheel = app.pickerWheels.firstMatch
                    if pickerWheel.exists {
                        pickerWheel.adjust(toPickerWheelValue: style)
                        sleep(1)
                    }
                }
            }
        }
    }
    
    func testAPIKeyNavigation() throws {
        navigateToSettings()
        
        // Enable AI messages first
        let aiToggle = app.cells.containing(.staticText, identifier: "AI生成メッセージ").switches.firstMatch
        if aiToggle.waitForExistence(timeout: 5) {
            if aiToggle.value as? String != "1" {
                aiToggle.tap()
            }
        }
        
        // Navigate to API key screen
        let apiKeyCell = app.cells.containing(.staticText, identifier: "OpenAI APIキー").firstMatch
        if apiKeyCell.waitForExistence(timeout: 5) {
            apiKeyCell.tap()
            
            // Verify API key screen is shown
            let apiKeyNavBar = app.navigationBars["APIキー設定"]
            XCTAssertTrue(apiKeyNavBar.waitForExistence(timeout: 5))
            
            // Check for key elements
            let apiKeyField = app.secureTextFields.firstMatch
            XCTAssertTrue(apiKeyField.exists)
            
            let validateButton = app.buttons["APIキーを検証"]
            XCTAssertTrue(validateButton.exists)
            
            // Go back
            let backButton = apiKeyNavBar.buttons["設定"]
            if backButton.exists {
                backButton.tap()
            }
        }
    }
    
    // MARK: - App Settings Tests
    
    func testLanguageSelection() throws {
        navigateToSettings()
        
        // Find and test language picker
        let languageCell = app.cells.containing(.staticText, identifier: "言語").firstMatch
        XCTAssertTrue(languageCell.waitForExistence(timeout: 5))
        
        languageCell.tap()
        
        let languagePicker = app.pickers.firstMatch
        if languagePicker.waitForExistence(timeout: 2) {
            let languages = ["日本語", "English"]
            for language in languages {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: language)
                    sleep(1)
                }
            }
        }
    }
    
    func testDistanceUnitSelection() throws {
        navigateToSettings()
        
        // Find and test distance unit picker
        let unitCell = app.cells.containing(.staticText, identifier: "距離単位").firstMatch
        XCTAssertTrue(unitCell.waitForExistence(timeout: 5))
        
        unitCell.tap()
        
        let unitPicker = app.pickers.firstMatch
        if unitPicker.waitForExistence(timeout: 2) {
            let units = ["メートル法 (km/m)", "ヤード・ポンド法 (mi/ft)"]
            for unit in units {
                let pickerWheel = app.pickerWheels.firstMatch
                if pickerWheel.exists {
                    pickerWheel.adjust(toPickerWheelValue: unit)
                    sleep(1)
                }
            }
        }
    }
    
    func testTimeFormatToggle() throws {
        navigateToSettings()
        
        // Find and test time format toggle
        let timeFormatToggle = app.cells.containing(.staticText, identifier: "24時間表示").switches.firstMatch
        XCTAssertTrue(timeFormatToggle.waitForExistence(timeout: 5))
        
        let initialValue = timeFormatToggle.value as? String == "1"
        timeFormatToggle.tap()
        let newValue = timeFormatToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    // MARK: - Privacy Settings Tests
    
    func testDataCollectionToggle() throws {
        navigateToSettings()
        
        // Scroll to privacy section
        let collectionView = app.scrollViews.firstMatch
        if !collectionView.exists {
            let table = app.tables.firstMatch
            table.swipeUp()
        }
        
        // Find and test data collection toggle
        let dataToggle = app.cells.containing(.staticText, identifier: "使用状況データの収集").switches.firstMatch
        XCTAssertTrue(dataToggle.waitForExistence(timeout: 5))
        
        let initialValue = dataToggle.value as? String == "1"
        dataToggle.tap()
        let newValue = dataToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    func testCrashReportsToggle() throws {
        navigateToSettings()
        
        // Scroll to privacy section
        let table = app.tables.firstMatch
        table.swipeUp()
        
        // Find and test crash reports toggle
        let crashToggle = app.cells.containing(.staticText, identifier: "クラッシュレポートの送信").switches.firstMatch
        XCTAssertTrue(crashToggle.waitForExistence(timeout: 5))
        
        let initialValue = crashToggle.value as? String == "1"
        crashToggle.tap()
        let newValue = crashToggle.value as? String == "1"
        XCTAssertNotEqual(initialValue, newValue)
    }
    
    // MARK: - Settings Reset Test
    
    func testResetAllSettings() throws {
        navigateToSettings()
        
        // Scroll to bottom
        let table = app.tables.firstMatch
        table.swipeUp()
        
        // Find and tap reset button
        let resetButton = app.buttons["すべての設定をリセット"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
        
        resetButton.tap()
        
        // Handle confirmation dialog
        let confirmationDialog = app.sheets["設定をリセット"]
        XCTAssertTrue(confirmationDialog.waitForExistence(timeout: 5))
        
        // Test cancel
        let cancelButton = confirmationDialog.buttons["キャンセル"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()
        
        // Verify dialog is dismissed
        XCTAssertFalse(confirmationDialog.exists)
        
        // Tap reset again and confirm
        resetButton.tap()
        
        if confirmationDialog.waitForExistence(timeout: 5) {
            let resetConfirmButton = confirmationDialog.buttons["リセット"]
            XCTAssertTrue(resetConfirmButton.exists)
            resetConfirmButton.tap()
        }
    }
    
    // MARK: - Performance Tests
    
    func testSettingsScreenLoadPerformance() throws {
        measure {
            // Navigate to settings
            let settingsTab = app.tabBars.buttons["設定"]
            if settingsTab.waitForExistence(timeout: 5) {
                settingsTab.tap()
            }
            
            // Wait for screen to load
            let settingsTitle = app.navigationBars["設定"]
            _ = settingsTitle.waitForExistence(timeout: 5)
            
            // Return to home
            let homeTab = app.tabBars.buttons["ホーム"]
            if homeTab.exists {
                homeTab.tap()
            }
        }
    }
    
    func testSettingsScrollPerformance() throws {
        navigateToSettings()
        
        measure {
            let table = app.tables.firstMatch
            // Scroll down
            table.swipeUp()
            table.swipeUp()
            // Scroll back up
            table.swipeDown()
            table.swipeDown()
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

