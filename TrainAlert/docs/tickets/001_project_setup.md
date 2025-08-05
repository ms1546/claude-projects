# Ticket #001: プロジェクトセットアップ

## 概要
Xcodeプロジェクトの初期設定とプロジェクト構造の構築

## 優先度: High
## 見積もり: 2h
## ステータス: [ ] Not Started

## タスク
- [ ] Xcodeで新規プロジェクト作成（iOS App, SwiftUI）
- [ ] Bundle Identifier設定: `com.yourdomain.TrainAlert`
- [ ] Deployment Target: iOS 16.0
- [ ] Device: iPhone only
- [ ] プロジェクトディレクトリ構造作成
  - [ ] Models/
  - [ ] Views/
  - [ ] ViewModels/
  - [ ] Services/
  - [ ] Resources/
  - [ ] Utilities/
- [ ] .gitignore追加
- [ ] SwiftLint設定
- [ ] プロジェクトのビルド確認

## 実装ガイドライン
- Xcode 15.0を使用
- SwiftUIテンプレートを選択
- Bundle Identifierは逆ドメイン形式
- Gitignoreは[gitignore.io](https://www.toptal.com/developers/gitignore/api/swift,xcode,macos)から生成

## 完了条件（Definition of Done）
- [ ] プロジェクトが正常にビルドできる
- [ ] ディレクトリ構造が整理されている
- [ ] Gitで管理可能な状態
- [ ] READMEに初期セットアップ手順記載
- [ ] SwiftLintが動作する

## テスト方法
1. `xcodebuild -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15' build`
2. 各ディレクトリにサンプルファイルを配置してビルド確認

## 依存関係
- 前提: なし
- ブロック: 全てのチケット

## 成果物
- TrainAlert.xcodeproj
- プロジェクトディレクトリ構造
- .gitignore
- .swiftlint.yml
- README.md（初期版）

## 備考
- M2 Macでの開発を前提
- 初回起動時にSigning設定が必要
