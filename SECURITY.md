# セキュリティ設定

## 環境変数の保護

このプロジェクトでは、セキュリティ強化のため以下の対策を実施しています：

### 1. 環境変数アクセスの制限

`.claude/settings.json`で以下のコマンドを禁止：
- `echo $*` - 環境変数の表示
- `printenv` - 全環境変数の一覧表示
- `env` - 環境変数の操作
- `export` - 環境変数の設定
- `set` - シェル変数の表示

さらに、以下のパターンを含むコマンドも禁止：
- `*GITHUB_PERSONAL_ACCESS_TOKEN*`
- `*API_KEY*`
- `*SECRET*`
- `*TOKEN*`
- `*PASSWORD*`

### 2. GitHub Personal Access Tokenの管理

1. **トークンはGitにコミットしない**
   - `.env`ファイルは`.gitignore`に追加済み
   - `mcp.json`にトークンを直接記載しない

2. **環境変数経由での使用**
   ```bash
   # .envファイルを作成
   cp .env.example .env
   # エディタで.envを編集してトークンを設定
   
   # Claude Code起動時に環境変数を設定
   source .env && claude
   ```

3. **direnvによる自動管理**（推奨）
   ```bash
   brew install direnv
   direnv allow .
   ```

### 3. 最小権限の原則

- GitHub tokenは必要最小限の権限のみ付与
- Web関連ツール（WebFetch, WebSearch）は無効化
- ファイルシステムアクセスは特定ディレクトリのみ

### 4. 定期的なセキュリティレビュー

- トークンの定期的な更新
- 権限設定の見直し
- アクセスログの確認

## 問題報告

セキュリティ上の問題を発見した場合は、公開せずに直接連絡してください。