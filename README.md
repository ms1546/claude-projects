# Claude Development Projects

このリポジトリは、Claude Codeを使用した開発プロジェクトのコレクションです。

## プロジェクト

### TrainAlert - 電車寝過ごし防止アプリ
iOS向けの電車寝過ごし防止アプリケーション。GPSとAI通知を活用。

- 📱 iOS 16.0+
- 🔧 Swift 5.9 / SwiftUI
- 🤖 ChatGPT APIによるカスタム通知
- 📍 位置情報ベースアラート

詳細は [TrainAlert/README.md](TrainAlert/README.md) を参照。

## セットアップ

### MCP (Model Context Protocol)
```bash
# MCPサーバーの設定
cat mcp.json

# serenaの使用
/symbol find [symbol-name]
/memory write [key] [value]
```

### カスタムコマンド
`.claude/commands/` にプロジェクト専用のslash commandsを定義。

### Hooks
`.claude/hooks/` に開発効率化のためのhooksを設定。

## 開発環境
- M2 Mac
- Xcode 15.0+
- Claude Code with MCP servers

## ライセンス
Private Repository