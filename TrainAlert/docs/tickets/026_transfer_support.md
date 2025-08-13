# チケット #026: 乗り換え対応機能

## 概要
乗り換えが必要な経路で、乗り換え駅での通知機能を実装する（シンプル版）。

## 要件
1. **乗り換え設定**
   - 複数の電車を連続して設定
   - 乗り換え駅の指定

2. **乗り換え通知**
   - 乗り換え駅到着時に「乗り換えてください」と通知
   - 次の電車情報を表示

3. **UI**
   - 乗り換え経路の視覚的表示
   - 各区間の設定

## 技術仕様
### データモデル
```swift
struct TransferRoute {
    let sections: [RouteSection]
    let transferStations: [Station]
}

struct RouteSection {
    let train: TrainInfo
    let departureStation: Station
    let arrivalStation: Station
}
```

## 実装タスク
- [ ] 乗り換え経路データモデル
- [ ] 複数区間の設定UI
- [ ] 乗り換え駅での通知ロジック
- [ ] 経路全体の表示UI
- [ ] Core Dataモデル拡張

## 受け入れ条件
- [ ] 乗り換え経路を設定できる
- [ ] 乗り換え駅で通知が来る
- [ ] 次の電車情報が確認できる
- [ ] 全体の経路が視覚的に分かる

## ステータス: [ ] Not Started / [ ] In Progress / [ ] Completed

## 見積もり工数
16時間

## 依存関係
- チケット#022（基本実装）
