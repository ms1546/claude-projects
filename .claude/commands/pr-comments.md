---
description: PRのレビューコメントを一覧表示して対応
argumentHints: "[pr-number]"
---

# PRレビューコメント管理

PR番号: $ARGUMENTS

GitHubのPRレビューコメントを構造化して表示し、対応を支援します。

## 処理内容

```bash
# PR番号の決定
if [ -z "$ARGUMENTS" ]; then
  # 現在のブランチのPRを取得
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
  if [ -z "$pr_number" ]; then
    echo "❌ PRが見つかりません"
    exit 1
  fi
else
  pr_number="$ARGUMENTS"
fi

echo "📝 PR #$pr_number のレビューコメント"
echo "================================"
```

## コメント取得と整形

```bash
# レビューコメントを取得
!gh pr view $pr_number --comments

# APIで詳細情報を取得
!gh api repos/ms1546/claude-projects/pulls/$pr_number/reviews --jq '.[] | {
  user: .user.login,
  state: .state,
  body: .body,
  submitted_at: .submitted_at
}'

# インラインコメント（コード行へのコメント）を取得
!gh api repos/ms1546/claude-projects/pulls/$pr_number/comments --jq '.[] | {
  path: .path,
  line: .line,
  body: .body,
  user: .user.login
}'
```

## コメントへの対応

### 1. コード修正が必要な場合
```bash
# 指摘されたファイルを開いて修正
# 例: path: "scripts/auto_git_pr.sh", line: 45
```

### 2. ドキュメント更新が必要な場合
```bash
# 関連するドキュメントを更新
```

### 3. テスト追加が必要な場合
```bash
# テストファイルを作成または更新
```

## 修正後の処理

```bash
# 修正をコミット
!git add -A
!git commit -m "fix: PR #$pr_number レビュー指摘対応

- [レビュアー名]の指摘に対応
- 具体的な修正内容"

# プッシュ
!git push

# レビュアーに通知
!gh pr comment $pr_number --body "@$reviewer_name 
ご指摘ありがとうございました。
修正を完了しましたので、再度ご確認をお願いします。

修正内容:
- 指摘事項1: 対応完了
- 指摘事項2: 対応完了"
```

## 使用例
- `/pr-comments` - 現在のブランチのPRコメントを表示
- `/pr-comments 1` - PR #1のコメントを表示

これにより、レビューコメントを効率的に処理できます。
