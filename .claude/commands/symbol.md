---
description: serenaでコードシンボルを検索・操作
argumentHints: "[find|overview|references|replace] [symbol-name] [options]"
---

# シンボル操作コマンド

アクション: $ARGUMENTS

serenaのシンボル検索機能を使用して、コードベース内のシンボルを効率的に操作します。

## 使用例
- `/symbol find Station` - Stationという名前のシンボルを検索
- `/symbol overview TrainAlert/Models/` - Modelsディレクトリのシンボル概要
- `/symbol references LocationManager` - LocationManagerの参照箇所を検索
- `/symbol replace Alert/isActive "var isActive: Bool" "let isActive: Bool"` - シンボルの置換

引数に応じて適切なserenaツールを使用:

1. **find**: `mcp__serena__find_symbol`を使用
   - 名前パスでシンボルを検索
   - 深さ指定で子要素も取得可能
   - include_body=trueで実装も表示

2. **overview**: `mcp__serena__get_symbols_overview`を使用
   - ディレクトリ/ファイルのトップレベルシンボル一覧
   - アーキテクチャ理解に最適

3. **references**: `mcp__serena__find_referencing_symbols`を使用
   - 指定シンボルを参照している箇所を検索
   - リファクタリング前の影響調査

4. **replace**: `mcp__serena__replace_symbol_body`を使用
   - シンボル全体を効率的に置換
   - 安全なリファクタリング