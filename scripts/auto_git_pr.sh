#!/bin/bash
# 自動Git操作とPR作成スクリプト

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 引数処理
TICKET_NUM=$1
COMMIT_MSG=$2
SKIP_CONFIRM=${3:-false}

# 現在のブランチを取得
CURRENT_BRANCH=$(git branch --show-current)

# mainブランチチェック
if [ "$CURRENT_BRANCH" = "main" ]; then
    echo -e "${RED}❌ エラー: mainブランチから直接の操作はできません${NC}"
    echo "新しいブランチを作成してください:"
    echo "  git checkout -b feature/ticket-XXX-description"
    exit 1
fi

# チケット番号の推定
if [ -z "$TICKET_NUM" ]; then
    # ブランチ名から推定
    TICKET_NUM=$(echo "$CURRENT_BRANCH" | grep -oE 'ticket-[0-9]{3}' | sed 's/ticket-//' || true)
    
    if [ -z "$TICKET_NUM" ]; then
        echo -e "${YELLOW}⚠️  チケット番号を特定できません${NC}"
        echo "使用方法: $0 <ticket-number> [commit-message]"
        exit 1
    fi
fi

# チケットファイルの確認
TICKET_FILE=$(find TrainAlert/docs/tickets -name "${TICKET_NUM}_*.md" 2>/dev/null | head -1)
if [ -z "$TICKET_FILE" ]; then
    echo -e "${RED}❌ チケット #$TICKET_NUM が見つかりません${NC}"
    exit 1
fi

TICKET_TITLE=$(basename "$TICKET_FILE" .md | sed "s/${TICKET_NUM}_//" | tr '_' ' ')

echo "📋 Git自動アップロード & PR作成"
echo "================================"
echo "ブランチ: $CURRENT_BRANCH"
echo "チケット: #$TICKET_NUM - $TICKET_TITLE"
echo ""

# 変更状況確認
echo "📝 変更ファイル:"
git status --short
echo ""

# 変更がない場合
if [ -z "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠️  変更がありません${NC}"
    
    # プッシュされていないコミットを確認
    UNPUSHED=$(git log origin/$CURRENT_BRANCH..$CURRENT_BRANCH --oneline 2>/dev/null | wc -l || echo "0")
    if [ "$UNPUSHED" -gt "0" ]; then
        echo "📤 $UNPUSHED 個のコミットがプッシュ待ちです"
        
        if [ "$SKIP_CONFIRM" != "true" ]; then
            echo "プッシュしてPRを作成しますか？ (y/n)"
            read -r CONFIRM
            if [ "$CONFIRM" != "y" ]; then
                exit 0
            fi
        fi
        
        # プッシュのみ実行
        echo "🚀 プッシュ中..."
        git push -u origin "$CURRENT_BRANCH"
    else
        echo "変更もプッシュ待ちのコミットもありません"
        exit 0
    fi
else
    # ステージングされていない変更を追加
    echo "📦 変更をステージング中..."
    git add -A
    
    # コミットメッセージ生成
    if [ -z "$COMMIT_MSG" ]; then
        # 変更ファイルリスト
        CHANGED_FILES=$(git diff --cached --name-only | head -5 | sed 's/^/  - /')
        MORE_FILES=$(git diff --cached --name-only | tail -n +6 | wc -l)
        
        if [ "$MORE_FILES" -gt "0" ]; then
            CHANGED_FILES="$CHANGED_FILES
  - ... and $MORE_FILES more files"
        fi
        
        COMMIT_MSG="feat: #$TICKET_NUM 実装進捗

変更ファイル:
$CHANGED_FILES"
    fi
    
    # 確認
    if [ "$SKIP_CONFIRM" != "true" ]; then
        echo -e "${BLUE}コミットメッセージ:${NC}"
        echo "$COMMIT_MSG"
        echo ""
        echo "この内容でコミット、プッシュ、PR作成を実行しますか？ (y/n)"
        read -r CONFIRM
        if [ "$CONFIRM" != "y" ]; then
            exit 0
        fi
    fi
    
    # コミット
    echo "💾 コミット中..."
    git commit -m "$COMMIT_MSG"
    
    # プッシュ
    echo "🚀 プッシュ中..."
    git push -u origin "$CURRENT_BRANCH"
fi

# PR作成
echo ""
echo "📝 PR作成中..."

# 環境変数チェック
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .envファイルが見つかりません${NC}"
    echo "GitHub CLIで認証してPRを作成します"
    PR_COMMAND="gh pr create"
else
    source .env
    if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
        echo -e "${YELLOW}⚠️  GitHub tokenが設定されていません${NC}"
        PR_COMMAND="gh pr create"
    else
        PR_COMMAND="GH_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN gh pr create"
    fi
fi

# 既存のPRをチェック
EXISTING_PR=$(eval "$PR_COMMAND --json number -q .number" 2>/dev/null || echo "")

if [ -n "$EXISTING_PR" ]; then
    echo -e "${GREEN}✅ 既存のPR #$EXISTING_PR を更新しました${NC}"
    echo "PR URL: https://github.com/ms1546/claude-projects/pull/$EXISTING_PR"
else
    # コミットログから変更内容を生成
    CHANGES=$(git log origin/main.."$CURRENT_BRANCH" --oneline | sed 's/^/- /')
    
    # PR本文生成
    PR_BODY="## 概要
チケット #$TICKET_NUM の実装
$TICKET_TITLE

## 変更内容
$CHANGES

## チェックリスト
- [ ] ビルドが成功する
- [ ] SwiftLintエラーなし
- [ ] テストが通る
- [ ] チケットの完了条件を満たしている

## テスト方法
\`\`\`bash
# ビルド確認
xcodebuild -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' build

# テスト実行（実装時）
/swift-test all
\`\`\`

## 関連チケット
Closes #$TICKET_NUM

## レビュー依頼
@ms1546 レビューをお願いします。

---
*Created by /git-upload command*"

    # PR作成
    eval "$PR_COMMAND" \
        --title "feat: #$TICKET_NUM $TICKET_TITLE" \
        --body "$PR_BODY" \
        --reviewer ms1546 \
        --base main \
        2>/dev/null || {
            echo -e "${YELLOW}⚠️  レビュアー設定に失敗しました（権限不足の可能性）${NC}"
            echo "レビュアーなしでPRを作成します..."
            eval "$PR_COMMAND" \
                --title "feat: #$TICKET_NUM $TICKET_TITLE" \
                --body "$PR_BODY" \
                --base main
        }
    
    echo -e "${GREEN}✅ PR作成完了！${NC}"
fi

echo ""
echo "🎉 完了しました！"
echo ""
echo "次のステップ:"
echo "1. PRのレビューを待つ"
echo "2. フィードバックに対応"
echo "3. 承認後にマージ"
