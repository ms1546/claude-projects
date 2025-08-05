---
description: ビルドとリリース準備
argumentHints: "[debug|release|testflight|clean]"
---

# ビルドコマンド

ビルドタイプ: $ARGUMENTS

## ビルドアクション
1. `debug`: 開発用ビルド
   ```bash
   !xcodebuild -scheme TrainAlert -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build
   ```

2. `release`: リリースビルド
   ```bash
   !xcodebuild -scheme TrainAlert -configuration Release -destination generic/platform=iOS archive -archivePath ./build/TrainAlert.xcarchive
   ```

3. `testflight`: TestFlight用IPA作成
   - アーカイブを作成
   - ExportOptions.plistを生成
   - IPAをエクスポート

4. `clean`: クリーンビルド
   ```bash
   !xcodebuild clean -scheme TrainAlert
   !rm -rf ~/Library/Developer/Xcode/DerivedData/TrainAlert-*
   ```

## ビルド後の確認
- ワーニング数を報告
- バイナリサイズを確認
- 必要な権限設定を確認
- Info.plistの設定を検証