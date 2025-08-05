---
description: 通知機能のテストとデバッグ
argumentHints: "[test|schedule|clear|debug]"
---

# 通知デバッグコマンド

アクション: $ARGUMENTS

## 通知テスト
1. ローカル通知の即時テスト:
   - 各キャラクタースタイルでサンプル通知を配信
   - バイブレーションパターンを確認
   - サウンド設定を確認

2. スケジュール通知のテスト:
   - 5秒後、30秒後、1分後に通知を設定
   - バックグラウンドでの配信を確認

## デバッグ情報
```bash
# 通知権限の状態を確認
!grep -A 10 "UNUserNotificationCenter" TrainAlert/Services/NotificationManager.swift
```

## よくある問題と対処
- 通知が表示されない → 権限設定、フォアグラウンド状態を確認
- バイブレーションが動作しない → Haptic Feedbackの実装を確認
- スヌーズが機能しない → 通知IDの管理を確認

問題を特定し、修正コードを提供します。