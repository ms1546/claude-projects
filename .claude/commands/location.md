---
description: 位置情報機能のデバッグとテスト
argumentHints: "[simulate|permission|accuracy|battery]"
---

# 位置情報デバッグコマンド

デバッグ対象: $ARGUMENTS

## 位置情報シミュレーション
1. Xcodeのロケーションシミュレーターを使用:
   - 東京駅から新宿駅への移動をシミュレート
   - バックグラウンドでの位置更新を確認

## 権限チェック
```swift
// 現在の権限状態を確認
!grep -r "requestWhenInUseAuthorization\|requestAlwaysAuthorization" TrainAlert/
```

## 精度とバッテリー最適化
@TrainAlert/Services/LocationManager.swift を確認し:
- 距離に応じた精度調整が実装されているか
- バックグラウンドでの更新頻度が適切か
- 省電力モードの対応状況

## テストケース実行
1. 権限拒否時の動作
2. GPS無効時の動作
3. バックグラウンド移行時の動作
4. 駅接近時の通知タイミング

問題があれば修正案を提示します。
