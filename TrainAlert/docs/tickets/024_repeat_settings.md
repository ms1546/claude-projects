# チケット #024: 繰り返し設定機能

## 概要
毎日同じ電車に乗る場合の繰り返し通知機能を実装する。

## 要件
### 繰り返しパターン
1. **毎日**
   - 毎日同じ時刻の電車で通知

2. **平日のみ**
   - 月〜金曜日のみ通知
   - 祝日は除外（将来対応）

3. **週末のみ**
   - 土日のみ通知

## 技術仕様
### データモデル
```swift
extension TimetableAlert {
    @NSManaged var isRepeating: Bool
    @NSManaged var repeatPattern: String // "daily", "weekdays", "weekends"
    @NSManaged var repeatDays: [Int]? // 0=日曜...6=土曜
}
```

### 通知スケジューリング
- UNCalendarNotificationTriggerで繰り返し設定
- 曜日指定での通知

## 実装タスク
- [ ] 繰り返し設定UI
- [ ] Core Dataモデル拡張
- [ ] 繰り返し通知のスケジューリング
- [ ] 次回通知時刻の計算ロジック
- [ ] 繰り返し設定の編集機能
- [ ] 祝日カレンダー対応（将来）

## 受け入れ条件
- [ ] 繰り返しパターンを選択できる
- [ ] 設定した曜日に通知が来る
- [ ] 繰り返し設定を解除できる
- [ ] 次回通知予定が表示される

## ステータス: [ ] Not Started / [ ] In Progress / [ ] Completed

## 見積もり工数
8時間

## 依存関係
- チケット#022（基本実装）
