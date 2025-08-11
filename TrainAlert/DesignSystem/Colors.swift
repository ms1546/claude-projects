import SwiftUI

// MARK: - Color Extensions for TrainAlert Design System

extension Color {
    
    // MARK: - Primary Colors
    
    /// ダークネイビー - メイン背景色
    static let darkNavy = Color(red: 0.11, green: 0.16, blue: 0.23)
    
    /// チャコールグレー - セカンダリ背景色
    static let trainCharcoalGray = Color(red: 0.18, green: 0.22, blue: 0.28)
    
    /// ホワイト - プライマリテキスト
    static let primaryText = Color.white
    
    // MARK: - Accent Colors
    
    /// ソフトブルー - アクティブ要素
    static let trainSoftBlue = Color(red: 0.29, green: 0.56, blue: 0.89)
    
    /// ウォームオレンジ - 警告・通知
    static let warmOrange = Color(red: 1.0, green: 0.42, blue: 0.29)
    
    /// ミントグリーン - 成功状態
    static let mintGreen = Color(red: 0.31, green: 0.80, blue: 0.77)
    
    // MARK: - Neutral Colors
    
    /// ライトグレー - 非アクティブ要素
    static let trainLightGray = Color(red: 0.63, green: 0.68, blue: 0.75)
    
    /// ダークグレー - セカンダリテキスト
    static let darkGray = Color(red: 0.45, green: 0.50, blue: 0.59)
    
    // MARK: - Semantic Colors
    
    /// 成功状態の色
    static let success = mintGreen
    
    /// エラー・危険状態の色
    static let error = warmOrange
    
    /// 警告状態の色
    static let warning = Color(red: 1.0, green: 0.80, blue: 0.0)
    
    /// 情報表示の色
    static let info = trainSoftBlue
    
    // MARK: - Background Colors
    
    /// プライマリ背景
    static let backgroundPrimary = darkNavy
    
    /// セカンダリ背景
    static let backgroundSecondary = trainCharcoalGray
    
    /// カード背景
    static let backgroundCard = Color(red: 0.20, green: 0.25, blue: 0.32)
    
    // MARK: - Text Colors
    
    /// プライマリテキスト
    static let textPrimary = primaryText
    
    /// セカンダリテキスト
    static let textSecondary = darkGray
    
    /// 非アクティブテキスト
    static let textInactive = trainLightGray
    
    // MARK: - Interactive Colors
    
    /// プライマリボタンの背景色
    static let buttonPrimaryBackground = trainSoftBlue
    
    /// プライマリボタンのテキスト色
    static let buttonPrimaryText = Color.white
    
    /// セカンダリボタンの背景色
    static let buttonSecondaryBackground = Color.clear
    
    /// セカンダリボタンのテキスト色
    static let buttonSecondaryText = trainSoftBlue
    
    /// セカンダリボタンのボーダー色
    static let buttonSecondaryBorder = trainSoftBlue
    
    // MARK: - Gradient Colors
    
    /// 背景グラデーション（上から下へ）
    static let backgroundGradient = LinearGradient(
        colors: [darkNavy, trainCharcoalGray],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// カードグラデーション
    static let cardGradient = LinearGradient(
        colors: [backgroundCard, trainCharcoalGray.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// ボタングラデーション
    static let buttonGradient = LinearGradient(
        colors: [trainSoftBlue, trainSoftBlue.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Convenience Extensions

extension Color {
    /// Neutral Colors
    static let mediumGray = Color(hex: "#718096")
    
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIKit Compatible Colors

#if canImport(UIKit)
import UIKit

extension UIColor {
    
    // MARK: - Primary Colors
    
    static let uiDarkNavy = UIColor(red: 0.11, green: 0.16, blue: 0.23, alpha: 1.0)
    static let uiCharcoalGray = UIColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1.0)
    
    // MARK: - Accent Colors
    
    static let uiSoftBlue = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0)
    static let uiWarmOrange = UIColor(red: 1.0, green: 0.42, blue: 0.29, alpha: 1.0)
    static let uiMintGreen = UIColor(red: 0.31, green: 0.80, blue: 0.77, alpha: 1.0)
    
    // MARK: - Neutral Colors
    
    static let uiLightGray = UIColor(red: 0.63, green: 0.68, blue: 0.75, alpha: 1.0)
    static let uiDarkGray = UIColor(red: 0.45, green: 0.50, blue: 0.59, alpha: 1.0)
}
#endif

// MARK: - Color Scheme Support

struct ColorSchemeAware {
    
    /// 現在のカラースキームに適応したテキスト色を返す
    static func adaptiveTextColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .textPrimary
        case .light:
            return .darkNavy
        @unknown default:
            return .textPrimary
        }
    }
    
    /// 現在のカラースキームに適応した背景色を返す
    static func adaptiveBackgroundColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return .backgroundPrimary
        case .light:
            return .white
        @unknown default:
            return .backgroundPrimary
        }
    }
}
