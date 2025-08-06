import SwiftUI

// MARK: - Card Component

struct Card<Content: View>: View {
    
    // MARK: - Properties
    
    let content: () -> Content
    
    var style: CardStyle = .default
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    var cornerRadius: CGFloat = 12
    var shadowStyle: ShadowStyle = .subtle
    
    // MARK: - Card Styles
    
    enum CardStyle {
        case `default`
        case elevated
        case outlined
        case transparent
        case gradient
    }
    
    // MARK: - Shadow Styles
    
    enum ShadowStyle {
        case none
        case subtle
        case medium
        case strong
        
        var color: Color {
            return Color.black.opacity(opacity)
        }
        
        var opacity: Double {
            switch self {
            case .none: return 0
            case .subtle: return 0.1
            case .medium: return 0.15
            case .strong: return 0.25
            }
        }
        
        var radius: CGFloat {
            switch self {
            case .none: return 0
            case .subtle: return 8
            case .medium: return 12
            case .strong: return 20
            }
        }
        
        var offset: CGSize {
            switch self {
            case .none: return .zero
            case .subtle: return CGSize(width: 0, height: 2)
            case .medium: return CGSize(width: 0, height: 4)
            case .strong: return CGSize(width: 0, height: 8)
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        content()
            .padding(padding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(overlayView)
            .shadow(
                color: shadowStyle.color,
                radius: shadowStyle.radius,
                x: shadowStyle.offset.width,
                y: shadowStyle.offset.height
            )
    }
    
    // MARK: - Background Views
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .default:
            Color.backgroundCard
        case .elevated:
            Color.backgroundCard
        case .outlined:
            Color.clear
        case .transparent:
            Color.clear
        case .gradient:
            Color.cardGradient
        }
    }
    
    @ViewBuilder
    private var overlayView: some View {
        if style == .outlined {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.lightGray.opacity(0.3), lineWidth: 1)
        }
    }
    
    // MARK: - Initializers
    
    init(
        style: CardStyle = .default,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        shadowStyle: ShadowStyle = .subtle,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadowStyle = shadowStyle
        self.content = content
    }
}

// MARK: - Convenience Initializers

extension Card {
    
    /// エレベーションカード（浮き上がって見える）
    static func elevated<T: View>(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: @escaping () -> T
    ) -> Card<T> {
        Card<T>(
            style: .elevated,
            padding: padding,
            cornerRadius: cornerRadius,
            shadowStyle: .medium,
            content: content
        )
    }
    
    /// アウトラインカード
    static func outlined<T: View>(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: @escaping () -> T
    ) -> Card<T> {
        Card<T>(
            style: .outlined,
            padding: padding,
            cornerRadius: cornerRadius,
            shadowStyle: .none,
            content: content
        )
    }
    
    /// 透明カード
    static func transparent<T: View>(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: @escaping () -> T
    ) -> Card<T> {
        Card<T>(
            style: .transparent,
            padding: padding,
            cornerRadius: cornerRadius,
            shadowStyle: .none,
            content: content
        )
    }
    
    /// グラデーションカード
    static func gradient<T: View>(
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        cornerRadius: CGFloat = 12,
        @ViewBuilder content: @escaping () -> T
    ) -> Card<T> {
        Card<T>(
            style: .gradient,
            padding: padding,
            cornerRadius: cornerRadius,
            shadowStyle: .subtle,
            content: content
        )
    }
}

// MARK: - Specialized Cards

/// アラートカード（通知表示用）
struct AlertCard: View {
    
    let title: String
    let subtitle: String?
    let status: AlertStatus
    let action: (() -> Void)?
    
    enum AlertStatus {
        case active
        case paused
        case inactive
        
        var color: Color {
            switch self {
            case .active: return .success
            case .paused: return .warning
            case .inactive: return .lightGray
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "location.fill"
            case .paused: return "pause.fill"
            case .inactive: return "location.slash"
            }
        }
        
        var statusText: String {
            switch self {
            case .active: return "アクティブ"
            case .paused: return "一時停止中"
            case .inactive: return "停止中"
            }
        }
    }
    
    var body: some View {
        Card.elevated {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.displaySmall)
                            .foregroundColor(.textPrimary)
                            .headingLayout()
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.bodySmall)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Image(systemName: status.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(status.color)
                        
                        Text(status.statusText)
                            .font(.caption)
                            .foregroundColor(status.color)
                    }
                }
                
                if let action = action {
                    HStack {
                        Spacer()
                        
                        Button("詳細") {
                            action()
                        }
                        .font(.labelSmall)
                        .foregroundColor(.softBlue)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)のアラート、\(status.statusText)")
        .accessibilityHint(action != nil ? "詳細を表示するにはダブルタップ" : "")
    }
}

/// 駅カード（駅選択用）
struct StationCard: View {
    
    let stationName: String
    let distance: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Card(
                style: isSelected ? .gradient : .default,
                shadowStyle: isSelected ? .medium : .subtle
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stationName)
                            .font(.labelLarge)
                            .foregroundColor(.textPrimary)
                        
                        if let distance = distance {
                            Text("現在地から \(distance)")
                                .font(.bodySmall)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.success)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.lightGray)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("ダブルタップして選択")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var accessibilityLabel: String {
        var label = stationName
        if let distance = distance {
            label += "、現在地から\(distance)"
        }
        if isSelected {
            label += "、選択中"
        }
        return label
    }
}

/// 履歴カード（履歴表示用）
struct HistoryCard: View {
    
    let stationName: String
    let date: String
    let time: String
    let character: String?
    
    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stationName)
                        .font(.labelMedium)
                        .foregroundColor(.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Text(time)
                            .font(.numbersMedium)
                            .foregroundColor(.textSecondary)
                    }
                    
                    if let character = character {
                        Text(character)
                            .font(.bodySmall)
                            .foregroundColor(.lightGray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundColor(.lightGray)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stationName)、\(date)、\(time)")
    }
}

// MARK: - Preview

#if DEBUG
struct Card_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic cards
                Card {
                    Text("デフォルトカード")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
                
                Card.elevated {
                    Text("エレベーションカード")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
                
                Card.outlined {
                    Text("アウトラインカード")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
                
                Card.gradient {
                    Text("グラデーションカード")
                        .font(.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
                
                // Specialized cards
                AlertCard(
                    title: "渋谷駅",
                    subtitle: "到着予定: 18:45",
                    status: .active,
                    action: {
                        print("アラートカードがタップされました")
                    }
                )
                
                StationCard(
                    stationName: "新宿駅",
                    distance: "2.3km",
                    isSelected: true,
                    action: {
                        print("駅カードがタップされました")
                    }
                )
                
                HistoryCard(
                    stationName: "東京駅",
                    date: "2024年1月15日",
                    time: "09:30",
                    character: "ギャル系キャラ"
                )
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
        .previewDisplayName("Card Variations")
    }
}
#endif