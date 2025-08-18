//
//  ArrivalStationSearchView.swift
//  TrainAlert
//
//  Created by Claude Code on 2025/08/18.
//

import SwiftUI

struct ArrivalStationSearchView: View {
    let departureStation: ODPTStation
    let train: ODPTTrainTimetableObject
    let railway: String
    let direction: String?
    let onSelect: (ODPTStation, Date) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var stations: [ODPTStation] = []
    @State private var estimatedTimes: [String: Date] = [:]
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingIndicator(text: "到着駅を取得中...")
                } else if stations.isEmpty {
                    emptyStateView
                } else {
                    stationList
                }
            }
            .navigationTitle("到着駅を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(Color.trainSoftBlue)
                }
            }
            .onAppear {
                loadPossibleArrivalStations()
            }
            .onChange(of: direction) { _ in
                isLoading = true
                stations = []
                estimatedTimes = [:]
                loadPossibleArrivalStations()
            }
        }
    }
    
    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(stations, id: \.sameAs) { station in
                    Button(action: {
                        if let arrivalTime = estimatedTimes[station.sameAs] {
                            onSelect(station, arrivalTime)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.stationTitle?.ja ?? station.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.textPrimary)
                                
                                if let time = estimatedTimes[station.sameAs] {
                                    Text("到着予定: \(formatTime(time))")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(Color.warmOrange)
            
            Text("到着駅情報を取得できませんでした")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            Text("ネットワーク接続を確認するか、\nしばらく経ってから再度お試しください")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { dismiss() }) {
                Text("閉じる")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.trainSoftBlue)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadPossibleArrivalStations() {
        Task {
            do {
                let apiClient = ODPTAPIClient.shared
                
                // 路線の全駅を順序付きで取得
                let allStationsOnLine = try await apiClient.getStationsOnRailway(railwayId: railway)
                
                if allStationsOnLine.isEmpty {
                    throw ODPTAPIError.invalidResponse
                }
                
                // 出発駅のインデックスを見つける
                let departureIndex = allStationsOnLine.firstIndex { station in
                    station.sameAs == departureStation.sameAs
                } ?? -1
                
                // 到着可能駅を取得
                let arrivalStations = getPossibleArrivalStations(
                    allStations: allStationsOnLine,
                    departureIndex: departureIndex
                )
                
                // 到着時刻を推定
                let estimatedTimes = estimateArrivalTimes(
                    for: arrivalStations,
                    baseTime: parseTime(train.departureTime) ?? Date()
                )
                
                await MainActor.run {
                    self.stations = arrivalStations
                    self.estimatedTimes = estimatedTimes
                    self.isLoading = false
                }
            } catch {
                // APIエラー時のフォールバック
                await MainActor.run {
                    self.isLoading = false
                    self.stations = []
                }
            }
        }
    }
    
    // MARK: - Direction Determination
    
    private func determineDirection(
        from directionString: String,
        allStations: [ODPTStation],
        departureIndex: Int
    ) -> Bool {
        // 方向文字列から終点駅名または方向を抽出
        let directionComponents = directionString.split(separator: ":").map { String($0) }
        let directionValue = directionComponents.last ?? ""
        
        // 一般的な方向名かチェック
        let generalDirections = ["Northbound", "Southbound", "Eastbound", "Westbound",
                               "Inbound", "Outbound", "Clockwise", "Counterclockwise"]
        let isGeneralDirection = generalDirections.contains(directionValue)
        
        if isGeneralDirection {
            return determineDirectionFromGeneralName(directionValue)
        } else {
            return determineDirectionFromStationName(
                directionValue: directionValue,
                allStations: allStations,
                departureIndex: departureIndex
            )
        }
    }
    
    private func determineDirectionFromGeneralName(_ directionValue: String) -> Bool {
        switch directionValue.lowercased() {
        case "northbound", "eastbound", "outbound", "clockwise":
            return true
        case "southbound", "westbound", "inbound", "counterclockwise":
            return false
        default:
            return true // デフォルトは順方向
        }
    }
    
    private func determineDirectionFromStationName(
        directionValue: String,
        allStations: [ODPTStation],
        departureIndex: Int
    ) -> Bool {
        let directionStationName = directionValue.split(separator: ".").last.map { String($0) } ?? directionValue
        let normalizedDirectionName = normalizeStationName(directionStationName)
        
        // 路線内の全駅をチェックして方向を判定
        if let directionStationIndex = findStationIndex(
            matching: directionStationName,
            normalizedName: normalizedDirectionName,
            in: allStations
        ) {
            return directionStationIndex > departureIndex
        }
        
        // 方向駅が見つからない場合は終点駅でチェック
        return checkDirectionByTerminalStations(
            directionStationName: directionStationName,
            normalizedDirectionName: normalizedDirectionName,
            allStations: allStations
        )
    }
    
    private func findStationIndex(
        matching stationName: String,
        normalizedName: String,
        in stations: [ODPTStation]
    ) -> Int? {
        for (index, station) in stations.enumerated() {
            let stationEnName = normalizeStationName(station.stationTitle?.en ?? "")
            let stationJaName = station.stationTitle?.ja ?? ""
            let stationTitle = normalizeStationName(station.title)
            
            if stationEnName.contains(normalizedName) ||
               stationJaName.contains(stationName) ||
               stationTitle.contains(normalizedName) {
                return index
            }
        }
        return nil
    }
    
    private func checkDirectionByTerminalStations(
        directionStationName: String,
        normalizedDirectionName: String,
        allStations: [ODPTStation]
    ) -> Bool {
        // 最初の駅をチェック
        if let first = allStations.first {
            let firstEnName = normalizeStationName(first.stationTitle?.en ?? "")
            let firstJaName = first.stationTitle?.ja ?? ""
            if firstEnName.contains(normalizedDirectionName) ||
               firstJaName.contains(directionStationName) {
                return false // 最初の駅方向なら逆方向
            }
        }
        
        // 最後の駅をチェック
        if let last = allStations.last {
            let lastEnName = normalizeStationName(last.stationTitle?.en ?? "")
            let lastJaName = last.stationTitle?.ja ?? ""
            if lastEnName.contains(normalizedDirectionName) ||
               lastJaName.contains(directionStationName) {
                return true // 最後の駅方向なら順方向
            }
        }
        
        return true // デフォルトは順方向
    }
    
    private func normalizeStationName(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "〈", with: "")
            .replacingOccurrences(of: "〉", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
    }
    
    // MARK: - Arrival Stations
    
    private func getPossibleArrivalStations(
        allStations: [ODPTStation],
        departureIndex: Int
    ) -> [ODPTStation] {
        guard departureIndex >= 0 else {
            // 出発駅が見つからない場合は全駅（出発駅以外）
            return allStations.filter { $0.sameAs != departureStation.sameAs }
        }
        
        if let dir = direction {
            let isForward = determineDirection(
                from: dir,
                allStations: allStations,
                departureIndex: departureIndex
            )
            
            return getStationsInDirection(
                allStations: allStations,
                departureIndex: departureIndex,
                isForward: isForward
            )
        } else {
            return getStationsByDestination(
                allStations: allStations,
                departureIndex: departureIndex
            )
        }
    }
    
    private func getStationsInDirection(
        allStations: [ODPTStation],
        departureIndex: Int,
        isForward: Bool
    ) -> [ODPTStation] {
        if isForward {
            // 順方向：出発駅より後の駅
            guard departureIndex < allStations.count - 1 else { return [] }
            return Array(allStations[(departureIndex + 1)...])
        } else {
            // 逆方向：出発駅より前の駅を逆順で
            guard departureIndex > 0 else { return [] }
            return Array(allStations[..<departureIndex]).reversed()
        }
    }
    
    private func getStationsByDestination(
        allStations: [ODPTStation],
        departureIndex: Int
    ) -> [ODPTStation] {
        let destinationName = train.destinationStationTitle?.ja ?? ""
        
        let destinationIndex = allStations.firstIndex { station in
            let stationName = station.stationTitle?.ja ?? station.title
            return destinationName.contains(stationName) || stationName == destinationName
        }
        
        if let destIndex = destinationIndex {
            if destIndex > departureIndex {
                // 行き先が後方：出発駅より後の駅
                return Array(allStations[(departureIndex + 1)...min(destIndex, allStations.count - 1)])
            } else if destIndex < departureIndex {
                // 行き先が前方：出発駅より前の駅
                return Array(allStations[max(0, destIndex)...(departureIndex - 1)]).reversed()
            }
        }
        
        // 行き先が不明な場合は出発駅以外の全駅
        return allStations.filter { $0.sameAs != departureStation.sameAs }
    }
    
    // MARK: - Arrival Time Estimation
    
    private func estimateArrivalTimes(
        for stations: [ODPTStation],
        baseTime: Date
    ) -> [String: Date] {
        var times: [String: Date] = [:]
        let minutesPerStation = railway.contains("TokyoMetro") ? 3 : 4 // メトロは3分、JRは4分
        
        for (index, station) in stations.enumerated() {
            let arrivalTime = baseTime.addingTimeInterval(
                TimeInterval((index + 1) * minutesPerStation * 60)
            )
            times[station.sameAs] = arrivalTime
        }
        
        return times
    }
    
    
    private func parseTime(_ timeString: String) -> Date? {
        // 時刻文字列から今日の日付でDateを作成
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }
        
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        dateComponents.second = 0
        
        return Calendar.current.date(from: dateComponents)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
}
