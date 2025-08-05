#!/bin/bash
# Agent間の連携と依存関係管理

set -e

# 基本設定
BASE_DIR=$(pwd)
TICKETS_DIR="$BASE_DIR/TrainAlert/docs/tickets"
AGENT_CONFIG_DIR="$BASE_DIR/.claude/agent_config"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 依存関係チェック
check_dependencies() {
    local ticket=$1
    local deps_file="$TICKETS_DIR/dependency_graph.md"
    
    echo "🔍 チケット #$ticket の依存関係を確認中..."
    
    # 依存するチケットを抽出
    local deps=()
    
    # Phase 1のチケット（001以外）は001に依存
    if [[ "$ticket" =~ ^00[2-6]$ ]]; then
        deps+=("001")
    fi
    
    # Phase 2のチケット
    case "$ticket" in
        "008")
            deps+=("002" "003")
            ;;
        "009")
            deps+=("006" "007")
            ;;
        "010")
            deps+=("003")
            ;;
        "011")
            deps+=("002")
            ;;
    esac
    
    # Phase 3のチケット
    case "$ticket" in
        "007")
            deps+=("005")
            ;;
        "012")
            deps+=("004" "005")
            ;;
    esac
    
    # 依存チケットの状態確認
    local blocked=false
    for dep in "${deps[@]}"; do
        local dep_file=$(find "$TICKETS_DIR" -name "${dep}_*.md" | head -1)
        if [ -f "$dep_file" ]; then
            local status=$(grep "## ステータス:" "$dep_file" | head -1)
            if ! echo "$status" | grep -q "Completed"; then
                echo -e "${RED}❌ ブロック: チケット #$dep が未完了${NC}"
                blocked=true
            else
                echo -e "${GREEN}✅ OK: チケット #$dep は完了済み${NC}"
            fi
        fi
    done
    
    if [ "$blocked" = true ]; then
        return 1
    else
        echo -e "${GREEN}✅ 全ての依存関係がクリアされています${NC}"
        return 0
    fi
}

# 実装可能なチケットを提案
suggest_tickets() {
    echo "📋 実装可能なチケット候補"
    echo ""
    
    local available_tickets=()
    
    # 全チケットをチェック
    for ticket_file in "$TICKETS_DIR"/[0-9][0-9][0-9]_*.md; do
        if [ -f "$ticket_file" ]; then
            local ticket_num=$(basename "$ticket_file" | cut -d'_' -f1)
            local status=$(grep "## ステータス:" "$ticket_file" | head -1)
            
            # Not Startedのチケットのみ
            if echo "$status" | grep -q "Not Started"; then
                # 依存関係をチェック
                if check_dependencies "$ticket_num" >/dev/null 2>&1; then
                    available_tickets+=("$ticket_num")
                fi
            fi
        fi
    done
    
    # グループ別に表示
    echo "=== データ層（並列実装可能）==="
    for ticket in "${available_tickets[@]}"; do
        case "$ticket" in
            "003"|"006"|"007")
                local title=$(basename "$(find "$TICKETS_DIR" -name "${ticket}_*.md")" .md | sed "s/${ticket}_//")
                echo -e "${GREEN}  #$ticket - $title${NC}"
                ;;
        esac
    done
    
    echo ""
    echo "=== システム層（並列実装可能）==="
    for ticket in "${available_tickets[@]}"; do
        case "$ticket" in
            "004"|"005")
                local title=$(basename "$(find "$TICKETS_DIR" -name "${ticket}_*.md")" .md | sed "s/${ticket}_//")
                echo -e "${GREEN}  #$ticket - $title${NC}"
                ;;
        esac
    done
    
    echo ""
    echo "=== UI層 ==="
    for ticket in "${available_tickets[@]}"; do
        case "$ticket" in
            "002"|"008"|"009"|"010"|"011")
                local title=$(basename "$(find "$TICKETS_DIR" -name "${ticket}_*.md")" .md | sed "s/${ticket}_//")
                echo -e "${GREEN}  #$ticket - $title${NC}"
                ;;
        esac
    done
}

# Agent割り当て提案
suggest_agent_assignment() {
    echo "🤖 Agent割り当て提案"
    echo ""
    
    # 現在のagent状態を取得
    local active_agents=()
    if [ -d "$AGENT_CONFIG_DIR" ]; then
        for config in "$AGENT_CONFIG_DIR"/*.json; do
            if [ -f "$config" ]; then
                local agent=$(basename "$config" .json)
                local ticket=$(jq -r '.ticket' "$config")
                local status=$(jq -r '.status' "$config")
                if [ "$status" = "in_progress" ]; then
                    active_agents+=("$agent:$ticket")
                fi
            fi
        done
    fi
    
    # アクティブなagentを表示
    if [ ${#active_agents[@]} -gt 0 ]; then
        echo "=== 現在作業中のAgent ==="
        for agent_info in "${active_agents[@]}"; do
            IFS=':' read -r agent ticket <<< "$agent_info"
            echo "  🔄 $agent - チケット #$ticket"
        done
        echo ""
    fi
    
    # 推奨割り当て
    echo "=== 推奨する新規割り当て ==="
    suggest_tickets | grep -E "#[0-9]{3}" | head -5 | while read -r line; do
        ticket=$(echo "$line" | grep -oE "#[0-9]{3}" | sed 's/#//')
        # 未割り当てのagent番号を生成
        local agent_num=$((${#active_agents[@]} + 1))
        echo "  🆕 agent$agent_num → $line"
        echo "     コマンド: ./scripts/agent_workspace.sh create agent$agent_num $ticket"
    done
}

# PR準備状態チェック
check_pr_ready() {
    echo "📝 PR作成準備チェック"
    echo ""
    
    if [ -d "$AGENT_CONFIG_DIR" ]; then
        for config in "$AGENT_CONFIG_DIR"/*.json; do
            if [ -f "$config" ]; then
                local agent=$(basename "$config" .json)
                local ticket=$(jq -r '.ticket' "$config")
                local workspace=$(jq -r '.workspace' "$config")
                
                echo "🤖 $agent (チケット #$ticket):"
                
                # ワークスペースでの変更を確認
                if [ -d "$workspace" ]; then
                    (
                        cd "$workspace"
                        
                        # コミットされていない変更
                        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                            echo -e "${YELLOW}  ⚠️  コミットされていない変更があります${NC}"
                        fi
                        
                        # プッシュされていないコミット
                        local unpushed=$(git log origin/main..HEAD --oneline 2>/dev/null | wc -l)
                        if [ "$unpushed" -gt 0 ]; then
                            echo -e "${BLUE}  📤 $unpushed 個のコミットがプッシュ待ち${NC}"
                        fi
                        
                        # PR作成可能かチェック
                        if [ "$unpushed" -gt 0 ] && git diff-index --quiet HEAD -- 2>/dev/null; then
                            echo -e "${GREEN}  ✅ PR作成可能${NC}"
                            echo "     コマンド: cd $workspace && ../scripts/create_pr.sh $ticket"
                        fi
                    )
                fi
                echo ""
            fi
        done
    fi
}

# メイン処理
case "$1" in
    "check")
        if [ -z "$2" ]; then
            echo "使用方法: $0 check <ticket-number>"
            exit 1
        fi
        check_dependencies "$2"
        ;;
    "suggest")
        suggest_agent_assignment
        ;;
    "pr-check")
        check_pr_ready
        ;;
    *)
        echo "📊 Agent Coordinator"
        echo ""
        echo "コマンド:"
        echo "  check <ticket>  - チケットの依存関係をチェック"
        echo "  suggest         - 実装可能なチケットとagent割り当てを提案"
        echo "  pr-check        - PR作成準備状態をチェック"
        echo ""
        echo "例:"
        echo "  $0 check 008"
        echo "  $0 suggest"
        echo "  $0 pr-check"
        ;;
esac