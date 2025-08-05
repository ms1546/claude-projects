---
description: Swift/iOSのテストを実行
argumentHints: "[unit|ui|all|specific-test-name]"
---

# Swiftテスト実行コマンド

テストタイプ: $ARGUMENTS

以下のテストコマンドを実行:

1. 引数に応じて適切なテストを実行:
   - `unit`または引数なし: `!xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TrainAlertTests`
   - `ui`: `!xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TrainAlertUITests`
   - `all`: `!xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'`
   - 特定のテスト名: `!xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TrainAlertTests/$ARGUMENTS`

2. テスト結果を分析し、失敗があれば:
   - エラー内容を詳しく説明
   - 修正案を提示
   - 関連するコードを確認

3. カバレッジレポートがあれば表示