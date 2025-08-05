#!/bin/bash
# ブランチ保護設定スクリプト

echo "🔒 GitHub ブランチ保護設定"
echo ""

# 環境変数チェック
if [ ! -f ".env" ]; then
    echo "❌ .envファイルが見つかりません"
    exit 1
fi

source .env

if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "❌ GITHUB_PERSONAL_ACCESS_TOKENが設定されていません"
    exit 1
fi

# リポジトリ情報
OWNER="ms1546"
REPO="claude-projects"

echo "📋 現在の設定:"
echo "- リポジトリ: $OWNER/$REPO"
echo "- ブランチ: main"
echo ""

# GitHub API でブランチ保護を設定
echo "🔧 ブランチ保護ルールを設定中..."

# 注意: Private リポジトリでのブランチ保護にはGitHub Proが必要
curl -X PUT \
  -H "Authorization: token $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$OWNER/$REPO/branches/main/protection \
  -d '{
    "required_status_checks": null,
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": false,
      "require_last_push_approval": false
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false,
    "block_creations": false,
    "required_conversation_resolution": true,
    "lock_branch": false,
    "allow_fork_syncing": true
  }'

echo ""
echo ""
echo "⚠️  注意: Private リポジトリでのブランチ保護にはGitHub Proが必要です"
echo ""
echo "📝 代替案: 手動でのブランチ保護設定"
echo "1. https://github.com/$OWNER/$REPO/settings/branches にアクセス"
echo "2. 'Add rule' をクリック"
echo "3. Branch name pattern: main"
echo "4. 以下を有効化:"
echo "   - Require a pull request before merging"
echo "   - Require approvals (1)"
echo "   - Dismiss stale pull request approvals when new commits are pushed"
echo "   - Require conversation resolution before merging"
echo ""
echo "🚀 推奨ワークフロー:"
echo "1. 必ず feature/xxx ブランチで作業"
echo "2. PR作成時は詳細な説明を記載"
echo "3. セルフレビューも含めて必ずPRを作成"
echo "4. マージ前にテストを実行"