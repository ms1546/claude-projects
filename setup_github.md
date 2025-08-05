# GitHub リポジトリセットアップ手順

## 1. GitHub Personal Access Token の作成

1. GitHubにログイン
2. Settings → Developer settings → Personal access tokens → Tokens (classic)
3. "Generate new token" をクリック
4. 必要な権限を選択:
   - `repo` (フルアクセス)
   - `workflow` (GitHub Actions用)
5. トークンをコピー

## 2. mcp.json の更新

```bash
# mcp.jsonのGITHUB_PERSONAL_ACCESS_TOKENにトークンを設定
# "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxxxxxxxxxxxx"
```

## 3. GitHubリポジトリの作成

### 方法1: GitHub CLIを使用（推奨）
```bash
# GitHub CLIでログイン
gh auth login

# リポジトリ作成
gh repo create claude-projects --private --description "Claude Code development projects"

# リモート追加
git remote add origin https://github.com/maemotosato/claude-projects.git
```

### 方法2: 手動で作成
1. https://github.com/new にアクセス
2. Repository name: `claude-projects`
3. Private を選択
4. Create repository

## 4. 初回コミットとプッシュ

```bash
# 全ファイルをステージング
git add .

# 初回コミット
git commit -m "Initial commit: TrainAlert project setup with MCP and hooks"

# mainブランチに設定
git branch -M main

# GitHubにプッシュ
git push -u origin main
```

## 5. 今後の更新

```bash
# 変更をステージング
git add .

# コミット
git commit -m "feat: 変更内容の説明"

# プッシュ
git push
```

## 注意事項

- `.gitignore`でAPIキーなどの機密情報は除外済み
- mcp.jsonのトークンは直接コミットしないこと
- 環境変数での管理を推奨
