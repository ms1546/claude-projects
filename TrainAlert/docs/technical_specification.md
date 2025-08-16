# TrainAlert 技術仕様書

## 1. システム構成

### 1.1 技術スタック
- **開発言語**: Swift 5.9
- **UI Framework**: SwiftUI
- **最小iOS**: iOS 16.0
- **開発環境**: Xcode 15, M2 Mac

### 1.2 主要ライブラリ・フレームワーク
- **Core Location**: GPS位置情報取得
- **UserNotifications**: ローカル通知
- **MapKit**: 地図表示・駅位置特定
- **Core Data**: データ永続化
- **URLSession**: API通信

### 1.3 外部API
- **HeartRails Express API**: 駅名検索（高速・日本専用）
- **Overpass API (OpenStreetMap)**: 位置情報ベースの最寄り駅検索
- **OpenAI API (ChatGPT)**: 通知メッセージ生成

## 2. 機能仕様

### 2.1 通知タイミング設定

#### デフォルト値
- **時間ベース**: 降車駅到着5分前
- **距離ベース**: 降車駅から2km
- **スヌーズ間隔**: 1分

#### 設定可能範囲
- **時間**: 1分〜30分前（1分単位）
- **距離**: 500m〜5km（500m単位）
- **スヌーズ**: 30秒〜5分（30秒単位）

### 2.2 位置情報更新頻度

| 状態 | 更新間隔 | 精度 |
|------|----------|------|
| 通常時 | 60秒 | kCLLocationAccuracyHundredMeters |
| 降車駅5km圏内 | 30秒 | kCLLocationAccuracyNearestTenMeters |
| 降車駅2km圏内 | 15秒 | kCLLocationAccuracyBest |

### 2.3 AI通知メッセージ

#### キャラクタースタイル
1. **ギャル系** - 明るく元気な口調
2. **執事系** - 丁寧で格式高い口調
3. **関西弁系** - フレンドリーな関西弁
4. **ツンデレ系** - ツンデレキャラ風
5. **体育会系** - 熱血コーチ風
6. **癒し系** - 優しく穏やかな口調

#### メッセージ生成仕様
- **API**: OpenAI GPT-3.5-turbo
- **トークン上限**: 100トークン/メッセージ
- **キャッシュ**: 生成したメッセージを30日間保存
- **オフライン対応**: キャッシュから類似メッセージを表示

#### プロンプト例
```
あなたは{スタイル}のキャラクターです。
電車で寝ている人を起こすメッセージを20文字以内で生成してください。
状況: {駅名}まであと{時間}分
```

### 2.4 データ保存仕様

#### Core Dataエンティティ

**Station（駅情報）**
- stationId: String
- name: String
- latitude: Double
- longitude: Double
- lines: [String]

**Alert（アラート設定）**
- alertId: UUID
- station: Station
- notificationTime: Int（分）
- notificationDistance: Double（km）
- snoozeInterval: Int（秒）
- characterStyle: String
- isActive: Bool
- createdAt: Date

**History（履歴）**
- historyId: UUID
- alert: Alert
- notifiedAt: Date
- message: String

#### 保存制限
- アラート履歴: 最新100件
- お気に入り駅: 最大20件
- AIメッセージキャッシュ: 1000件

## 3. API仕様

### 3.1 駅検索API

#### HeartRails Express API（駅名検索用）
- **用途**: 駅名による高速検索
- **特徴**: 日本の駅専用、レスポンス1秒以内
- **制限**: なし（無料）

**駅名検索**
```
GET http://express.heartrails.com/api/json?method=getStations&name={station_name}
```

**レスポンス例**
```json
{
  "response": {
    "station": [{
      "name": "読売ランド前",
      "line": "小田急小田原線",
      "x": 139.518788,
      "y": 35.635013
    }]
  }
}
```

#### Overpass API（位置情報検索用）
- **用途**: 現在地から最寄り駅検索
- **特徴**: OpenStreetMapベース、全世界対応
- **制限**: 無料だがサーバー負荷により遅延あり

**最寄り駅検索**
```
POST https://overpass-api.de/api/interpreter
data=[out:json][timeout:25];
(
  node[railway=station](around:2000,{latitude},{longitude});
  way[railway=station](around:2000,{latitude},{longitude});
);
out center;
```

### 3.2 OpenAI API

**メッセージ生成**
```swift
let request = ChatCompletionRequest(
    model: "gpt-3.5-turbo",
    messages: [
        .system("あなたは\(style)のキャラクターです"),
        .user("降車駅まで\(minutes)分。20文字以内で起こして")
    ],
    maxTokens: 100,
    temperature: 0.8
)
```

## 4. バックグラウンド処理

### 4.1 Background Modes
- Location updates
- Background fetch
- Remote notifications（将来拡張用）

### 4.2 バッテリー最適化
- 重要度の低い更新はバッチ処理
- 画面オフ時は更新頻度を削減
- Low Power Mode検出時は最小限の動作

## 5. エラー処理

### 5.1 位置情報エラー
- GPS無効: 時刻ベース通知のみ動作
- 精度低下: 最後の有効位置を使用

### 5.2 API通信エラー
- 駅情報API: オフラインDBフォールバック
- ChatGPT API: プリセットメッセージ使用

### 5.3 通知配信エラー
- 権限なし: アプリ内アラート表示
- 配信失敗: 最大3回リトライ

## 6. セキュリティ

### 6.1 APIキー管理
- OpenAI APIキー: Keychainに暗号化保存
- ユーザー入力による設定

### 6.2 プライバシー
- 位置情報: 端末内処理のみ
- 履歴データ: iCloud同期なし（ローカルのみ）

## 7. パフォーマンス目標

- アプリ起動: 2秒以内
- 駅名検索（HeartRails）: 1秒以内
- 最寄り駅検索（Overpass）: 5秒以内
- 通知配信遅延: 10秒以内
- バッテリー消費: 1時間あたり5%以下

## 8. API選定理由

### 8.1 駅検索APIの使い分け
- **駅名検索**: HeartRails Express API
  - タイムアウトエラーが発生しない
  - 日本の駅に特化した高速レスポンス
  - 駅名の別名対応（例：読売ランド→読売ランド前）
  
- **位置情報検索**: Overpass API
  - 緯度経度から最寄り駅を検索可能
  - OpenStreetMapの豊富な地理データを活用
  - 無料で利用可能だが、レスポンスが遅い場合あり
