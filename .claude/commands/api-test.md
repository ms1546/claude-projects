---
description: HeartRails APIとOpenAI APIのテスト
argumentHints: "[heartrails|openai|both] [optional-params]"
---

# API動作確認コマンド

APIタイプ: $ARGUMENTS

指定されたAPIの動作確認を実行:

## HeartRails Express API
```bash
# 東京駅周辺の駅を検索
!curl -s "http://express.heartrails.com/api/json?method=getStations&x=139.7671&y=35.6812" | jq .

# 路線情報を取得
!curl -s "http://express.heartrails.com/api/json?method=getLines&area=関東" | jq .
```

## OpenAI API
1. @TrainAlert/Services/OpenAIService.swift を確認
2. APIキーが設定されているか確認
3. テストメッセージ生成:
   - ギャル系キャラでメッセージ生成
   - レスポンス時間を計測
   - トークン使用量を確認

## 結果分析
- APIレスポンスの構造を解析
- エラーがあれば対処法を提示
- 実装時の注意点をまとめる
