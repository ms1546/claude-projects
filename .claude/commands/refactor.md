---
description: serenaを使った安全なリファクタリング
argumentHints: "[regex|symbol] [target] [replacement] [--preview]"
---

# リファクタリングコマンド

モード: $ARGUMENTS

serenaの強力なリファクタリング機能を使用して、コードを安全に変更します。

## 使用例
- `/refactor regex "print\\((.*?)\\)" "debugPrint(\\1)" --preview` - print文をdebugPrintに変換（プレビュー）
- `/refactor symbol Station/name "var name: String" "let name: String"` - シンボル単位で変更
- `/refactor regex "TODO:.*" "" --multiple` - TODO コメントを一括削除

## リファクタリングモード

### 1. regex（正規表現）
`mcp__serena__replace_regex`を使用:
- 柔軟な文字列置換
- ワイルドカード使用推奨
- 複数マッチ対応

### 2. symbol（シンボル単位）
`mcp__serena__replace_symbol_body`を使用:
- メソッド/クラス全体の置換
- 安全で確実な変更
- インデント自動調整

## オプション
- `--preview`: 実行前に変更内容を確認
- `--multiple`: 複数箇所の一括変更を許可

リファクタリング前に:
1. 影響範囲を`find_referencing_symbols`で確認
2. プレビューモードで変更内容を検証
3. 実行後にテストを実行
