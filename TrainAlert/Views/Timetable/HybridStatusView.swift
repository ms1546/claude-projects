//
//  HybridStatusView.swift
//  TrainAlert
//
//  Created by Claude on 2025/08/24.
//

import CoreLocation
import SwiftUI

/// ハイブリッド通知の動作状態を表示するビュー
struct HybridStatusView: View {
    @StateObject private var hybridManager = HybridNotificationManager.shared
    @StateObject private var accuracyManager = LocationAccuracyManager.shared
    @StateObject private var fallbackHandler = GPSFallbackHandler.shared
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showingDebugInfo = false
    @State private var expandedSection: ExpandedSection?
    
    enum ExpandedSection {
        case mode
        case accuracy
        case fallback
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // メインステータスカード
            mainStatusCard
            
            // 詳細セクション
            VStack(spacing: 12) {
                // 動作モード
                statusSection(
                    title: "動作モード",
                    icon: hybridManager.currentMode.icon,
                    expanded: expandedSection == .mode
                ) {
                    modeDetailView
                } onTap: {
                    withAnimation {
                        expandedSection = expandedSection == .mode ? nil : .mode
                    }
                }
                
                // GPS精度
                statusSection(
                    title: "GPS精度",
                    icon: "location.circle.fill",
                    expanded: expandedSection == .accuracy
                ) {
                    accuracyDetailView
                } onTap: {
                    withAnimation {
                        expandedSection = expandedSection == .accuracy ? nil : .accuracy
                    }
                }
                
                // フォールバック状態
                if fallbackHandler.isInFallbackMode {
                    statusSection(
                        title: "フォールバック",
                        icon: "exclamationmark.triangle.fill",
                        expanded: expandedSection == .fallback
                    ) {
                        fallbackDetailView
                    } onTap: {
                        withAnimation {
                            expandedSection = expandedSection == .fallback ? nil : .fallback
                        }
                    }
                }
            }
            
            // デバッグボタン
            if showingDebugInfo {
                debugInfoView
            }
            
            Button(action: {
                withAnimation {
                    showingDebugInfo.toggle()
                }
            }) {
                Label(showingDebugInfo ? "デバッグ情報を隠す" : "デバッグ情報を表示", 
                      systemImage: showingDebugInfo ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.backgroundCard)
        .cornerRadius(16)
    }
    
    // MARK: - Main Status Card
    
    private var mainStatusCard: some View {
        VStack(spacing: 12) {
            // ヘッダー
            HStack {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundColor(.trainSoftBlue)
                
                Text("ハイブリッド通知")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $hybridManager.isEnabled)
                    .labelsHidden()
                    .tint(.trainSoftBlue)
            }
            
            // 現在の状態
            HStack(spacing: 16) {
                // モード
                VStack(alignment: .leading, spacing: 4) {
                    Text("モード")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: hybridManager.currentMode.icon)
                            .font(.caption)
                        Text(hybridManager.currentMode.displayName)
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(modeColor)
                }
                
                Divider()
                    .frame(height: 30)
                
                // 信頼度
                VStack(alignment: .leading, spacing: 4) {
                    Text("信頼度")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: confidenceIcon)
                            .font(.caption)
                        Text("\(Int(hybridManager.confidenceLevel * 100))%")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(confidenceColor)
                }
                
                Divider()
                    .frame(height: 30)
                
                // GPS状態
                VStack(alignment: .leading, spacing: 4) {
                    Text("GPS")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(gpsStatusColor)
                            .frame(width: 8, height: 8)
                        Text(gpsStatusText)
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            // ズレ表示
            if let deviation = hybridManager.currentDeviation {
                HStack {
                    Image(systemName: deviation.isDelayed ? "clock.badge.exclamationmark" : "clock.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(deviation.isDelayed ? .orange : .green)
                    
                    Text("時刻表との差: \(deviation.displayText)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.backgroundPrimary.opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Detail Views
    
    private var modeDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 優先モード設定
            VStack(alignment: .leading, spacing: 8) {
                Text("優先モード")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Picker("", selection: $hybridManager.preferredMode) {
                    ForEach(HybridNotificationManager.NotificationMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                            Text(mode.displayName)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // 最後の判定
            if let decision = hybridManager.lastDecision {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最後の判定")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    Text(decision.reason)
                        .font(.footnote)
                        .foregroundColor(.textPrimary)
                    
                    if let eta = decision.estimatedTimeToArrival {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("到着まで約\(Int(eta / 60))分")
                                .font(.caption2)
                        }
                        .foregroundColor(.textSecondary)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var accuracyDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 現在の精度
            HStack {
                Text("現在の精度")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("\(Int(accuracyManager.currentAccuracy))m")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(accuracyManager.accuracyLevel.color)
            }
            
            // 精度レベル
            HStack {
                Text("精度レベル")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(accuracyManager.accuracyLevel.color)
                        .frame(width: 8, height: 8)
                    Text(accuracyManager.accuracyLevel.displayName)
                        .font(.footnote)
                }
            }
            
            // 更新モード
            HStack {
                Text("更新モード")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(accuracyManager.updateMode.displayName)
                    .font(.footnote)
                    .foregroundColor(.textPrimary)
            }
            
            // バッテリー最適化
            HStack {
                Text("バッテリー最適化")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Toggle("", isOn: $accuracyManager.batteryOptimizationEnabled)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            
            // 環境
            HStack {
                Text("環境")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(accuracyManager.environment.displayName)
                    .font(.footnote)
                    .foregroundColor(.textPrimary)
            }
        }
    }
    
    private var fallbackDetailView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // フォールバック戦略
            HStack {
                Text("戦略")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text(fallbackHandler.currentState.strategy.displayName)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            
            // GPS途絶時間
            HStack {
                Text("GPS途絶")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("\(Int(fallbackHandler.gpsOutageDuration))秒")
                    .font(.footnote)
                    .foregroundColor(.textPrimary)
            }
            
            // 理由
            Text(fallbackHandler.currentState.reason)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .padding(.top, 4)
            
            // 最後の有効な位置
            if let lastGood = fallbackHandler.lastGoodLocation {
                let age = Date().timeIntervalSince(lastGood.timestamp)
                HStack {
                    Image(systemName: "location.slash")
                        .font(.caption2)
                    Text("最後の位置: \(Int(age))秒前")
                        .font(.caption2)
                }
                .foregroundColor(.textSecondary)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Debug View
    
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("デバッグ情報")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(getDebugInfo())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.textSecondary)
                    .padding(8)
                    .background(Color.backgroundPrimary.opacity(0.5))
                    .cornerRadius(8)
            }
        }
        .padding(.top)
    }
    
    // MARK: - Helper Methods
    
    private func statusSection<Content: View>(
        title: String,
        icon: String,
        expanded: Bool,
        @ViewBuilder content: () -> Content,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(.trainSoftBlue)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
            }
            
            if expanded {
                content()
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.backgroundPrimary.opacity(0.3))
        .cornerRadius(12)
    }
    
    private func getDebugInfo() -> String {
        var info = ""
        info += hybridManager.getDebugInfo() + "\n\n"
        info += accuracyManager.getDebugInfo() + "\n\n"
        info += fallbackHandler.getDebugInfo()
        return info
    }
    
    // MARK: - Computed Properties
    
    private var modeColor: Color {
        switch hybridManager.currentMode {
        case .hybrid:
            return .trainSoftBlue
        case .timetableOnly:
            return .purple
        case .locationOnly:
            return .green
        case .fallback:
            return .orange
        }
    }
    
    private var confidenceIcon: String {
        if hybridManager.confidenceLevel >= 0.8 {
            return "checkmark.circle.fill"
        } else if hybridManager.confidenceLevel >= 0.6 {
            return "exclamationmark.circle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    private var confidenceColor: Color {
        if hybridManager.confidenceLevel >= 0.8 {
            return .green
        } else if hybridManager.confidenceLevel >= 0.6 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var gpsStatusColor: Color {
        if accuracyManager.accuracyLevel == .unavailable {
            return .red
        } else if fallbackHandler.isInFallbackMode {
            return .orange
        } else if accuracyManager.accuracyLevel == .high {
            return .green
        } else {
            return .yellow
        }
    }
    
    private var gpsStatusText: String {
        if accuracyManager.accuracyLevel == .unavailable {
            return "利用不可"
        } else if fallbackHandler.isInFallbackMode {
            return "フォールバック"
        } else {
            return "正常"
        }
    }
}

// MARK: - Debug Extension

extension HybridNotificationManager {
    func getDebugInfo() -> String {
        var info = "=== Hybrid Notification Debug ===\n"
        info += "Enabled: \(isEnabled)\n"
        info += "Current Mode: \(currentMode.displayName)\n"
        info += "Confidence: \(Int(confidenceLevel * 100))%\n"
        info += "Monitoring: \(isMonitoring)\n"
        
        if let decision = lastDecision {
            info += "\nLast Decision:\n"
            info += "  Should Notify: \(decision.shouldNotify)\n"
            info += "  Reason: \(decision.reason)\n"
            
            if let eta = decision.estimatedTimeToArrival {
                info += "  ETA: \(Int(eta / 60))min\n"
            }
            
            if let distance = decision.distanceToTarget {
                info += "  Distance: \(Int(distance))m\n"
            }
        }
        
        if let deviation = currentDeviation {
            info += "\nDeviation: \(deviation.displayText)\n"
        }
        
        return info
    }
}

// MARK: - Preview

#if DEBUG
struct HybridStatusView_Previews: PreviewProvider {
    static var previews: some View {
        HybridStatusView()
            .environmentObject(LocationManager())
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.backgroundPrimary)
    }
}
#endif
