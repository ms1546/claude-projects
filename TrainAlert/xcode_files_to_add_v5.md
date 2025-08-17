# Xcodeに追加する必要があるファイル（位置追跡・通知機能）

## 新規作成したファイル

### 1. AlertMonitoringService.swift
- **パス**: `TrainAlert/Services/AlertMonitoringService.swift`
- **説明**: アラートの条件を監視し、適切なタイミングで通知を発火するサービス
- **機能**:
  - アクティブなアラートの監視
  - 時間ベースのアラートチェック
  - 距離ベースのアラートチェック
  - 通知の送信

## 追加手順

1. **Xcodeでプロジェクトを開く**

2. **AlertMonitoringService.swiftを追加**
   - プロジェクトナビゲーターで`Services`フォルダを右クリック
   - "Add Files to TrainAlert..."を選択
   - `AlertMonitoringService.swift`を選択
   - Target membershipで"TrainAlert"にチェックが入っていることを確認

3. **ビルドして動作確認**
   - Command+Bでビルド
   - エラーが出ないことを確認

## 主な変更内容

### 既存ファイルの更新
1. **AppDelegate.swift**
   - AlertMonitoringServiceの初期化を追加
   - アプリ起動時に監視を開始

2. **TrainAlertApp.swift**
   - AppStateにAlertMonitoringServiceを追加
   - 初期化時に監視サービスを開始

3. **HomeViewModel.swift**
   - アラート切り替え時にAlertMonitoringServiceを更新
   - アラート削除時にAlertMonitoringServiceを更新

4. **StationAlertSetupView.swift**
   - アラート作成時にAlertMonitoringServiceを更新

5. **TimetableAlertSetupView.swift**
   - アラート作成時にAlertMonitoringServiceを更新

## 動作確認手順

1. **位置情報の許可**
   - アプリ起動時に位置情報の使用許可を求められる
   - 「常に許可」を選択（バックグラウンドでも動作させるため）

2. **アラートの作成**
   - 距離ベースアラート（例：500m）を作成
   - 時間ベースアラート（例：5分前）を作成

3. **通知の確認**
   - 設定した条件を満たすと通知が発火
   - キャラクタースタイルに応じたメッセージが表示される

## 注意事項
- シミュレーターでテストする場合は、Debug → Location → Custom Locationで位置を変更して動作確認
- 実機でテストする場合は、実際に移動して動作確認