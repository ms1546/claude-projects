# チケット #034: TimetableSearchViewのリファクタリング

## 概要
TimetableSearchView.swiftの複雑度エラーを解消し、ファイルサイズを適切なサイズに分割する。チケット#033で残った最後のSwiftLintエラーを解決する。

## 優先度
High - 技術的負債の解消とコード品質の向上

## 見積もり
8-10時間

## ステータス
[ ] Not Started / [ ] In Progress / [x] Completed

## 実装完了日
2025-08-18

## 実装の詳細
- TimetableSearchView.swiftを822行から443行に削減（46%削減）
- SwiftLintエラーを2個から0個に削減
- 以下のコンポーネントを分離：
  - TimetableStationSearchView.swift（時刻表用駅検索）
  - TrainRowView.swift（電車行表示）
  - DirectionTabView.swift（方向選択タブ）
- getRailwayDisplayName関数の重複を削除し、Railway+Localization.swiftに統合
- ビルドエラーを修正（Railway+Localization.swiftをUtilities/Extensions/に移動）

## 背景
- チケット#033でSwiftLintエラーを59個から2個まで削減
- 残りの2個のエラーはTimetableSearchView.swiftの循環的複雑度違反
- 現在のファイルサイズ：822行（推奨：500行以下）

## タスクリスト

### SwiftLintエラー修正（必須）
- [x] getRailwayJapaneseName関数の複雑度削減（cyclomatic_complexity: 26）
- [x] formatTrainType関数の複雑度削減（cyclomatic_complexity: 26）

### ファイル分割
- [x] TimetableSearchView.swift（822行）を適切なサイズに分割
  - [x] StationSearchSection を別ファイルに分離
  - [x] DirectionTabView を別ファイルに分離
  - [x] TrainRowView を別ファイルに分離
  - [ ] TimetableListView を別ファイルに分離

### コンポーネント化
- [x] 駅検索セクションのコンポーネント化
- [x] 方向選択タブのコンポーネント化
- [x] 列車行表示のコンポーネント化
- [ ] 時刻表リストのコンポーネント化

### ヘルパー関数の整理
- [ ] 時刻フォーマット処理を別ファイルに移動
- [x] 列車種別フォーマット処理を別ファイルに移動
- [x] 路線名処理をRailway+Localization.swiftに統合

## 実装ガイドライン

### ファイル構成案
```
Views/Timetable/
├── TimetableSearchView.swift（メインビュー：300行以下）
├── Components/
│   ├── StationSearchSection.swift
│   ├── DirectionTabView.swift
│   ├── TrainRowView.swift
│   └── TimetableListView.swift
└── Helpers/
    ├── TrainTypeFormatter.swift
    └── TimeFormatter.swift
```

### リファクタリング方針
1. 各コンポーネントは単一の責任を持つ
2. プロトコルを使用して依存性を管理
3. ViewModelとViewの責任を明確に分離
4. 再利用可能なコンポーネントとして設計

## 完了条件（Definition of Done）
- [x] SwiftLintエラーが0件
- [x] TimetableSearchView.swiftが500行以下
- [x] 各分割ファイルが300行以下
- [x] ビルドが成功する
- [x] 既存の時刻表検索機能が正常に動作する
- [ ] 単体テストがすべてパス

## テスト方法

### 自動テスト
```bash
# SwiftLintチェック
swiftlint

# ビルドチェック
xcodebuild -workspace TrainAlert.xcworkspace -scheme TrainAlert -sdk iphonesimulator build
```

### 手動テスト
1. 駅検索機能の動作確認
2. 方向切り替えの動作確認
3. 時刻表表示の正確性確認
4. 列車選択から通知設定までのフロー確認

## 依存関係
- チケット#033（完了済み）

## 成果物
- リファクタリング後の`TimetableSearchView.swift`
- 新規作成されるコンポーネントファイル群
- 更新された`Railway+Localization.swift`

## 備考
- UIの変更は行わない（純粋なリファクタリング）
- パフォーマンスへの影響を最小限に抑える
- 将来の機能拡張を考慮した設計にする
