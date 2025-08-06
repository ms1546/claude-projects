import SwiftUI

// MARK: - Secondary Button Component

struct SecondaryButton: View {
    
    // MARK: - Properties
    
    let title: String
    let action: () -> Void
    
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var style: ButtonStyle = .default
    var size: ButtonSize = .medium
    
    // MARK: - Button Styles
    
    enum ButtonStyle {
        case `default`
        case outlined
        case ghost
        case text
    }
    
    // MARK: - Button Sizes
    
    enum ButtonSize {
        case small
        case medium
        case large
        case fullWidth
        
        var height: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 56
            case .fullWidth: return 56
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            case .fullWidth: return 24
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .labelSmall
            case .medium: return .labelMedium
            case .large: return .labelLarge
            case .fullWidth: return .labelLarge
            }
        }
    }
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                // ハプティックフィードバック
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                action()
            }
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(size.font)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(textColor)
            .frame(height: size.height)
            .frame(maxWidth: size == .fullWidth ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .disabled(!isEnabled || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isEnabled ? .isButton : [.isButton, .isNotEnabled])
    }
    
    // MARK: - Style Properties
    
    private var backgroundColor: Color {
        switch style {
        case .default:
            return isHovered ? Color.buttonSecondaryBackground.opacity(0.1) : .buttonSecondaryBackground
        case .outlined:
            return isHovered ? Color.buttonSecondaryText.opacity(0.1) : .clear
        case .ghost:
            return isHovered ? Color.textSecondary.opacity(0.1) : .clear
        case .text:
            return .clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .default, .outlined:
            return .buttonSecondaryText
        case .ghost:
            return .textSecondary
        case .text:
            return .textPrimary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .default:
            return .clear
        case .outlined:
            return .buttonSecondaryBorder
        case .ghost:
            return .textSecondary.opacity(0.3)
        case .text:
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .default, .text:
            return 0
        case .outlined:
            return 2
        case .ghost:
            return 1
        }
    }
    
    private var opacity: Double {
        if !isEnabled {
            return 0.6
        } else if isPressed {
            return 0.8
        } else {
            return 1.0
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        if isLoading {
            return "\(title)、読み込み中"
        } else if !isEnabled {
            return "\(title)、無効"
        } else {
            return title
        }
    }
    
    private var accessibilityHint: String {
        if isLoading {
            return "処理中です。しばらくお待ちください。"
        } else if !isEnabled {
            return "このボタンは現在使用できません。"
        } else {
            return "ダブルタップして実行します。"
        }
    }
    
    // MARK: - Initializers
    
    init(
        _ title: String,
        style: ButtonStyle = .default,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
}

// MARK: - Convenience Initializers

extension SecondaryButton {
    
    /// アウトラインボタン
    static func outlined(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> SecondaryButton {
        SecondaryButton(
            title,
            style: .outlined,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
    
    /// ゴーストボタン
    static func ghost(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> SecondaryButton {
        SecondaryButton(
            title,
            style: .ghost,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
    
    /// テキストボタン
    static func text(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> SecondaryButton {
        SecondaryButton(
            title,
            style: .text,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
}

// MARK: - Icon Button Support

struct IconSecondaryButton: View {
    
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var style: SecondaryButton.ButtonStyle = .default
    var size: SecondaryButton.ButtonSize = .medium
    var iconPosition: IconPosition = .leading
    
    enum IconPosition {
        case leading
        case trailing
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLoading {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }
        }) {
            HStack(spacing: 8) {
                if iconPosition == .leading {
                    iconView
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(size.font)
                        .fontWeight(.medium)
                }
                
                if iconPosition == .trailing {
                    iconView
                }
            }
            .foregroundColor(textColor)
            .frame(height: size.height)
            .frame(maxWidth: size == .fullWidth ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .disabled(!isEnabled || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var iconView: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .medium))
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        case .fullWidth: return 18
        }
    }
    
    // Style properties (同様の実装)
    private var backgroundColor: Color {
        switch style {
        case .default: return .buttonSecondaryBackground
        case .outlined: return .clear
        case .ghost: return .clear
        case .text: return .clear
        }
    }
    
    private var textColor: Color {
        switch style {
        case .default, .outlined: return .buttonSecondaryText
        case .ghost: return .textSecondary
        case .text: return .textPrimary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .default: return .clear
        case .outlined: return .buttonSecondaryBorder
        case .ghost: return .textSecondary.opacity(0.3)
        case .text: return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .default, .text: return 0
        case .outlined: return 2
        case .ghost: return 1
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SecondaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Basic buttons
            SecondaryButton("デフォルト") {
                print("デフォルトボタンがタップされました")
            }
            
            SecondaryButton.outlined("アウトライン") {
                print("アウトラインボタンがタップされました")
            }
            
            SecondaryButton.ghost("ゴースト") {
                print("ゴーストボタンがタップされました")
            }
            
            SecondaryButton.text("テキスト") {
                print("テキストボタンがタップされました")
            }
            
            // Different sizes
            SecondaryButton("小サイズ", style: .outlined, size: .small) {
                print("小サイズボタンがタップされました")
            }
            
            SecondaryButton("大サイズ", style: .outlined, size: .large) {
                print("大サイズボタンがタップされました")
            }
            
            SecondaryButton("フル幅", style: .outlined, size: .fullWidth) {
                print("フル幅ボタンがタップされました")
            }
            
            // Icon button
            IconSecondaryButton(
                title: "アイコン付き",
                systemImage: "star.fill",
                action: {
                    print("アイコンボタンがタップされました")
                }
            )
            
            // States
            SecondaryButton("無効", style: .outlined, isEnabled: false) {
                print("無効ボタンがタップされました")
            }
            
            SecondaryButton("読み込み中", style: .outlined, isLoading: true) {
                print("読み込み中ボタンがタップされました")
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
        .previewDisplayName("SecondaryButton Variations")
    }
}
#endif
