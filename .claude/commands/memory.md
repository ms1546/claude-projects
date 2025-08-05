---
description: serenaのメモリ機能でプロジェクト情報を管理
argumentHints: "[write|read|list|delete] [memory-name] [content]"
---

# プロジェクトメモリ管理

アクション: $ARGUMENTS

serenaのメモリ機能を使用してプロジェクト固有の情報を永続化します。

## 使用例
- `/memory write architecture "MVVMパターンを採用、SwiftUI使用"` - アーキテクチャ情報を保存
- `/memory read architecture` - 保存した情報を読み込み
- `/memory list` - 全メモリ一覧表示
- `/memory delete old-notes` - 不要なメモリを削除

## メモリの活用例
1. **アーキテクチャ決定事項**
   - デザインパターン
   - 技術スタック
   - 依存関係

2. **実装メモ**
   - 複雑な処理の説明
   - バグ修正履歴
   - TODO管理

3. **API情報**
   - エンドポイント一覧
   - 認証方法
   - レスポンス形式

serenaのメモリツールを使用:
- `mcp__serena__write_memory`: 情報の保存
- `mcp__serena__read_memory`: 情報の読み込み
- `mcp__serena__list_memories`: 一覧表示
- `mcp__serena__delete_memory`: 削除

プロジェクトの重要情報を整理して管理できます。