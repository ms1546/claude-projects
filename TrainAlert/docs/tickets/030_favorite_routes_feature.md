# Ticket #030: 経路お気に入り機能

## 概要
よく使う経路をお気に入りとして保存し、簡単に呼び出せる機能を実装する。UIは既に存在しているため、バックエンドの実装が主となる。

## 優先度: Medium
## 見積もり: 6h
## ステータス: [ ] Not Started / [ ] In Progress / [x] Completed

## タスク
### データモデル実装
- [x] FavoriteRoute Core Dataエンティティ
  - [x] routeIdフィールド（UUID）
  - [x] departureStationフィールド
  - [x] arrivalStationフィールド
  - [x] departureTimeフィールド（デフォルト時刻）
  - [x] nickNameフィールド（オプション）
  - [x] sortOrderフィールド（並び順）
  - [x] createdAtフィールド
  - [x] lastUsedAtフィールド
- [x] リレーションシップ設定
  - [x] Station エンティティとの関連
  - [x] Alert エンティティとの関連（オプション）

### ビジネスロジック
- [x] お気に入り管理機能
  - [x] 経路の保存処理
  - [x] 重複チェック（同じ経路の防止）
  - [x] 最大保存数の制限（例：20件）
  - [x] 並び順の管理
- [x] お気に入りの利用
  - [x] 選択時の経路情報復元
  - [x] 最終利用日時の更新
  - [x] 利用頻度のトラッキング

### UI実装（既存UIとの接続）
- [x] FavoriteRoutesViewとの連携
  - [x] データソースの実装
  - [x] 保存/削除機能の接続
  - [x] 並び替え機能の実装
- [x] 経路検索画面での保存UI
  - [x] お気に入り追加ボタンの機能実装
  - [x] ニックネーム入力ダイアログ
  - [x] 保存成功フィードバック

### 追加機能
- [x] スマート並び替え
  - [x] 利用頻度順
  - [x] 最近使った順
  - [x] 手動並び替え
  - [ ] 時間帯別の表示
- [ ] お気に入りの編集
  - [ ] ニックネームの変更
  - [ ] デフォルト時刻の変更
  - [ ] アイコン/カラーの設定

## 実装ガイドライン
- 保存は非同期で高速に
- iCloudSync対応の準備
- お気に入りは永続化
- 削除時は確認ダイアログ

## 完了条件（Definition of Done）
- [x] 経路をお気に入りに保存できる
- [x] お気に入りから経路を呼び出せる
- [x] お気に入りを削除できる
- [x] 並び順を変更できる

## テスト方法
1. 経路のお気に入り保存
2. お気に入りからの経路復元
3. 複数お気に入りの管理
4. 並び替え機能の動作確認

## 依存関係
- なし（独立機能）

## 成果物
- FavoriteRoute+CoreDataClass.swift
- FavoriteRoute+CoreDataProperties.swift
- FavoriteRouteManager.swift
- FavoriteRoutesViewModel.swift

## 備考
- 将来的にはウィジェット対応も検討
- Apple Watchからのお気に入りアクセス
