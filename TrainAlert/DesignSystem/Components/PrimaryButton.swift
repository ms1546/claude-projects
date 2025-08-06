import SwiftUI

// MARK: - Primary Button Component

struct PrimaryButton: View {
    
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
        case destructive
        case success
        case gradient
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
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(textColor)
            .frame(height: size.height)
            .frame(maxWidth: size == .fullWidth ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundView)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isEnabled ? .isButton : [.isButton, .isNotEnabled])
    }
    
    // MARK: - Style Properties
    
    private var backgroundColor: Color {
        switch style {
        case .default:
            return .buttonPrimaryBackground
        case .destructive:
            return .error
        case .success:
            return .success
        case .gradient:
            return .clear // グラデーション使用時は透明
        }
    }
    
    private var backgroundView: some View {
        Group {
            if style == .gradient {
                Color.buttonGradient
            } else {
                backgroundColor
            }
        }
    }
    
    private var textColor: Color {
        switch style {
        case .default, .destructive, .success, .gradient:
            return .buttonPrimaryText
        }
    }
    
    private var borderColor: Color {
        return .clear
    }
    
    private var borderWidth: CGFloat {
        return 0
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

extension PrimaryButton {
    
    /// デストラクティブボタン（削除など）
    static func destructive(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> PrimaryButton {
        PrimaryButton(
            title,
            style: .destructive,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
    
    /// 成功・完了ボタン
    static func success(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> PrimaryButton {
        PrimaryButton(
            title,
            style: .success,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
    
    /// グラデーションボタン
    static func gradient(
        _ title: String,
        size: ButtonSize = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> PrimaryButton {
        PrimaryButton(
            title,
            style: .gradient,
            size: size,
            isEnabled: isEnabled,
            isLoading: isLoading,
            action: action
        )
    }
}

// MARK: - Preview

#if DEBUG
struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Basic buttons
            PrimaryButton("デフォルトボタン") {
                print("デフォルトボタンがタップされました")
            }
            
            PrimaryButton.destructive("削除") {
                print("削除ボタンがタップされました")
            }
            
            PrimaryButton.success("完了") {
                print("完了ボタンがタップされました")
            }
            
            PrimaryButton.gradient("グラデーション") {
                print("グラデーションボタンがタップされました")
            }
            
            // Different sizes
            PrimaryButton("小サイズ", size: .small) {
                print("小サイズボタンがタップされました")
            }
            
            PrimaryButton("大サイズ", size: .large) {
                print("大サイズボタンがタップされました")
            }
            
            PrimaryButton("フル幅", size: .fullWidth) {
                print("フル幅ボタンがタップされました")
            }
            
            // States
            PrimaryButton("無効", isEnabled: false) {
                print("無効ボタンがタップされました")
            }
            
            PrimaryButton("読み込み中", isLoading: true) {
                print("読み込み中ボタンがタップされました")
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
        .previewDisplayName("PrimaryButton Variations")
    }
}
#endif
