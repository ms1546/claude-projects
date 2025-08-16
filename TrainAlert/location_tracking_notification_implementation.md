# 位置追跡・通知機能実装完了レポート

## 実装内容

### 1. AlertMonitoringService（新規作成）
アラートの条件を監視し、適切なタイミングで通知を発火するサービス

#### 主な機能
- **アクティブなアラートの監視**
  - 30秒ごとに全アラートをチェック
  - 位置情報更新時にも自動チェック

- **時間ベースのアラート**
  - 到着時刻の指定時間前に通知
  - 経路から作成したアラートで動作

- **距離ベースのアラート**
  - 駅から指定距離以内に入ると通知
  - 現在位置と駅位置の距離を計算

- **通知の送信**
  - キャラクタースタイルに応じたメッセージ生成
  - 通知履歴をCore Dataに保存

### 2. 既存ファイルの更新

#### TrainAlertApp.swift
- AlertMonitoringServiceをAppStateに追加
- アプリ初期化時に監視を開始

#### HomeViewModel.swift
- アラートの有効/無効切り替え時にサービスを更新
- アラート削除時にサービスを更新

#### StationAlertSetupView.swift / TimetableAlertSetupView.swift
- アラート作成時にサービスを更新

## 動作の仕組み

### 監視フロー
1. アプリ起動時に`AlertMonitoringService.startMonitoring()`が呼ばれる
2. アクティブなアラートをCore Dataから読み込み
3. 30秒ごと＋位置更新時にアラートをチェック
4. 条件を満たしたら通知を送信

### 通知条件
- **時間ベース**: 現在時刻 >= (到着時刻 - 通知時間) && 現在時刻 < 到着時刻
- **距離ベース**: 現在位置から駅までの距離 <= 設定距離
- **駅数ベース**: 実装準備済み（駅順データが必要）

## 必要な設定

### Info.plist（設定済み）
```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>fetch</string>
    <string>processing</string>
</array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>降車駅に近づいたことを検知してお知らせするために...</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>アプリがバックグラウンドにある時でも...</string>
```

## テスト方法

### シミュレーターでのテスト
1. Debug → Location → Custom Locationで位置を変更
2. 駅の座標を入力して距離ベースアラートをテスト

### 実機でのテスト
1. 実際に移動して動作確認
2. バックグラウンドでも通知が来ることを確認

## 制限事項と今後の課題

### 現在の制限
1. **駅から検索の時間ベースアラート**
   - 到着時刻が設定されていないため動作しない
   - 回避策：模擬的な到着時刻を設定するか、距離ベースを使用

2. **駅数ベースアラート**
   - 現在の駅を特定する仕組みが未実装
   - ODPT APIとの連携が必要

3. **バッテリー消費**
   - 30秒ごとのチェックは頻度が高い可能性
   - 位置情報の精度設定の最適化が必要

### 改善案
1. 位置情報の更新頻度を動的に調整
2. ジオフェンシングAPIの活用
3. 通知のグループ化（複数アラートがある場合）

## ビルドエラーについて

`AlertMonitoringService`がXcodeプロジェクトに追加されていないため、ビルドエラーが発生しています。
`xcode_files_to_add_v5.md`の手順に従ってファイルを追加してください。