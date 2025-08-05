---
description: 変更を自動でコミット、プッシュ、PR作成
argumentHints: "[ticket-number] [commit-message]"
---

# Git自動アップロード & PR作成

引数: $ARGUMENTS

現在の変更を自動でGitにアップロードし、開発フローに従ってPRを作成します。

## 処理フロー

1. **現在のブランチと状態確認**
   - mainブランチでないことを確認
   - 変更があることを確認
   - チケット番号を特定

2. **自動コミット**
   - 変更をステージング
   - 適切なコミットメッセージ生成
   - コミット実行

3. **リモートへプッシュ**
   - 現在のブランチをoriginにプッシュ
   - 新規ブランチの場合は-uオプション付き

4. **PR自動作成**
   - チケット情報から内容生成
   - レビュアー自動設定（@ms1546）
   - テンプレートに基づいた本文

## 実行内容

```bash
# 現在のブランチ確認
!git branch --show-current

# 変更状況確認
!git status --short

# mainブランチチェック
current_branch=$(git branch --show-current)
if [ "$current_branch" = "main" ]; then
  echo "❌ mainブランチから直接の操作はできません"
  echo "新しいブランチを作成してください"
  exit 1
fi

# チケット番号の推定
if [ -z "$1" ]; then
  # ブランチ名から推定: feature/ticket-XXX-*
  ticket_num=$(echo $current_branch | grep -oE 'ticket-[0-9]{3}' | sed 's/ticket-//')
else
  ticket_num="$1"
fi

# 変更をステージング
!git add -A

# コミットメッセージ生成
if [ -z "$2" ]; then
  # チケット情報から自動生成
  commit_msg="feat: #$ticket_num 実装進捗

$(git diff --cached --name-only | head -10 | sed 's/^/- /')"
else
  commit_msg="$2"
fi

# コミット
!git commit -m "$commit_msg"

# プッシュ
!git push -u origin $current_branch

# PR作成
!source .env && GH_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN gh pr create \
  --title "feat: #$ticket_num $(basename $(ls TrainAlert/docs/tickets/${ticket_num}_*.md 2>/dev/null | head -1) .md | sed 's/[0-9]*_//')" \
  --body "## 概要
チケット #$ticket_num の実装

## 変更内容
$(git log origin/main..$current_branch --oneline | sed 's/^/- /')

## チェックリスト
- [ ] ビルドが成功する
- [ ] SwiftLintエラーなし
- [ ] テストが通る
- [ ] チケットの完了条件を満たしている

## 関連チケット
Closes #$ticket_num

## レビュー依頼
@ms1546 レビューをお願いします。" \
  --reviewer ms1546 \
  --base main
```

## 使用例
- `/git-upload` - ブランチ名からチケット番号を推定して自動実行
- `/git-upload 001` - チケット#001として処理
- `/git-upload 001 "fix: レビュー指摘修正"` - カスタムコミットメッセージ

## 注意事項
- mainブランチでは実行不可
- .envファイルにGitHub tokenが必要
- 変更がない場合はスキップ