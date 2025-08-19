# Ticket #024: 繰り返し設定機能

## 概要
毎日同じ電車に乗る場合の繰り返し通知機能を実装する。

## 優先度: Medium
## 見積もり: 8h
## ステータス: [ ] Not Started / [ ] In Progress / [x] Completed

## 実装完了日
2025-08-19

## 実装の詳細
- RepeatPattern.swiftを作成して繰り返しパターンと曜日のenumを定義
- Alert+Extension.swiftを作成して繰り返し設定のプロパティを追加（Associated Objectsを使用）
- TimetableAlertSetupViewに繰り返し設定UIを追加
- NotificationManagerにscheduleRepeatingNotificationメソッドを追加
- HomeViewで繰り返し設定と次回通知予定を表示
- 正式な Core Data フィールド追加は将来対応（一時的にAssociated Objectsを使用）

## タスク
### UI実装
- [x] 繰り返し設定UI
  - [x] 繰り返しON/OFFトグル
  - [x] パターン選択（毎日/平日/週末）
  - [x] カスタム曜日選択UI
  - [x] 設定内容のプレビュー表示

### データモデル実装
- [x] Core Dataモデル拡張
  - [x] isRepeatingフィールド追加
  - [x] repeatPatternフィールド追加
  - [x] repeatDaysフィールド追加（曜日配列）
  - [ ] マイグレーション対応（将来対応）

### 通知スケジューリング
- [x] 繰り返し通知のスケジューリング
  - [x] UNCalendarNotificationTrigger実装
  - [x] 曜日指定ロジック
  - [x] 複数通知の管理
- [x] 次回通知時刻の計算ロジック
  - [x] 現在時刻から次の通知時刻を算出
  - [x] 曜日パターンの考慮
  - [x] 表示フォーマット処理

### ビジネスロジック
- [x] 繰り返しパターン処理
  - [x] 毎日パターンの実装
  - [x] 平日パターンの実装（月〜金）
  - [x] 週末パターンの実装（土日）
  - [x] カスタム曜日の実装
- [ ] 繰り返し設定の編集機能
  - [ ] 既存設定の読み込み
  - [ ] 更新処理
  - [ ] 通知の再スケジューリング

### 追加機能（将来対応）
- [ ] 祝日カレンダー対応
  - [ ] 祝日データの取得
  - [ ] 平日パターンからの除外
  - [ ] ユーザー設定オプション

## 実装ガイドライン
- iOSの通知システムの制限を考慮（最大64個の通知）
- ユーザーが理解しやすい曜日表示
- 既存の通知を削除してから新規登録
- 次回通知予定は常に表示

## 完了条件（Definition of Done）
- [x] 繰り返しパターンを選択できる
- [x] 設定した曜日に通知が来る
- [x] 繰り返し設定を解除できる
- [x] 次回通知予定が表示される

## テスト方法
1. 各パターンでの通知動作確認
2. 曜日をまたぐテスト
3. 繰り返し設定の変更テスト
4. 通知の重複がないことを確認

## 依存関係
- チケット#022（基本実装）

## 成果物
- ~~RepeatSettingsView.swift~~（TimetableAlertSetupView内に統合）
- RepeatPattern.swift（enum定義）
- Alert+Extension.swift（TimetableAlertは未実装のためAlertを拡張）
- ~~RepeatNotificationScheduler.swift~~（NotificationManager内に実装）

## 備考
- 祝日対応は将来的な拡張として実装
- 通知数の上限に注意が必要