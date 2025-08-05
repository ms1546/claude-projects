# TrainAlert 実装計画書

## 1. 開発フェーズ

### Phase 1: 基盤構築（1週間）
- [ ] Xcodeプロジェクト作成
- [ ] 基本的なプロジェクト構造設定
- [ ] Core Data モデル定義
- [ ] 基本的なナビゲーション実装
- [ ] カラーテーマ・デザインシステム構築

### Phase 2: コア機能実装（2週間）
- [ ] 位置情報サービス実装
- [ ] 駅情報API連携（HeartRails）
- [ ] 通知システム実装
- [ ] アラート管理機能
- [ ] バックグラウンド処理

### Phase 3: AI機能実装（1週間）
- [ ] OpenAI API連携
- [ ] キャラクター別プロンプト実装
- [ ] メッセージキャッシュシステム
- [ ] APIキー管理（Keychain）

### Phase 4: UI/UX実装（1週間）
- [ ] 全画面のUI実装
- [ ] アニメーション追加
- [ ] ダークモード最適化
- [ ] アクセシビリティ対応

### Phase 5: テスト・最適化（1週間）
- [ ] ユニットテスト作成
- [ ] UIテスト作成
- [ ] バッテリー消費最適化
- [ ] パフォーマンスチューニング

### Phase 6: リリース準備（3日）
- [ ] TestFlight準備
- [ ] アプリアイコン・スクリーンショット作成
- [ ] プライバシーポリシー作成
- [ ] 最終動作確認

## 2. 実装優先順位

### 必須機能（MVP）
1. 基本的なアラート機能（位置情報ベース）
2. シンプルな通知
3. 駅検索・選択
4. 最小限のUI

### 追加機能（Phase 2以降）
1. AI通知メッセージ
2. 時刻ベース通知
3. 遅延対応
4. 履歴機能
5. お気に入り機能

## 3. 技術的マイルストーン

### Week 1
```swift
// Core Dataモデル
// LocationManager実装
// 基本的なView構造
```

### Week 2-3
```swift
// HeartRails API Client
// NotificationManager
// BackgroundTaskManager
```

### Week 4
```swift
// OpenAIService
// CharacterStyleManager
// MessageCache
```

### Week 5
```swift
// 全画面実装完了
// アニメーション
// エラーハンドリング
```

## 4. リスク管理

### 技術的リスク
- **バックグラウンド位置情報**: iOS制限への対応
- **バッテリー消費**: 継続的な最適化が必要
- **API制限**: レート制限への対応

### 対策
- 段階的な実装でリスクを分散
- 早期のTestFlight配布でフィードバック収集
- フォールバック機能の実装

## 5. 開発環境セットアップ

### 必要なツール
- Xcode 15.0+
- Swift 5.9
- iOS 16.0+ Simulator
- 実機（iPhone）でのテスト

### 初期設定
1. Bundle Identifier: `com.yourname.TrainAlert`
2. Capabilities:
   - Background Modes (Location updates)
   - Push Notifications
   - Maps

### APIキー取得
1. OpenAI API: https://platform.openai.com/
2. HeartRails: 申請不要（利用規約確認）

## 6. コーディング規約

### 命名規則
- View: `〜View`
- ViewModel: `〜ViewModel`
- Service: `〜Service`
- Manager: `〜Manager`

### アーキテクチャ
- MVVM + Combine
- Dependency Injection
- Protocol-Oriented

## 7. 成果物

### 各フェーズの成果物
- Phase 1: 動作する基本アプリ
- Phase 2: 位置情報通知が機能
- Phase 3: AI通知が動作
- Phase 4: 完成されたUI
- Phase 5: 最適化されたアプリ
- Phase 6: TestFlight配布

### ドキュメント
- 技術仕様書（完成）
- UI設計書（完成）
- APIドキュメント
- 運用マニュアル
