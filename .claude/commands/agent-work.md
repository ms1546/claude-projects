---
description: Agent用ワークスペース管理
argumentHints: "[setup|create|switch|status|sync] [agent-name] [ticket-number]"
---

# Agent ワークスペース管理

アクション: $ARGUMENTS

Git worktreeを使用して、複数のagentが同時に異なるチケットを開発できる環境を管理します。

## 使用例
- `/agent-work setup` - 初期セットアップ
- `/agent-work create agent1 001` - agent1用にチケット#001のワークスペース作成
- `/agent-work switch agent1` - agent1のワークスペースに切り替え
- `/agent-work status` - 全agentの進捗確認
- `/agent-work sync agent1` - mainブランチの変更を同期

## ワークフロー

### 1. 新しいAgentタスク開始
```bash
# 実装可能なチケットを確認
!./scripts/agent_workspace.sh status

# ワークスペース作成
!./scripts/agent_workspace.sh create agent1 001
```

### 2. 開発作業
```bash
# ワークスペースに移動
!cd .worktrees/agent1

# 開発を実施
# ...

# 進捗を確認
!git status
```

### 3. 他のAgentとの調整
```bash
# 全体の状況確認
!./scripts/agent_workspace.sh status

# mainの変更を取り込み
!./scripts/agent_workspace.sh sync agent1
```

### 4. PR作成
```bash
# ワークスペースから直接PR作成
!cd .worktrees/agent1 && ../scripts/create_pr.sh 001
```

## 並行開発の例
- Agent1: #001 プロジェクトセットアップ
- Agent2: #002 デザインシステム
- Agent3: #004 位置情報サービス
- Agent4: #005 通知システム

各agentは独立したワークスペースで作業し、お互いに干渉しません。