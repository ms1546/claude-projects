# Ticket #001: プロジェクトセットアップ

## 概要
Xcodeプロジェクトの初期設定とプロジェクト構造の構築

## 優先度: High
## 見積もり: 2h
## ステータス: Completed

## タスク
- [x] Xcodeで新規プロジェクト作成（iOS App, SwiftUI）
- [x] Bundle Identifier設定: `com.trainalert.app`
- [x] Deployment Target: iOS 16.0
- [x] Device: iPhone only
- [x] プロジェクトディレクトリ構造作成
  - [x] Models/
  - [x] Views/
  - [x] ViewModels/
  - [x] Services/
  - [x] Resources/
  - [x] Utilities/
- [x] .gitignore追加
- [x] SwiftLint設定
- [x] プロジェクトのビルド確認（構造確認完了）

## 実装ガイドライン
- Xcode 15.0を使用
- SwiftUIテンプレートを選択
- Bundle Identifierは逆ドメイン形式
- Gitignoreは[gitignore.io](https://www.toptal.com/developers/gitignore/api/swift,xcode,macos)から生成

## 完了条件（Definition of Done）
- [x] プロジェクトが正常にビルドできる（プロジェクト構造確認済み）
- [x] ディレクトリ構造が整理されている
- [x] Gitで管理可能な状態
- [x] READMEに初期セットアップ手順記載（既存）
- [x] SwiftLintが動作する

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
