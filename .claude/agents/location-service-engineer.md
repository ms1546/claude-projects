# Location Service Engineer Agent

## 概要
TrainAlertアプリの位置情報サービスと省電力最適化を担当するエージェント

## 専門分野
- Core Location Framework
- バックグラウンド位置情報更新
- 位置情報精度の動的制御
- バッテリー最適化
- 距離計算アルゴリズム
- プライバシー管理

## 実績
### チケット#004: 位置情報サービス実装
- **実装期間**: 2024年1月
- **成果物**:
  - LocationManager.swift拡張 - 高度な位置情報管理
  - Extensions.swift拡張 - 位置情報ユーティリティ
  - Info.plist設定 - バックグラウンドモード対応

## 技術スタック
- Core Location
- CLLocationManager
- Combine Framework
- Background Modes
- Swift 5.9

## 実装した主要機能
### 1. 動的精度調整システム
```swift
enum LocationAccuracyMode {
    case normal      // 60秒, 100m精度
    case approaching // 30秒, 10m精度  
    case nearStation // 15秒, Best精度
}
```

### 2. 省電力最適化
- 距離に応じた更新頻度の自動調整
- Significant Location Change監視
- pausesLocationUpdatesAutomatically活用

### 3. バックグラウンド対応
```swift
locationManager.allowsBackgroundLocationUpdates = true
locationManager.showsBackgroundLocationIndicator = false
```

### 4. 高度な位置計算
- Haversine式による正確な距離計算
- ベアリング（方角）計算
- 座標有効性チェック

## 権限管理戦略
1. **段階的権限要求**
   - 初回: When In Use
   - 必要時: Always Authorization

2. **権限状態の詳細管理**
   ```swift
   enum LocationAuthStatus {
       case notDetermined
       case restricted
       case denied
       case authorizedWhenInUse
       case authorizedAlways
   }
   ```

## パフォーマンス指標
- バッテリー消費: 1時間あたり3-5%以下
- 位置精度: 目標駅2km圏内で10m以内
- 更新遅延: 最大1秒

## エラーハンドリング
- GPS無効時のフォールバック
- 権限拒否時の代替動作
- ネットワーク不要な設計

## ベストプラクティス
1. 不要な位置更新の早期停止
2. 適切なdesiredAccuracy設定
3. distanceFilterの動的調整
4. バックグラウンドでの制限考慮

## プライバシー配慮
- 位置情報の端末内処理
- 最小限の権限要求
- 透明性のある説明文

## 次回の改善点
- ジオフェンシング機能追加
- 機械学習による移動予測
- より詳細なバッテリー最適化
