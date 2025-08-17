# Configuration.plist 設定ガイド

## 実機での動作に必要な設定

TrainAlertを実機で動作させるには、Configuration.plistファイルが必要です。

### 設定手順

1. **Configuration.plistを作成**
   ```bash
   cp TrainAlert/Configuration.plist.sample TrainAlert/Configuration.plist
   ```

2. **APIキーを設定**
   Configuration.plistを開いて、以下のキーを設定してください：
   - `ODPT_API_KEY`: ODPT（公共交通オープンデータ）のAPIキー
   - `OPENAI_API_KEY`: OpenAI APIキー（オプション）

3. **Xcodeプロジェクトに追加**
   - XcodeでTrainAlertプロジェクトを開く
   - Configuration.plistをプロジェクトナビゲータにドラッグ＆ドロップ
   - "Copy items if needed"にチェック
   - ターゲット"TrainAlert"が選択されていることを確認
   - "Finish"をクリック

4. **ビルドフェーズを確認**
   - プロジェクト設定 → TrainAlertターゲット → Build Phases
   - "Copy Bundle Resources"にConfiguration.plistが含まれていることを確認

### APIキーの取得方法

#### ODPT APIキー
1. https://developer.odpt.org/ にアクセス
2. 無料でアカウント登録
3. APIキーを発行

#### OpenAI APIキー（オプション）
1. https://platform.openai.com/ にアクセス
2. アカウント登録
3. API Keysページでキーを生成

### トラブルシューティング

実機でAPIが動作しない場合：
1. Configuration.plistがアプリバンドルに含まれているか確認
2. APIキーが正しく設定されているか確認
3. .gitignoreにConfiguration.plistが含まれているか確認（含まれている必要がある）

### セキュリティ注意事項

- Configuration.plistには機密情報が含まれるため、Gitにコミットしないでください
- .gitignoreに既に登録されています
- APIキーは他人と共有しないでください