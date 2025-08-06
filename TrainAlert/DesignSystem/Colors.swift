import SwiftUI

// MARK: - Color Extensions for TrainAlert Design System

extension Color {
    
    // MARK: - Primary Colors
    
    /// ダークネイビー - メイン背景色
    static let darkNavy = Color("DarkNavy", bundle: .main) ?? Color(red: 0.11, green: 0.16, blue: 0.23)
    
    /// チャコールグレー - セカンダリ背景色
    static let charcoalGray = Color("CharcoalGray", bundle: .main) ?? Color(red: 0.18, green: 0.22, blue: 0.28)
    
    /// ホワイト - プライマリテキスト
    static let primaryText = Color.white
    
    // MARK: - Accent Colors
    
    /// ソフトブルー - アクティブ要素
    static let softBlue = Color("SoftBlue", bundle: .main) ?? Color(red: 0.29, green: 0.56, blue: 0.89)
    
    /// ウォームオレンジ - 警告・通知
    static let warmOrange = Color("WarmOrange", bundle: .main) ?? Color(red: 1.0, green: 0.42, blue: 0.29)
    
    /// ミントグリーン - 成功状態
    static let mintGreen = Color("MintGreen", bundle: .main) ?? Color(red: 0.31, green: 0.80, blue: 0.77)
    
    // MARK: - Neutral Colors
    
    /// ライトグレー - 非アクティブ要素
    static let lightGray = Color("LightGray", bundle: .main) ?? Color(red: 0.63, green: 0.68, blue: 0.75)
    
    /// ダークグレー - セカンダリテキスト
    static let darkGray = Color("DarkGray", bundle: .main) ?? Color(red: 0.45, green: 0.50, blue: 0.59)
    
    // MARK: - Semantic Colors
    
    /// 成功状態の色
    static let success = mintGreen
    
    /// エラー・危険状態の色
    static let error = warmOrange
    
    /// 警告状態の色
    static let warning = Color(red: 1.0, green: 0.80, blue: 0.0)
    
    /// 情報表示の色
    static let info = softBlue
    
    // MARK: - Background Colors
    
    /// プライマリ背景
    static let backgroundPrimary = darkNavy
    
    /// セカンダリ背景
    static let backgroundSecondary = charcoalGray
    
    /// カード背景
    static let backgroundCard = Color(red: 0.20, green: 0.25, blue: 0.32)
    
    // MARK: - Text Colors
    
    /// プライマリテキスト
    static let textPrimary = primaryText
    
    /// セカンダリテキスト
    static let textSecondary = darkGray
    
    /// 非アクティブテキスト
    static let textInactive = lightGray
    
    // MARK: - Interactive Colors
    
    /// プライマリボタンの背景色
    static let buttonPrimaryBackground = softBlue
    
    /// プライマリボタンのテキスト色
    static let buttonPrimaryText = Color.white
    
    /// セカンダリボタンの背景色
    static let buttonSecondaryBackground = Color.clear
    
    /// セカンダリボタンのテキスト色
    static let buttonSecondaryText = softBlue
    
    /// セカンダリボタンのボーダー色
    static let buttonSecondaryBorder = softBlue
    
    // MARK: - Gradient Colors
    
    /// 背景グラデーション（上から下へ）
    static let backgroundGradient = LinearGradient(
        colors: [darkNavy, charcoalGray],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// カードグラデーション
    static let cardGradient = LinearGradient(
        colors: [backgroundCard, charcoalGray.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// ボタングラデーション
    static let buttonGradient = LinearGradient(
        colors: [softBlue, softBlue.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - UIKit Compatible Colors

#if canImport(UIKit)
import UIKit

extension UIColor {
    
    // MARK: - Primary Colors
    
    static let darkNavy = UIColor(red: 0.11, green: 0.16, blue: 0.23, alpha: 1.0)
    static let charcoalGray = UIColor(red: 0.18, green: 0.22, blue: 0.28, alpha: 1.0)
    
    // MARK: - Accent Colors
    
    static let softBlue = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1.0)
    static let warmOrange = UIColor(red: 1.0, green: 0.42, blue: 0.29, alpha: 1.0)
    static let mintGreen = UIColor(red: 0.31, green: 0.80, blue: 0.77, alpha: 1.0)
    
    // MARK: - Neutral Colors
    
    static let lightGray = UIColor(red: 0.63, green: 0.68, blue: 0.75, alpha: 1.0)
    static let darkGray = UIColor(red: 0.45, green: 0.50, blue: 0.59, alpha: 1.0)
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