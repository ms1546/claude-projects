//
//  ODPTAPIConfiguration.swift
//  TrainAlert
//
//  ODPT API設定管理
//

import Foundation

/// ODPT API設定管理クラス
final class ODPTAPIConfiguration {
    static let shared = ODPTAPIConfiguration()
    
    /// APIベースURL
    let baseURL = "https://api.odpt.org/api/v4"
    
    /// APIキー
    var apiKey: String {
        // 1. 環境変数から取得（開発時）
        if let envKey = ProcessInfo.processInfo.environment["ODPT_API_KEY"], !envKey.isEmpty {
            print("ODPT API Key: Using environment variable")
            return envKey
        }
        
        // 2. Configuration.plistから取得（実機時）
        if let path = Bundle.main.path(forResource: "Configuration", ofType: "plist") {
            print("Configuration.plist found at: \(path)")
            if let config = NSDictionary(contentsOfFile: path) {
                print("Configuration.plist loaded, keys: \(config.allKeys)")
                if let plistKey = config["ODPT_API_KEY"] as? String {
                    print("ODPT_API_KEY found in plist: \(plistKey.prefix(10))...")
                    if !plistKey.isEmpty && plistKey != "YOUR_ODPT_API_KEY_HERE" {
                        print("ODPT API Key: Using Configuration.plist")
                        return plistKey
                    } else {
                        print("ODPT_API_KEY is empty or placeholder")
                    }
                } else {
                    print("ODPT_API_KEY not found in plist")
                }
            } else {
                print("Failed to load Configuration.plist as NSDictionary")
            }
        } else {
            print("Configuration.plist not found in bundle")
        }
        
        // 3. Keychainから取得（ユーザー設定）
        if let keychainKey = try? KeychainManager.shared.getODPTAPIKey(),
           !keychainKey.isEmpty {
            print("ODPT API Key: Using Keychain")
            return keychainKey
        }
        
        print("ODPT API Key: NOT FOUND - returning empty string")
        return ""
    }
    
    /// APIキーが設定されているか
    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }
    
    /// 現在のAPIキーで利用可能な事業者（推定）
    /// 実際のAPIレスポンスに基づいて動的に更新される
    var availableOperators: [String] {
        // デフォルトは一般的な無料APIキーの権限
        [
            "東京メトロ各線",
            "都営地下鉄各線",
            "ゆりかもめ",
            "りんかい線"
        ]
    }
    
    /// JR線が利用可能かどうか（APIキーの権限による）
    var isJRAvailable: Bool {
        // 現在の実装では、APIキーの権限チェックロジックを実装
        // 将来的にはAPIのメタデータエンドポイントから取得可能
        false  // 現在のAPIキーではJR線は利用不可
    }
    
    private init() {}
}


// MARK: - ODPT APIエラー

enum ODPTAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int)
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ODPT APIキーが設定されていません"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .networkError(let error):
            return "ネットワークエラー: \(error.localizedDescription)"
        case .decodingError:
            return "データの解析に失敗しました"
        case .serverError(let statusCode):
            return "サーバーエラー: \(statusCode)"
        case .rateLimitExceeded:
            return "APIの呼び出し制限に達しました。しばらく待ってから再試行してください"
        }
    }
}
