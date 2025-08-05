#!/bin/bash
# PR作成ヘルパースクリプト

# 引数チェック
if [ $# -lt 1 ]; then
    echo "使用方法: ./scripts/create_pr.sh <ticket-number> [pr-title]"
    echo "例: ./scripts/create_pr.sh 001"
    echo "例: ./scripts/create_pr.sh 001 \"カスタムタイトル\""
    exit 1
fi

TICKET_NUM=$1
TICKET_FILE="TrainAlert/docs/tickets/${TICKET_NUM}_*.md"

# チケットファイルの存在確認
if ! ls $TICKET_FILE 1> /dev/null 2>&1; then
    echo "❌ チケット #$TICKET_NUM が見つかりません"
    exit 1
fi

# チケット情報を取得
TICKET_PATH=$(ls $TICKET_FILE | head -1)
TICKET_TITLE=$(grep "^# Ticket" $TICKET_PATH | sed 's/# Ticket #[0-9]*: //')

# PRタイトル設定
if [ $# -ge 2 ]; then
    PR_TITLE="$2"
else
    PR_TITLE="feat: #$TICKET_NUM $TICKET_TITLE"
fi

# 現在のブランチ名を取得
CURRENT_BRANCH=$(git branch --show-current)

# mainブランチかチェック
if [ "$CURRENT_BRANCH" = "main" ]; then
    echo "❌ mainブランチから直接PRを作成することはできません"
    echo "💡 新しいブランチを作成してください:"
    echo "   git checkout -b feature/ticket-$TICKET_NUM-$(echo $TICKET_TITLE | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
    exit 1
fi

# 変更の確認
echo "📋 PR作成情報:"
echo "- チケット: #$TICKET_NUM"
echo "- タイトル: $PR_TITLE"
echo "- ブランチ: $CURRENT_BRANCH → main"
echo ""

# チケットの実装内容を取得
echo "📝 チケット内容:"
grep -A 20 "## タスク" $TICKET_PATH | head -25
echo ""

# PR本文を生成
PR_BODY=$(cat <<EOF
## 概要
チケット #$TICKET_NUM の実装

$TICKET_TITLE

## 変更内容
$(git log main..$CURRENT_BRANCH --oneline | sed 's/^/- /')

## チェックリスト
- [ ] ビルドが成功する
- [ ] SwiftLintエラーなし
- [ ] テストが通る
- [ ] チケットの完了条件を満たしている

## テスト方法
\`\`\`bash
# ビルド確認
xcodebuild -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' build

# テスト実行
/swift-test all
\`\`\`

## スクリーンショット
（該当する場合）

## 関連チケット
Closes #$TICKET_NUM

## レビュー観点
- コード品質
- iOS開発のベストプラクティス準拠
- セキュリティ考慮事項
EOF
)

# 確認
echo "この内容でPRを作成しますか？ (y/n)"
read -r CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "キャンセルしました"
    exit 0
fi

# 環境変数チェック
if [ ! -f ".env" ]; then
    echo "⚠️  .envファイルが見つかりません"
    echo "GitHub CLIで認証してください: gh auth login"
    # GitHub CLIでPR作成
    gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main
else
    # 環境変数を使用してPR作成
    source .env
    GH_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN gh pr create --title "$PR_TITLE" --body "$PR_BODY" --base main
fi

echo ""
echo "✅ PR作成完了！"
echo ""
echo "次のステップ:"
echo "1. PRのURLを開いてレビュー依頼"
echo "2. CIの結果を確認（将来実装）"
echo "3. レビューコメントに対応"
echo "4. 承認後にマージ"