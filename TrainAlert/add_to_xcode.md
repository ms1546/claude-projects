# Xcodeプロジェクトに追加するファイル

以下のファイルをXcodeプロジェクトに追加してください：

## 1. ODPTフォルダを作成して追加
Services グループ内に "ODPT" フォルダを作成し、以下を追加：
- [ ] Services/ODPT/ODPTAPIConfiguration.swift
- [ ] Services/ODPT/ODPTModels.swift
- [ ] Services/ODPT/ODPTAPIClient.swift

## 2. Core Dataモデル
CoreData/Models グループに追加：
- [ ] CoreData/Models/RouteAlert+CoreDataClass.swift

## 3. ViewModels
ViewModels グループに追加：
- [ ] ViewModels/RouteSearchViewModel.swift

## 4. RouteSearchフォルダを作成して追加
Views グループ内に "RouteSearch" フォルダを作成し、以下を追加：
- [ ] Views/RouteSearch/RouteSearchView.swift
- [ ] Views/RouteSearch/TimetableAlertSetupView.swift

## 追加手順
1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲータで該当するグループを右クリック
3. "Add Files to TrainAlert..." を選択
4. 上記のファイルを選択
5. "Copy items if needed" にチェック
6. "Create groups" を選択
7. Target "TrainAlert" にチェック
8. "Add" をクリック

## ビルド前の確認事項
- [ ] 環境変数 ODPT_API_KEY が設定されていること
- [ ] すべてのファイルがTargetメンバーシップに含まれていること