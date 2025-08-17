# 通知機能のテスト方法

## 現在の実装状態

### ✅ 実装済み
1. **AlertMonitoringService** - アラート監視と通知発火
2. **位置追跡** - LocationManagerで現在位置を取得
3. **通知送信** - キャラクタースタイルでメッセージ生成

### ❌ Xcodeへの追加が必要
- `AlertMonitoringService.swift`をXcodeプロジェクトに追加

## 簡易テスト方法（Xcodeに追加せずにテスト）

### 1. HomeViewに通知テストボタンを追加
```swift
// HomeView.swiftの適当な場所に追加
Button("通知テスト") {
    Task {
        let content = UNMutableNotificationContent()
        content.title = "🚃 もうすぐ新宿駅です！"
        content.body = "駅まであと500mです。ゆっくりと準備してくださいね。"
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

### 2. 距離計算のテスト
現在地から駅までの距離を表示して、距離ベースアラートの動作を確認

## 完全な実装のために必要な作業

1. **AlertMonitoringService.swiftをXcodeに追加**
   - Services/AlertMonitoringService.swift
   - Target: TrainAlert

2. **アプリを実行**
   - 位置情報の許可を「常に許可」に設定
   - アラートを作成（距離ベース推奨）
   - 位置を変更して通知を確認

## 動作確認のポイント

### 距離ベースアラート
- 設定：500m
- テスト：シミュレーターで駅から600m→400mに位置変更
- 期待：500m圏内に入った時点で通知

### 時間ベースアラート（経路から作成）
- 設定：5分前
- テスト：到着時刻の5分前になるまで待つ
- 期待：指定時刻に通知

### 通知メッセージの確認
各キャラクタースタイルで異なるメッセージが表示されることを確認