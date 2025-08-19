# チケット #035: お気に入り経路機能のバグ修正

## 概要
お気に入り経路機能に関する複数のバグを修正する。

## 優先度
Medium - 機能は動作するがUXに影響する

## 見積もり
4-6時間

## ステータス
[ ] Not Started / [ ] In Progress / [x] Completed

## 実装完了日
2025-08-19

## 実装の詳細
- FavoriteRouteManagerにtoggleFavoriteとfindFavoriteRouteメソッドを追加
- RouteSearchViewModelにtoggleFavoriteRouteメソッドを追加
- RouteSearchViewのお気に入りボタンをトグル動作に変更、disabledの条件を修正
- FavoriteRoutesViewのカードスタイルをRouteSearchViewと統一（影の濃度、背景色）
- HomeViewのHomeAlertCardで路線名表示にrailwayDisplayNameを適用
- ビルドエラーなく全ての修正が完了

## バグ詳細

### 1. お気に入り解除ができない
- **現象**: 経路検索でお気に入りにした経路について、もう一度お気に入りマークを押してもお気に入り解除されない
- **期待する動作**: お気に入りマークをタップすることでお気に入りの登録/解除がトグルする
- **影響範囲**: RouteSearchView、FavoriteRouteManager

### 2. お気に入り経路のUI統一性
- **現象**: お気に入り経路のUIが白背景の部分（カード？）があり、見えにくく統一感がない
- **期待する動作**: アプリ全体のデザインシステムに準拠した統一感のあるUI
- **影響範囲**: FavoriteRoutesView

### 3. 路線名の日本語表記
- **現象**: 目覚まし一覧で出る路線名が日本語表記になっていないものがある
- **期待する動作**: すべての路線名が日本語で表示される
- **影響範囲**: HomeView、AlertListItem

## タスクリスト

### バグ1: お気に入り解除機能
- [x] FavoriteRouteManagerのトグル機能を確認
- [x] RouteSearchViewのお気に入りボタンのロジックを修正
- [x] お気に入り状態の更新が正しく反映されるか確認

### バグ2: UI統一性
- [x] FavoriteRoutesViewのカードコンポーネントを確認
- [x] backgroundColorをbackgroundPrimary/backgroundSecondaryに統一
- [x] カードのスタイルをDesignSystemのCardコンポーネントに準拠

### バグ3: 路線名日本語化
- [x] HomeViewで使用している路線名表示部分を特定
- [x] String+Railway.swiftのrailwayDisplayNameを使用するよう修正
- [x] すべての路線名が正しく日本語化されることを確認

## 実装ガイドライン

### お気に入り解除の実装例
```swift
// FavoriteRouteManager
func toggleFavorite(route: RouteInfo) {
    if isFavorite(route) {
        removeFavorite(route)
    } else {
        addFavorite(route)
    }
}
```

### UI統一性の改善例
```swift
// 統一されたカードスタイル
Card {
    // コンテンツ
}
.background(Color.backgroundCard)
.shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
```

### 路線名日本語化の適用例
```swift
// Before
Text(railway)

// After
Text(railway.railwayDisplayName)
```

## 完了条件（Definition of Done）
- [x] お気に入りのトグル機能が正常に動作する
- [x] UIがアプリ全体で統一されている
- [x] すべての路線名が日本語で表示される
- [x] ビルドが成功する
- [x] 既存機能への影響がない

## テスト方法

### 手動テスト
1. 経路検索でお気に入り登録/解除の動作確認
2. お気に入り一覧画面のUI確認
3. ホーム画面の路線名表示確認

## 依存関係
- なし（独立したバグ修正タスク）

## 成果物
- 修正された各Viewファイル
- 必要に応じて更新されたViewModelファイル

## 備考
- UI変更は既存のデザインシステムに準拠する
- 路線名の日本語化はString+Railway.swiftの既存実装を活用する
