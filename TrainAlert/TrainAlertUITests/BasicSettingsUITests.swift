//
//  BasicSettingsUITests.swift
//  TrainAlertUITests
//
//  Created by Claude on 2024/01/08.
//

import XCTest

final class BasicSettingsUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        // テストが失敗したら続行しない
        continueAfterFailure = false
        
        // アプリケーションを初期化
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // アプリを終了
        app = nil
    }
    
    // MARK: - 基本的なナビゲーションテスト
    
    func test_01_設定タブへの遷移() throws {
        // タブバーの設定ボタンを探す
        let settingsTab = app.tabBars.buttons["設定"]
        
        // 設定タブが存在することを確認（5秒待機）
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "設定タブが見つかりません")
        
        // 設定タブをタップ
        settingsTab.tap()
        
        // 設定画面のナビゲーションバーが表示されることを確認
        let settingsNavBar = app.navigationBars["設定"]
        XCTAssertTrue(settingsNavBar.waitForExistence(timeout: 5), "設定画面が表示されませんでした")
    }
    
    // MARK: - セクション表示テスト
    
    func test_02_設定画面のセクション表示() throws {
        // まず設定画面に遷移
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()
        
        // 各セクションのヘッダーが存在することを確認
        let sections = [
            "位置情報",
            "通知設定",
            "AI設定",
            "アプリ設定",
            "プライバシー",
            "情報"
        ]
        
        for sectionName in sections {
            let section = app.staticTexts[sectionName]
            XCTAssertTrue(section.exists, "\(sectionName)セクションが見つかりません")
        }
    }
    
    // MARK: - 簡単なトグルテスト
    
    func test_03_バイブレーション設定のONOFF() throws {
        // 設定画面に遷移
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()
        
        // バイブレーション設定を探す
        let vibrationLabel = app.staticTexts["バイブレーション"]
        XCTAssertTrue(vibrationLabel.waitForExistence(timeout: 5), "バイブレーション設定が見つかりません")
        
        // バイブレーション設定のセルを探す（スイッチが含まれるセル）
        let vibrationCell = app.cells.containing(.staticText, identifier: "バイブレーション").firstMatch
        let vibrationSwitch = vibrationCell.switches.firstMatch
        
        XCTAssertTrue(vibrationSwitch.exists, "バイブレーションのスイッチが見つかりません")
        
        // 現在の状態を記録
        let initialValue = vibrationSwitch.value as? String
        
        // スイッチをタップ
        vibrationSwitch.tap()
        
        // 値が変わったことを確認
        let newValue = vibrationSwitch.value as? String
        XCTAssertNotEqual(initialValue, newValue, "スイッチの状態が変わりませんでした")
        
        // もう一度タップして元に戻す
        vibrationSwitch.tap()
        
        // 元の値に戻ったことを確認
        let finalValue = vibrationSwitch.value as? String
        XCTAssertEqual(initialValue, finalValue, "スイッチが元の状態に戻りませんでした")
    }
    
    // MARK: - バージョン情報の表示テスト
    
    func test_04_バージョン情報の表示() throws {
        // 設定画面に遷移
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()
        
        // 情報セクションまでスクロール
        let table = app.tables.firstMatch
        table.swipeUp()
        
        // バージョン表示を探す
        let versionLabel = app.staticTexts["バージョン"]
        XCTAssertTrue(versionLabel.waitForExistence(timeout: 5), "バージョン表示が見つかりません")
        
        // バージョン番号が表示されていることを確認（形式: x.x.x (xxx)）
        let versionCell = app.cells.containing(.staticText, identifier: "バージョン").firstMatch
        let versionTexts = versionCell.staticTexts
        
        // 少なくとも2つのテキスト要素（ラベルと値）があることを確認
        XCTAssertTrue(versionTexts.count >= 2, "バージョン情報が正しく表示されていません")
    }
    
    // MARK: - リセットボタンの存在確認
    
    func test_05_設定リセットボタンの存在確認() throws {
        // 設定画面に遷移
        let settingsTab = app.tabBars.buttons["設定"]
        settingsTab.tap()
        
        // 情報セクションまでスクロール
        let table = app.tables.firstMatch
        table.swipeUp()
        
        // リセットボタンを探す
        let resetButton = app.buttons["すべての設定をリセット"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5), "リセットボタンが見つかりません")
        
        // ボタンがタップ可能であることを確認
        XCTAssertTrue(resetButton.isEnabled, "リセットボタンがタップできません")
        
        // ボタンをタップ
        resetButton.tap()
        
        // 確認ダイアログが表示されることを確認
        let confirmDialog = app.sheets["設定をリセット"]
        XCTAssertTrue(confirmDialog.waitForExistence(timeout: 5), "確認ダイアログが表示されませんでした")
        
        // キャンセルボタンが存在することを確認
        let cancelButton = confirmDialog.buttons["キャンセル"]
        XCTAssertTrue(cancelButton.exists, "キャンセルボタンが見つかりません")
        
        // キャンセルをタップ
        cancelButton.tap()
        
        // ダイアログが閉じられたことを確認
        XCTAssertFalse(confirmDialog.exists, "ダイアログが閉じられませんでした")
    }
}

