//
//  LinearProgressView.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/26.
//

import SwiftUI

struct LinearProgressView: View {
    let value: Double
    let total: Double
    var height: CGFloat = 4
    var cornerRadius: CGFloat = 2
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)
                
                // Progress
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.trainSoftBlue)
                    .frame(width: geometry.size.width * progress, height: height)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}
