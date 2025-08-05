# 開発ワークフロー

## ブランチ戦略

### 基本ルール
- `main`ブランチへの直接プッシュは禁止
- すべての変更はPull Request (PR)経由でマージ
- PRにはレビューと承認が必要

### ブランチ命名規則
- `feature/ticket-XXX-description` - 新機能
- `fix/ticket-XXX-description` - バグ修正
- `docs/description` - ドキュメント更新
- `refactor/ticket-XXX-description` - リファクタリング

## 開発フロー

### 1. 新しい作業を開始

```bash
# 最新のmainを取得
git checkout main
git pull origin main

# チケットに基づいて新しいブランチを作成
git checkout -b feature/ticket-001-project-setup

# または、slashコマンドを使用
/ticket start 001
```

### 2. 開発作業

```bash
# 変更を加える
# ... コーディング ...

# 変更を確認
git status
git diff

# コミット
git add .
git commit -m "feat: #001 プロジェクトセットアップ完了

- Xcodeプロジェクト作成
- ディレクトリ構造整理
- SwiftLint設定"
```

### 3. プッシュとPR作成

```bash
# リモートにプッシュ
git push -u origin feature/ticket-001-project-setup

# GitHub CLIでPR作成
gh pr create --title "feat: #001 プロジェクトセットアップ" \
  --body "## 概要
チケット #001 の実装

## 変更内容
- Xcodeプロジェクトの初期設定
- プロジェクト構造の整理
- 開発環境の構築

## テスト
- [ ] ビルド成功確認
- [ ] SwiftLint実行確認

## チケット
Closes #001"
```

### 4. レビューとマージ

#### レビュアー側
```bash
# PR一覧を確認
gh pr list

# PRをチェックアウト
gh pr checkout 123

# ローカルでテスト
/swift-test all

# レビューコメント
gh pr review 123 --comment -b "LGTMです。マージして問題ありません。"

# 承認
gh pr review 123 --approve
```

#### 作成者側（レビュー後）
```bash
# フィードバックに対応
git add .
git commit -m "fix: レビュー指摘事項を修正"
git push

# マージ（レビュー承認後）
gh pr merge 123 --squash --delete-branch
```

## コミットメッセージ規約

### フォーマット
```
<type>: <subject>

<body>

<footer>
```

### Type
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメントのみの変更
- `style`: コードの意味に影響しない変更
- `refactor`: リファクタリング
- `test`: テストの追加・修正
- `chore`: ビルドプロセスやツールの変更

### 例
```
feat: #001 位置情報サービスの実装

- CLLocationManagerの初期設定
- バックグラウンド更新の対応
- 権限リクエストの実装

Closes #001
```

## GitHub Pro未使用時の運用ルール

### 手動で守るべきルール
1. **mainへの直接プッシュ禁止**
   - 必ずブランチを作成
   - 自己レビューでもPRを作成

2. **PR作成時のチェックリスト**
   - [ ] ビルドが通る
   - [ ] テストが通る
   - [ ] SwiftLintエラーなし
   - [ ] チケット番号を記載
   - [ ] 適切なレビュアーを指定

3. **マージ前の確認**
   - [ ] 最低1人のレビュー
   - [ ] すべてのコメントに対応
   - [ ] CIが通っている（将来実装）

## 緊急時の対応

### ホットフィックス
```bash
# mainから直接ブランチを作成
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# 修正後、通常通りPRを作成
# タイトルに[HOTFIX]を付ける
gh pr create --title "[HOTFIX] 重大なバグの修正"
```

## ベストプラクティス

1. **小さなPRを心がける**
   - 1つのPRで1つの機能/修正
   - レビューしやすい規模に保つ

2. **早めのPR作成**
   - WIP（Work In Progress）でも早めに共有
   - `gh pr create --draft`でドラフトPR作成

3. **継続的な統合**
   - 定期的にmainをマージ
   - コンフリクトを早期解決

4. **コミュニケーション**
   - PRにはコンテキストを記載
   - レビューコメントは建設的に
   - 不明点は積極的に質問

## 自動化スクリプト

### PR作成補助スクリプト
`scripts/create_pr.sh`を作成予定：
- チケット番号から自動的にPRタイトル生成
- テンプレートに基づいたPR本文作成
- レビュアーの自動アサイン