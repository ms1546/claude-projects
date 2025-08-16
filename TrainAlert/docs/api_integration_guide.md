# API統合ガイド

## 概要

TrainAlertでは、パフォーマンスとデータの完全性のバランスを取るため、2つのAPIを併用しています。

### 使用API

1. **HeartRails Express API**
   - 用途: 駅名検索（高速レスポンス）
   - 特徴: レスポンスが高速で、駅名検索に最適
   - エンドポイント: `http://express.heartrails.com/api/json`

2. **ODPT API（公共交通オープンデータセンター）**
   - 用途: 時刻表データ、詳細な路線情報
   - 特徴: 公式データで信頼性が高いが、レスポンスが遅い
   - エンドポイント: `https://api-tokyochallenge.odpt.org/api/v4/`

## 現在の実装方針

### 駅検索フロー
1. ユーザーが駅名を入力
2. HeartRails APIで高速に駅名検索
3. 検索結果を表示（この時点では時刻表データなし）
4. ユーザーが駅を選択した後、必要に応じてODPT APIから詳細データを取得

### 問題点と解決策

#### 問題: ID形式の不一致

HeartRails APIとODPT APIでは、駅と路線のID形式が異なります：

- **HeartRails**: `heartrails:表参道:東京メトロ千代田線`
- **ODPT**: `odpt.Station:TokyoMetro.Chiyoda.Omotesando`

#### 解決策（実装予定）

1. **IDマッピングテーブルの作成**
   ```swift
   // StationIDMapper.swift
   struct StationIDMapper {
       static let mapping: [String: String] = [
           // HeartRails形式 -> ODPT形式
           "東京メトロ千代田線": "odpt.Railway:TokyoMetro.Chiyoda",
           "JR山手線": "odpt.Railway:JR-East.Yamanote",
           // ... 他の路線
       ]
       
       static func convertToODPTStationID(stationName: String, lineName: String) -> String? {
           // 実装例
           guard let odptRailway = mapping[lineName] else { return nil }
           let romanizedName = romanize(stationName) // ローマ字変換
           return "\(odptRailway).\(romanizedName)"
       }
   }
   ```

2. **段階的データ取得**
   ```swift
   // RouteSearchViewModel.swift
   func searchRoute() async {
       // Step 1: HeartRails APIで駅を高速検索
       let heartRailsStations = try await heartRailsClient.searchStations(name: query)
       
       // Step 2: 必要な駅のみODPT APIで詳細取得
       if let selectedStation = heartRailsStations.first {
           if let odptID = StationIDMapper.convertToODPTStationID(
               stationName: selectedStation.name,
               lineName: selectedStation.line
           ) {
               // ODPT APIで時刻表取得
               let timetable = try await odptClient.getStationTimetable(
                   stationId: odptID,
                   railwayId: odptRailwayID
               )
           }
       }
   }
   ```

3. **キャッシュの活用**
   - 一度取得したマッピング情報はキャッシュ
   - よく使われる駅の時刻表データもキャッシュ

## 実装上の注意点

1. **エラーハンドリング**
   - HeartRails APIが失敗した場合のフォールバック
   - ODPT APIがタイムアウトした場合の処理

2. **パフォーマンス最適化**
   - 必要最小限のAPIコールに留める
   - バックグラウンドでの事前取得は避ける（バッテリー消費）

3. **ユーザー体験**
   - 駅検索は即座に結果を表示（HeartRails）
   - 時刻表データは選択後に取得（ローディング表示）

## 今後の改善案

1. **独自の駅データベース構築**
   - 初回起動時にODPT APIから全駅データを取得
   - ローカルDBに保存して高速検索を実現
   - 定期的な更新処理

2. **路線ごとのAPI使い分け**
   - JR東日本: ekidata.jp APIの検討
   - 私鉄各社: 各社提供のAPIがあれば利用

3. **機械学習による予測**
   - ユーザーの利用パターンから次に検索される駅を予測
   - 事前にデータを取得してキャッシュ

## 関連ファイル

- `/Services/HeartRailsAPIClient.swift` - HeartRails API実装
- `/Services/ODPT/ODPTAPIClient.swift` - ODPT API実装
- `/ViewModels/RouteSearchViewModel.swift` - API統合ロジック