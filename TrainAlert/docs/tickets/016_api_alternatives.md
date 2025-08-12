# 無料駅検索API調査結果

## 1. 駅すぱあとWebサービス フリープラン
- **URL**: https://docs.ekispert.com/v1/
- **制限**: 1日50リクエストまで
- **特徴**: 
  - 駅名検索機能あり
  - 路線情報も取得可能
  - 申請が必要

## 2. 路線.jp API
- **URL**: http://www.roote.jp/api/
- **制限**: 商用利用不可
- **特徴**:
  - 駅名検索可能
  - シンプルなAPI

## 3. simpleapi.net 駅検索API
- **URL**: https://www.simpleapi.net/
- **制限**: 無料プランあり（リクエスト数制限）
- **特徴**:
  - RESTful API
  - JSONレスポンス
  - 駅名検索対応

## 4. 国土交通省 国土数値情報ダウンロードサービス
- **URL**: https://nlftp.mlit.go.jp/
- **特徴**:
  - 完全無料
  - 全国の駅データ
  - XMLまたはGeoJSON形式
  - ダウンロードして使用（API提供なし）

## 5. OpenStreetMap Overpass API
- **URL**: https://overpass-api.de/
- **特徴**:
  - 完全無料
  - 世界中のデータ
  - 駅検索可能
  - クエリ言語を使用

## 推奨案: simpleapi.net

### 実装例
```swift
// 駅名検索
https://www.simpleapi.net/api/v1/station/search?name=東京

// レスポンス例
{
  "stations": [
    {
      "id": "1",
      "name": "東京",
      "latitude": 35.6812,
      "longitude": 139.7671,
      "lines": ["JR山手線", "JR中央線", ...]
    }
  ]
}
```

### 利点
- 駅名検索APIが直接提供されている
- JSONレスポンスで扱いやすい
- 無料プランで趣味利用には十分

### 注意点
- APIキーの取得が必要
- レート制限あり（無料プランの場合）