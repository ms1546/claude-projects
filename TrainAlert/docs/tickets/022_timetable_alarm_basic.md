# チケット #022: 時刻表連携アラーム機能（基本実装）

## 概要
時刻表から具体的な電車を選択して、到着時刻の○分前に通知する基本機能を実装する。

## 背景
現在の実装（チケット#018）は経路検索ベースだが、ユーザーは具体的な電車（何時何分発）を選んで通知を設定したい。

## 要件
### 基本機能
1. **電車選択フロー**
   - 出発駅を選択
   - 時刻表から電車を選択（発車時刻、種別、行き先）
   - 到着駅を選択
   - 通知タイミング設定（到着○分前）

2. **時刻表表示**
   - 始発〜終電まで表示
   - 現在時刻周辺を優先表示
   - 時間帯での絞り込み

3. **通知機能**
   - 到着予定時刻の○分前に通知
   - プッシュ通知、アラーム音、バイブ

## 技術仕様
### 新規画面
- `TimetableSearchView`: 時刻表から電車を選択
- `TrainSelectionView`: 電車の詳細選択
- `TimetableAlarmSetupView`: 通知設定（修正版）

### APIエンドポイント
```
GET /api/v4/odpt:StationTimetable
?acl:consumerKey={API_KEY}
&odpt:station={駅ID}
&odpt:railDirection={方向}
&odpt:calendar={平日/土休日}
```

### データモデル
```swift
// 時刻表データ
struct StationTimetable {
    let station: String
    let railway: String
    let trainTimetables: [TrainDeparture]
}

struct TrainDeparture {
    let departureTime: String // "HH:mm"
    let trainType: String // "各停", "快速", etc
    let destinationStation: String
    let trainNumber: String
}
```

## 実装タスク
- [ ] ODPT StationTimetable APIクライアント実装
- [ ] 時刻表データモデル定義
- [ ] 時刻表表示UI（TimetableSearchView）
- [ ] 電車選択UI（TrainSelectionView）
- [ ] Core Dataモデル拡張（TimetableAlert）
- [ ] 通知スケジューリング機能
- [ ] 現在時刻周辺の優先表示ロジック
- [ ] 時間帯フィルタリング機能

## 受け入れ条件
- [ ] 出発駅の時刻表が表示される
- [ ] 電車を選択できる（時刻、種別、行き先）
- [ ] 到着駅を選択できる
- [ ] 通知タイミングを設定できる（1〜30分前）
- [ ] 設定した時刻に通知が来る
- [ ] 現在時刻に近い電車が上部に表示される

## ステータス: [ ] Not Started / [ ] In Progress / [ ] Completed

## 見積もり工数
16時間

## 依存関係
- チケット#018（時刻表連携機能の実装）- 完了済み
