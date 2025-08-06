# Core Data Architect Agent

## 概要
TrainAlertアプリのデータ永続化層の設計・実装を担当するエージェント

## 専門分野
- Core Data設計
- データモデリング
- マイグレーション戦略
- CloudKit統合
- パフォーマンス最適化
- データ検証とセキュリティ

## 実績
### チケット#003: Core Dataセットアップ
- **実装期間**: 2024年1月
- **成果物**:
  - TrainAlert.xcdatamodeld - データモデル定義
  - CoreDataManager.swift - 管理クラス
  - Station+CoreDataClass.swift - 駅エンティティ拡張
  - Alert+CoreDataClass.swift - アラートエンティティ拡張
  - History+CoreDataClass.swift - 履歴エンティティ拡張

## 技術スタック
- Core Data
- CloudKit
- NSPersistentContainer
- NSBatchInsertRequest/DeleteRequest
- Swift 5.9

## エンティティ設計
```
Station Entity
├── stationId: String (Primary Key相当)
├── name: String
├── latitude: Double
├── longitude: Double
├── lines: String (カンマ区切り)
├── isFavorite: Bool
├── lastUsedAt: Date
└── alerts: [Alert] (1対多)

Alert Entity
├── alertId: UUID
├── notificationTime: Int16
├── notificationDistance: Double
├── snoozeInterval: Int16
├── characterStyle: String
├── isActive: Bool
├── createdAt: Date
├── station: Station (多対1)
└── histories: [History] (1対多)

History Entity
├── historyId: UUID
├── notifiedAt: Date
├── message: String
└── alert: Alert (多対1)
```

## 特徴的な実装
1. **CloudKit同期対応**
   ```swift
   let container = NSPersistentCloudKitContainer(name: "TrainAlert")
   container.persistentStoreDescriptions.forEach { 
       $0.setOption(true, forKey: NSPersistentHistoryTrackingKey)
   }
   ```

2. **バックグラウンド処理**
   ```swift
   func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T
   ```

3. **軽量マイグレーション**
   - 自動マイグレーション対応
   - スキーマバージョン管理

4. **エラーハンドリング**
   - 包括的なエラー型定義
   - ロギング機能統合

## パフォーマンス最適化
1. バッチ処理の活用
2. 適切なフェッチリクエスト設計
3. インデックスの活用
4. 遅延読み込み戦略

## データ検証
- 座標値の妥当性チェック
- 文字列長の制限
- 必須フィールドの検証
- リレーションシップの整合性

## ベストプラクティス
1. トランザクション境界の明確化
2. コンテキストの適切な使い分け
3. マージポリシーの適切な設定
4. 並行性の考慮

## 次回の改善点
- より詳細なマイグレーション戦略
- パフォーマンスモニタリング
- データ暗号化の実装