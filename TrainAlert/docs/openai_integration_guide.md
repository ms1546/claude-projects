# OpenAI Integration Guide

## 概要

TrainAlertアプリでは、OpenAI ChatGPT APIを使用してキャラクター性のある通知メッセージを動的に生成します。これにより、ユーザーが電車で寝過ごすことを防ぐための魅力的で効果的なアラートを提供します。

## アーキテクチャ

### 主要コンポーネント

1. **OpenAIClient** (`Services/OpenAIClient.swift`)
   - OpenAI APIとの通信を管理
   - レート制限、リトライ、エラーハンドリングを実装

2. **CharacterStyle** (`Models/CharacterStyle.swift`)
   - 6つの異なるキャラクタースタイルを定義
   - システムプロンプトとフォールバックメッセージを提供

3. **NotificationManager** (`Services/NotificationManager.swift`)
   - OpenAIClientを統合して通知メッセージを生成
   - API失敗時のフォールバック機能

## キャラクタースタイル

### 実装済みスタイル

1. **ギャル系 (.gyaru)**
   - 明るくテンション高めの話し方
   - 「〜だよ！」「〜じゃん！」などの口調

2. **執事系 (.butler)**
   - 礼儀正しく品格のある話し方
   - 「〜でございます」「〜いたします」などの敬語

3. **関西弁系 (.kansai)**
   - 親しみやすい関西弁
   - 「〜やで」「〜やん」「あかん」などの表現

4. **ツンデレ系 (.tsundere)**
   - ツンとした態度だが実は優しい
   - 「別に〜」「〜じゃない」などの照れ隠し表現

5. **体育会系 (.sporty)**
   - ハキハキとした元気な話し方
   - 「よし！」「頑張ろう！」「ファイト！」などの掛け声

6. **癒し系 (.healing)**
   - 穏やかで優しい話し方
   - 「〜ですね」「〜でしょうか」などの柔らかい表現

## 使用方法

### 基本的な使用例

```swift
// OpenAIClientのインスタンス取得
let openAIClient = OpenAIClient.shared

// APIキーの設定
openAIClient.setAPIKey("your-api-key-here")

// メッセージ生成
do {
    let message = try await openAIClient.generateNotificationMessage(
        for: "新宿",
        arrivalTime: "5分後",
        characterStyle: .gyaru
    )
    print("Generated message: \(message)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### NotificationManagerでの使用

```swift
// NotificationManagerは自動的にOpenAIClientを使用
let notificationManager = NotificationManager.shared

// キャラクタースタイルを設定
notificationManager.updateCharacterStyle(.butler)

// 通知スケジュール時に自動でAIメッセージが生成される
try await notificationManager.scheduleTrainAlert(
    for: "新宿",
    arrivalTime: arrivalDate,
    currentLocation: currentLocation,
    targetLocation: targetLocation,
    characterStyle: .butler
)
```

## エラーハンドリング

### エラータイプ

```swift
enum OpenAIError: LocalizedError {
    case missingAPIKey        // APIキーが設定されていない
    case invalidAPIKey        // 無効なAPIキー
    case invalidURL           // 無効なURL
    case invalidResponse      // 無効なレスポンス
    case rateLimitExceeded    // レート制限超過
    case serverError          // サーバーエラー
    case networkUnavailable   // ネットワーク未接続
    case httpError(statusCode: Int) // HTTPエラー
}
```

### エラー対策

1. **APIキー未設定**
   - 設定画面でユーザーにAPIキーの入力を促す

2. **レート制限**
   - 自動リトライ（指数バックオフ）
   - キャッシュによるAPI呼び出し削減

3. **ネットワークエラー**
   - フォールバックメッセージの使用
   - ユーザーへの適切なエラー通知

## パフォーマンス最適化

### キャッシング戦略

- **キャッシュキー**: `"{駅名}_{キャラクタースタイル}"`
- **有効期限**: 30日間
- **保存場所**: UserDefaults
- **自動クリーンアップ**: 期限切れキャッシュの自動削除

### レート制限管理

- **制限**: 20リクエスト/分
- **最小間隔**: 1秒
- **リトライ**: 最大3回（指数バックオフ）
- **待機処理**: 制限到達時の自動待機

### APIコスト最適化

1. **キャッシュ活用**
   - 同じ駅・キャラクターの組み合わせは30日間キャッシュ

2. **短いプロンプト**
   - 効率的なプロンプト設計でトークン数削減

3. **適切なモデル選択**
   - gpt-3.5-turboを使用（gpt-4より低コスト）

4. **トークン制限**
   - 最大100トークンで生成を制限

## セキュリティ

### APIキー管理

```swift
class KeychainHelper {
    static let shared = KeychainHelper()
    
    func saveAPIKey(_ key: String) {
        // Keychainに安全に保存
    }
    
    func getAPIKey() -> String? {
        // Keychainから安全に取得
    }
}
```

### セキュリティ対策

1. **Keychain使用**
   - APIキーはKeychainで暗号化保存
   - UserDefaultsやplainテキストでの保存は避ける

2. **入力検証**
   - APIキーフォーマットの検証
   - 不正な入力値のフィルタリング

3. **ネットワークセキュリティ**
   - HTTPS通信のみ
   - 適切なタイムアウト設定

## テスト

### ユニットテスト

```swift
// OpenAIClientTests.swift
func testMessageGeneration() async {
    let client = OpenAIClient.shared
    client.setAPIKey("test-key")
    
    do {
        let message = try await client.generateNotificationMessage(
            for: "新宿",
            arrivalTime: "5分後",
            characterStyle: .gyaru
        )
        XCTAssertFalse(message.isEmpty)
    } catch {
        XCTFail("Message generation failed: \(error)")
    }
}
```

### 統合テスト

1. **実際のAPI呼び出し**
   - 有効なAPIキーでのテスト
   - エラーケースのテスト

2. **フォールバック機能**
   - API失敗時のフォールバック動作
   - オフライン時の動作

3. **キャッシュ機能**
   - キャッシュの保存・取得
   - 期限切れの処理

## トラブルシューティング

### よくある問題

1. **APIキーエラー**
   ```
   Error: 無効なAPIキーです
   ```
   - 解決策: OpenAI ConsoleでAPIキーを確認

2. **レート制限エラー**
   ```
   Error: API利用制限に達しました
   ```
   - 解決策: 時間を置いてリトライ、またはキャッシュを活用

3. **ネットワークエラー**
   ```
   Error: ネットワークに接続できません
   ```
   - 解決策: ネットワーク接続を確認、フォールバックメッセージ使用

### ログの確認

```swift
// デバッグログの有効化
print("📝 Generated AI message: \(message)")
print("⚠️ Falling back to preset message")
print("🔄 Retrying API call (attempt \(attempt)/\(maxRetryAttempts))")
```

## 今後の拡張予定

### 新機能

1. **追加キャラクタースタイル**
   - 方言バリエーション
   - 季節限定スタイル

2. **パーソナライゼーション**
   - ユーザーの使用履歴に基づくカスタマイズ
   - 学習機能

3. **多言語対応**
   - 英語、中国語、韓国語サポート
   - ローカライズ対応

### パフォーマンス改善

1. **より効率的なキャッシング**
   - Core Dataでの永続化
   - より細かい粒度でのキャッシュ管理

2. **API呼び出し最適化**
   - バッチリクエスト
   - より効率的なプロンプト

## まとめ

OpenAI統合により、TrainAlertは従来の画一的な通知から、ユーザーに親しまれる個性的なアラートシステムへと進化しました。適切なエラーハンドリングとフォールバック機能により、API障害時でも確実に通知が配信される信頼性の高いシステムを実現しています。
