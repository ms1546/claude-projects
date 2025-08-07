# Ticket #008: ホーム画面実装

## 概要
メイン画面の実装（アラート表示、クイックアクション）

## 優先度: High
## 見積もり: 4h

## ステータス: [x] Completed

## タスク
- [x] HomeView作成
- [x] HomeViewModel実装
- [x] アクティブアラート表示
  - [x] カードUIコンポーネント
  - [x] アラート情報表示
  - [x] 一時停止/再開ボタン
  - [x] 削除ボタン
- [x] アラート未設定時のUI
  - [x] 空状態の表示
  - [x] 設定促進ボタン
- [x] 最近使った駅リスト
  - [x] 履歴から表示
  - [x] タップで素早く設定
- [x] FloatingActionButton
  - [x] 新規アラート作成
- [x] Pull to Refresh
- [x] アニメーション実装

## 実装内容
- **HomeViewModel**: Core Data統合、位置情報管理、アラート状態管理
- **HomeView**: レスポンシブなUI、アニメーション、プルツーリフレッシュ
- **AlertCardView**: アクティブアラート表示カード
- **EmptyStateView**: アラート未設定時の状態表示
- **RecentStationCard**: 最近使った駅のクイックアクセス
- **MapView**: 現在地とアラート位置表示
- **FloatingActionButton**: 新規アラート作成ボタン

## 受け入れ条件
- [x] 直感的なUI
- [x] スムーズなアニメーション  
- [x] 状態変更が即座に反映

## 依存関係
- #002, #003完了後に着手

## 完了日
2024年1月8日
