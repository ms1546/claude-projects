//
//  KeychainManager.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/09.
//

import Foundation
import Security

/// Keychainを使用してセキュアにデータを保存・取得するマネージャー
final class KeychainManager {
    
    // MARK: - Singleton
    
    static let shared = KeychainManager()
    
    // MARK: - Properties
    
    private let service = Bundle.main.bundleIdentifier ?? "com.app.TrainAlert"
    
    // MARK: - Keys
    
    enum KeychainKey: String {
        case openAIAPIKey = "openai_api_key"
        case userAuthToken = "user_auth_token"
    }
    
    // MARK: - Errors
    
    enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unhandledError(status: OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "アイテムが見つかりません"
            case .duplicateItem:
                return "アイテムが既に存在します"
            case .invalidData:
                return "無効なデータです"
            case .unhandledError(let status):
                return "Keychainエラー: \(status)"
            }
        }
    }
    
    // MARK: - Private Init
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 文字列をKeychainに保存
    /// - Parameters:
    ///   - value: 保存する文字列
    ///   - key: Keychainキー
    /// - Throws: KeychainError
    func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        // 既存のアイテムを削除
        SecItemDelete(query as CFDictionary)
        
        // 新しいアイテムを追加
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Keychainから文字列を取得
    /// - Parameter key: Keychainキー
    /// - Returns: 保存された文字列（存在しない場合はnil）
    /// - Throws: KeychainError
    func getString(for key: KeychainKey) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        switch status {
        case errSecSuccess:
            guard let data = dataTypeRef as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return string
            
        case errSecItemNotFound:
            return nil
            
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Keychainからアイテムを削除
    /// - Parameter key: Keychainキー
    /// - Throws: KeychainError
    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// アイテムが存在するかチェック
    /// - Parameter key: Keychainキー
    /// - Returns: 存在する場合true
    func exists(for key: KeychainKey) -> Bool {
        do {
            _ = try getString(for: key)
            return true
        } catch {
            return false
        }
    }
    
    /// すべてのKeychainアイテムをクリア（開発・テスト用）
    func clearAll() {
        for key in KeychainKey.allCases {
            try? delete(for: key)
        }
    }
}

// MARK: - KeychainKey CaseIterable

extension KeychainManager.KeychainKey: CaseIterable {}

// MARK: - Convenience Methods

extension KeychainManager {
    
    /// OpenAI APIキーを保存
    /// - Parameter apiKey: APIキー
    /// - Throws: KeychainError
    func saveOpenAIAPIKey(_ apiKey: String) throws {
        try save(apiKey, for: .openAIAPIKey)
    }
    
    /// OpenAI APIキーを取得
    /// - Returns: APIキー（存在しない場合はnil）
    /// - Throws: KeychainError
    func getOpenAIAPIKey() throws -> String? {
        return try getString(for: .openAIAPIKey)
    }
    
    /// OpenAI APIキーを削除
    /// - Throws: KeychainError
    func deleteOpenAIAPIKey() throws {
        try delete(for: .openAIAPIKey)
    }
    
    /// OpenAI APIキーが存在するかチェック
    /// - Returns: 存在する場合true
    var hasOpenAIAPIKey: Bool {
        return exists(for: .openAIAPIKey)
    }
}
