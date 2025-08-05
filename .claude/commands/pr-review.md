---
description: PRレビューコメントを取得して対応
argumentHints: "[pr-number] [action]"
---

# PRレビュー対応

引数: $ARGUMENTS

GitHubのPRレビューコメントを取得して、自動的に修正を行います。

## 使用例
- `/pr-review` - 現在のブランチのPRレビューを取得
- `/pr-review 1` - PR #1のレビューを取得
- `/pr-review 1 apply` - レビューコメントに基づいて自動修正

## 処理フロー

1. **PRレビューコメントの取得**
```bash
# 現在のブランチのPR番号を取得
!gh pr view --json number -q .number 2>/dev/null || echo ""

# レビューコメントを取得
!gh pr view $pr_number --comments
```

2. **レビュー内容の分析**
- コード修正の指摘
- ドキュメント更新の要求
- テスト追加の要望

3. **自動修正の実行**
- 指摘箇所の特定
- 修正内容の生成
- ファイルの更新

## 実装内容

```bash
# PR番号の取得
if [ -z "$1" ]; then
  pr_number=$(gh pr view --json number -q .number 2>/dev/null)
else
  pr_number="$1"
fi

# レビューコメントの取得
!gh pr view $pr_number --comments

# レビューの詳細情報取得
!gh api repos/ms1546/claude-projects/pulls/$pr_number/reviews

# コメント付きのコード変更を取得
!gh api repos/ms1546/claude-projects/pulls/$pr_number/comments
```

## レビュー対応の自動化

1. **コメントの解析**
   - 修正が必要な箇所を特定
   - 修正内容を理解

2. **修正の実行**
   - 該当ファイルを編集
   - テストを追加（必要な場合）
   - ドキュメントを更新

3. **修正のコミット**
```bash
!git add -A
!git commit -m "fix: PR #$pr_number レビュー指摘対応

$(echo "$review_comments" | head -5)"
!git push
```

4. **レビュアーへの返信**
```bash
!gh pr comment $pr_number --body "レビューありがとうございます。
以下の修正を行いました：
- 指摘事項1の対応
- 指摘事項2の対応
再度ご確認をお願いします。"
```
