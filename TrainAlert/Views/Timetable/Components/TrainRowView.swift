//
//  TrainRowView.swift
//  TrainAlert
//
//  時刻表の電車行表示コンポーネント
//

import SwiftUI

struct TrainRowView: View {
    let train: ODPTTrainTimetableObject
    let isNearCurrent: Bool
    let isPastTime: Bool
    let isLoading: Bool
    let isDataPreparing: Bool
    let isDataReady: Bool
    let onSelect: () -> Void
    
    private var isDisabled: Bool {
        isPastTime || isLoading || isDataPreparing || !isDataReady
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // 時刻
                VStack(spacing: 2) {
                    Text(train.departureTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(isPastTime ? Color.textSecondary.opacity(0.5) : Color.textPrimary)
                    
                    if isNearCurrent {
                        Text("もうすぐ")
                            .font(.caption2)
                            .foregroundColor(Color.warmOrange)
                    }
                }
                .frame(width: 80)
                
                // データ準備中インジケーター
                if !isDataReady && !isPastTime {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                // 列車情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        // 列車種別
                        if let trainTypeTitle = train.trainTypeTitle?.ja {
                            Text(trainTypeTitle)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(getTrainTypeColor(train.trainType))
                        }
                        
                        // 行き先
                        if let destination = train.destinationStationTitle?.ja {
                            Text(destination + "行")
                                .font(.system(size: 14))
                                .foregroundColor(Color.textPrimary)
                        }
                    }
                    
                    // プラットフォーム
                    if let platform = train.platformNumber {
                        Label("\(platform)番線", systemImage: "tram.fill")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Spacer()
                
                // 選択インジケーター
                if !isDataReady && !isPastTime {
                    Text("準備中...")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isNearCurrent ? Color.warmOrange.opacity(0.1) : Color.clear)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    private func getTrainTypeColor(_ trainType: String?) -> Color {
        guard let type = trainType?.lowercased() else { return Color.textPrimary }
        
        if type.contains("rapid") || type.contains("快速") {
            return Color.warmOrange
        } else if type.contains("express") || type.contains("急行") {
            return Color.red
        } else if type.contains("limited") || type.contains("特急") {
            return Color.purple
        } else {
            return Color.trainSoftBlue
        }
    }
}

