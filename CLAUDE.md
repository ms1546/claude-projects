# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: TrainAlert - 電車寝過ごし防止アプリ

iOS app to prevent oversleeping on trains using location-based and AI-generated notifications.

## Development Setup

### Environment
- Xcode 15.0+
- Swift 5.9
- iOS 16.0 (Minimum deployment target - iOS 18は未対応)
- SwiftUI for UI
- M2 Mac development environment

### Project Structure
```
TrainAlert/
├── Models/         # Core Data entities, data models
├── Views/          # SwiftUI views
├── ViewModels/     # MVVM view models with Combine
├── Services/       # API clients, managers
├── Resources/      # Assets, Info.plist
├── Utilities/      # Extensions, helpers
└── docs/           # Project documentation
```

## iOS Development Best Practices

### 1. SwiftUI & State Management
```swift
// Use @StateObject for owned objects
@StateObject private var viewModel = AlertViewModel()

// Use @EnvironmentObject for shared state
@EnvironmentObject var locationManager: LocationManager

// Use @AppStorage for user preferences
@AppStorage("defaultNotificationTime") var notificationTime: Int = 5
```

### 2. Location Services
```swift
// Always check authorization before using location
func checkLocationAuthorization() {
    switch locationManager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
        // Start location updates
    case .denied, .restricted:
        // Show alert to user
    case .notDetermined:
        locationManager.requestWhenInUseAuthorization()
    @unknown default:
        break
    }
}

// Use appropriate accuracy based on distance
if distanceToStation > 5000 {
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
} else {
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
}
```

### 3. Background Tasks
```swift
// Register background tasks in AppDelegate
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.app.refresh",
    using: nil
) { task in
    handleAppRefresh(task: task as! BGAppRefreshTask)
}

// Handle background location updates efficiently
locationManager.allowsBackgroundLocationUpdates = true
locationManager.pausesLocationUpdatesAutomatically = true
```

### 4. Notifications
```swift
// Always request permission before scheduling
UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge]
) { granted, error in
    // Handle permission result
}

// Use proper notification categories
let content = UNMutableNotificationContent()
content.categoryIdentifier = "TRAIN_ALERT"
content.sound = .defaultCritical
```

### 5. Core Data
```swift
// Use NSPersistentContainer
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "TrainAlert")
    container.loadPersistentStores { _, error in
        if let error = error {
            fatalError("Core Data failed: \(error)")
        }
    }
    return container
}()

// Always save on background queue
persistentContainer.performBackgroundTask { context in
    // Perform saves here
    try? context.save()
}
```

### 6. API Integration
```swift
// Use URLSession with proper error handling
func fetchStations(near location: CLLocation) async throws -> [Station] {
    let url = URL(string: "...")!
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw APIError.invalidResponse
    }

    return try JSONDecoder().decode([Station].self, from: data)
}

// Cache API responses
let cache = URLCache(
    memoryCapacity: 10_000_000,  // 10MB
    diskCapacity: 50_000_000      // 50MB
)
```

### 7. Security
```swift
// Store sensitive data in Keychain
let apiKey = KeychainWrapper.standard.string(forKey: "openai_api_key")

// Never hardcode API keys
// Never log sensitive information
// Always use HTTPS for API calls
```

### 8. Performance
- Use lazy loading for views
- Implement image caching
- Minimize Core Data fetches
- Use Instruments for profiling
- Test on older devices

### 9. Testing Commands
```bash
# Unit tests
xcodebuild test -scheme TrainAlert -destination 'platform=iOS Simulator,name=iPhone 15'

# UI tests
xcodebuild test -scheme TrainAlertUITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for TestFlight
xcodebuild archive -scheme TrainAlert -archivePath ./build/TrainAlert.xcarchive

# Export IPA
xcodebuild -exportArchive -archivePath ./build/TrainAlert.xcarchive -exportPath ./build -exportOptionsPlist ExportOptions.plist
```

### 10. Code Style
- Use Swift's native naming conventions
- Prefer value types (struct) over reference types when possible
- Use extensions to organize code
- Follow SOLID principles
- Add MARK: comments for organization
- **IMPORTANT: Always ensure files end with a newline character**
  - This follows POSIX standards and prevents git diff issues
  - SwiftLint will flag files without trailing newlines
  - Configure your editor to automatically add newlines at EOF

## Important Implementation Notes

1. **Battery Optimization**: Always balance accuracy with battery usage
2. **API Rate Limits**: Implement caching and throttling for OpenAI API
3. **Error Handling**: Always provide user-friendly error messages
4. **Accessibility**: Support VoiceOver and Dynamic Type
5. **Privacy**: Request permissions only when needed, explain why
6. **Build Verification**: ALWAYS verify that code changes compile successfully before finalizing
   - Check for optional unwrapping errors (e.g., `String?` to `String`)
   - Verify all property types match their expected values
   - Test build with `xcodebuild` if possible
   - Pay special attention to async/await syntax changes
   - When fixing compile errors, always check related code for similar issues
7. **Mock Data Policy**:
   - Mock data should ONLY be used for development and testing purposes
   - NEVER use mock data as a fallback for production API failures
   - When API returns empty or error responses, display appropriate error messages to users
   - Mock data generators should be clearly marked as development-only features
   - Prefer proper error handling over mock data substitution
8. **Data Management Policy**:
   - AVOID hardcoding any data that might change (station names, travel times, routes, etc.) in the app
   - Always fetch dynamic data from APIs rather than storing it locally
   - DO NOT create local databases or mappings for:
     - Station-to-station travel times
     - Route information
     - Timetable data
     - Station relationships
   - Reason: When data changes (e.g., new stations, changed schedules), hardcoded data requires app updates and becomes a maintenance burden
   - Exception: Only minimal mapping data (like station name romanization) that rarely changes may be included
   - Prefer real-time API calls even if it means showing "estimated" or "unavailable" for some data

## Common Issues & Solutions

1. **Location not updating in background**
   - Ensure `UIBackgroundModes` includes `location` in Info.plist
   - Set `allowsBackgroundLocationUpdates = true`

2. **Notifications not showing**
   - Check notification permissions
   - Ensure app is not in foreground
   - Verify notification content is valid

3. **Core Data crashes**
   - Always use proper context management
   - Avoid accessing objects across contexts
   - Use `performBackgroundTask` for background saves

## Task Management

### タスクチケット管理方法

プロジェクトのタスクは `docs/tickets/` ディレクトリ内の連番ファイルで管理されています。

#### チケットファイル形式
- ファイル名: `XXX_feature_name.md` (例: `001_project_setup.md`)
- 各タスクは `- [ ]` でチェックリスト形式
- 完了したタスクは `- [x]` に変更

#### チケット一覧
1. `001_project_setup.md` - プロジェクトセットアップ
2. `002_design_system.md` - デザインシステム構築
3. `003_core_data_setup.md` - Core Dataセットアップ
4. `004_location_service.md` - 位置情報サービス実装
5. `005_notification_system.md` - 通知システム実装
6. `006_station_api_integration.md` - 駅情報API連携
7. `007_openai_integration.md` - OpenAI API連携
8. `008_home_screen.md` - ホーム画面実装
9. `009_alert_setup_flow.md` - アラート設定フロー
10. `010_history_screen.md` - 履歴画面実装
11. `011_settings_screen.md` - 設定画面実装
12. `012_background_processing.md` - バックグラウンド処理最適化
13. `013_testing.md` - テスト実装
14. `014_performance_optimization.md` - パフォーマンス最適化
15. `015_release_preparation.md` - リリース準備

#### 進捗管理
- 各チケットファイル内のチェックリストで進捗を管理
- タスク完了時は `- [ ]` を `- [x]` に更新
- 依存関係がある場合はチケット内に明記
- ステータス更新: `## ステータス: [ ] Not Started / [x] In Progress / [x] Completed`

#### 実装時の手順
1. チケットの依存関係を確認（dependency_graph.md参照）
2. チケットのステータスを"In Progress"に更新
3. 実装ガイドラインに従って実装
4. 完了条件を満たしているか確認
5. テストを実行して成功を確認
6. チケットのステータスを"Completed"に更新
7. ticket_status.mdを更新

#### 関連ドキュメント
- `docs/tickets/dependency_graph.md` - 依存関係図
- `docs/tickets/implementation_guide.md` - Agent向け実装ガイド
- `docs/tickets/ticket_status.md` - 全体進捗管理
- `docs/tickets/ticket_template.md` - チケットテンプレート

#### 優先度
- High: 基本機能の実装（#001-#009, #012）
- Medium: 追加機能とテスト（#007, #010-#011, #013-#014）
- Low: リリース準備（#015）

### チケット020-031 実装状況（2025-08-17時点）

#### 実装状況
- **全チケット未実装**: #020〜#031（#021は存在しない）
- **依存関係の起点**: #018（時刻表統合）と#004（位置情報サービス）は完了済み
- **独立実装可能**: #020（目覚まし編集）、#030（お気に入り）

#### 推奨実装順序
1. **Phase 1 - 独立機能**（すぐに開始可能）
   - #030 経路お気に入り機能（UI既存、バックエンドのみ、工数: 6h）
   - #020 目覚まし編集機能（独立機能、工数: 未定）※最後に行うので残しておく

2. **Phase 2 - 基盤機能**
   - #022 時刻表連携アラーム機能（多くの機能の前提条件、工数: 16h）

3. **Phase 3 - 拡張機能**（並列実装可能）
   - #023 駅数ベース通知機能（工数: 12h）
   - #024 繰り返し設定機能（工数: 8h）
   - #025 遅延対応機能（工数: 12h）
   - #029 出発日時の詳細設定（工数: 6h）

4. **Phase 4 - システム統合**
   - #026 乗り換え対応機能（工数: 16h）
   - #027 位置情報連携機能（工数: 16h）

5. **Phase 5 - 高度な機能**
   - #028 スヌーズ機能（工数: 8h）
   - #031 路線検索の拡充（工数: 24h）

#### 実装時の注意点
- #022は多くの機能の基盤となるため、早期実装が推奨される
- #026と#031は乗り換え機能で関連（#031は拡張版）
- 並列実装可能なグループを活用して効率化を図る

#### 関連ドキュメント（チケット020-031）
- `docs/tickets/summary_020_031.md` - 実装状況まとめ
- `docs/tickets/dependency_graph_020_031.md` - 依存関係図
