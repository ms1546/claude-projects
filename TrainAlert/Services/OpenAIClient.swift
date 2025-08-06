//
//  OpenAIClient.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation

// MARK: - OpenAI Models
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let id: String
    let choices: [Choice]
    let usage: Usage
    
    struct Choice: Codable {
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - OpenAI Client
@MainActor
class OpenAIClient: ObservableObject {
    static let shared = OpenAIClient()
    
    private let baseURL = "https://api.openai.com/v1"
    private let session: URLSession
    private var apiKey: String?
    
    // キャッシュ
    private var messageCache: [String: String] = [:]
    private let cacheExpiry: TimeInterval = 30 * 24 * 60 * 60 // 30日
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        // APIキーをKeychainから読み込む
        self.apiKey = KeychainHelper.shared.getAPIKey()
    }
    
    // MARK: - API Key Management
    func setAPIKey(_ key: String) {
        self.apiKey = key
        KeychainHelper.shared.saveAPIKey(key)
    }
    
    func hasAPIKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    // MARK: - Message Generation
    func generateNotificationMessage(
        for station: String,
        arrivalTime: String,
        characterStyle: CharacterStyle
    ) async throws -> String {
        
        // キャッシュチェック
        let cacheKey = "\(station)_\(characterStyle.rawValue)"
        if let cachedMessage = getCachedMessage(for: cacheKey) {
            return cachedMessage
        }
        
        // APIキー確認
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        // プロンプト生成
        let systemPrompt = characterStyle.systemPrompt
        let userPrompt = """
        電車で寝ている人を起こすメッセージを生成してください。
        
        条件:
        - 降車駅: \(station)
        - 到着まで: \(arrivalTime)
        - 文字数: 30-50文字
        - 口調: \(characterStyle.tone)
        - 必ず駅名を含める
        - 優しく起こす
        """
        
        let request = ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.8,
            maxTokens: 100
        )
        
        // API呼び出し
        let response = try await callAPI(request: request, apiKey: apiKey)
        
        guard let message = response.choices.first?.message.content else {
            throw OpenAIError.invalidResponse
        }
        
        // キャッシュに保存
        saveToCache(message: message, for: cacheKey)
        
        return message
    }
    
    // MARK: - Private Methods
    private func callAPI(request: ChatCompletionRequest, apiKey: String) async throws -> ChatCompletionResponse {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(ChatCompletionResponse.self, from: data)
        case 401:
            throw OpenAIError.invalidAPIKey
        case 429:
            throw OpenAIError.rateLimitExceeded
        case 500...599:
            throw OpenAIError.serverError
        default:
            throw OpenAIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Cache Management
    private func getCachedMessage(for key: String) -> String? {
        if let data = UserDefaults.standard.data(forKey: "openai_cache_\(key)"),
           let cache = try? JSONDecoder().decode(MessageCache.self, from: data),
           Date().timeIntervalSince(cache.timestamp) < cacheExpiry {
            return cache.message
        }
        return nil
    }
    
    private func saveToCache(message: String, for key: String) {
        let cache = MessageCache(message: message, timestamp: Date())
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: "openai_cache_\(key)")
        }
    }
    
    struct MessageCache: Codable {
        let message: String
        let timestamp: Date
    }
}

// MARK: - OpenAI Error
enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidURL
    case invalidResponse
    case rateLimitExceeded
    case serverError
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI APIキーが設定されていません"
        case .invalidAPIKey:
            return "無効なAPIキーです"
        case .invalidURL:
            return "URLが無効です"
        case .invalidResponse:
            return "無効なレスポンスです"
        case .rateLimitExceeded:
            return "API利用制限に達しました"
        case .serverError:
            return "サーバーエラーが発生しました"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        }
    }
}

// MARK: - Character Style Extension
extension CharacterStyle {
    var systemPrompt: String {
        switch self {
        case .friendly:
            return "あなたは優しくて親しみやすいお姉さんです。丁寧で温かい言葉遣いで、相手を優しく起こします。"
        case .energetic:
            return "あなたは元気いっぱいのギャル系女子です。明るくテンション高めで、ポジティブなエネルギーで相手を起こします。"
        case .gentle:
            return "あなたは穏やかで優しい性格の人です。相手を気遣いながら、そっと起こすような言葉を使います。"
        case .formal:
            return "あなたは礼儀正しい執事です。敬語を使い、品格のある言葉遣いで相手を起こします。"
        }
    }
    
    var tone: String {
        switch self {
        case .friendly:
            return "親しみやすく丁寧な口調"
        case .energetic:
            return "元気でカジュアルな口調（〜だよ！など）"
        case .gentle:
            return "優しく穏やかな口調"
        case .formal:
            return "丁寧な敬語"
        }
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let apiKeyKey = "com.trainalert.openai.apikey"
    
    private init() {}
    
    func saveAPIKey(_ key: String) {
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyKey,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKeyKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        
        return nil
    }
}
