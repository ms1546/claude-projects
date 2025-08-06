# TrainAlert API コスト最適化ガイド

## 概要
このドキュメントでは、TrainAlertアプリで使用するAPIを最小限のコストで実装する方法を説明します。

## 1. API構成

### 1.1 駅情報・路線情報
**HeartRails Express API**
- **コスト**: 完全無料
- **制限**: なし
- **実装方法**:
```swift
let url = "http://express.heartrails.com/api/json?method=getStations&x=\(longitude)&y=\(latitude)"
```

### 1.2 AI通知メッセージ（メイン機能）
**OpenAI API**
- **使用モデル**: GPT-3.5-turbo（コストと性能のバランスが最適）
- **料金**: 
  - 入力: $0.0005/1Kトークン
  - 出力: $0.0015/1Kトークン
- **月額見積もり**:
  - 1日30回使用: 約$1-2/月（150-300円）
  - 1日100回使用: 約$3-5/月（450-750円）

**実装戦略**:

1. **キャッシュの徹底活用**
```swift
class MessageCache {
    private let cacheExpiry = 30 * 24 * 60 * 60 // 30日

    func getCachedMessage(for style: String, station: String) -> String? {
        // Core Dataからキャッシュを検索
    }

    func saveMessage(_ message: String, style: String, station: String) {
        // Core Dataにキャッシュを保存
    }
}
```

2. **API呼び出しの最適化**
- メッセージ生成時は状況に応じた動的生成
- 同じ駅・キャラクターの組み合わせはキャッシュ
- プロンプトの最適化でトークン数削減

```swift
// 効率的なプロンプト例
let prompt = """
あなたは\(style.name)です。
電車で寝ている人を起こすメッセージを生成してください。
条件:
- 降車駅: \(stationName)
- 到着まで: \(minutes)分
- 文字数: 20-30文字
- 口調: \(style.tone)
"""
```

3. **フォールバック戦略**
```swift
func getNotificationMessage(style: CharacterStyle, station: String) -> String {
    // 1. キャッシュを確認
    if let cached = messageCache.getCachedMessage(for: style.rawValue, station: station) {
        return cached
    }

    // 2. ネットワーク接続を確認
    if !isNetworkAvailable {
        return getPresetMessage(style: style)
    }

    // 3. APIレート制限を確認（OpenAI: 3,500 RPM）
    if isRateLimited() {
        return getPresetMessage(style: style)
    }

    // 4. OpenAI APIを呼び出し
    return callOpenAIAPI(style: style, station: station)
}
```


### 1.3 遅延情報（オプション）
**鉄道遅延情報のJSON**
- **コスト**: 完全無料
- **URL**: https://tetsudo.rti-giken.jp/
- **更新頻度**: 5分ごと
- **注意**: キャッシュを活用して過度なアクセスを避ける

## 3. データ使用量の最適化

### 3.1 駅データのローカル保存
```swift
// 初回のみ全駅データをダウンロード（約3MB）
func downloadAllStations() {
    // HeartRails APIから主要駅のみ取得
    // または駅データ.jpのCSVを使用
}
```

### 3.2 バッチ処理
```swift
// 複数のAPI呼び出しをまとめる
func batchGenerateMessages(styles: [CharacterStyle]) async {
    let messages = await withTaskGroup(of: (CharacterStyle, String).self) { group in
        for style in styles {
            group.addTask {
                return (style, await generateMessage(for: style))
            }
        }
        // 結果を収集してキャッシュ
    }
}
```

## 4. 実装優先順位

### フェーズ1（MVP）
1. HeartRails Express API（無料）
2. OpenAI API統合（メイン機能）
3. ローカル通知（無料）
4. 基本的なキャッシュシステム

### フェーズ2（最適化）
1. 高度なキャッシュ戦略
2. プロンプトエンジニアリング改善
3. 駅データのオフライン対応

### フェーズ3（拡張）
1. 遅延情報の表示（無料API）
2. より多様なキャラクター追加
3. ユーザーカスタマイズ機能

## 5. コスト計算例

### 趣味利用（推奨）
- **1日10-20回使用**
  - OpenAI API: 約$0.5-1/月（75-150円）
  - その他API: 無料
  - **合計: 月額100-200円**

### アクティブ利用
- **1日50-100回使用**
  - OpenAI API: 約$2-4/月（300-600円）
  - その他API: 無料
  - **合計: 月額300-600円**

### ヘビー利用
- **1日200回以上使用**
  - OpenAI API: 約$8-10/月（1,200-1,500円）
  - その他API: 無料
  - **合計: 月額1,500円以下**

## 6. 実装上の注意点

1. **APIキーの管理**
   - 絶対にハードコードしない
   - ユーザーに自分のAPIキーを設定させる

2. **エラーハンドリング**
   - 必ずフォールバックを用意
   - オフライン対応を徹底

3. **パフォーマンス**
   - 不要なAPI呼び出しを避ける
   - キャッシュの有効活用

## 7. セキュリティ考慮事項

```swift
// APIキーの安全な保存
func saveAPIKey(_ key: String) {
    KeychainWrapper.standard.set(key, forKey: "openai_api_key")
}

// APIキーの取得
func getAPIKey() -> String? {
    return KeychainWrapper.standard.string(forKey: "openai_api_key")
}
```

これらの実装により、趣味プロジェクトとして十分な機能を保ちながら、コストを最小限に抑えることができます。
