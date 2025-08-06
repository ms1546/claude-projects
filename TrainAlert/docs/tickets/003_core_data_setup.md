# Ticket #003: Core Dataセットアップ

## 概要
データモデルの定義とCore Dataスタックの実装

## 優先度: High
## 見積もり: 3h
## ステータス: [x] Completed

## タスク
- [x] Core Dataモデルファイル作成
- [x] Entityの定義
  - [x] Station Entity
    - [x] stationId: String
    - [x] name: String
    - [x] latitude: Double
    - [x] longitude: Double
    - [x] lines: String (追加)
    - [x] isFavorite: Bool (追加)
    - [x] lastUsedAt: Date (追加)
  - [x] Alert Entity
    - [x] alertId: UUID
    - [x] notificationTime: Int16
    - [x] notificationDistance: Double
    - [x] snoozeInterval: Int16
    - [x] characterStyle: String
    - [x] isActive: Bool
    - [x] createdAt: Date (追加)
  - [x] History Entity
    - [x] historyId: UUID
    - [x] notifiedAt: Date
    - [x] message: String
- [x] Relationshipの設定
- [x] CoreDataManager作成
- [x] CRUD操作の実装
- [x] Migration対応

## 受け入れ条件
- データの保存・読み込みが正常に動作
- 適切なエラーハンドリング
- Unit Test作成

## 依存関係
- #001完了後に着手
