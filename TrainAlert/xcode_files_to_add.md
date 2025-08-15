# Xcodeに追加するファイル一覧

## 修正済みファイル一覧

### 1. Services/ODPT フォルダを作成して追加
- Services/ODPT/ODPTAPIConfiguration.swift
- Services/ODPT/ODPTModels.swift
- Services/ODPT/ODPTAPIClient.swift

### 2. Models フォルダに追加
- Models/RouteModels.swift

### 3. CoreData/Models フォルダに追加
- CoreData/Models/RouteAlert+CoreDataClass.swift

### 4. ViewModels フォルダに追加
- ViewModels/RouteSearchViewModel.swift

### 5. Views/RouteSearch フォルダを作成して追加
- Views/RouteSearch/RouteSearchView.swift
- Views/RouteSearch/TimetableAlertSetupView.swift

## 修正済みの既存ファイル
- Services/NotificationManager.swift（scheduleRouteNotificationメソッドを追加）
- Views/HomeView.swift（経路検索へのナビゲーションを追加）
- Models/CharacterStyle.swift（normalプロパティとヘルパーメソッドを追加）

## ビルド前の確認
1. 環境変数 ODPT_API_KEY を設定
2. すべての新規ファイルをXcodeプロジェクトに追加
3. Target membershipが正しく設定されていることを確認