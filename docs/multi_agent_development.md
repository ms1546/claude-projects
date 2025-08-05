# 複数Agent同時開発ガイド

## 概要

Git worktreeを使用して、複数のagentが同時に異なるチケットを開発できる環境を提供します。
各agentは独立したワークスペースで作業し、依存関係を管理しながら効率的に開発を進められます。

## アーキテクチャ

```
claude-projects/
├── .git/                    # メインリポジトリ
├── .worktrees/             # Agent用ワークスペース
│   ├── agent1/             # agent1の作業ディレクトリ
│   ├── agent2/             # agent2の作業ディレクトリ
│   └── agent3/             # agent3の作業ディレクトリ
├── .claude/
│   └── agent_config/       # Agent設定ファイル
│       ├── agent1.json
│       ├── agent2.json
│       └── agent3.json
└── TrainAlert/             # メインプロジェクト
```

## セットアップ

### 初期設定
```bash
# ワークスペース環境の初期化
./scripts/agent_workspace.sh setup
```

## 基本的なワークフロー

### 1. 実装可能なチケットの確認

```bash
# 依存関係を考慮した実装可能チケットの提案
./scripts/agent_coordinator.sh suggest
```

出力例：
```
🤖 Agent割り当て提案

=== 推奨する新規割り当て ===
  🆕 agent1 → #001 - プロジェクトセットアップ
     コマンド: ./scripts/agent_workspace.sh create agent1 001
  🆕 agent2 → #002 - デザインシステム構築
     コマンド: ./scripts/agent_workspace.sh create agent2 002
```

### 2. Agentワークスペースの作成

```bash
# agent1用にチケット#001のワークスペースを作成
./scripts/agent_workspace.sh create agent1 001

# 作成されるもの:
# - .worktrees/agent1/ (独立した作業ディレクトリ)
# - feature/ticket-001-project_setup ブランチ
# - .claude/agent_config/agent1.json (設定ファイル)
```

### 3. ワークスペースでの開発

```bash
# ワークスペースに移動
cd .worktrees/agent1

# 通常通り開発
# ... ファイル編集 ...
git add .
git commit -m "feat: #001 実装内容"
git push -u origin feature/ticket-001-project_setup
```

### 4. 他のAgentとの連携

```bash
# 全agentの進捗確認
./scripts/agent_workspace.sh status

# mainブランチの最新を同期
./scripts/agent_workspace.sh sync agent1

# PR作成準備チェック
./scripts/agent_coordinator.sh pr-check
```

### 5. PR作成

```bash
# ワークスペースから直接PR作成
cd .worktrees/agent1
../scripts/create_pr.sh 001
```

## 並行開発シナリオ例

### Phase 1: 基盤構築（5 agents同時作業）
```bash
# Agent1: インフラ担当
./scripts/agent_workspace.sh create agent1 001  # プロジェクトセットアップ

# 001完了後、並列実装開始
./scripts/agent_workspace.sh create agent2 002  # デザインシステム
./scripts/agent_workspace.sh create agent3 003  # Core Data
./scripts/agent_workspace.sh create agent4 004  # 位置情報サービス
./scripts/agent_workspace.sh create agent5 005  # 通知システム
```

### Phase 2: UI実装（依存関係に注意）
```bash
# 依存関係チェック
./scripts/agent_coordinator.sh check 008
# → #002と#003が完了していることを確認

# UI実装開始
./scripts/agent_workspace.sh create agent6 008  # ホーム画面
```

## コマンドリファレンス

### agent_workspace.sh
| コマンド | 説明 | 例 |
|---------|------|-----|
| setup | 初期セットアップ | `./scripts/agent_workspace.sh setup` |
| create | 新規ワークスペース作成 | `./scripts/agent_workspace.sh create agent1 001` |
| list | ワークスペース一覧 | `./scripts/agent_workspace.sh list` |
| switch | ワークスペース切り替え | `./scripts/agent_workspace.sh switch agent1` |
| status | 全体進捗確認 | `./scripts/agent_workspace.sh status` |
| sync | mainブランチ同期 | `./scripts/agent_workspace.sh sync agent1` |
| cleanup | 完了ワークスペース削除 | `./scripts/agent_workspace.sh cleanup` |

### agent_coordinator.sh
| コマンド | 説明 | 例 |
|---------|------|-----|
| check | 依存関係チェック | `./scripts/agent_coordinator.sh check 008` |
| suggest | 実装可能チケット提案 | `./scripts/agent_coordinator.sh suggest` |
| pr-check | PR準備状態確認 | `./scripts/agent_coordinator.sh pr-check` |

## ベストプラクティス

### 1. 依存関係の管理
- 新しいタスクを始める前に必ず依存関係をチェック
- ブロックされているチケットは避ける

### 2. 定期的な同期
- 少なくとも1日1回はmainブランチを同期
- 大きな変更がマージされた場合は即座に同期

### 3. コミュニケーション
- agent間で影響がある変更は事前に共有
- PR作成時は影響範囲を明記

### 4. ワークスペースの管理
- 完了したワークスペースは定期的にクリーンアップ
- 一時的に作業を中断する場合はstashを活用

## トラブルシューティング

### worktreeエラー
```bash
# worktreeがロックされている場合
git worktree prune

# 強制的に削除
git worktree remove .worktrees/agent1 --force
```

### マージコンフリクト
```bash
# agent1のワークスペースで
cd .worktrees/agent1
git fetch origin main
git merge origin/main
# コンフリクトを解決
git add .
git commit -m "fix: merge conflicts with main"
```

### 依存関係の問題
```bash
# 依存チケットの状態を再確認
./scripts/agent_coordinator.sh check 009

# 手動でチケットステータスを更新
vim TrainAlert/docs/tickets/006_*.md
# ステータスをCompletedに変更
```

## Claude Codeでの活用

### slash commandの使用
```
# ワークスペース管理
/agent-work create agent1 001
/agent-work status

# チケット管理
/ticket status
/ticket complete 001
```

### 複数ターミナルでの作業
1. メインプロジェクト用ターミナル
2. 各agent用ターミナル（worktree）
3. 監視・調整用ターミナル

これにより、効率的な並行開発が可能になります。
