//
//  OpenAIClient.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import Network

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
    
    // レート制限管理
    private var lastRequestTime: Date = .distantPast
    private let minimumRequestInterval: TimeInterval = 1.0 // 1秒間隔
    private var requestCount: Int = 0
    private var requestResetTime: Date = Date()
    private let maxRequestsPerMinute: Int = 20
    
    // リトライ設定
    private let maxRetryAttempts: Int = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // ネットワーク監視
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        // APIキーをKeychainから読み込む
        self.apiKey = try? KeychainManager.shared.getOpenAIAPIKey()
        
        // ネットワーク監視開始
        setupNetworkMonitoring()
    }
    
    // MARK: - API Key Management
    func setAPIKey(_ key: String) {
        self.apiKey = key
        try? KeychainManager.shared.saveOpenAIAPIKey(key)
    }
    
    func hasAPIKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    /// API キーの有効性を検証
    func validateAPIKey(_ key: String) async throws -> Bool {
        let testRequest = ChatCompletionRequest(
            model: "gpt-3.5-turbo",
            messages: [ChatMessage(role: "user", content: "test")],
            temperature: 0.5,
            maxTokens: 1
        )
        
        do {
            _ = try await callAPI(request: testRequest, apiKey: key)
            return true
        } catch OpenAIError.invalidAPIKey {
            return false
        } catch {
            // ネットワークエラーなどの場合は判断できないのでtrueを返す
            return true
        }
    }
    
    // MARK: - Message Generation
    func generateNotificationMessage(
        for station: String,
        arrivalTime: String,
        characterStyle: CharacterStyle
    ) async throws -> String {
        
        // ネットワーク接続チェック
        guard isNetworkAvailable else {
            throw OpenAIError.networkUnavailable
        }
        
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
        
        // API呼び出し（リトライ付き）
        let response = try await callAPIWithRetry(request: request, apiKey: apiKey)
        
        guard let message = response.choices.first?.message.content,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAIError.invalidResponse
        }
        
        // メッセージの長さをチェック（30-50文字の範囲内か）
        let cleanedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedMessage.count < 10 || cleanedMessage.count > 100 {
            // ⚠️ Generated message length is out of expected range
        }
        
        // キャッシュに保存
        saveToCache(message: cleanedMessage, for: cacheKey)
        
        return cleanedMessage
    }
    
    // MARK: - Private Methods
    
    /// API呼び出し（リトライ機能付き）
    private func callAPIWithRetry(request: ChatCompletionRequest, apiKey: String) async throws -> ChatCompletionResponse {
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                // レート制限チェック
                try await enforceRateLimit()
                
                let response = try await callAPI(request: request, apiKey: apiKey)
                
                // 成功した場合はリクエストカウントを更新
                updateRequestCount()
                
                return response
                
            } catch OpenAIError.rateLimitExceeded {
                lastError = OpenAIError.rateLimitExceeded
                
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(for: attempt)
                    // ⏳ Rate limit exceeded. Retrying...
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    // ❌ Rate limit exceeded. Max retry attempts reached.
                    throw OpenAIError.rateLimitExceeded
                }
                
            } catch OpenAIError.serverError {
                lastError = OpenAIError.serverError
                
                if attempt < maxRetryAttempts {
                    let delay = calculateRetryDelay(for: attempt)
                    // ⏳ Server error. Retrying...
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    // ❌ Server error. Max retry attempts reached.
                    throw OpenAIError.serverError
                }
                
            } catch {
                lastError = error
                // その他のエラーはリトライしない
                throw error
            }
        }
        
        // ここに到達することはないはずだが、安全のため
        throw lastError ?? OpenAIError.invalidResponse
    }
    
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
    
    // MARK: - Rate Limiting
    
    private func enforceRateLimit() async throws {
        let now = Date()
        
        // 1分ごとにリクエストカウントをリセット
        if now.timeIntervalSince(requestResetTime) >= 60 {
            requestCount = 0
            requestResetTime = now
        }
        
        // 1分間のリクエスト数制限チェック
        if requestCount >= maxRequestsPerMinute {
            let waitTime = 60 - now.timeIntervalSince(requestResetTime)
            if waitTime > 0 {
                // ⏱️ Rate limit reached. Waiting...
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                requestCount = 0
                requestResetTime = Date()
            }
        }
        
        // 最小リクエスト間隔チェック
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < minimumRequestInterval {
            let waitTime = minimumRequestInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
    }
    
    private func updateRequestCount() {
        requestCount += 1
    }
    
    private func calculateRetryDelay(for attempt: Int) -> TimeInterval {
        // 指数バックオフ: 1秒, 2秒, 4秒
        return baseRetryDelay * pow(2.0, Double(attempt - 1))
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
        
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
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
    case networkUnavailable
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
        case .networkUnavailable:
            return "ネットワークに接続できません"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        }
    }
}


