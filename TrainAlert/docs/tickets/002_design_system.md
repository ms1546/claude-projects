# Ticket #002: デザインシステム構築

## 概要
シックなテーマのカラーパレット、フォント、共通UIコンポーネントの実装

## 優先度: High
## 見積もり: 3h
## ステータス: [ ] Not Started

## タスク
- [ ] Color Extension作成
  - [ ] Primary Colors定義
  - [ ] Accent Colors定義
  - [ ] Neutral Colors定義
- [ ] Typography定義
  - [ ] Font styles
  - [ ] Text modifiers
- [ ] 共通UIコンポーネント作成
  - [ ] PrimaryButton
  - [ ] SecondaryButton
  - [ ] Card View
  - [ ] Loading Indicator
- [ ] アプリアイコンデザイン
- [ ] Launch Screen作成
- [ ] ダークモード対応確認

## 実装ガイドライン
- SwiftUIのColor ExtensionとViewModifier使用
- Dynamic Type対応必須
- ダークモードをデフォルトに
- 参考: Apple Human Interface Guidelines

## 完了条件（Definition of Done）
- [ ] 全カラーがAsset Catalogに登録
- [ ] 各コンポーネントのプレビュー実装
- [ ] VoiceOver対応
- [ ] Dynamic Type対応
- [ ] ドキュメント作成

## テスト方法
1. 各種デバイスサイズでプレビュー確認
2. アクセシビリティインスペクタでチェック
3. 色覚多様性シミュレーター確認

## 依存関係
- 前提: #001完了
- ブロック: #008, #009, #010, #011

## 成果物
- DesignSystem/Colors.swift
- DesignSystem/Typography.swift
- DesignSystem/Components/
- docs/design_system_guide.md

## 実装メモ
- カラーコードは/docs/ui_design.mdを参照
- コンポーネントは再利用性を重視