# チケット #017: 位置情報・通知設定機能の実装

## 概要
設定画面の「位置情報」「通知設定」セクションを機能させ、ユーザーが詳細な設定を行えるようにする。

## 背景
- 現在の設定画面では表示のみで機能していない
- ユーザーが位置情報の精度や通知の詳細をカスタマイズできない

## 要件
### 位置情報設定
1. **位置情報の精度設定**
   - 高精度モード（バッテリー消費大）
   - バランスモード（標準）
   - 省電力モード（バッテリー優先）

2. **バックグラウンド更新**
   - 更新頻度の設定（1分/3分/5分/10分）
   - バックグラウンド更新のON/OFF

3. **位置情報の権限管理**
   - 現在の権限状態表示
   - 設定アプリへの遷移ボタン

### 通知設定
1. **通知タイミング**
   - デフォルト通知時間の設定（1分前〜10分前）
   - デフォルト通知距離の設定（100m〜1000m）

2. **通知音設定**
   - システム音の選択
   - 音量設定
   - バイブレーションのON/OFF

3. **通知内容**
   - プレビュー表示のON/OFF
   - 通知バナーの表示時間

## 実装詳細

### 変更対象ファイル
1. **SettingsView.swift**
   - 各設定項目をインタラクティブに
   - 設定値の保存・読み込み

2. **SettingsViewModel.swift**
   - UserDefaultsまたはCoreDataでの設定管理
   - LocationManagerとの連携
   - NotificationManagerとの連携

3. **LocationManager.swift**
   - 精度設定の反映
   - バックグラウンド更新頻度の制御

4. **NotificationManager.swift**
   - 通知音の設定
   - 通知タイミングの反映

### データ保存
```swift
// UserDefaultsキー
- "locationAccuracy": String (high/balanced/battery)
- "backgroundUpdateInterval": Int (minutes)
- "backgroundUpdateEnabled": Bool
- "defaultNotificationTime": Int (minutes)
- "defaultNotificationDistance": Double (meters)
- "notificationSound": String
- "vibrationEnabled": Bool
```

## 受け入れ条件
- [ ] 位置情報の精度設定が反映される
- [ ] バックグラウンド更新頻度が設定通りに動作する
- [ ] 通知タイミングの設定がアラート作成時のデフォルト値になる
- [ ] 通知音の設定が実際の通知に反映される
- [ ] 設定が永続化され、アプリ再起動後も保持される

## ステータス: [ ] Not Started / [ ] In Progress / [ ] Completed

## 依存関係
- なし（独立したタスク）

## 見積もり工数
- 12時間