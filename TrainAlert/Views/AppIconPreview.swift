//
//  AppIconPreview.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

/// アプリアイコンのデザインプレビュー
/// 実際のアイコンは1024x1024のPNGファイルとして書き出す必要があります
struct AppIconPreview: View {
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.95, blue: 1.0),  // 薄い青みがかった白
                    Color(red: 0.85, green: 0.85, blue: 0.95)  // 薄い青
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // メインコンテンツ
            VStack(spacing: 0) {
                // 目覚まし時計
                ZStack {
                    // 時計の本体
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                    
                    // 時計の針
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 3, height: 40)
                        .offset(y: -20)
                        .rotationEffect(.degrees(30))
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 3, height: 30)
                        .offset(y: -15)
                        .rotationEffect(.degrees(-60))
                    
                    // ベル
                    Image(systemName: "bell.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                        .offset(x: 0, y: -70)
                        .rotationEffect(.degrees(-15))
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.orange)
                        .offset(x: 0, y: -70)
                        .rotationEffect(.degrees(15))
                }
                .offset(y: -40)
                
                // 電車（寝ている）
                ZStack {
                    // 電車本体
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color(red: 0.0, green: 0.4, blue: 0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 200, height: 80)
                    
                    // 窓
                    HStack(spacing: 10) {
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.8))
                                .frame(width: 40, height: 30)
                        }
                    }
                    
                    // Zzz... (寝ている表現)
                    Text("Zzz...")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 100, y: -40)
                        .rotationEffect(.degrees(15))
                }
                .offset(y: 40)
            }
        }
        .frame(width: 300, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 60))
    }
}

#if DEBUG
struct AppIconPreview_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // 大きいプレビュー
            AppIconPreview()
                .frame(width: 300, height: 300)
            
            // 実際のアプリアイコンサイズのプレビュー
            HStack(spacing: 20) {
                AppIconPreview()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                AppIconPreview()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif

