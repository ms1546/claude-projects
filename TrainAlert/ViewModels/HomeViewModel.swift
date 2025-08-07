//
//  HomeViewModel.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var isAlertActive = false
    @Published var selectedStation: Station?
    
    init() {
        // Initialize view model
    }
    
    func startAlert() {
        guard selectedStation != nil else { return }
        isAlertActive = true
    }
    
    func stopAlert() {
        isAlertActive = false
    }
}

