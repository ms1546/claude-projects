import SwiftUI

// MARK: - Font Extensions for TrainAlert Design System

extension Font {
    
    // MARK: - Display Fonts (見出し用)
    
    /// 大見出し - 画面タイトル用
    static let displayLarge = Font.custom("SF Pro Display", size: 32, relativeTo: .largeTitle)
        .weight(.bold)
    
    /// 中見出し - セクションタイトル用
    static let displayMedium = Font.custom("SF Pro Display", size: 24, relativeTo: .title)
        .weight(.bold)
    
    /// 小見出し - サブセクションタイトル用
    static let displaySmall = Font.custom("SF Pro Display", size: 20, relativeTo: .title2)
        .weight(.bold)
    
    // MARK: - Text Fonts (本文用)
    
    /// 本文大 - 重要な本文
    static let bodyLarge = Font.custom("SF Pro Text", size: 18, relativeTo: .body)
        .weight(.regular)
    
    /// 本文中 - 標準の本文
    static let bodyMedium = Font.custom("SF Pro Text", size: 16, relativeTo: .body)
        .weight(.regular)
    
    /// 本文小 - キャプション
    static let bodySmall = Font.custom("SF Pro Text", size: 14, relativeTo: .callout)
        .weight(.regular)
    
    /// キャプション - 補足情報
    static let caption = Font.custom("SF Pro Text", size: 12, relativeTo: .caption)
        .weight(.regular)
    
    // MARK: - Label Fonts (ラベル用)
    
    /// ラベル大 - ボタンテキスト
    static let labelLarge = Font.custom("SF Pro Text", size: 16, relativeTo: .body)
        .weight(.semibold)
    
    /// ラベル中 - フォームラベル
    static let labelMedium = Font.custom("SF Pro Text", size: 14, relativeTo: .callout)
        .weight(.semibold)
    
    /// ラベル小 - 小さなラベル
    static let labelSmall = Font.custom("SF Pro Text", size: 12, relativeTo: .caption)
        .weight(.semibold)
    
    // MARK: - Monospace Fonts (数値・コード用)
    
    /// 数値大 - 時刻表示用
    static let numbersLarge = Font.custom("SF Mono", size: 24, relativeTo: .title)
        .weight(.medium)
    
    /// 数値中 - 距離・時間表示用
    static let numbersMedium = Font.custom("SF Mono", size: 18, relativeTo: .body)
        .weight(.medium)
    
    /// 数値小 - 詳細数値表示用
    static let numbersSmall = Font.custom("SF Mono", size: 14, relativeTo: .callout)
        .weight(.medium)
}

// MARK: - Text Style Modifiers

struct TextStyleModifiers {
    
    // MARK: - Emphasis Modifiers
    
    /// 強調テキスト用のModifier
    struct EmphasizedText: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.labelMedium)
                .foregroundColor(.textPrimary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
    
    /// セカンダリテキスト用のModifier
    struct SecondaryText: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.bodySmall)
                .foregroundColor(.textSecondary)
        }
    }
    
    /// キャプション用のModifier
    struct CaptionText: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.caption)
                .foregroundColor(.textInactive)
        }
    }
    
    /// エラーテキスト用のModifier
    struct ErrorText: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.bodySmall)
                .foregroundColor(.error)
                .fontWeight(.medium)
        }
    }
    
    /// 成功テキスト用のModifier
    struct SuccessText: ViewModifier {
        func body(content: Content) -> some View {
            content
                .font(.bodySmall)
                .foregroundColor(.success)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Layout Modifiers
    
    /// 見出しレイアウト用のModifier
    struct HeadingLayout: ViewModifier {
        func body(content: Content) -> some View {
            content
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    /// 本文レイアウト用のModifier
    struct BodyLayout: ViewModifier {
        func body(content: Content) -> some View {
            content
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    /// 中央揃えレイアウト用のModifier
    struct CenteredLayout: ViewModifier {
        func body(content: Content) -> some View {
            content
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
}

// MARK: - View Extensions for Typography

extension View {
    
    // MARK: - Text Style Applications
    
    /// 強調テキストスタイルを適用
    func emphasizedTextStyle() -> some View {
        self.modifier(TextStyleModifiers.EmphasizedText())
    }
    
    /// セカンダリテキストスタイルを適用
    func secondaryTextStyle() -> some View {
        self.modifier(TextStyleModifiers.SecondaryText())
    }
    
    /// キャプションスタイルを適用
    func captionTextStyle() -> some View {
        self.modifier(TextStyleModifiers.CaptionText())
    }
    
    /// エラーテキストスタイルを適用
    func errorTextStyle() -> some View {
        self.modifier(TextStyleModifiers.ErrorText())
    }
    
    /// 成功テキストスタイルを適用
    func successTextStyle() -> some View {
        self.modifier(TextStyleModifiers.SuccessText())
    }
    
    // MARK: - Layout Applications
    
    /// 見出しレイアウトを適用
    func headingLayout() -> some View {
        self.modifier(TextStyleModifiers.HeadingLayout())
    }
    
    /// 本文レイアウトを適用
    func bodyLayout() -> some View {
        self.modifier(TextStyleModifiers.BodyLayout())
    }
    
    /// 中央揃えレイアウトを適用
    func centeredLayout() -> some View {
        self.modifier(TextStyleModifiers.CenteredLayout())
    }
}

// MARK: - Dynamic Type Support

struct DynamicTypeSupport {
    
    /// Dynamic Typeのサイズカテゴリに基づいてフォントサイズを調整
    static func adjustedFontSize(
        baseSize: CGFloat,
        for category: ContentSizeCategory
    ) -> CGFloat {
        let scaleFactor: CGFloat
        
        switch category {
        case .extraSmall:
            scaleFactor = 0.82
        case .small:
            scaleFactor = 0.88
        case .medium:
            scaleFactor = 0.95
        case .large:
            scaleFactor = 1.0
        case .extraLarge:
            scaleFactor = 1.12
        case .extraExtraLarge:
            scaleFactor = 1.23
        case .extraExtraExtraLarge:
            scaleFactor = 1.35
        case .accessibilityMedium:
            scaleFactor = 1.6
        case .accessibilityLarge:
            scaleFactor = 1.9
        case .accessibilityExtraLarge:
            scaleFactor = 2.3
        case .accessibilityExtraExtraLarge:
            scaleFactor = 2.8
        case .accessibilityExtraExtraExtraLarge:
            scaleFactor = 3.5
        @unknown default:
            scaleFactor = 1.0
        }
        
        return baseSize * scaleFactor
    }
}

// MARK: - Text Accessibility

extension Text {
    
    /// アクセシビリティラベルと併用可能なテキスト作成
    func accessibleText(
        label: String? = nil,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label ?? "")
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
    }
}

