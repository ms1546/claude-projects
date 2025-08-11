import SwiftUI

// MARK: - Loading Indicator Component

struct LoadingIndicator: View {
    
    // MARK: - Properties
    
    var style: LoadingStyle = .default
    var size: LoadingSize = .medium
    var color: Color = .trainSoftBlue
    var text: String? = nil
    
    // MARK: - Loading Styles
    
    enum LoadingStyle {
        case `default`
        case pulsing
        case rotating
        case bouncing
        case wave
    }
    
    // MARK: - Loading Sizes
    
    enum LoadingSize {
        case small
        case medium
        case large
        
        var diameter: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 32
            case .large: return 48
            }
        }
        
        var strokeWidth: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }
        
        var textFont: Font {
            switch self {
            case .small: return .caption
            case .medium: return .bodySmall
            case .large: return .bodyMedium
            }
        }
    }
    
    // MARK: - Animation State
    
    @State private var isAnimating = false
    @State private var rotationAngle: Double = 0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            loadingView
            
            if let text = text {
                Text(text)
                    .font(size.textFont)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.7)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Loading Views
    
    @ViewBuilder
    private var loadingView: some View {
        switch style {
        case .default:
            defaultLoadingView
        case .pulsing:
            pulsingLoadingView
        case .rotating:
            rotatingLoadingView
        case .bouncing:
            bouncingLoadingView
        case .wave:
            waveLoadingView
        }
    }
    
    // MARK: - Default Loading View
    
    private var defaultLoadingView: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: color))
            .scaleEffect(scaleForSize)
    }
    
    // MARK: - Pulsing Loading View
    
    private var pulsingLoadingView: some View {
        Circle()
            .fill(color)
            .frame(width: size.diameter, height: size.diameter)
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
    }
    
    // MARK: - Rotating Loading View
    
    private var rotatingLoadingView: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round))
            .frame(width: size.diameter, height: size.diameter)
            .rotationEffect(.degrees(rotationAngle))
            .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
    }
    
    // MARK: - Bouncing Loading View
    
    private var bouncingLoadingView: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: size.diameter / 3, height: size.diameter / 3)
                    .scaleEffect(isAnimating ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
    }
    
    // MARK: - Wave Loading View
    
    private var waveLoadingView: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: size.diameter)
                    .scaleEffect(x: 1, y: isAnimating ? 0.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var scaleForSize: CGFloat {
        switch size {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.5
        }
    }
    
    private var accessibilityLabel: String {
        if let text = text {
            return "読み込み中、\(text)"
        } else {
            return "読み込み中"
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimation() {
        isAnimating = true
        
        // 回転アニメーション用
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    // MARK: - Initializers
    
    init(
        style: LoadingStyle = .default,
        size: LoadingSize = .medium,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) {
        self.style = style
        self.size = size
        self.color = color
        self.text = text
    }
}

// MARK: - Convenience Initializers

extension LoadingIndicator {
    
    /// 小さなローディングインジケーター
    static func small(
        style: LoadingStyle = .default,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) -> LoadingIndicator {
        LoadingIndicator(style: style, size: .small, color: color, text: text)
    }
    
    /// 大きなローディングインジケーター
    static func large(
        style: LoadingStyle = .default,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) -> LoadingIndicator {
        LoadingIndicator(style: style, size: .large, color: color, text: text)
    }
    
    /// パルシングローディング
    static func pulsing(
        size: LoadingSize = .medium,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) -> LoadingIndicator {
        LoadingIndicator(style: .pulsing, size: size, color: color, text: text)
    }
    
    /// 回転ローディング
    static func rotating(
        size: LoadingSize = .medium,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) -> LoadingIndicator {
        LoadingIndicator(style: .rotating, size: size, color: color, text: text)
    }
    
    /// バウンシングローディング
    static func bouncing(
        size: LoadingSize = .medium,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) -> LoadingIndicator {
        LoadingIndicator(style: .bouncing, size: size, color: color, text: text)
    }
    
    /// ウェーブローディング
    static func wave(
        size: LoadingSize = .medium,
        color: Color = .trainSoftBlue,
        text: String? = nil
    ) -> LoadingIndicator {
        LoadingIndicator(style: .wave, size: size, color: color, text: text)
    }
}

// MARK: - Full Screen Loading

struct FullScreenLoading: View {
    
    let message: String
    var style: LoadingIndicator.LoadingStyle = .default
    var backgroundColor: Color = Color.backgroundPrimary.opacity(0.8)
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            Card(style: .elevated) {
                LoadingIndicator.large(style: style, text: message)
                    .frame(minWidth: 200, minHeight: 120)
            }
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("読み込み画面、\(message)")
    }
}

// MARK: - Inline Loading

struct InlineLoading: View {
    
    let message: String?
    var style: LoadingIndicator.LoadingStyle = .default
    var alignment: HorizontalAlignment = .center
    
    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            LoadingIndicator(style: style, size: .small)
            
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(textAlignment)
            }
        }
    }
    
    private var textAlignment: TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }
}

// MARK: - Button Loading State

struct LoadingButtonContent: View {
    
    let title: String
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                LoadingIndicator.small(style: .default, color: .white)
            }
            
            Text(title)
                .opacity(isLoading ? 0.7 : 1.0)
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Basic loading indicators
                Group {
                    LoadingIndicator(text: "読み込み中...")
                    LoadingIndicator.pulsing(text: "パルシング")
                    LoadingIndicator.rotating(text: "回転中")
                    LoadingIndicator.bouncing(text: "バウンシング")
                    LoadingIndicator.wave(text: "ウェーブ")
                }
                
                Divider()
                    .background(Color.trainLightGray)
                
                // Different sizes
                HStack(spacing: 20) {
                    LoadingIndicator.small()
                    LoadingIndicator()
                    LoadingIndicator.large()
                }
                
                Divider()
                    .background(Color.trainLightGray)
                
                // Specialized loading views
                InlineLoading(message: "データを読み込み中...")
                
                Card {
                    LoadingButtonContent(title: "保存中", isLoading: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
        .preferredColorScheme(.dark)
        .previewDisplayName("LoadingIndicator Variations")
        
        // Full screen loading preview
        FullScreenLoading(message: "アプリを初期化中...")
            .previewDisplayName("FullScreen Loading")
    }
}
#endif
