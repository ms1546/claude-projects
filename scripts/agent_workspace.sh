#!/bin/bash
# Agent用ワークスペース管理スクリプト

set -e

# 基本設定
BASE_DIR=$(pwd)
WORKTREE_DIR="$BASE_DIR/.worktrees"
TICKETS_DIR="$BASE_DIR/TrainAlert/docs/tickets"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# コマンドのヘルプ
show_help() {
    echo "📋 Agent Workspace Manager"
    echo ""
    echo "使用方法:"
    echo "  ./scripts/agent_workspace.sh <command> [options]"
    echo ""
    echo "コマンド:"
    echo "  setup           - 初期セットアップ"
    echo "  list            - 全ワークスペースの一覧"
    echo "  create <agent> <ticket> - 新しいワークスペースを作成"
    echo "  switch <agent>  - ワークスペースに切り替え"
    echo "  status          - 全agentの進捗状況"
    echo "  sync <agent>    - mainブランチの変更を同期"
    echo "  cleanup         - 完了したワークスペースを削除"
    echo ""
    echo "例:"
    echo "  ./scripts/agent_workspace.sh create agent1 001"
    echo "  ./scripts/agent_workspace.sh status"
}

# 初期セットアップ
setup_workspace() {
    echo "🔧 ワークスペースの初期セットアップ中..."
    
    # worktreeディレクトリ作成
    mkdir -p "$WORKTREE_DIR"
    
    # .gitignoreに追加
    if ! grep -q "^.worktrees/" .gitignore 2>/dev/null; then
        echo ".worktrees/" >> .gitignore
        echo "✅ .gitignoreに.worktrees/を追加"
    fi
    
    # agent設定ファイル作成
    mkdir -p .claude/agent_config
    
    echo "✅ セットアップ完了"
}

# ワークスペース一覧
list_workspaces() {
    echo "📁 現在のワークスペース:"
    echo ""
    
    if [ -d "$WORKTREE_DIR" ]; then
        for dir in "$WORKTREE_DIR"/*; do
            if [ -d "$dir" ]; then
                agent=$(basename "$dir")
                branch=$(cd "$dir" && git branch --show-current)
                echo "  🤖 $agent"
                echo "     └─ ブランチ: $branch"
                echo "     └─ パス: $dir"
                echo ""
            fi
        done
    else
        echo "  ワークスペースがありません"
    fi
}

# 新しいワークスペースを作成
create_workspace() {
    local agent=$1
    local ticket=$2
    
    if [ -z "$agent" ] || [ -z "$ticket" ]; then
        echo -e "${RED}エラー: agent名とチケット番号が必要です${NC}"
        exit 1
    fi
    
    # チケットファイルの確認
    local ticket_file=$(find "$TICKETS_DIR" -name "${ticket}_*.md" | head -1)
    if [ -z "$ticket_file" ]; then
        echo -e "${RED}エラー: チケット #$ticket が見つかりません${NC}"
        exit 1
    fi
    
    # チケット情報取得
    local ticket_title=$(basename "$ticket_file" .md | sed "s/${ticket}_//")
    local branch_name="feature/ticket-${ticket}-${ticket_title}"
    local workspace_path="$WORKTREE_DIR/$agent"
    
    echo "🚀 Agent: $agent のワークスペースを作成中..."
    echo "   チケット: #$ticket - $ticket_title"
    
    # worktree作成
    if [ -d "$workspace_path" ]; then
        echo -e "${YELLOW}警告: $agent のワークスペースは既に存在します${NC}"
        echo "既存のワークスペースを削除しますか？ (y/n)"
        read -r response
        if [ "$response" = "y" ]; then
            git worktree remove "$workspace_path" --force
        else
            exit 1
        fi
    fi
    
    # mainから最新を取得
    git fetch origin main
    
    # 新しいworktreeとブランチを作成
    git worktree add "$workspace_path" -b "$branch_name" origin/main
    
    # agent設定ファイル作成
    cat > ".claude/agent_config/${agent}.json" <<EOF
{
  "agent": "$agent",
  "ticket": "$ticket",
  "branch": "$branch_name",
  "workspace": "$workspace_path",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "status": "in_progress"
}
EOF
    
    # チケットステータス更新
    sed -i '' "s/## ステータス: \[ \] Not Started/## ステータス: [x] In Progress/" "$ticket_file"
    
    echo -e "${GREEN}✅ ワークスペース作成完了${NC}"
    echo ""
    echo "次のステップ:"
    echo "  cd $workspace_path"
    echo "  # 開発を開始"
    echo ""
    echo "または:"
    echo "  ./scripts/agent_workspace.sh switch $agent"
}

# ワークスペースに切り替え
switch_workspace() {
    local agent=$1
    
    if [ -z "$agent" ]; then
        echo -e "${RED}エラー: agent名が必要です${NC}"
        exit 1
    fi
    
    local workspace_path="$WORKTREE_DIR/$agent"
    
    if [ ! -d "$workspace_path" ]; then
        echo -e "${RED}エラー: $agent のワークスペースが見つかりません${NC}"
        exit 1
    fi
    
    echo "📂 $agent のワークスペースに切り替えます"
    echo "cd $workspace_path"
    echo ""
    echo "💡 ヒント: 以下のコマンドを実行してください:"
    echo "   cd $workspace_path"
}

# 全agentの進捗状況
show_status() {
    echo "📊 Agent進捗状況"
    echo ""
    
    # 依存関係図を参照
    echo "=== 実装可能なチケット ==="
    grep -E "^#[0-9]{3}" "$TICKETS_DIR/dependency_graph.md" | while read -r line; do
        ticket_num=$(echo "$line" | grep -oE "^#[0-9]{3}" | sed 's/#//')
        ticket_file=$(find "$TICKETS_DIR" -name "${ticket_num}_*.md" | head -1)
        
        if [ -f "$ticket_file" ]; then
            status=$(grep "## ステータス:" "$ticket_file" | head -1)
            if echo "$status" | grep -q "Not Started"; then
                echo -e "${GREEN}✅ 実装可能: $line${NC}"
            elif echo "$status" | grep -q "In Progress"; then
                echo -e "${YELLOW}🔄 実装中: $line${NC}"
            elif echo "$status" | grep -q "Completed"; then
                echo -e "${BLUE}✓ 完了: $line${NC}"
            fi
        fi
    done
    
    echo ""
    echo "=== Agentワークスペース ==="
    if [ -d ".claude/agent_config" ]; then
        for config in .claude/agent_config/*.json; do
            if [ -f "$config" ]; then
                agent=$(basename "$config" .json)
                ticket=$(jq -r '.ticket' "$config")
                status=$(jq -r '.status' "$config")
                echo "🤖 $agent - チケット #$ticket [$status]"
            fi
        done
    fi
}

# mainブランチの変更を同期
sync_workspace() {
    local agent=$1
    
    if [ -z "$agent" ]; then
        echo -e "${RED}エラー: agent名が必要です${NC}"
        exit 1
    fi
    
    local workspace_path="$WORKTREE_DIR/$agent"
    
    if [ ! -d "$workspace_path" ]; then
        echo -e "${RED}エラー: $agent のワークスペースが見つかりません${NC}"
        exit 1
    fi
    
    echo "🔄 $agent のワークスペースを同期中..."
    
    # mainの最新を取得
    git fetch origin main
    
    # ワークスペースで同期
    (
        cd "$workspace_path"
        current_branch=$(git branch --show-current)
        
        # 未コミットの変更を確認
        if ! git diff-index --quiet HEAD --; then
            echo -e "${YELLOW}警告: 未コミットの変更があります${NC}"
            echo "変更をstashしますか？ (y/n)"
            read -r response
            if [ "$response" = "y" ]; then
                git stash push -m "Sync with main - $(date)"
            else
                exit 1
            fi
        fi
        
        # mainをマージ
        git merge origin/main --no-edit
        
        echo -e "${GREEN}✅ 同期完了${NC}"
    )
}

# 完了したワークスペースをクリーンアップ
cleanup_workspaces() {
    echo "🧹 完了したワークスペースをクリーンアップ中..."
    
    local cleaned=0
    
    if [ -d ".claude/agent_config" ]; then
        for config in .claude/agent_config/*.json; do
            if [ -f "$config" ]; then
                agent=$(basename "$config" .json)
                status=$(jq -r '.status' "$config")
                
                if [ "$status" = "completed" ]; then
                    workspace_path="$WORKTREE_DIR/$agent"
                    
                    echo "削除: $agent のワークスペース"
                    git worktree remove "$workspace_path" --force 2>/dev/null || true
                    rm "$config"
                    ((cleaned++))
                fi
            fi
        done
    fi
    
    if [ $cleaned -eq 0 ]; then
        echo "クリーンアップ対象のワークスペースはありません"
    else
        echo -e "${GREEN}✅ $cleaned 個のワークスペースを削除しました${NC}"
    fi
}

# メイン処理
case "$1" in
    setup)
        setup_workspace
        ;;
    list)
        list_workspaces
        ;;
    create)
        create_workspace "$2" "$3"
        ;;
    switch)
        switch_workspace "$2"
        ;;
    status)
        show_status
        ;;
    sync)
        sync_workspace "$2"
        ;;
    cleanup)
        cleanup_workspaces
        ;;
    *)
        show_help
        ;;
esac