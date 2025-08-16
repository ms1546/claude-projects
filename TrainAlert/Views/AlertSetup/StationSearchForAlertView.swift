//
//  StationSearchForAlertView.swift
//  TrainAlert
//
//  駅検索してアラート設定する画面
//

import CoreData
import CoreLocation
import MapKit
import SwiftUI

struct StationSearchForAlertView: View {
    // MARK: - Properties
    
    @StateObject private var stationAPI = StationAPIClient()
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    var onAlertCreated: (() -> Void)?
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var searchResults: [StationModel] = []
    @State private var nearbyStations: [StationModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSegment = 0 // 0: 近くの駅, 1: 検索
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedStation: Station?
    @State private var navigationPath = NavigationPath()
    
    private let segments = ["近くの駅", "検索"]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Segment Control
                segmentControl
                
                // Content
                content
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("駅を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadNearbyStations()
            }
            .navigationDestination(for: Station.self) { station in
                StationAlertSetupView(station: station) {
                    // アラート作成完了時の処理
                    dismiss()
                    onAlertCreated?()
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            
            TextField("駅名を検索", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    performSearch()
                }
                .onChange(of: searchText) { newValue in
                    // Cancel previous search
                    searchTask?.cancel()
                    
                    if newValue.isEmpty {
                        searchResults = []
                        return
                    }
                    
                    // Debounce search - wait 0.5 seconds before searching
                    searchTask = Task {
                        do {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                            await performSearch()
                        } catch {
                            // Task was cancelled
                        }
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Segment Control
    
    private var segmentControl: some View {
        Picker("", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { index in
                Text(segments[index]).tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Content
    
    private var content: some View {
        Group {
            if isLoading && nearbyStations.isEmpty && searchResults.isEmpty {
                loadingView
            } else if let error = errorMessage {
                errorView(error: error)
            } else {
                switch selectedSegment {
                case 0:
                    nearbyStationsView
                case 1:
                    searchResultsView
                default:
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("読み込み中...")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.trainCharcoalGray)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("再試行") {
                Task {
                    await loadNearbyStations()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var nearbyStationsView: some View {
        ScrollView {
            if nearbyStations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.trainCharcoalGray)
                    
                    Text("近くの駅が見つかりません")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    Text("位置情報の許可を確認してください")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    
                    if locationManager.authorizationStatus == .denied ||
                       locationManager.authorizationStatus == .restricted {
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("設定を開く")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.trainSoftBlue)
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(nearbyStations) { station in
                        stationRow(station)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.trainCharcoalGray)
                    
                    Text("駅名を入力してください")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                    
                    Text("検索中...")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.trainCharcoalGray)
                    
                    Text("「\(searchText)」に一致する駅が見つかりません")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    if errorMessage != nil {
                        Text(errorMessage!)
                            .font(.caption)
                            .foregroundColor(.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { station in
                        stationRow(station)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func stationRow(_ stationModel: StationModel) -> some View {
        Button(action: {
            selectStation(stationModel)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "tram.fill")
                    .font(.title3)
                    .foregroundColor(.trainSoftBlue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(stationModel.name)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    if !stationModel.lines.isEmpty {
                        Text(stationModel.lines.joined(separator: " • "))
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Calculate distance if we have user location
                if selectedSegment == 0, let userLocation = locationManager.location {
                    let stationLocation = CLLocation(latitude: stationModel.latitude, longitude: stationModel.longitude)
                    let distance = userLocation.distance(from: stationLocation)
                    Text(formatDistance(distance))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Methods
    
    private func loadNearbyStations() async {
        // First check location authorization
        let authStatus = locationManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            // Request permission
            locationManager.requestAuthorization()
            // Wait a bit for permission to be granted
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        case .denied, .restricted:
            errorMessage = "位置情報の使用が許可されていません。設定から許可してください。"
            isLoading = false
            return
        default:
            break
        }
        
        // Start updating location if needed
        if locationManager.location == nil {
            locationManager.startUpdatingLocation()
            // Wait a bit for location to be available
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        guard let location = locationManager.location else {
            errorMessage = "位置情報を取得できません。しばらくお待ちください。"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            nearbyStations = try await stationAPI.getNearbyStations(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 2_000
            )
        } catch {
            errorMessage = "駅情報の取得に失敗しました"
        }
        
        isLoading = false
    }
    
    @MainActor
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        selectedSegment = 1 // 検索タブに切り替え
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // HeartRails APIで高速検索
                let heartRailsStations = try await HeartRailsAPIClient.shared.searchStations(by: searchText)
                
                // HeartRailsStationをStationModelに変換
                searchResults = heartRailsStations.map { hrStation in
                    StationModel(
                        id: "\(hrStation.name)_\(hrStation.line)",
                        name: hrStation.name,
                        latitude: hrStation.y,
                        longitude: hrStation.x,
                        lines: [hrStation.line]
                    )
                }
                
                // 結果が見つからない場合
                if searchResults.isEmpty {
                    errorMessage = "駅が見つかりませんでした"
                }
            } catch {
                errorMessage = "検索に失敗しました"
                searchResults = []
            }
            
            isLoading = false
        }
    }
    
    private func selectStation(_ stationModel: StationModel) {
        // Core Dataで既存の駅を検索または新規作成
        let fetchRequest = Station.fetchRequest(stationId: stationModel.id)
        let existingStation = try? viewContext.fetch(fetchRequest).first
        
        let station: Station
        if let existing = existingStation {
            station = existing
        } else {
            let newStation = Station(context: viewContext)
            newStation.stationId = stationModel.id
            newStation.name = stationModel.name
            newStation.latitude = stationModel.latitude
            newStation.longitude = stationModel.longitude
            newStation.lines = stationModel.lines
            newStation.isFavorite = false
            newStation.createdAt = Date()
            
            do {
                try viewContext.save()
                station = newStation
            } catch {
                print("Failed to save station: \(error)")
                return
            }
        }
        
        selectedStation = station
        // Navigate to alert setup
        navigationPath.append(station)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1_000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1_000)
        }
    }
}

// MARK: - Preview

struct StationSearchForAlertView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StationSearchForAlertView()
                .environmentObject(LocationManager())
        }
    }
}
