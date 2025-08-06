# Agent向け実装ガイド

## 実装の進め方

### 1. チケット着手前の確認事項
```bash
# 1. 依存チケットの完了確認
cat docs/tickets/XXX_*.md | grep "ステータス"

# 2. プロジェクトの最新状態を取得
git pull

# 3. 新しいブランチを作成
git checkout -b feature/ticket-XXX-機能名
```

### 2. 実装中の進捗更新
```markdown
# チケットファイル内のステータスを更新
## ステータス: [x] In Progress

# タスク完了時にチェックボックスを更新
- [x] 完了したタスク
```

### 3. 完了条件の確認方法

#### コード品質
- SwiftLintエラーが0件
- ビルドワーニングが0件
- **全てのファイルが改行で終わっていること**
  - `trailing_newline`ルールでチェックされます
  - エディタの設定で自動追加を有効にしてください
- 適切なコメントとドキュメント

#### テスト実行
```bash
# Unit Test
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'

# 特定のテストのみ実行
xcodebuild test -scheme TrainAlert -only-testing:TrainAlertTests/LocationManagerTests
```

#### 手動確認
- シミュレーターでの動作確認
- 各種デバイスサイズでのUI確認
- メモリリークの確認（Instruments）

### 4. チケット完了時の手順

1. **全タスクの完了確認**
   ```markdown
   - [x] 全てのタスクにチェック
   ## ステータス: [x] Completed
   ```

2. **成果物の確認**
   - 作成したファイルのリスト
   - 更新したファイルのリスト
   - テストカバレッジ

3. **プルリクエスト作成**
   ```bash
   git add .
   git commit -m "feat: #XXX 機能名の実装"
   git push origin feature/ticket-XXX-機能名
   ```

4. **次のチケットへの引き継ぎ**
   - 実装時の注意点をチケットに追記
   - 依存関係の更新

## 各Agentの専門分野

### インフラAgent
- プロジェクト設定
- データベース設計
- API通信基盤

### システムAgent
- バックグラウンド処理
- 位置情報管理
- 通知システム

### UI Agent
- 画面実装
- アニメーション
- ユーザビリティ

### 機能Agent
- ビジネスロジック
- 外部API連携
- データ処理

### 品質Agent
- テスト実装
- パフォーマンス改善
- リリース準備

## コミュニケーション方法

### チケット内でのメモ
```markdown
## 実装メモ
- [Agent1] Core Dataのマイグレーションに注意
- [Agent2] Background Modesの設定を忘れずに
```

### ブロッカーの報告
```markdown
## ブロッカー
- [ ] #006のAPI実装待ち（予定: MM/DD）
```

### 完了通知
```markdown
## 完了通知
- [x] #003 Core Data実装完了 - Agent1
- 次のチケット #010 に着手可能
```

## トラブルシューティング

### ビルドエラー
1. Clean Build Folder（Cmd+Shift+K）
2. Derived Data削除
3. Pod/SPM更新

### 依存関係の問題
1. dependency_graph.mdを確認
2. 前提チケットの完了状態を確認
3. 必要に応じて実装順序を調整

### マージコンフリクト
1. 最新のmainをpull
2. コンフリクト解消
3. テスト再実行

## 成功のポイント

1. **こまめな進捗更新**
   - 1日1回以上チケット更新
   - ブロッカーは即座に報告

2. **品質重視**
   - テストを書く
   - コードレビューの観点を意識

3. **ドキュメント**
   - 実装の意図を明確に
   - 次のAgentが理解しやすく

4. **協調作業**
   - 並列作業時の調整
   - 共通コンポーネントの共有
