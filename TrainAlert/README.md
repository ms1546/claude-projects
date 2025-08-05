# TrainAlert - 電車寝過ごし防止アプリ

## 概要
電車での寝過ごしを防止するiOSアプリケーション。GPS位置情報と時刻情報を組み合わせて、降車駅に近づいたら通知を送信します。

## 主な機能
- GPS位置情報による降車駅接近通知
- 時刻ベースの通知設定
- 遅延対応
- プッシュ通知とバイブレーション

## 技術スタック
- Swift 5.9
- SwiftUI
- iOS 16.0+
- Core Location
- UserNotifications
- HeartRails Express API

## プロジェクト構造
```
TrainAlert/
├── Models/         # データモデル
├── Views/          # SwiftUIビュー
├── ViewModels/     # ビューモデル
├── Services/       # APIサービス、位置情報サービス
├── Resources/      # アセット、設定ファイル
└── Utilities/      # ユーティリティ関数
```

## セットアップ
1. Xcode 15でプロジェクトを開く
2. Bundle Identifierを設定
3. Signing & Capabilitiesで必要な権限を追加
   - Location Services
   - Push Notifications
   - Background Modes

## TestFlight配布
趣味プロジェクトとしてTestFlightで配布予定