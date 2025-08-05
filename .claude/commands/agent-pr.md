---
description: Agent作業のPR自動作成
argumentHints: "[agent-name]"
---

# Agent PR自動作成

Agent: $ARGUMENTS

指定されたagentのワークスペースから自動的にPRを作成します。

## 処理内容

1. Agentのワークスペースを特定
2. 変更をコミット・プッシュ
3. チケット情報からPR作成
4. レビュアー自動設定

## 実行例
- `/agent-pr agent1` - agent1の作業をPR化
- `/agent-pr` - 現在のディレクトリから推定

引数に応じて実行:

```bash
# Agent名が指定された場合
if [ -n "$ARGUMENTS" ]; then
    agent_name="$ARGUMENTS"
    workspace_path=".worktrees/$agent_name"
    
    if [ ! -d "$workspace_path" ]; then
        echo "❌ $agent_name のワークスペースが見つかりません"
        exit 1
    fi
    
    # Agent設定から情報取得
    config_file=".claude/agent_config/${agent_name}.json"
    if [ -f "$config_file" ]; then
        ticket_num=$(jq -r '.ticket' "$config_file")
        echo "🤖 $agent_name (チケット #$ticket_num) のPRを作成"
    fi
    
    # ワークスペースで実行
    cd "$workspace_path"
fi

# 自動PR作成スクリプトを実行
!../scripts/auto_git_pr.sh $ticket_num "" true
```

## Agent間の調整

PRを作成する前に、依存関係をチェック:

```bash
# 依存チケットの確認
!./scripts/agent_coordinator.sh check $ticket_num

# 全agentの状況確認
!./scripts/agent_coordinator.sh pr-check
```

これにより、agent作業を簡単にPR化できます。
