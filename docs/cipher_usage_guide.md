# Cipher MCP サーバー活用ガイド

## 概要
Cipher MCPサーバーは、暗号化・復号化、ハッシュ生成、セキュアなランダム値生成などのセキュリティ機能を提供します。TrainAlertプロジェクトでの活用方法を説明します。

## 主な機能

### 1. 暗号化・復号化
- AES-256-GCM暗号化
- パスワードベースの暗号化
- セキュアなデータ保護

### 2. ハッシュ生成
- SHA-256, SHA-512
- MD5（レガシー用途のみ）
- データ整合性チェック

### 3. ランダム値生成
- 暗号学的に安全な乱数
- UUID生成
- セキュアトークン生成

## TrainAlertでの活用例

### 1. OpenAI APIキーの暗号化保存

```swift
// APIキーを暗号化して保存
func saveAPIKey(_ apiKey: String, password: String) {
    // Cipherで暗号化
    let encrypted = cipher.encrypt(apiKey, password: password)
    
    // Keychainに暗号化されたデータを保存
    KeychainWrapper.standard.set(encrypted, forKey: "encrypted_openai_key")
    
    // パスワードのハッシュも保存（検証用）
    let passwordHash = cipher.hash(password, algorithm: "sha256")
    KeychainWrapper.standard.set(passwordHash, forKey: "api_key_hash")
}

// APIキーを復号化して取得
func getAPIKey(password: String) -> String? {
    // パスワード検証
    guard let storedHash = KeychainWrapper.standard.string(forKey: "api_key_hash"),
          let inputHash = cipher.hash(password, algorithm: "sha256"),
          storedHash == inputHash else {
        return nil
    }
    
    // 暗号化されたキーを取得
    guard let encrypted = KeychainWrapper.standard.string(forKey: "encrypted_openai_key") else {
        return nil
    }
    
    // 復号化
    return cipher.decrypt(encrypted, password: password)
}
```

### 2. ユーザー設定の暗号化

```swift
struct SecureUserSettings {
    // 個人的なメモや設定を暗号化
    func saveSecureNote(_ note: String, for station: String) {
        let key = generateStationKey(station)
        let encrypted = cipher.encrypt(note, password: key)
        
        UserDefaults.standard.set(encrypted, forKey: "note_\(station)")
    }
    
    // 駅ごとのユニークキー生成
    private func generateStationKey(_ station: String) -> String {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        return cipher.hash("\(station)_\(deviceId)", algorithm: "sha256")
    }
}
```

### 3. キャッシュデータの整合性チェック

```swift
class SecureMessageCache {
    struct CachedMessage {
        let content: String
        let hash: String
        let timestamp: Date
    }
    
    // メッセージを保存時にハッシュを生成
    func saveMessage(_ message: String, style: String, station: String) {
        let hash = cipher.hash(message, algorithm: "sha256")
        
        let cached = CachedMessage(
            content: message,
            hash: hash,
            timestamp: Date()
        )
        
        // Core Dataに保存
        saveToCoreData(cached, key: "\(style)_\(station)")
    }
    
    // メッセージ取得時に整合性を確認
    func getMessage(style: String, station: String) -> String? {
        guard let cached = loadFromCoreData(key: "\(style)_\(station)") else {
            return nil
        }
        
        // ハッシュ検証
        let currentHash = cipher.hash(cached.content, algorithm: "sha256")
        guard currentHash == cached.hash else {
            // データが改ざんされている可能性
            print("Cache integrity check failed")
            return nil
        }
        
        return cached.content
    }
}
```

### 4. セキュアなセッショントークン生成

```swift
class SessionManager {
    // アプリ起動時のセッションID生成
    func generateSessionId() -> String {
        return cipher.generateRandomString(length: 32)
    }
    
    // API呼び出し用の一時トークン
    func generateAPIToken() -> String {
        let timestamp = Date().timeIntervalSince1970
        let random = cipher.generateRandomString(length: 16)
        return cipher.hash("\(timestamp)_\(random)", algorithm: "sha256")
    }
}
```

### 5. 位置情報の匿名化

```swift
extension CLLocation {
    // 位置情報をハッシュ化して匿名化
    func anonymizedIdentifier() -> String {
        let coordString = "\(coordinate.latitude),\(coordinate.longitude)"
        return cipher.hash(coordString, algorithm: "sha256").prefix(8).lowercased()
    }
}
```

## Cipherコマンドの使用例

Claude Code内で直接Cipherコマンドを使用：

```bash
# テキストの暗号化
/cipher encrypt "秘密のメッセージ" --password "mypassword"

# ハッシュ生成
/cipher hash "データ" --algorithm sha256

# ランダム文字列生成
/cipher random --length 32

# UUID生成
/cipher uuid
```

## セキュリティベストプラクティス

1. **APIキーの保護**
   - 必ず暗号化して保存
   - プレーンテキストでの保存は避ける

2. **パスワード管理**
   - パスワードそのものは保存しない
   - ハッシュ値のみを保存

3. **データ整合性**
   - 重要なキャッシュデータはハッシュで検証
   - 改ざん検出の仕組みを実装

4. **セッション管理**
   - セキュアな乱数を使用
   - 予測不可能なトークン生成

## 実装時の注意点

1. **パフォーマンス**
   - 暗号化/復号化は処理コストが高い
   - 必要な箇所のみで使用

2. **エラーハンドリング**
   - 復号化失敗時の処理を実装
   - ユーザーフレンドリーなエラーメッセージ

3. **バックアップ**
   - 暗号化キーの紛失対策
   - リカバリー機能の実装

これらの機能により、TrainAlertアプリのセキュリティを大幅に向上させることができます。
