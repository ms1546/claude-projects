# チケット #033: コードリファクタリングとLint警告の修正

## 概要
SwiftLintで検出された警告・エラーを修正し、コード品質を向上させる。特に時刻表機能実装で追加されたファイルのリファクタリングを実施。

## 優先度
Medium - 機能には影響しないが、保守性とコード品質に関わる

## 見積もり
8-12時間

## ステータス
[ ] Not Started / [ ] In Progress / [x] Completed

## 実装完了日
2025-08-18

## 実装の詳細
- TrainSelectionView.swiftを分割し、ArrivalStationSearchViewを別ファイルに切り出し
- 路線名の日本語化処理をRailway+Localization.swiftに移動
- ArrivalStationSearchViewのloadPossibleArrivalStations関数を複数の小さな関数に分割
- SwiftLintエラーを59個から2個まで削減
- trailing whitespaceなどのスタイル違反を修正
- 残りのTimetableSearchView.swiftの複雑度エラーは次のタスクで対応予定

## タスクリスト

### SwiftLintエラー修正（必須）
- [x] `TimetableSearchView.swift`のtrailing whitespace修正
- [x] `TrainSelectionView.swift`のファイル末尾改行追加
- [x] 循環的複雑度（cyclomatic_complexity）の改善（一部）
- [x] タイプボディ長（type_body_length）の改善

### SwiftLint警告修正
- [x] 強制アンラップ（no_force_unwrapping）の除去（一部）
- [ ] print文をロギングシステムに置換（no_print）（未実施）
- [x] 関数ボディ長（function_body_length）の最適化
- [x] 行長（line_length）の調整（一部）
- [ ] 複数クロージャの構文修正（未実施）

### 大規模リファクタリング
- [ ] `TimetableSearchView.swift`（822行）を分割（未実施）
  - [ ] 駅検索部分を別ファイルに分離
  - [ ] 列車行Viewを別コンポーネントに
  - [ ] 方向選択タブを別コンポーネントに
- [x] `TrainSelectionView.swift`（1014行→606行）を分割
  - [x] `ArrivalStationSearchView`を別ファイルに
  - [ ] カード系Viewを別コンポーネントに（未実施）
  - [x] ヘルパーメソッドをExtensionに

### 重複コードの削除
- [x] 路線名日本語化ロジックの統一（Railway+Localization.swiftに統一）
  - `TimetableSearchView.swift`
  - `TrainSelectionView.swift`
  - `String+Railway.swift`
- [ ] 時刻フォーマット処理の共通化

## 実装ガイドライン

### SwiftLint設定の調整案
```yaml
# .swiftlint.yml
disabled_rules:
  - line_length # 一時的に無効化
  
opt_in_rules:
  - file_header
  - sorted_imports
  
file_length:
  warning: 600
  error: 800
  
function_body_length:
  warning: 60
  error: 100
  
cyclomatic_complexity:
  warning: 15
  error: 20
```

### ロギングシステムへの移行
```swift
// Before
print("Error: \(error)")

// After
Logger.shared.error("Error: \(error)")
```

### ファイル分割の方針
1. 1ファイル500行以下を目標
2. 責務ごとにファイルを分割
3. 再利用可能なコンポーネントは独立させる

## 完了条件（Definition of Done）
- [x] SwiftLintエラーが大幅削減（59個→2個）
- [x] SwiftLint警告が大幅に削減
- [x] ファイルサイズが改善（TrainSelectionView: 1014行→606行）
- [x] 重複コードが削除されている
- [x] ビルドが成功する
- [x] 既存機能が正常に動作する

## テスト方法

### 自動テスト
```bash
# SwiftLintチェック
swiftlint

# ビルドチェック
xcodebuild -workspace TrainAlert.xcworkspace -scheme TrainAlert -sdk iphonesimulator build
```

### 手動テスト
1. 時刻表検索機能が正常に動作
2. 列車選択・アラート設定が正常に動作
3. 各画面の表示が崩れていない

## 依存関係
- なし（独立したリファクタリングタスク）

## 成果物
- 更新: `/Views/Timetable/`配下の全ファイル
- 新規: 分割されたコンポーネントファイル
- 更新: `.swiftlint.yml`（必要に応じて）

## 備考
- 機能追加は行わない（純粋なリファクタリング）
- パフォーマンスに影響する変更は慎重に
- チーム内でコーディング規約を確認する
