#!/bin/bash

# PR作成スクリプト
cat << 'EOF'
## 概要
チケット #001 プロジェクトセットアップを完了しました。

## 変更内容
- ✅ Xcodeプロジェクト作成 (Bundle ID: com.trainalert.app)
- ✅ iOS 16.0+ 対応設定
- ✅ MVVM構造のディレクトリ作成
- ✅ SwiftLint設定追加
- ✅ テストターゲット作成（Unit/UI Tests）
- ✅ Info.plist設定（位置情報、バックグラウンドモード）
- ✅ .gitignore追加

## テスト
- プロジェクト構造の確認完了
- SwiftLint設定の動作確認

## チェックリスト
- [x] コードレビュー依頼
- [x] テスト実行
- [x] ドキュメント更新

## 関連Issue
- #001

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF