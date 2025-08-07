# Ticket #007: OpenAI API連携

## 概要
ChatGPT APIを使用したAI通知メッセージ生成機能の実装

## 優先度: Medium
## 見積もり: 5h

## タスク
- [x] OpenAIService作成
- [x] APIキー管理
  - [x] Keychain保存
  - [ ] 設定画面でのキー入力 (別チケットで実装予定)
  - [x] キー検証
- [x] キャラクタースタイル定義
  - [x] ギャル系プロンプト
  - [x] 執事系プロンプト
  - [x] 関西弁系プロンプト
  - [x] ツンデレ系プロンプト
  - [x] 体育会系プロンプト
  - [x] 癒し系プロンプト
- [x] メッセージ生成ロジック
  - [x] プロンプトテンプレート
  - [x] トークン制限設定
  - [x] Temperature調整
- [x] キャッシングシステム
  - [x] 生成済みメッセージ保存
  - [x] キャッシュ有効期限
- [x] フォールバック対応
  - [x] API失敗時のデフォルトメッセージ
  - [x] オフライン時の対応
- [x] レート制限対応

## 受け入れ条件
- 各キャラクターで適切なメッセージ生成
- API使用量の最適化
- エラー時も通知は配信される

## 依存関係
- #005完了後に着手

## ステータス: [x] Completed

## 実装詳細

### 完了した機能
1. **OpenAIClient作成** (`Services/OpenAIClient.swift`)
   - ChatGPT API連携
   - リトライ機能付きAPI呼び出し
   - レート制限対応
   - ネットワーク監視
   - APIキーValidation

2. **CharacterStyle拡張** (`Models/CharacterStyle.swift`)
   - 6つのキャラクタースタイル実装
   - 各スタイルの詳細なシステムプロンプト
   - フォールバックメッセージシステム
   - Codable対応

3. **NotificationManager更新** (`Services/NotificationManager.swift`)
   - OpenAI統合
   - フォールバック機能
   - エラーハンドリング強化

4. **テスト実装**
   - OpenAIClientTests.swift
   - CharacterStyleTests.swift
   - 包括的なユニットテスト

### 技術仕様
- **API**: OpenAI ChatGPT 3.5-turbo
- **キャッシュ**: UserDefaults + 30日間有効期限
- **レート制限**: 20リクエスト/分、1秒間隔
- **リトライ**: 指数バックオフで3回まで
- **フォールバック**: 6キャラクター × 3メッセージタイプ

### セキュリティ
- APIキーはKeychainで安全に保存
- ネットワーク接続確認
- 入力値検証

## 次のステップ
- 設定画面でのAPIキー入力UI実装（別チケット）
- 実際のテスト環境での動作確認
