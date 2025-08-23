//
//  TransferRouteView.swift
//  TrainAlert
//
//  乗り換え経路の視覚的表示
//

import SwiftUI

struct TransferRouteView: View {
    let transferRoute: TransferRoute
    @State private var selectedSection: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(transferRoute.sections.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        // 区間の表示
                        sectionView(
                            section: transferRoute.sections[index],
                            index: index,
                            isSelected: selectedSection == index
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                selectedSection = selectedSection == index ? nil : index
                            }
                        }
                        
                        // 乗り換え表示（最後の区間以外）
                        if index < transferRoute.sections.count - 1,
                           let transfer = transferRoute.transferStations.first(where: { 
                               $0.stationName == transferRoute.sections[index].arrivalStation 
                           }) {
                            transferView(transfer: transfer)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.backgroundPrimary)
    }
    
    // MARK: - Section View
    
    private func sectionView(section: RouteSection, index: Int, isSelected: Bool) -> some View {
        VStack(spacing: 0) {
            // 駅と路線情報
            HStack(spacing: 16) {
                // 路線カラーバー
                RoundedRectangle(cornerRadius: 2)
                    .fill(lineColor(for: section.railway))
                    .frame(width: 4, height: 80)
                
                // 駅情報
                VStack(alignment: .leading, spacing: 8) {
                    // 出発駅
                    stationRow(
                        name: section.departureStation,
                        time: section.departureTime,
                        type: .departure
                    )
                    
                    // 路線情報
                    HStack {
                        Image(systemName: "tram.fill")
                            .font(.caption2)
                            .foregroundColor(Color.textSecondary)
                        Text(section.railway)
                            .font(.caption2)
                            .foregroundColor(Color.textSecondary)
                        if let trainType = section.trainType {
                            Text("・\(trainType)")
                                .font(.caption2)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .padding(.leading, 24)
                    
                    // 到着駅
                    stationRow(
                        name: section.arrivalStation,
                        time: section.arrivalTime,
                        type: .arrival
                    )
                }
                
                Spacer()
                
                // 所要時間
                if let duration = sectionDuration(section) {
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .padding(8)
                        .background(Color.backgroundCard)
                        .cornerRadius(6)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.trainSoftBlue.opacity(0.1) : Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.trainSoftBlue : Color.clear, lineWidth: 2)
                    )
            )
            
            // 詳細情報（選択時のみ表示）
            if isSelected {
                sectionDetails(section: section)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }
        }
    }
    
    private func stationRow(name: String, time: Date, type: StationType) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(type == .departure ? Color.trainSoftBlue : Color.warmOrange)
                .frame(width: 12, height: 12)
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color.textPrimary)
            
            Text(formatTime(time))
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
    }
    
    // MARK: - Transfer View
    
    private func transferView(transfer: TransferStation) -> some View {
        HStack(spacing: 12) {
            // 接続線
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.textSecondary.opacity(0.3))
                        .frame(width: 2, height: 2)
                }
            }
            .padding(.leading, 20)
            
            // 乗り換え情報
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(Color.warmOrange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("乗り換え")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.warmOrange)
                    
                    Text("\(transfer.fromLine) → \(transfer.toLine)")
                        .font(.caption2)
                        .foregroundColor(Color.textSecondary)
                    
                    if transfer.transferTime > 0 {
                        Text("乗り換え時間: \(Int(transfer.transferTime / 60))分")
                            .font(.caption2)
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Spacer()
                
                if let platform = transfer.platform {
                    Text(platform)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.backgroundCard)
                        .cornerRadius(4)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.warmOrange.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Section Details
    
    private func sectionDetails(section: RouteSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let trainNumber = section.trainNumber {
                detailRow(label: "列車番号", value: trainNumber)
            }
            
            if let trainType = section.trainType {
                detailRow(label: "種別", value: trainType)
            }
            
            detailRow(label: "路線", value: section.railway)
            
            if let duration = sectionDuration(section) {
                detailRow(label: "所要時間", value: duration)
            }
        }
        .padding()
        .background(Color.backgroundCard)
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.textPrimary)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func sectionDuration(_ section: RouteSection) -> String? {
        let duration = section.arrivalTime.timeIntervalSince(section.departureTime)
        let minutes = Int(duration / 60)
        
        if minutes > 0 {
            return "\(minutes)分"
        }
        return nil
    }
    
    private func lineColor(for railway: String) -> Color {
        // 路線に応じた色を返す（実際にはもっと多くの路線に対応）
        switch railway {
        case "JR山手線":
            return Color(hex: "99CC00")
        case "東京メトロ銀座線":
            return Color(hex: "FF9500")
        case "東京メトロ丸ノ内線":
            return Color(hex: "F62E36")
        default:
            return Color.trainSoftBlue
        }
    }
    
    enum StationType {
        case departure
        case arrival
    }
}

// MARK: - Preview

struct TransferRouteView_Previews: PreviewProvider {
    static var previews: some View {
        TransferRouteView(transferRoute: TransferRoute.mockData)
    }
}

