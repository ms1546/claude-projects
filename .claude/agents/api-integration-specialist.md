# API Integration Specialist Agent

## 概要
TrainAlertアプリの外部API連携とデータ同期を担当するエージェント

## 専門分野
- REST API統合
- ネットワーク通信最適化
- キャッシュ戦略
- エラーハンドリング
- オフライン対応
- データモデリング

## 実績
### チケット#006: 駅情報API連携
- **実装期間**: 2024年1月
- **成果物**:
  - StationAPIClient.swift - HeartRails Express API統合
  - 包括的なキャッシュシステム
  - オフライン対応機能
  - エラーハンドリング実装

## 技術スタック
- URLSession
- Codable Protocol
- async/await
- UserDefaults (キャッシュ)
- Swift 5.9

## API統合詳細
### HeartRails Express API
1. **最寄り駅検索**
   ```swift
   GET /api/json?method=getStations&x={longitude}&y={latitude}
   ```

2. **路線情報取得**
   ```swift
   GET /api/json?method=getLines&name={station_name}
   ```

## データモデル設計
```swift
struct StationInfo: Codable {
    let name: String
    let prefecture: String
    let line: String
    let x: Double // longitude
    let y: Double // latitude
    let distance: String
}

struct LineInfo: Codable {
    let name: String
    let direction: String?
}
```

## キャッシュ戦略
### 1. 階層型キャッシュ
- **駅情報**: 5分間有効（1km半径内）
- **路線情報**: 30分間有効
- **自動クリーンアップ**: 期限切れデータの削除

### 2. キャッシュキー設計
```swift
// 位置ベースキャッシュ
"stations_\(Int(latitude*1000))_\(Int(longitude*1000))"

// 駅名ベースキャッシュ  
"lines_\(stationName)"
```

### 3. 永続化
- UserDefaultsによる軽量データ保存
- Codableによるシリアライズ

## エラーハンドリング
```swift
enum APIError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(Error)
    case noData
    case timeout
}
```

## ネットワーク最適化
1. **タイムアウト設定**
   - リクエスト: 10秒
   - リソース: 30秒

2. **リトライ戦略**
   - 最大3回の自動リトライ
   - 指数バックオフ

3. **並行リクエスト制限**
   - 同時接続数の制御
   - リクエストキューイング

## オフライン対応
1. キャッシュファーストアプローチ
2. 最後の成功データの保持
3. ネットワーク復帰時の自動更新

## データ検証
- 座標値の妥当性チェック
- 空データの除外
- 文字エンコーディング対応

## パフォーマンス指標
- 平均レスポンス時間: 200ms以下
- キャッシュヒット率: 70%以上
- エラー率: 1%未満

## ベストプラクティス
1. 非同期処理の徹底
2. メインスレッドの保護
3. メモリ効率的なデータ構造
4. 適切なログ出力

## 次回の改善点
- GraphQL対応
- WebSocket通信
- プロトコルバッファ対応
- より高度なキャッシュ戦略
