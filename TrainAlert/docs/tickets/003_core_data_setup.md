# Ticket #003: Core Dataセットアップ

## 概要
データモデルの定義とCore Dataスタックの実装

## 優先度: High
## 見積もり: 3h

## タスク
- [ ] Core Dataモデルファイル作成
- [ ] Entityの定義
  - [ ] Station Entity
    - [ ] stationId: String
    - [ ] name: String
    - [ ] latitude: Double
    - [ ] longitude: Double
  - [ ] Alert Entity
    - [ ] alertId: UUID
    - [ ] notificationTime: Int16
    - [ ] notificationDistance: Double
    - [ ] snoozeInterval: Int16
    - [ ] characterStyle: String
    - [ ] isActive: Bool
  - [ ] History Entity
    - [ ] historyId: UUID
    - [ ] notifiedAt: Date
    - [ ] message: String
- [ ] Relationshipの設定
- [ ] CoreDataManager作成
- [ ] CRUD操作の実装
- [ ] Migration対応

## 受け入れ条件
- データの保存・読み込みが正常に動作
- 適切なエラーハンドリング
- Unit Test作成

## 依存関係
- #001完了後に着手
