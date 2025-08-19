//
//  DirectionTabView.swift
//  TrainAlert
//
//  時刻表の方向選択タブコンポーネント
//

import SwiftUI

struct DirectionTabView: View {
    let directions: [String]
    @Binding var selectedDirection: String?
    let getDirectionTitle: (String) -> String
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(directions, id: \.self) { direction in
                    Button(action: {
                        withAnimation {
                            selectedDirection = direction
                            onSelect(direction)
                        }
                    }) {
                        Text(getDirectionTitle(direction))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(
                                selectedDirection == direction ? .white : Color.textPrimary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        selectedDirection == direction ?
                                        Color.trainSoftBlue : Color.backgroundCard
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.backgroundSecondary)
        .onAppear {
            // 初回表示時に最初の方向を選択
            if selectedDirection == nil, let firstDirection = directions.first {
                selectedDirection = firstDirection
            }
        }
    }
}

