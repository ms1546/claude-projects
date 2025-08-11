//
//  SplashScreen.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

/// Optimized splash screen that provides visual feedback during app initialization
/// Designed to improve perceived startup time while maintaining 60fps performance
struct SplashScreen: View {
    
    // MARK: - State
    
    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    @State private var trainOffset: CGFloat = -100
    
    // MARK: - Constants
    
    private enum AnimationConstants {
        static let logoAppearDuration: Double = 0.4
        static let trainMoveDuration: Double = 0.8
        static let pulseInterval: Double = 1.2
        static let scaleRange: ClosedRange<CGFloat> = 0.95...1.05
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 40) {
                Spacer()
                
                // App logo with animation
                appLogo
                
                // Loading indicator
                loadingIndicator
                
                Spacer()
                
                // Branding text
                brandingText
            }
            .padding()
            
            // Animated train
            animatedTrain
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                .trainCharcoalGray,
                .trainCharcoalGray.opacity(0.8),
                Color.trainSoftBlue.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var appLogo: some View {
        VStack(spacing: 16) {
            // Train icon
            Image(systemName: "tram.fill")
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundColor(.trainSoftBlue)
                .scaleEffect(scale)
                .opacity(opacity)
                .animation(
                    .easeInOut(duration: AnimationConstants.logoAppearDuration)
                    .repeatForever(autoreverses: true),
                    value: scale
                )
            
            // App title
            Text("TrainAlert")
                .font(.largeTitle)
                .fontWeight(.thin)
                .foregroundColor(.white)
                .opacity(opacity)
                .animation(
                    .easeInOut(duration: AnimationConstants.logoAppearDuration)
                    .delay(0.2),
                    value: opacity
                )
        }
    }
    
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            // Modern loading dots
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.trainSoftBlue)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: isAnimating
                        )
                }
            }
            
            Text("読み込み中...")
                .font(.caption)
                .foregroundColor(.trainLightGray)
                .opacity(opacity)
        }
    }
    
    private var brandingText: some View {
        VStack(spacing: 4) {
            Text("電車寝過ごし防止アプリ")
                .font(.caption)
                .foregroundColor(.trainLightGray)
            
            Text("Train Alert")
                .font(.caption2)
                .foregroundColor(Color.trainLightGray.opacity(0.7))
        }
        .opacity(opacity)
        .animation(
            .easeInOut(duration: AnimationConstants.logoAppearDuration)
            .delay(0.6),
            value: opacity
        )
    }
    
    private var animatedTrain: some View {
        VStack {
            Spacer()
            
            HStack {
                Image(systemName: "tram")
                    .font(.system(size: 24))
                    .foregroundColor(Color.trainSoftBlue.opacity(0.6))
                    .offset(x: trainOffset)
                    .animation(
                        .easeInOut(duration: AnimationConstants.trainMoveDuration)
                        .repeatForever(autoreverses: true),
                        value: trainOffset
                    )
                
                Spacer()
            }
            
            // Track line
            Rectangle()
                .fill(Color.trainLightGray.opacity(0.3))
                .frame(height: 1)
                .opacity(opacity)
                .padding(.horizontal)
                .padding(.bottom, 50)
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimations() {
        // Start immediately visible animations
        withAnimation(.easeOut(duration: AnimationConstants.logoAppearDuration)) {
            opacity = 1.0
        }
        
        // Delayed animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isAnimating = true
            }
            
            startPulseAnimation()
            startTrainAnimation()
        }
    }
    
    private func startPulseAnimation() {
        let timer = Timer.scheduledTimer(withTimeInterval: AnimationConstants.pulseInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = scale == AnimationConstants.scaleRange.lowerBound ? 
                       AnimationConstants.scaleRange.upperBound : 
                       AnimationConstants.scaleRange.lowerBound
            }
        }
        
        // Stop timer when view disappears (handled by SwiftUI automatically)
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func startTrainAnimation() {
        withAnimation(.easeInOut(duration: AnimationConstants.trainMoveDuration).repeatForever(autoreverses: true)) {
            trainOffset = 100
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SplashScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreen()
            .preferredColorScheme(.dark)
            .previewDisplayName("SplashScreen - Dark")
    }
}
#endif
