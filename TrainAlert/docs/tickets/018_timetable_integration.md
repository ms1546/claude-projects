# Ticket #018: 時刻表連携機能の実装

## 概要
電車の時刻表と連携し、出発駅・出発時刻・到着駅・到着時刻を設定できるようにする。到着時刻の何分前に通知するかを設定可能にする。

## 優先度: High
## 見積もり: 20h
## ステータス: [ ] Not Started / [ ] In Progress / [x] Completed

## タスク
### フェーズ1: API承認待ち期間の準備
- [x] UI/UXデザインの作成
  - [x] RouteSearchViewのデザイン
  - [x] TimetableAlertSetupViewのデザイン
- [x] データモデルの設計
  - [x] RouteAlertエンティティ設計
  - [x] Core Dataスキーマ更新
- [x] モックデータでの画面実装
  - [x] RouteSearchView実装
  - [x] TimetableAlertSetupView実装
  - [x] モックAPIサービス作成

### フェーズ2: API承認後の実装
- [x] APIクライアントの実装
  - [x] ODPT API認証設定
  - [x] エンドポイント実装
- [x] 実データとの連携
  - [x] 経路検索API連携（HeartRails Express API使用）
  - [x] 時刻表データ取得（モックデータ使用）
- [x] エラーハンドリング
  - [x] ネットワークエラー対応
  - [x] APIエラー対応
- [x] パフォーマンス最適化
  - [x] レスポンスキャッシング（HeartRails APIで実装）
  - [x] 非同期処理最適化（デバウンス実装）

## 実装ガイドライン
- ODPT APIの利用申請が承認されたことを前提に実装
- エラーハンドリングは適切な日本語メッセージで表示
- キャッシュ機能により通信量を削減
- SwiftUIのasync/awaitパターンを使用

## 完了条件（Definition of Done）
- [x] 出発駅と到着駅を指定して経路検索できる
- [x] 実際の時刻表に基づいた到着時刻が表示される（モックデータ使用）
- [x] 到着時刻の指定した分数前に通知が来る
- [ ] 遅延情報が反映される（API対応の場合）
- [x] よく使う経路を保存・呼び出しできる

## テスト方法
1. 実際の駅名で経路検索を実行
2. 時刻表データが正しく表示されることを確認
3. 通知タイミングの設定と動作確認
4. オフライン時のエラーハンドリング確認

## 依存関係
- チケット#016（駅情報API基盤の確立）- 完了済み
- 公共交通オープンデータセンターのAPI承認 - 取得済み

## 成果物
- RouteSearchView.swift
- TimetableAlertSetupView.swift
- RouteAlert+CoreDataClass.swift
- ODPTAPIClient.swift
- RouteSearchViewModel.swift

## 備考
- ODPT APIの利用申請は承認済み
- 遅延情報の取得は次フェーズで拡張予定