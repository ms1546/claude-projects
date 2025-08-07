# Ticket #009: アラート設定フロー

## 概要
新規アラート作成の画面フローと設定画面の実装

## 優先度: High
## 見積もり: 5h

## ステータス: [x] Completed

## タスク
- [x] 駅選択画面
  - [x] StationSearchView
  - [x] 検索バー実装
  - [x] 現在地から検索
  - [x] お気に入り駅表示
  - [x] 検索結果リスト
- [x] アラート詳細設定画面
  - [x] AlertSettingView
  - [x] AlertSetupViewModel
  - [x] 通知タイミング設定
    - [x] 時間設定スライダー
    - [x] 距離設定スライダー
  - [x] スヌーズ設定
  - [x] キャラクター選択統合
- [x] キャラクター選択画面
  - [x] CharacterSelectView
  - [x] キャラクターカード
  - [x] プレビューメッセージ
- [x] 設定確認画面
  - [x] 設定内容サマリー
  - [x] アラート開始ボタン
- [x] フォームバリデーション
- [x] AlertSetupData モデル作成
- [x] AlertSetupCoordinator ナビゲーション管理
- [x] HomeView統合

## 受け入れ条件
- 3タップ以内で設定完了
- 入力エラーの適切な表示
- 設定値の永続化

## 依存関係
- #006, #007完了後に着手
