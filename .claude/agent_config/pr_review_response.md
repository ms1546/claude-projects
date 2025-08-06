# PRレビュー対応ガイド（Agent向け）

## 概要
このドキュメントは、GitHub PRレビューコメントへの対応方法をAgentが効率的に処理するためのガイドです。

## よくあるレビュー指摘と対応方法

### 1. ファイル末尾の改行不足（No Newline at End of File）

#### 検出方法
```bash
# 改行がないファイルを検索
find . -type f -name "*.swift" -exec sh -c 'tail -c1 {} | read -r _ && echo {}' \;

# ファイルの最後の文字を確認
tail -c 5 "filename.swift" | od -c
```

#### 修正方法
```bash
# すべてのSwiftファイルに改行を追加（存在しない場合のみ）
find . -name "*.swift" -type f -exec sh -c 'tail -c1 {} | read -r _ || echo >> {}' \;

# 特定のファイルタイプに対して実行
find . -type f \( -name "*.swift" -o -name "*.yml" -o -name "*.plist" \) -exec sh -c 'tail -c1 {} | read -r _ || echo >> {}' \;
```

#### 再発防止策
1. **CLAUDE.mdに記載済み** - コードスタイルセクションで改行の重要性を明記
2. **SwiftLint設定** - `.swiftlint.yml`に`trailing_newline`ルールを追加
3. **エディタ設定** - VSCode、Xcodeで自動改行を有効化

### 2. PRコメントへの返信テンプレート

#### 修正完了時
```bash
gh pr comment [PR番号] --body "@[レビュアー名] 
ご指摘ありがとうございました。
以下の対応を完了しましたので、ご確認をお願いします。

**修正内容:**
- ✅ [具体的な修正内容1]
- ✅ [具体的な修正内容2]

**確認方法:**
\`\`\`bash
# 修正確認コマンド
[確認コマンド]
\`\`\`

**再発防止策:**
- [実施した対策1]
- [実施した対策2]
"
```

#### 質問・確認が必要な場合
```bash
gh pr comment [PR番号] --body "@[レビュアー名]
ご確認ありがとうございます。

以下の点について確認させてください：
- 🤔 [質問内容1]
- 🤔 [質問内容2]

現在の実装では[現状の説明]となっていますが、
[代替案]についてはいかがでしょうか？
"
```

### 3. ブランチ操作のベストプラクティス

#### Worktree使用時の注意
```bash
# worktreeの状態確認
git worktree list

# worktreeが壊れた場合の修復
git worktree prune

# 新しいworktreeを作成
git worktree add -b feature/fix-review ../fix-review origin/feature/branch-name
```

#### 現在の変更を保持しながらPRブランチで作業
```bash
# 1. 現在の変更を退避
git stash push -m "WIP: current work"

# 2. PRブランチに切り替え
git checkout feature/pr-branch

# 3. 修正作業を実施
# ...

# 4. 修正をコミット・プッシュ
git add -A
git commit -m "fix: レビュー指摘対応"
git push

# 5. 元のブランチに戻る
git checkout main
git stash pop
```

### 4. 自動化スクリプト

#### PR修正対応スクリプト
```bash
#!/bin/bash
# pr-fix.sh

PR_NUMBER=$1
REVIEW_ITEM=$2

case "$REVIEW_ITEM" in
  "newline")
    echo "🔧 ファイル末尾の改行を修正中..."
    find . -name "*.swift" -type f -exec sh -c 'tail -c1 {} | read -r _ || echo >> {}' \;
    find . -name "*.yml" -type f -exec sh -c 'tail -c1 {} | read -r _ || echo >> {}' \;
    echo "✅ 改行の修正完了"
    ;;
  "format")
    echo "🔧 コードフォーマットを実行中..."
    swiftlint autocorrect
    echo "✅ フォーマット完了"
    ;;
  *)
    echo "❌ 不明な修正項目: $REVIEW_ITEM"
    exit 1
    ;;
esac

# 変更をコミット
if [[ -n $(git status --porcelain) ]]; then
  git add -A
  git commit -m "fix: PR #$PR_NUMBER - $REVIEW_ITEM 修正"
  echo "📝 コミット完了"
fi
```

### 5. チェックリスト

PR作成前の確認事項：
- [ ] すべてのファイルが改行で終わっている
- [ ] SwiftLintエラーがない
- [ ] テストが通る
- [ ] ドキュメントが更新されている
- [ ] コミットメッセージが規約に従っている

### 6. トラブルシューティング

#### "Already checked out in worktree"エラー
```bash
# エラーが発生したworktreeを確認
git worktree list

# 不要なworktreeを削除
git worktree remove [path]

# または強制的にチェックアウト
git checkout -f feature/branch-name
```

#### GitHub APIの権限エラー
```bash
# トークンの権限を確認
gh auth status

# 必要なスコープ：repo, read:org
# .envファイルのGITHUB_PERSONAL_ACCESS_TOKENを更新
```

## 関連ドキュメント
- [PR Comment Setup Guide](/docs/setup/pr_comment_setup.md)
- [CLAUDE.md](/CLAUDE.md) - コーディング規約
- [GitHub API Documentation](https://docs.github.com/en/rest)