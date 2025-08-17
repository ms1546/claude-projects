# チケット #032: 時刻表から「もうすぐ」電車選択時の白画面問題修正

## 概要
時刻表検索画面で「もうすぐ」がついている電車を選択すると、白い画面（エラー画面）が表示される問題を修正する。

## 優先度
High - ユーザビリティに大きく影響する問題

## 見積もり
8-16時間

## ステータス
[ ] Not Started / [x] In Progress / [ ] Completed

## 問題の詳細
1. **現象**: 
   - 時刻表検索画面で「もうすぐ」ラベルがついた電車を選択時に白画面が表示される
   - 同じ電車を2回タップすると正常に表示されることがある
   - 非同期処理のタイミング問題と推測される

2. **根本原因**:
   - sheet表示時に必要なrailwayデータが失われている
   - 非同期処理（時刻表読み込み）と画面遷移のタイミングが競合している

## 実施した対策

### 1. データキャッシング戦略（部分的に改善）
```swift
@State private var cachedRailway: String = ""
@State private var cachedDirection: String? = nil
```
- 結果: 改善はあったが完全には解決せず

### 2. データ準備フラグの追加（部分的に改善）
```swift
@State private var isDataPreparing = false
```
- データロード中はボタンを無効化
- 結果: タイミング問題は残存

### 3. 構造体によるデータ管理（最終実装）
```swift
struct TrainSelectionData: Equatable {
    let train: ODPTTrainTimetableObject
    let station: ODPTStation
    let railway: String
    let direction: String?
}
```
- データの一貫性を保証
- 0.1秒の遅延でsheet表示
- 結果: 発生頻度は減少したが、完全には解決せず

## 残存する問題

1. **SwiftUIのsheet表示の制限**:
   - 状態変更とsheet表示の同期が困難
   - 非同期処理完了前にユーザーがタップするケースに対応困難

2. **タイミング依存の問題**:
   - APIレスポンスの遅延
   - UIの状態更新タイミングのばらつき

## 今後の対策案

- [ ] 遅延時間を0.2秒に増やす
- [ ] NavigationLinkを使った画面遷移への変更
- [ ] sheet表示前のデータ検証をより厳密に行う
- [ ] ローディング状態の視覚的フィードバックを強化
- [ ] sheet表示をTask内で管理する

## 実装ガイドライン

### 使用するFramework/ライブラリ
- SwiftUI
- Combine（状態管理）

### 参考にすべきコード
- `/Views/Timetable/TimetableSearchView.swift`
- `/Views/Timetable/TrainSelectionView.swift`

### 注意事項
- 非同期処理とUI更新のタイミングを慎重に管理
- ユーザーの高速タップに対応できる設計が必要

## 完了条件（Definition of Done）
- [ ] 「もうすぐ」電車を選択しても白画面が表示されない
- [ ] 全ての時刻の電車で正常に画面遷移が行われる
- [ ] 高速タップしても問題が発生しない
- [ ] エラーハンドリングが適切に実装されている

## テスト方法

### 手動テストの手順
1. 時刻表検索画面を開く
2. 駅を選択し、時刻表を表示
3. 「もうすぐ」ラベルがついた電車を選択
4. 正常に列車選択画面が表示されることを確認
5. 高速で複数回タップしても問題ないことを確認

### 期待される結果
- 白画面が表示されない
- 選択した電車の情報が正しく表示される
- エラーが発生した場合は適切なエラーメッセージが表示される

## 依存関係
- 前提: #022（時刻表連携アラーム機能）
- 関連: #018（時刻表統合）

## 成果物
- 更新: `/Views/Timetable/TimetableSearchView.swift`
- 更新: `/Views/Timetable/TrainSelectionView.swift`

## 備考
- ユーザーからの報告により発覚した問題
- SwiftUIのsheet表示の仕様上、完全な解決が困難な可能性あり
- UX改善のため、別の画面遷移方法の検討も必要