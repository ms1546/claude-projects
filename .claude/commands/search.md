---
description: serenaの高度な検索機能
argumentHints: "[pattern] [--file <pattern>] [--exclude <pattern>] [--context <n>]"
---

# 高度な検索コマンド

検索パターン: $ARGUMENTS

serenaの`search_for_pattern`ツールを使用した柔軟な検索を実行します。

## 使用例
- `/search "class.*Alert"` - Alertで終わるクラスを検索
- `/search "TODO|FIXME" --file "*.swift"` - SwiftファイルのTODO/FIXMEを検索
- `/search "LocationManager" --exclude "*Test*" --context 3` - テスト以外でLocationManagerを検索（前後3行表示）

## オプション
- `--file <pattern>`: 検索対象ファイルパターン（例: "*.swift", "**/*.md"）
- `--exclude <pattern>`: 除外ファイルパターン
- `--context <n>`: マッチ前後の表示行数
- `--code-only`: コードファイルのみ検索

serenaツール`mcp__serena__search_for_pattern`を使用して:
1. 正規表現パターンでの高度な検索
2. ファイルパターンによる絞り込み
3. コンテキスト付き結果表示
4. 非コードファイル（yaml, json等）も検索可能

検索結果をわかりやすく整形して表示します。
