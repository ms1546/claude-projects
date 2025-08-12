# PR作成前ワークフロー

## 概要
プルリクエスト（PR）を作成する前に実施すべき手順とチェックリストです。

## 1. 実装前の準備

### 1.1 チケットの確認
- [ ] 実装するチケットの要件を理解している
- [ ] 依存関係にあるチケットが完了している
- [ ] 受け入れ要件が明確である

### 1.2 ブランチの作成
```bash
# 最新のmainブランチから作成
git checkout main
git pull origin main
git checkout -b <feature/fix>/<ticket-number>-<brief-description>

# 例：
# git checkout -b feat/016-free-station-api
# git checkout -b fix/station-search-issue
```

## 2. 実装

### 2.1 コーディング規約
- [ ] SwiftLintの設定に従っている
- [ ] プロジェクトのコーディング規約に準拠している
- [ ] 不要なprint文やデバッグコードを削除している

### 2.2 実装の確認
- [ ] 要件定義通りに実装されている
- [ ] エラーハンドリングが適切に実装されている
- [ ] パフォーマンスへの影響を考慮している

## 3. テスト

### 3.1 ユニットテスト
```bash
# 特定のテストを実行
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:<TestTarget>/<TestClass>

# 全てのテストを実行
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### 3.2 受け入れテスト
- [ ] 受け入れ要件ドキュメントの全項目をテストした
- [ ] 正常系・異常系の両方をテストした
- [ ] エッジケースをテストした

### 3.3 動作確認
- [ ] シミュレーターで動作確認した
- [ ] 可能であれば実機で動作確認した
- [ ] 既存機能へのリグレッションがないことを確認した

## 4. コード品質チェック

### 4.1 SwiftLint
```bash
# プロジェクト全体のLintチェック
swiftlint lint --strict

# 修正が必要なエラーのみ表示
swiftlint lint --strict --reporter json | jq -r '.[] | select(.severity == "Error") | "\(.file):\(.line):\(.character) \(.rule_id): \(.reason)"'
```

### 4.2 ビルド確認
```bash
# Debugビルド
xcodebuild -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet build

# Releaseビルド（オプション）
xcodebuild -scheme TrainAlert -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet build
```

## 5. コミット

### 5.1 コミット前の確認
- [ ] 不要なファイルがステージングされていない
- [ ] .gitignoreで除外すべきファイルがない
- [ ] 変更内容が適切にグループ化されている

### 5.2 コミットメッセージ
```bash
# コミットメッセージの形式
<type>: <subject>

<body>

<footer>

# type: feat, fix, docs, style, refactor, test, chore
# subject: 50文字以内の変更内容の要約
# body: 詳細な説明（なぜ変更したか、どのように変更したか）
# footer: 関連するIssue番号、Breaking Changeなど
```

例：
```bash
git commit -m "feat: 無料駅データAPI統合の実装

- HeartRails Express APIを使用した動的な駅データ取得
- searchStations関数をAPI対応に改修
- 検索結果のキャッシュ機能（24時間有効）

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## 6. PR作成

### 6.1 PR作成前の最終確認
- [ ] 全てのテストが通っている
- [ ] SwiftLintエラーがない
- [ ] ビルドが成功している
- [ ] 受け入れ要件を満たしている

### 6.2 PRの作成
```bash
# GitHub CLIを使用
gh pr create --repo <owner>/<repo> --title "<PR title>" --body "<PR description>"

# または、ブラウザで作成
# 1. git push -u origin <branch-name>
# 2. GitHubのリポジトリページでPRを作成
```

### 6.3 PRテンプレート
```markdown
## 概要
[変更の概要を簡潔に記載]

## 変更内容
- [ ] 機能A の実装
- [ ] バグB の修正
- [ ] ドキュメントC の更新

## テスト
- [ ] ユニットテストを実行し、全てパスした
- [ ] 受け入れテストを実行し、全てパスした
- [ ] 手動テストを実行し、問題がないことを確認した

## スクリーンショット
[必要に応じて画面キャプチャを添付]

## 注意事項
[レビュアーに伝えるべき注意事項があれば記載]

## 関連チケット
- #[チケット番号]
```

## 7. CI/CDの確認

### 7.1 GitHub Actions
- [ ] 全てのCIジョブが成功している
- [ ] コードカバレッジが低下していない
- [ ] セキュリティスキャンに問題がない

### 7.2 失敗時の対応
1. エラーログを確認
2. ローカルで同じテストを実行して再現
3. 修正をコミット＆プッシュ
4. CIが再実行されることを確認

## 8. トラブルシューティング

### 8.1 よくある問題

#### SwiftLintエラー
```bash
# 自動修正可能なものは修正
swiftlint autocorrect

# pre-commit hookをスキップ（緊急時のみ）
git commit --no-verify
```

#### テストの失敗
- 環境依存の問題がないか確認
- テストデータの初期化が正しく行われているか確認
- 非同期処理のタイムアウト時間が適切か確認

#### ビルドエラー
- クリーンビルドを試す
- DerivedDataを削除する
- Xcodeを再起動する

## 9. レビュー対応

### 9.1 レビューコメントへの対応
- [ ] 全てのコメントに返信または対応している
- [ ] 変更要求に対して適切に修正している
- [ ] 修正内容を明確にコミットメッセージに記載している

### 9.2 マージ準備
- [ ] Approveを得ている
- [ ] CIが全て成功している
- [ ] コンフリクトが解決されている
- [ ] ブランチが最新のmainと同期している

---

このワークフローに従うことで、品質の高いPRを作成し、スムーズなレビュープロセスを実現できます。