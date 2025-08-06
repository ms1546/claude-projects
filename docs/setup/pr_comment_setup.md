# GitHub PR コメント機能セットアップガイド

## 概要
このドキュメントでは、Claude Codeで GitHub PR のレビューコメントを効率的に管理する方法を説明します。

## 必要な権限

### GitHub Personal Access Token のスコープ
PRコメント機能を使用するには、以下のスコープが必要です：

1. **必須スコープ**
   - `repo` - リポジトリへのフルアクセス
   - `read:org` - 組織情報の読み取り（PR詳細表示に必要）

2. **推奨スコープ**
   - `workflow` - GitHub Actions ワークフローの管理
   - `read:user` - ユーザー情報の読み取り
   - `read:discussion` - ディスカッションの読み取り

### トークンの更新手順
1. https://github.com/settings/tokens にアクセス
2. 既存のトークンを編集または新規作成
3. 必要なスコープを選択
4. `.env` ファイルの `GITHUB_PERSONAL_ACCESS_TOKEN` を更新

## PRコメントの確認方法

### 1. コマンドラインでの確認
```bash
# 環境変数の設定
source .env && export GH_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN

# PR一覧の表示
gh pr list --state all

# 特定のPRのコメント表示
gh pr view [PR番号] --comments

# APIを使用した詳細情報の取得
gh api repos/[owner]/[repo]/pulls/[PR番号]/reviews
```

### 2. Claude Codeでの確認
```bash
# 現在のブランチのPRコメント
/pr-comments

# 特定のPRのコメント
/pr-comments 2
```

## レビュー指摘への対応例

### ケース1: ファイル末尾の改行不足
**指摘内容**: "No Newline at End of File"

**対応方法**:
1. 該当ファイルを特定
```bash
# 改行がないファイルを検索
find . -type f -name "*.swift" -exec tail -c 1 {} \; | wc -l
```

2. 自動修正
```bash
# すべてのSwiftファイルに改行を追加
find . -type f -name "*.swift" -exec sh -c 'tail -c1 {} | read -r _ || echo >> {}' \;
```

3. 再発防止策
- `.swiftlint.yml` に `trailing_newline` ルールを追加
- エディタ設定で自動改行を有効化
- CLAUDE.md に記載済み

### ケース2: コード品質の指摘
**対応フロー**:
1. 指摘内容の確認
2. 該当箇所の修正
3. テストの実行
4. コミット・プッシュ
5. レビュアーへの返信

## 修正後のワークフロー

### 1. 修正のコミット
```bash
git add -A
git commit -m "fix: PR #[番号] レビュー指摘対応

- ファイル末尾に改行を追加
- .swiftlint.yml にtrailing_newlineルールを追加
- CLAUDE.md に再発防止策を記載"
```

### 2. プッシュ
```bash
git push origin [ブランチ名]
```

### 3. レビュアーへの通知
```bash
gh pr comment [PR番号] --body "
@[レビュアー名] 
ご指摘ありがとうございました。
以下の修正を完了しましたので、再度ご確認をお願いします。

**修正内容:**
- ✅ 全ファイルの末尾に改行を追加
- ✅ CLAUDE.md に再発防止策を記載（既に対応済み）
- ✅ .swiftlint.yml にルールを追加

**再発防止策:**
- SwiftLintで自動チェック
- エディタ設定でEOF改行を自動化
- PR作成前のチェックリストに追加
"
```

## トラブルシューティング

### エラー: "Your token has not been granted the required scopes"
**原因**: トークンの権限不足
**解決策**: 上記の必要なスコープを追加

### エラー: "PR not found"
**原因**: リポジトリ名の誤りまたはプライベートリポジトリ
**解決策**: 
- リポジトリ名を確認: `git remote -v`
- トークンの `repo` スコープを確認

### エラー: "fatal: branch already checked out"
**原因**: git worktree で別の場所にチェックアウト済み
**解決策**: 
- `git worktree list` で確認
- 別のworktreeで作業するか、`git worktree remove` で削除

## ベストプラクティス

1. **定期的なチェック**
   - PR作成後は定期的にコメントを確認
   - レビュアーの指摘には迅速に対応

2. **丁寧なコミュニケーション**
   - 修正内容を明確に記載
   - 質問がある場合は遠慮なく確認

3. **自動化の活用**
   - Linterやフォーマッターで自動修正
   - CI/CDでの自動チェック

これにより、効率的にPRレビューコメントを管理し、迅速に対応することができます。