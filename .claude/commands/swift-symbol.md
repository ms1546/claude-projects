---
description: Swift専用のシンボル操作
argumentHints: "[class|method|property|protocol] [name] [action]"
---

# Swiftシンボル専用コマンド

タイプ: $ARGUMENTS

Swift開発に特化したserenaのシンボル操作を実行します。

## 使用例
- `/swift-symbol class LocationManager show` - クラス全体を表示
- `/swift-symbol method viewDidLoad find` - viewDidLoadメソッドを検索
- `/swift-symbol property isActive rename isEnabled` - プロパティ名を変更
- `/swift-symbol protocol Alertable implementations` - プロトコル実装を検索

## Swift固有の操作

### クラス操作
- 継承関係の確認
- extensionの検索
- プロトコル準拠の確認

### メソッド操作
- オーバーライドの追跡
- @objc/@IBAction の検索
- async/awaitメソッドの特定

### プロパティ操作
- @Published/@State の検索
- computed propertyの分析
- property wrapperの使用箇所

### プロトコル操作
- 実装クラスの一覧
- デフォルト実装の確認
- associated typeの追跡

serenaのツールを組み合わせて、Swift特有の構造を効率的に操作します。
