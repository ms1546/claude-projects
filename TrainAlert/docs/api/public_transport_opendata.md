# 公共交通オープンデータセンター API仕様

## 概要
公共交通オープンデータセンターは、日本の鉄道事業者が提供する時刻表・運行情報を統一的に提供するAPIサービス。

## 申請状況
- 申請日: （記入予定）
- 承認予定日: （記入予定）
- ステータス: 申請中

## 提供データ

### 1. 静的データ（GTFS形式）
- 駅情報（stations.txt）
- 路線情報（routes.txt）
- 時刻表情報（stop_times.txt）
- 運行カレンダー（calendar.txt）

### 2. 動的データ（GTFS-RT形式）
- リアルタイム運行情報
- 遅延情報
- 運休情報
- 位置情報

## API仕様（予定）

### エンドポイント
```
https://api.odpt.org/api/v4/
```

### 認証
- APIキーによる認証
- ヘッダー: `x-api-key: YOUR_API_KEY`

### 主要なAPI

#### 1. 駅情報取得
```
GET /odpt:Station
```

#### 2. 時刻表取得
```
GET /odpt:StationTimetable?odpt:station={駅ID}
```

#### 3. 運行情報取得
```
GET /odpt:TrainInformation
```

#### 4. 列車位置情報
```
GET /odpt:Train
```

## 実装時の注意事項

1. **レート制限**
   - 1秒あたり10リクエストまで
   - 1日あたり10万リクエストまで

2. **キャッシュポリシー**
   - 静的データ: 24時間キャッシュ推奨
   - 動的データ: 30秒〜1分キャッシュ

3. **エラーハンドリング**
   - 429: レート制限超過
   - 503: メンテナンス中

## 参考リンク
- [公共交通オープンデータセンター](https://www.odpt.org/)
- [開発者向けドキュメント](https://developer-dc.odpt.org/)
- [API利用規約](https://www.odpt.org/terms-of-use/)