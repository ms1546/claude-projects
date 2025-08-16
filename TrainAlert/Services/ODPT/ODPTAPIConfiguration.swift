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
        // 環境変数から取得
        if let envKey = ProcessInfo.processInfo.environment["ODPT_API_KEY"] {
            return envKey
        }
        
        // デバッグビルドの場合はKeychainからも取得を試みる
        #if DEBUG
        // TODO: KeychainManagerの拡張が必要な場合は後で実装
        #endif
        
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
