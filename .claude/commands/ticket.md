---
description: TrainAlertプロジェクトのチケット操作
argumentHints: "[start|complete|status|next] [ticket-number]"
---

# チケット管理コマンド

## 使用方法
- `/ticket start 001` - チケット#001の実装を開始
- `/ticket complete 001` - チケット#001を完了
- `/ticket status` - 全チケットの進捗確認
- `/ticket next` - 次に実装可能なチケットを表示

引数: $ARGUMENTS

@TrainAlert/docs/tickets/ticket_status.md を確認し、以下を実行:

1. 指定されたアクションに応じて:
   - `start`: チケットのステータスを"In Progress"に更新し、実装を開始
   - `complete`: チケットのステータスを"Completed"に更新し、ticket_status.mdも更新
   - `status`: 現在の全体進捗をサマリー表示
   - `next`: dependency_graph.mdを参照し、実装可能なチケットをリストアップ

2. チケット更新時は必ず:
   - 該当チケットファイルのステータスを更新
   - ticket_status.mdの進捗を更新
   - 依存関係を確認

3. 実装開始時は:
   - 新しいブランチを作成: `git checkout -b feature/ticket-XXX`
   - 実装ガイドラインを表示
