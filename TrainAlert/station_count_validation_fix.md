# 駅数ベースアラートのバリデーション修正

## 修正内容

### 1. バリデーションエラーの修正
**問題**: 駅数ベースのアラートで`notificationDistance = 0`を設定すると、バリデーションエラーが発生

**解決**: Alert+CoreDataClass.swiftの`validateAlert()`メソッドを修正
- `notificationType == "station"`の場合は距離の検証をスキップ
- 新しいエラーケース`invalidNotificationStations`を追加

### 2. 駅数選択の最適化
**変更前**: 1〜5駅前から選択
**変更後**: 1〜3駅前から選択（一般的な利用ケースに合わせて）

### 3. UIの改善
- 「実際の駅数より多い設定は通知されません」の注意書きを追加
- 保存ボタンの有効化条件を修正（駅数ベースも考慮）

## 実装詳細

### Core Dataバリデーション
```swift
if notificationType == "station" {
    // 駅数ベースの場合
    guard notificationStationsBefore >= 1 && notificationStationsBefore <= 10 else {
        throw AlertValidationError.invalidNotificationStations
    }
} else {
    // 時間ベースまたは距離ベースの場合
    // 距離は0より大きい場合のみ検証
    if notificationDistance > 0 {
        guard notificationDistance >= 50 && notificationDistance <= 10000 else {
            throw AlertValidationError.invalidNotificationDistance
        }
    }
}
```

## 今後の改善案

### 駅数の動的制限
現在は仮実装で1〜3駅前を表示していますが、将来的には：
1. ODPT APIから駅順情報を取得
2. 実際の経路の駅数を計算
3. 選択可能な駅数を動的に制限

例：東京→新宿が3駅なら、1〜2駅前のみ選択可能にする

## テスト確認
- ビルドエラー：なし ✅
- 駅数ベースのアラート作成：成功 ✅
- バリデーションエラー：解消 ✅