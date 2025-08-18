# Ticket #022: 時刻表連携アラーム機能（基本実装）

## 概要
時刻表から具体的な電車を選択して、到着時刻の○分前に通知する基本機能を実装する。

## 優先度: High
## 見積もり: 16h
## ステータス: [ ] Not Started / [ ] In Progress / [x] Completed

## 実装完了日
2025-08-17 (PR#32)

## タスク
### API実装
- [x] ODPT StationTimetable APIクライアント実装
  - [x] エンドポイント定義
  - [x] リクエスト/レスポンスモデル
  - [x] エラーハンドリング
- [x] 時刻表データモデル定義
  - [x] StationTimetable構造体（ODPTStationTimetable）
  - [x] TrainDeparture構造体（ODPTTrainTimetableObject）
  - [x] データ変換ロジック

### UI実装
- [x] 時刻表表示UI（TimetableSearchView）
  - [x] 駅選択インターフェース
  - [x] 時刻表リスト表示
  - [x] 現在時刻ハイライト機能（isNearCurrentTime, nearestTrain）
  - [ ] 時間帯フィルタリング（未実装）
- [x] 電車選択UI（TrainSelectionView）
  - [x] 電車詳細表示
  - [x] 到着駅選択
  - [x] 通知タイミング設定（1-30分前）
- [x] アラート設定画面（TimetableAlarmSetupView）修正
  - [x] 既存画面の拡張（HomeViewに時刻表から設定ボタン追加）
  - [x] 時刻表ベース設定追加

### データ層実装
- [x] Core Dataモデル拡張（既存のRouteAlertを活用）
  - [x] 必要なフィールド追加（trainType, departureTime, arrivalTime）
  - [x] リレーションシップ設定
  - [x] マイグレーション対応
- [x] 通知スケジューリング機能
  - [x] 時刻ベース通知設定（saveAlert メソッド）
  - [x] バックグラウンドタスク登録
  - [x] 通知内容生成

### ビジネスロジック
- [x] 現在時刻周辺の優先表示ロジック
  - [x] 時刻比較アルゴリズム（isNearCurrentTime, isPastTime）
  - [x] スクロール位置調整（nearestTrain を使用）
- [ ] 時間帯フィルタリング機能（未実装）
  - [ ] 朝/昼/夜の区分
  - [ ] カスタム時間帯設定

## 実装ガイドライン
- ODPT APIの仕様に準拠した実装
- 現在時刻から前後2時間を優先的に表示
- 通知タイミングは1分〜30分の範囲で設定可能
- UIは既存のデザインシステムに準拠

## 完了条件（Definition of Done）
- [x] 出発駅の時刻表が表示される
- [x] 電車を選択できる（時刻、種別、行き先）
- [x] 到着駅を選択できる
- [x] 通知タイミングを設定できる（1〜30分前）
- [x] 設定した時刻に通知が来る
- [x] 現在時刻に近い電車が上部に表示される（「もうすぐ」ラベル表示）

## テスト方法
1. 実際の駅で時刻表を表示
2. 電車を選択して通知設定
3. 設定時刻に通知が来ることを確認
4. 異なる時間帯でのフィルタリング動作確認

## 依存関係
- チケット#018（時刻表連携機能の実装）- 完了済み

## 成果物
- TimetableSearchView.swift
- TrainSelectionView.swift
- TimetableAlarmSetupView.swift（修正版）
- StationTimetableAPIClient.swift
- TimetableAlert+CoreDataClass.swift

## 備考
- ユーザーは具体的な電車（何時何分発）を選んで通知を設定したいというニーズに対応
- 将来的には遅延情報の反映も検討

## 実装の詳細
- PR#32で実装完了
- TimetableAlertエンティティは作成せず、既存のRouteAlertエンティティを拡張して実装
- 時間帯フィルタリング機能は未実装（今後の拡張として残る）
- 「もうすぐ」ラベルで現在時刻に近い電車を視覚的に強調
- チケット#032で白画面問題を修正済み
