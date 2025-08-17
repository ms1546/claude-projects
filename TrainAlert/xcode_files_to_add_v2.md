# Xcodeに追加する必要があるファイル

以下のファイルをXcodeプロジェクトに追加してください：

## 新規作成したファイル

1. **StationAlertSetupView.swift**
   - パス: `TrainAlert/Views/AlertSetup/StationAlertSetupView.swift`
   - 説明: 駅単体でアラートを設定する画面（時刻表ベースの設定画面と統一されたUI）

2. **StationSearchForAlertView.swift**
   - パス: `TrainAlert/Views/AlertSetup/StationSearchForAlertView.swift`
   - 説明: 駅を検索してアラート設定画面に遷移する画面
   - ✅ ビルドエラー修正済み

## 変更内容

- HomeViewが`AlertSetupCoordinator`の代わりに`StationSearchForAlertView`を表示するように変更
- 「駅から設定」と「経路から選択」のUIが統一されました
- NavigationStackを使った適切な画面遷移に修正
- 位置情報の権限処理を改善

## 修正したビルドエラー

1. `StationModel`に`distance`プロパティがない → 動的に計算するように修正
2. `searchNearbyStations` → `getNearbyStations`に修正
3. `searchStations(by:)` → `searchStations(query:near:)`に修正
4. `location.latitude/longitude` → `stationModel.latitude/longitude`に修正
5. `.textTertiary` → `.textSecondary`に修正
6. 必要なimport文を追加（CoreLocation）
7. `newStation`のスコープエラーを修正 → station変数を使って統一的に扱うように変更
8. **最新修正**: 駅検索のタイムアウトエラーを修正
   - URLSessionのタイムアウトを30秒に延長
   - Overpass APIのタイムアウトを25秒に延長
   - 検索範囲を20kmに最適化
   - デバウンスを0.5秒に調整
   - エラーハンドリングとUXを改善

## 追加手順

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーターで`Views/AlertSetup`フォルダを右クリック
3. "Add Files to TrainAlert..."を選択
4. 上記の2つのファイルを選択して追加
5. Target membershipで"TrainAlert"にチェックが入っていることを確認
6. ビルドして動作確認

## 動作確認

1. ホーム画面で「駅から設定」をタップ
2. 駅を検索または近くの駅から選択
3. 選択すると新しいアラート設定画面が表示される
4. 通知時間とキャラクターを選択して「アラートを設定」をタップ
5. 自動的にホーム画面に戻り、新しいアラートが表示される