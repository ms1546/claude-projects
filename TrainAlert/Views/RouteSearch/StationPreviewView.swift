//
//  StationPreviewView.swift
//  TrainAlert
//
//  駅数ベース通知のプレビュー画面
//

import SwiftUI

struct StationPreviewView: View {
    let route: RouteSearchResult
    let notificationStations: Int
    @State private var stopStations: [StationCountCalculator.StopStation] = []
    @State private var notificationStation: StationCountCalculator.NotificationStation?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private let calculator = StationCountCalculator()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tram.fill")
                    .foregroundColor(Color.trainSoftBlue)
                    .font(.system(size: 18))
                Text("停車駅プレビュー")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .trainSoftBlue))
                    Text("停車駅情報を取得中...")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.vertical, 8)
            } else {
                // 路線図風の停車駅リスト
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(stopStations.enumerated()), id: \.offset) { index, station in
                            stationItem(
                                station: station,
                                index: index,
                                isNotificationStation: station.stationName == notificationStation?.station.stationName,
                                isArrivalStation: index == stopStations.count - 1
                            )
                        }
                    }
                }
                
                // 通知情報
                if let notification = notificationStation {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .font(.caption)
                                .foregroundColor(Color.trainSoftBlue)
                            Text("\(notification.station.stationName)駅で通知")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color.textPrimary)
                        }
                        
                        if let time = notification.estimatedTime {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(Color.textSecondary)
                                Text("通知予定時刻: \(formatTime(time))")
                                    .font(.caption)
                                    .foregroundColor(Color.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(20)
        .background(Color.backgroundCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal)
        .onAppear {
            loadStationData()
        }
        .onChange(of: notificationStations) { _ in
            updateNotificationStation()
        }
    }
    
    // MARK: - Station Item View
    
    private func stationItem(
        station: StationCountCalculator.StopStation,
        index: Int,
        isNotificationStation: Bool,
        isArrivalStation: Bool
    ) -> some View {
        HStack(spacing: 0) {
            // 駅マーカー
            VStack(spacing: 0) {
                Circle()
                    .fill(stationMarkerColor(
                        isNotification: isNotificationStation,
                        isArrival: isArrivalStation,
                        isPassing: station.isPassingStation
                    ))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.trainSoftBlue, lineWidth: 2)
                            .opacity(isNotificationStation ? 1 : 0)
                    )
                
                // 駅名
                VStack(spacing: 2) {
                    if isNotificationStation {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundColor(Color.trainSoftBlue)
                    }
                    
                    Text(station.stationName)
                        .font(.caption2)
                        .fontWeight(isNotificationStation || isArrivalStation ? .bold : .regular)
                        .foregroundColor(stationTextColor(
                            isNotification: isNotificationStation,
                            isArrival: isArrivalStation,
                            isPassing: station.isPassingStation
                        ))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                    
                    if let time = station.departureTime ?? station.arrivalTime {
                        Text(time)
                            .font(.system(size: 10))
                            .foregroundColor(Color.textSecondary)
                    }
                    
                    if station.isPassingStation {
                        Text("通過")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
                .padding(.top, 4)
            }
            
            // 接続線
            if index < stopStations.count - 1 {
                Rectangle()
                    .fill(Color.trainSoftBlue.opacity(0.5))
                    .frame(width: 30, height: 2)
                    .offset(y: -28)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func stationMarkerColor(isNotification: Bool, isArrival: Bool, isPassing: Bool) -> Color {
        if isNotification {
            return Color.trainSoftBlue
        } else if isArrival {
            return Color.red
        } else if isPassing {
            return Color.gray.opacity(0.3)
        } else {
            return Color.gray.opacity(0.6)
        }
    }
    
    private func stationTextColor(isNotification: Bool, isArrival: Bool, isPassing: Bool) -> Color {
        if isNotification || isArrival {
            return Color.textPrimary
        } else if isPassing {
            return Color.textSecondary.opacity(0.5)
        } else {
            return Color.textSecondary
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    
    // MARK: - Data Loading
    
    private func loadStationData() {
        Task {
            // 現在は列車番号が取得できないため、モックデータを使用
            // 実際の実装では route.trainNumber を使用
            let mockStations = createMockStations()
            
            await MainActor.run {
                self.stopStations = mockStations
                self.isLoading = false
                updateNotificationStation()
            }
        }
    }
    
    private func updateNotificationStation() {
        guard !stopStations.isEmpty else { return }
        
        notificationStation = calculator.calculateNotificationWithMockData(
            route: route,
            stationsBeforeArrival: notificationStations
        )
    }
    
    // MARK: - Mock Data
    
    private func createMockStations() -> [StationCountCalculator.StopStation] {
        // 実際のAPIが利用可能になるまでのモックデータ
        let stationNames = generateMockStationNames()
        var stations: [StationCountCalculator.StopStation] = []
        
        let startTime = route.departureTime
        let totalDuration = route.arrivalTime.timeIntervalSince(route.departureTime)
        let stationCount = stationNames.count
        let intervalPerStation = totalDuration / Double(stationCount - 1)
        
        for (index, name) in stationNames.enumerated() {
            let stationTime = startTime.addingTimeInterval(intervalPerStation * Double(index))
            let timeString = formatTime(stationTime)
            
            // ランダムに通過駅を設定（最初と最後以外）
            let isPassingStation = index != 0 && index != stationNames.count - 1 && index % 4 == 2
            
            stations.append(StationCountCalculator.StopStation(
                stationId: "mock.station.\(index)",
                stationName: name,
                arrivalTime: index == 0 ? nil : timeString,
                departureTime: index == stationNames.count - 1 ? nil : timeString,
                isPassingStation: isPassingStation
            ))
        }
        
        return stations
    }
    
    private func generateMockStationNames() -> [String] {
        // 出発駅から到着駅までの仮想的な駅名を生成
        var names: [String] = [route.departureStation]
        
        // 中間駅を追加（駅数に応じて調整）
        let intermediateStations = ["中央", "新町", "本町", "駅前", "公園前", "市役所前", "大学前", "病院前"]
        let stationCount = min(notificationStations + 3, 8) // 最大8駅
        
        for i in 0..<(stationCount - 2) {
            if i < intermediateStations.count {
                names.append(intermediateStations[i])
            }
        }
        
        names.append(route.arrivalStation)
        return names
    }
}
