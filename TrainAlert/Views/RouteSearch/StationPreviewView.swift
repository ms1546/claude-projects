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
            } else if stopStations.isEmpty {
                Text("DEBUG: 停車駅データがありません")
                    .foregroundColor(.red)
                    .padding()
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
            let stations = createStationsFromRoute()
            
            await MainActor.run {
                self.stopStations = stations
                self.isLoading = false
                updateNotificationStation()
            }
        }
    }
    
    private func updateNotificationStation() {
        guard !stopStations.isEmpty else { return }
        
        print("=== Debug Info ===")
        print("Total stations: \(stopStations.count)")
        print("Stations before arrival setting: \(notificationStations)")
        for (index, station) in stopStations.enumerated() {
            print("[\(index)] \(station.stationName)")
        }
        
        // 実際の停車駅から通知駅を計算
        notificationStation = calculator.getNotificationStation(
            stopStations: stopStations,
            stationsBeforeArrival: notificationStations
        )
        
        if let notification = notificationStation {
            print("Notification station: \(notification.station.stationName)")
        }
        print("=================")
    }
    
    // MARK: - Route Data Processing
    
    private func createStationsFromRoute() -> [StationCountCalculator.StopStation] {
        var stations: [StationCountCalculator.StopStation] = []
        var addedStations = Set<String>() // 重複チェック用
        
        // セクションが空の場合は、出発駅と到着駅のみを追加
        if route.sections.isEmpty {
            stations.append(StationCountCalculator.StopStation(
                stationId: "station_\(route.departureStation)",
                stationName: route.departureStation,
                arrivalTime: nil,
                departureTime: formatTime(route.departureTime),
                isPassingStation: false
            ))
            stations.append(StationCountCalculator.StopStation(
                stationId: "station_\(route.arrivalStation)",
                stationName: route.arrivalStation,
                arrivalTime: formatTime(route.arrivalTime),
                departureTime: nil,
                isPassingStation: false
            ))
            return stations
        }
        
        // 最初の駅（出発駅）を追加
        if !route.departureStation.isEmpty {
            stations.append(StationCountCalculator.StopStation(
                stationId: "station_\(route.departureStation)",
                stationName: route.departureStation,
                arrivalTime: nil,
                departureTime: formatTime(route.departureTime),
                isPassingStation: false
            ))
            addedStations.insert(route.departureStation)
        }
        
        // 各セクションから中間駅を抽出
        for (index, section) in route.sections.enumerated() {
            // セクションの出発駅を追加（最初のセクションは既に追加済みなのでスキップ）
            if index > 0 && !addedStations.contains(section.departureStation) {
                stations.append(StationCountCalculator.StopStation(
                    stationId: "station_\(section.departureStation)",
                    stationName: section.departureStation,
                    arrivalTime: formatTime(section.departureTime),
                    departureTime: formatTime(section.departureTime),
                    isPassingStation: false
                ))
                addedStations.insert(section.departureStation)
            }
            
            // セクションの到着駅を追加
            if !addedStations.contains(section.arrivalStation) {
                let isLastSection = index == route.sections.count - 1
                stations.append(StationCountCalculator.StopStation(
                    stationId: "station_\(section.arrivalStation)",
                    stationName: section.arrivalStation,
                    arrivalTime: formatTime(section.arrivalTime),
                    departureTime: isLastSection ? nil : formatTime(section.arrivalTime),
                    isPassingStation: false
                ))
                addedStations.insert(section.arrivalStation)
            }
        }
        
        // 最終駅が含まれていない場合は追加
        if !addedStations.contains(route.arrivalStation) {
            stations.append(StationCountCalculator.StopStation(
                stationId: "station_\(route.arrivalStation)",
                stationName: route.arrivalStation,
                arrivalTime: formatTime(route.arrivalTime),
                departureTime: nil,
                isPassingStation: false
            ))
        }
        
        return stations
    }
}
