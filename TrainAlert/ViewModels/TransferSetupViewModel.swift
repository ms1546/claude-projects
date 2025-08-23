//
//  TransferSetupViewModel.swift
//  TrainAlert
//
//  乗り換え経路設定のViewModel
//

import Combine
import CoreData
import Foundation
import SwiftUI

@MainActor
class TransferSetupViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var sections: [TransferSection] = []
    @Published var departureTime = Date()
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var canCreateAlert: Bool {
        // 少なくとも1つの完全な区間があること
        sections.contains { section in
            section.departureStation != nil && section.arrivalStation != nil
        }
    }
    
    var departureTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: departureTime)
    }
    
    var totalDurationString: String? {
        guard let route = createTransferRoute(),
              !route.sections.isEmpty else { return nil }
        
        let totalMinutes = Int(route.totalDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    // MARK: - Section Management
    
    func addSection() {
        let newSection = TransferSection()
        
        // 前の区間の到着駅を次の区間の出発駅に設定
        if let lastSection = sections.last,
           let arrivalStation = lastSection.arrivalStation {
            newSection.departureStation = arrivalStation
        }
        
        sections.append(newSection)
    }
    
    func removeSection(at index: Int) {
        guard sections.indices.contains(index) else { return }
        sections.remove(at: index)
        
        // 区間を削除した後、連続性を保つ
        updateSectionContinuity()
    }
    
    func updateStation(at index: Int, station: String) {
        guard sections.indices.contains(index) else { return }
        
        // 現在編集中の区間の駅を更新
        if sections[index].departureStation == nil {
            sections[index].departureStation = station
        } else {
            sections[index].arrivalStation = station
            
            // 次の区間の出発駅も更新
            if index + 1 < sections.count {
                sections[index + 1].departureStation = station
            }
        }
        
        // 時刻表検索を実行（仮実装）
        updateSectionTimes(at: index)
    }
    
    // MARK: - Transfer Station Management
    
    func getTransferStation(between fromIndex: Int, and toIndex: Int) -> String? {
        guard sections.indices.contains(fromIndex),
              sections.indices.contains(toIndex) else { return nil }
        
        // 前の区間の到着駅と次の区間の出発駅が同じ場合、それが乗り換え駅
        if sections[fromIndex].arrivalStation == sections[toIndex].departureStation {
            return sections[fromIndex].arrivalStation
        }
        
        return nil
    }
    
    // MARK: - Time Management
    
    func updateDepartureTime() {
        // 出発時刻が更新されたら、各区間の時刻を再計算
        updateAllSectionTimes()
    }
    
    private func updateSectionTimes(at index: Int) {
        // 実際にはAPIを呼び出して時刻表を取得
        // ここでは仮の実装
        guard sections.indices.contains(index) else { return }
        
        let currentTime = departureTime
        
        for i in 0..<sections.count {
            if i == 0 {
                sections[i].departureTime = currentTime
                sections[i].arrivalTime = currentTime.addingTimeInterval(20 * 60) // 仮に20分
            } else {
                // 乗り換え時間を5分と仮定
                sections[i].departureTime = sections[i - 1].arrivalTime?.addingTimeInterval(5 * 60)
                sections[i].arrivalTime = sections[i].departureTime?.addingTimeInterval(15 * 60) // 仮に15分
            }
        }
    }
    
    private func updateAllSectionTimes() {
        for index in sections.indices {
            updateSectionTimes(at: index)
        }
    }
    
    // MARK: - Section Continuity
    
    private func updateSectionContinuity() {
        // 区間の連続性を保つ
        for i in 1..<sections.count {
            if let previousArrival = sections[i - 1].arrivalStation {
                sections[i].departureStation = previousArrival
            }
        }
    }
    
    // MARK: - Transfer Route Creation
    
    func createTransferRoute() -> TransferRoute? {
        let validSections = sections.compactMap { section -> RouteSection? in
            guard let departure = section.departureStation,
                  let arrival = section.arrivalStation,
                  let depTime = section.departureTime,
                  let arrTime = section.arrivalTime else { return nil }
            
            return RouteSection(
                departureStation: departure,
                arrivalStation: arrival,
                departureTime: depTime,
                arrivalTime: arrTime,
                trainType: section.trainType,
                trainNumber: section.trainNumber,
                railway: section.railway ?? "未設定"
            )
        }
        
        guard !validSections.isEmpty else { return nil }
        
        // 乗り換え駅情報を生成
        var transferStations: [TransferStation] = []
        
        for i in 0..<(validSections.count - 1) {
            let currentSection = validSections[i]
            let nextSection = validSections[i + 1]
            
            if currentSection.arrivalStation == nextSection.departureStation {
                let transfer = TransferStation(
                    stationName: currentSection.arrivalStation,
                    fromLine: currentSection.railway,
                    toLine: nextSection.railway,
                    arrivalTime: currentSection.arrivalTime,
                    departureTime: nextSection.departureTime
                )
                transferStations.append(transfer)
            }
        }
        
        return TransferRoute(
            sections: validSections,
            transferStations: transferStations
        )
    }
    
    // MARK: - Alert Creation
    
    func createTransferAlert(
        notificationTime: Int16,
        characterStyle: CharacterStyle
    ) async throws {
        guard let route = createTransferRoute() else {
            throw TransferAlertError.invalidRoute
        }
        
        isLoading = true
        
        do {
            try await coreDataManager.performBackgroundTask { context in
                let alert = TransferAlert(context: context)
                alert.transferAlertId = UUID()
                alert.departureStation = route.departureStation
                alert.arrivalStation = route.arrivalStation
                alert.departureTime = route.departureTime
                alert.arrivalTime = route.arrivalTime
                alert.totalDuration = route.totalDuration
                alert.transferCountValue = Int16(route.transferCount)
                alert.transferRoute = route
                alert.notificationTime = notificationTime
                alert.characterStyle = characterStyle.rawValue
                alert.isActive = true
                alert.createdAt = Date()
                
                try context.save()
            }
            
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "アラートの作成に失敗しました"
            showError = true
            throw error
        }
    }
}

// MARK: - Transfer Section Model

class TransferSection: ObservableObject, Identifiable {
    let id = UUID()
    @Published var departureStation: String?
    @Published var arrivalStation: String?
    @Published var departureTime: Date?
    @Published var arrivalTime: Date?
    @Published var trainType: String?
    @Published var trainNumber: String?
    @Published var railway: String?
}

// MARK: - Errors

enum TransferAlertError: LocalizedError {
    case invalidRoute
    case missingStations
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidRoute:
            return "有効な経路を作成できませんでした"
        case .missingStations:
            return "出発駅と到着駅を設定してください"
        case .saveFailed:
            return "保存に失敗しました"
        }
    }
}

