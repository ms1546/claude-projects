# チケット #020: 目覚まし編集機能の実装

## 概要
既存の目覚ましを編集できる機能を追加する

## ステータス: [ ] Not Started / [ ] In Progress / [x] Completed

## 要件
1. **編集UI**
   - 既存の目覚ましをタップまたはスワイプで編集モードに入る
   - AlertSetupCoordinatorを再利用して編集できるようにする
   - 編集中は「作成」ではなく「更新」と表示

2. **編集可能な項目**
   - 降車駅の変更
   - 通知タイミング（分前）
   - 通知距離
   - スヌーズ間隔
   - キャラクタースタイル

3. **UIフロー**
   - HomeViewの目覚ましカードから編集を開始
   - 左スワイプで「編集」オプションを表示
   - または長押しメニューから「編集」を選択
   - 編集画面は新規作成と同じUIを使用

## 実装内容
- [x] AlertSetupCoordinatorに編雈モードを追加
- [x] AlertSetupViewModelに既存データの読み込み機能を追加
- [x] HomeViewから編雈画面への遷移を実装
- [x] CoreDataの更新処理を実装
- [x] 編雈完了後の通知メッセージを調整

## 技術仕様
- AlertSetupCoordinatorの初期化時に編集対象のAlertを渡す
- ViewModelで編集モードを判定してUIを切り替える
- Core Dataの更新はCoreDataManagerで処理

## 依存関係
- なし（独立したタスク）

## 完了条件
- [x] 既存の目覚ましを編集できる
- [x] 編集内容が正しく保存される
- [x] UIが編集モードと新規作成モードで適切に切り替わる
- [x] エラーハンドリングが適切に実装されている

## 実装完了日
2025-08-25

## 実装の詳細
- HomeViewのスワイプアクションに編集ボタンを追加
- AlertSetupCoordinatorに編集対象のアラートを受け取る機能を追加  
- AlertSetupViewModelにloadExistingAlert関数を追加し、既存データを読み込み可能に
- CoreDataの更新処理（updateAlertInCoreData）を実装
- 編集モードでは「作成」の代わりに「更新」と表示するよう調整
- ビルドエラーを修正し、正常にビルドできることを確認