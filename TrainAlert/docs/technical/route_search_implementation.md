# 経路検索の実装方法

## 現状の制限

1. **ODPT APIには経路検索APIがない**
   - 駅時刻表API: 各駅の出発時刻のみ
   - 列車時刻表API: 特定列車の各駅到着・出発時刻

2. **現在の実装**
   - 同一路線内のみ対応
   - 到着時刻は仮の値（30分後）
   - 乗換案内なし

## 到着時刻を正確に取得する方法

### 方法1: TrainTimetable APIを使用

```swift
// 1. StationTimetableで列車番号を取得
let trainNumber = stationTimetable.stationTimetableObject[0].trainNumber

// 2. TrainTimetableで到着時刻を取得
let trainTimetable = await apiClient.getTrainTimetable(
    trainNumber: trainNumber,
    railwayId: railwayId
)

// 3. 目的駅の到着時刻を探す
for stop in trainTimetable.trainTimetableObject {
    if stop.arrivalStation == targetStationId {
        let arrivalTime = stop.arrivalTime // これが正確な到着時刻
    }
}
```

### 方法2: 事前計算された所要時間データベース

主要駅間の標準所要時間をデータベース化（ローカルに保存）

## 複数路線の経路検索を実現する方法

### 方法1: グラフ探索アルゴリズム（推奨）

```swift
// 1. 全駅をノード、隣接駅をエッジとしたグラフを構築
struct StationGraph {
    let stations: [String: Station]
    let connections: [String: [Connection]]
}

// 2. ダイクストラ法で最短経路を探索
func findRoute(from: String, to: String) -> [Route] {
    // 乗換駅の特定
    // 各路線の時刻表を取得
    // 乗換時間を考慮した経路を計算
}
```

### 方法2: 主要乗換駅を経由した検索

```swift
// 主要乗換駅リスト
let transferStations = [
    "新宿": ["JR山手線", "JR中央線", "小田急線", "京王線"],
    "渋谷": ["JR山手線", "東急東横線", "東京メトロ半蔵門線"],
    // ...
]

// 乗換駅を特定して2区間の検索に分割
```

### 方法3: 外部APIとの併用

- Google Directions API（経路のみ）
- Yahoo!路線情報API（有料）
- 駅すぱあとAPI（有料）

## 実装の優先順位

1. **フェーズ1: 到着時刻の正確化**（1-2週間）
   - TrainTimetable APIの実装
   - 同一路線内での正確な到着時刻表示

2. **フェーズ2: 主要路線間の乗換対応**（2-3週間）
   - 山手線を中心とした乗換データベース構築
   - 1回乗換までの経路検索

3. **フェーズ3: 完全な経路検索**（1-2ヶ月）
   - 全路線のグラフ構築
   - 複数乗換対応
   - 最適経路の計算

## 代替案

現実的な短期実装として：
- **駅間の標準所要時間データベース**を作成
- **主要100駅程度**に限定
- 乗換は**新宿・渋谷・東京**などの主要駅のみ対応