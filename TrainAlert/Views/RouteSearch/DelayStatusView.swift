//
//  DelayStatusView.swift
//  TrainAlert
//
//  遅延情報表示ビュー
//

import SwiftUI

/// 遅延情報表示ビュー
struct DelayStatusView: View {
    let trainNumber: String?
    let railwayId: String?
    @State private var delayInfo: TrainDelayInfo?
    @State private var isLoading = false
    @State private var lastError: Error?
    
    @StateObject private var delayManager = DelayNotificationManager.shared
    
    var body: some View {
        Group {
            if let trainNumber = trainNumber, let railwayId = railwayId {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("遅延情報を確認中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                } else if let delayInfo = delayInfo {
                    DelayInfoBadge(delayInfo: delayInfo)
                } else if lastError != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("遅延情報取得エラー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .task {
            await loadDelayInfo()
        }
        .refreshable {
            await loadDelayInfo()
        }
    }
    
    private func loadDelayInfo() async {
        guard let trainNumber = trainNumber,
              let railwayId = railwayId else { return }
        
        isLoading = true
        lastError = nil
        
        do {
            delayInfo = try await delayManager.getDelayInfo(
                for: trainNumber,
                railwayId: railwayId
            )
        } catch {
            lastError = error
            print("Failed to load delay info: \(error)")
        }
        
        isLoading = false
    }
}

/// 遅延情報バッジ
struct DelayInfoBadge: View {
    let delayInfo: TrainDelayInfo
    
    var badgeColor: Color {
        switch delayInfo.delayMinutes {
        case 0:
            return .green
        case 1..<10:
            return .yellow
        case 10..<30:
            return .orange
        default:
            return .red
        }
    }
    
    var iconName: String {
        switch delayInfo.delayMinutes {
        case 0:
            return "checkmark.circle.fill"
        case 1..<30:
            return "exclamationmark.triangle.fill"
        default:
            return "exclamationmark.octagon.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(badgeColor)
            
            Text(delayInfo.delayDescription)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(delayInfo.delayMinutes == 0 ? .secondary : badgeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            badgeColor.opacity(0.15)
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(badgeColor.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 遅延情報詳細ビュー
struct DelayDetailView: View {
    let delayInfo: TrainDelayInfo
    @State private var showingSettings = false
    @StateObject private var delayManager = DelayNotificationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("遅延情報")
                        .font(.headline)
                    Text("最終更新: \(delayInfo.lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                }
            }
            
            // 遅延状況
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("列車番号", systemImage: "tram.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(delayInfo.trainNumber)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label("遅延時間", systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(delayInfo.delayDescription)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(delayInfo.delayMinutes > 0 ? .orange : .green)
                }
                
                if let fromStation = delayInfo.fromStation,
                   let toStation = delayInfo.toStation {
                    HStack {
                        Label("運行区間", systemImage: "arrow.right.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(extractStationName(from: fromStation)) → \(extractStationName(from: toStation))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // 通知設定状態
            if delayManager.isEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("遅延が\(delayManager.notificationThreshold)分を超えた場合、通知時刻を自動調整します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingSettings) {
            DelayNotificationSettingsView()
        }
    }
    
    private func extractStationName(from stationId: String) -> String {
        // "odpt.Station:TokyoMetro.Ginza.Shibuya" -> "渋谷"
        let components = stationId.split(separator: ".")
        return String(components.last ?? "")
    }
}

/// 遅延通知設定ビュー
struct DelayNotificationSettingsView: View {
    @StateObject private var delayManager = DelayNotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("遅延通知を有効化", isOn: $delayManager.isEnabled)
                        .onChange(of: delayManager.isEnabled) { _ in
                            delayManager.saveSettings()
                        }
                } header: {
                    Text("遅延通知設定")
                } footer: {
                    Text("遅延情報に基づいて通知時刻を自動的に調整します")
                }
                
                if delayManager.isEnabled {
                    Section {
                        Stepper(
                            "通知閾値: \(delayManager.notificationThreshold)分",
                            value: $delayManager.notificationThreshold,
                            in: 5...60,
                            step: 5
                        )
                        .onChange(of: delayManager.notificationThreshold) { _ in
                            delayManager.saveSettings()
                        }
                    } header: {
                        Text("通知条件")
                    } footer: {
                        Text("指定した分数以上の遅延が発生した場合に通知時刻を調整します")
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("30分以上の遅延では特別な通知を送信します")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("遅延通知設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("遅延なし") {
    DelayStatusView(
        trainNumber: "1234",
        railwayId: "odpt.Railway:JR-East.Yamanote"
    )
}

#Preview("遅延あり") {
    DelayInfoBadge(
        delayInfo: TrainDelayInfo(
            trainNumber: "1234",
            railwayId: "odpt.Railway:JR-East.Yamanote",
            delayMinutes: 15,
            fromStation: "odpt.Station:JR-East.Yamanote.Tokyo",
            toStation: "odpt.Station:JR-East.Yamanote.Shinjuku",
            lastUpdated: Date()
        )
    )
}

#Preview("遅延詳細") {
    DelayDetailView(
        delayInfo: TrainDelayInfo(
            trainNumber: "1234",
            railwayId: "odpt.Railway:JR-East.Yamanote",
            delayMinutes: 25,
            fromStation: "odpt.Station:JR-East.Yamanote.Tokyo",
            toStation: "odpt.Station:JR-East.Yamanote.Shinjuku",
            lastUpdated: Date()
        )
    )
    .padding()
}

#Preview("設定画面") {
    DelayNotificationSettingsView()
}
