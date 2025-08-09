#!/bin/bash

# GitHub Actions状態確認スクリプト

echo "========================================="
echo "GitHub Actions Status Check"
echo "========================================="

# 最新のコミット情報
echo -e "\n📍 Latest commit:"
git log --oneline -n 1

echo -e "\n🔍 Checking GitHub Actions..."
echo "Please check the following URL for the latest workflow runs:"
echo "https://github.com/ms1546/claude-projects/actions"

# ブランチ名を取得
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "\n🌿 Current branch: $BRANCH"

# 最新のコミットハッシュを取得
COMMIT=$(git rev-parse HEAD)
echo "📝 Commit: $COMMIT"

echo -e "\n💡 Direct links:"
echo "• All workflows: https://github.com/ms1546/claude-projects/actions"
echo "• Branch workflows: https://github.com/ms1546/claude-projects/actions?query=branch%3A$BRANCH"

echo -e "\n✅ To see if all tests passed, look for green checkmarks in the Actions tab"
echo "❌ If tests failed, click on the failed job to see detailed logs"

echo -e "\n========================================="
