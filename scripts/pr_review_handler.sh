#!/bin/bash
# PRレビューコメント自動処理スクリプト

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 引数処理
PR_NUMBER=$1
ACTION=$2

# GitHub token確認
if [ -f ".env" ]; then
    source .env
    GH_PREFIX="GH_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN"
else
    GH_PREFIX=""
fi

# PR番号の取得
if [ -z "$PR_NUMBER" ]; then
    echo "🔍 現在のブランチのPRを検索中..."
    PR_NUMBER=$(eval "$GH_PREFIX gh pr view --json number -q .number" 2>/dev/null || echo "")
    
    if [ -z "$PR_NUMBER" ]; then
        echo -e "${RED}❌ PRが見つかりません${NC}"
        echo "使用方法: $0 [pr-number] [action]"
        exit 1
    fi
fi

echo "📋 PR #$PR_NUMBER のレビュー情報を取得中..."
echo ""

# PR情報を取得
PR_INFO=$(eval "$GH_PREFIX gh pr view $PR_NUMBER --json title,state,author,url")
PR_TITLE=$(echo "$PR_INFO" | jq -r '.title')
PR_STATE=$(echo "$PR_INFO" | jq -r '.state')
PR_URL=$(echo "$PR_INFO" | jq -r '.url')

echo -e "${BLUE}PR情報:${NC}"
echo "  タイトル: $PR_TITLE"
echo "  状態: $PR_STATE"
echo "  URL: $PR_URL"
echo ""

# レビューを取得
echo -e "${BLUE}レビュー一覧:${NC}"
REVIEWS=$(eval "$GH_PREFIX gh api repos/ms1546/claude-projects/pulls/$PR_NUMBER/reviews" 2>/dev/null || echo "[]")

if [ "$REVIEWS" = "[]" ]; then
    echo "  レビューはまだありません"
else
    echo "$REVIEWS" | jq -r '.[] | "  \(.user.login): \(.state) - \(.submitted_at)"'
fi
echo ""

# レビューコメントを取得
echo -e "${BLUE}レビューコメント:${NC}"
COMMENTS=$(eval "$GH_PREFIX gh pr view $PR_NUMBER --comments" 2>/dev/null || echo "")

if [ -z "$COMMENTS" ]; then
    echo "  コメントはありません"
else
    echo "$COMMENTS" | sed 's/^/  /'
fi
echo ""

# インラインコメント（コード行へのコメント）を取得
echo -e "${BLUE}コード行へのコメント:${NC}"
INLINE_COMMENTS=$(eval "$GH_PREFIX gh api repos/ms1546/claude-projects/pulls/$PR_NUMBER/comments" 2>/dev/null || echo "[]")

if [ "$INLINE_COMMENTS" = "[]" ]; then
    echo "  インラインコメントはありません"
else
    echo "$INLINE_COMMENTS" | jq -r '.[] | "  📄 \(.path):\(.line)\n    💬 \(.user.login): \(.body)\n"'
fi

# アクションの実行
if [ "$ACTION" = "apply" ] || [ "$ACTION" = "fix" ]; then
    echo ""
    echo -e "${YELLOW}🔧 レビューコメントに基づいて修正を開始します...${NC}"
    echo ""
    
    # コメントから修正が必要な箇所を抽出
    echo "修正が必要な箇所:"
    
    # インラインコメントから修正箇所を特定
    if [ "$INLINE_COMMENTS" != "[]" ]; then
        echo "$INLINE_COMMENTS" | jq -r '.[] | "- \(.path):\(.line) - \(.body)"' | head -10
    fi
    
    echo ""
    echo "以下の手順で修正を行ってください:"
    echo "1. 各コメントの指摘事項を確認"
    echo "2. 該当ファイルを修正"
    echo "3. 修正完了後、以下のコマンドを実行:"
    echo ""
    echo -e "${GREEN}# 修正をコミット${NC}"
    echo "git add -A"
    echo "git commit -m \"fix: PR #$PR_NUMBER レビュー指摘対応\""
    echo "git push"
    echo ""
    echo -e "${GREEN}# レビュアーに返信${NC}"
    echo "$GH_PREFIX gh pr comment $PR_NUMBER --body \"レビューありがとうございます。指摘事項を修正しました。\""
    
elif [ "$ACTION" = "resolve" ]; then
    echo ""
    echo -e "${GREEN}✅ レビューコメントを解決済みとしてマーク${NC}"
    
    # レビューへの返信
    RESPONSE_BODY="すべての指摘事項に対応しました。
    
修正内容:
$(git log --oneline -5 | sed 's/^/- /')

ご確認をお願いします。"
    
    eval "$GH_PREFIX gh pr comment $PR_NUMBER --body \"$RESPONSE_BODY\""
    echo "✅ レビュアーに通知しました"
    
else
    echo ""
    echo -e "${PURPLE}使用可能なアクション:${NC}"
    echo "  apply/fix - レビューコメントに基づいて修正"
    echo "  resolve   - 修正完了を通知"
    echo ""
    echo "例:"
    echo "  $0 $PR_NUMBER apply"
    echo "  $0 $PR_NUMBER resolve"
fi
