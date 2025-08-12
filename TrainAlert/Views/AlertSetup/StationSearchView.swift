//
//  StationSearchView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import MapKit
import SwiftUI

struct StationSearchView: View {
    // MARK: - Properties
    
    @StateObject private var stationAPI = StationAPIClient()
    @EnvironmentObject var locationManager: LocationManager
    @ObservedObject var setupData: AlertSetupData
    
    let onStationSelected: (StationModel) -> Void
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var searchResults: [StationModel] = []
    @State private var nearbyStations: [StationModel] = []
    @State private var favoriteStations: [StationModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showMap = false
    @State private var selectedSegment = 0 // 0: 近くの駅, 1: 検索結果, 2: お気に入り
    @State private var searchTask: Task<Void, Never>?
    
    private let segments = ["近くの駅", "検索", "お気に入り"]
    
    var body: some View {
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("マップ") {
                    showMap = true
                }
                .foregroundColor(.trainSoftBlue)
            }
        }
        .onAppear {
            loadInitialData()
        }
        .onChange(of: searchText) { newValue in
            performSearch(query: newValue)
        }
        .sheet(isPresented: $showMap) {
            StationMapView(
                stations: currentStations
            )                { station in
                    selectStation(station)
                    showMap = false
                }
        }
    }
    
    // MARK: - Views
    
    private var searchBar: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(UIColor.systemGray))
                    .frame(width: 20, height: 20)
                
                TextField("駅名で検索", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(UIColor.systemGray))
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            if isLoading {
                Text("検索中...")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
        }
    }
    
    private var segmentControl: some View {
        Picker("表示切替", selection: $selectedSegment) {
            ForEach(0..<segments.count, id: \.self) { index in
                Text(segments[index])
                    .tag(index)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var content: some View {
        Group {
            if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else {
                stationList
            }
        }
    }
    
    private var stationList: some View {
        Group {
            if currentStations.isEmpty {
                Text("検索結果がありません")
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                List(currentStations, id: \.id) { station in
                    StationRowView(
                        station: station,
                        isSelected: setupData.selectedStation?.id == station.id
                    ) {
                        selectStation(station)
                    }
                    .listRowBackground(Color.backgroundPrimary)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(PlainListStyle())
                .background(Color.backgroundPrimary)
            }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            let isOffline = message.contains("オフライン")
            let isLocation = message.contains("位置情報")
            
            Image(systemName: isOffline ? "wifi.slash" : (isLocation ? "location.slash" : "exclamationmark.triangle"))
                .font(.system(size: 50))
                .foregroundColor(isLocation ? .textSecondary : .error)
            
            Text(message)
                .font(.body)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if isOffline {
                Text("インターネット接続を確認してください")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if !isLocation {
                PrimaryButton("再試行") {
                    loadInitialData()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
    
    // MARK: - Computed Properties
    
    private var currentStations: [StationModel] {
        switch selectedSegment {
        case 0:
            return nearbyStations
        case 1:
            return searchResults
        case 2:
            return favoriteStations
        default:
            return []
        }
    }
    
    // MARK: - Methods
    
    private func loadInitialData() {
        loadNearbyStations()
        loadFavoriteStations()
    }
    
    private func loadNearbyStations() {
        guard let location = locationManager.location else {
            // Request location permission instead of using default
            requestLocationPermission()
            return
        }
        
        loadStationsForLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }
    
    private func loadStationsForLocation(latitude: Double, longitude: Double) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let stations = try await stationAPI.getNearbyStations(
                    latitude: latitude,
                    longitude: longitude
                )
                
                await MainActor.run {
                    self.nearbyStations = stations
                    self.isLoading = false
                    // Loaded nearby stations
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.nearbyStations = []
                }
            }
        }
    }
    
    private func requestLocationPermission() {
        locationManager.requestAuthorization()
        
        // Monitor location authorization changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if locationManager.location != nil {
                loadNearbyStations()
            } else {
                // If still no location, show all stations
                self.showAllStations()
            }
        }
    }
    
    private func showAllStations() {
        // 位置情報が利用できない場合は、メッセージを表示
        errorMessage = "位置情報が利用できません。駅名で検索してください。"
        isLoading = false
        nearbyStations = []
    }
    
    private func performSearch(query: String) {
        // 入力があったら検索タブに自動切り替え
        if !query.isEmpty && selectedSegment != 1 {
            withAnimation {
                selectedSegment = 1
            }
        }
        
        // キャンセル処理
        searchTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // デバウンス処理（0.5秒待機）
        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                
                // タスクがキャンセルされていないかチェック
                guard !Task.isCancelled else { return }
                
                // Use current location if available, otherwise search without location
                let location = locationManager.location?.coordinate
                let stations = try await stationAPI.searchStations(
                    query: trimmedQuery,
                    near: location
                )
                
                // タスクがキャンセルされていないかチェック
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = stations
                    self.isLoading = false
                }
            } catch {
                // タスクがキャンセルされた場合は何もしない
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.searchResults = []
                    self.isLoading = false
                    if !(error is CancellationError) {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    private func loadFavoriteStations() {
        // TODO: Implement favorite stations loading from UserDefaults or Core Data
        favoriteStations = []
    }
    
    private func selectStation(_ station: StationModel) {
        setupData.selectedStation = station
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Station selected
        onStationSelected(station)
    }
}

// MARK: - Station Row View

struct StationRowView: View {
    let station: StationModel
    let isSelected: Bool
    let onTap: () -> Void
    
    // Line color mapping
    private func lineColor(for line: String) -> Color {
        // JR Lines
        if line.contains("JR") || line.contains("山手") {
            return Color(red: 0.0, green: 0.7, blue: 0.3)
        }
        // Tokyo Metro
        if line.contains("メトロ") || line.contains("丸ノ内") || line.contains("銀座") || line.contains("日比谷") {
            return Color(red: 0.0, green: 0.4, blue: 0.8)
        }
        // Toei
        if line.contains("都営") || line.contains("大江戸") || line.contains("新宿線") {
            return Color(red: 0.8, green: 0.0, blue: 0.4)
        }
        // Private railways
        if line.contains("京王") || line.contains("小田急") || line.contains("東急") || line.contains("京急") {
            return Color(red: 0.5, green: 0.0, blue: 0.5)
        }
        // Default
        return Color.gray
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Station Icon
                Image(systemName: "train.side.front.car")
                    .font(.title2)
                    .foregroundColor(.trainSoftBlue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Station Name (Above Lines)
                    Text(station.name)
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    // Lines (Below Station Name)
                    if !station.lines.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(station.lines, id: \.self) { line in
                                    Text(line)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(lineColor(for: line))
                                        )
                                }
                            }
                        }
                        .frame(height: 20)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.success)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.backgroundCard : Color.backgroundPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Station Map View

struct StationMapView: View {
    let stations: [StationModel]
    let onStationSelected: (StationModel) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671), // Tokyo
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: stations) { station in
                MapAnnotation(coordinate: station.coordinate) {
                    Button(action: {
                        onStationSelected(station)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "train.side.front.car")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color.trainSoftBlue)
                                .clipShape(Circle())
                            
                            Text(station.name)
                                .font(.caption)
                                .foregroundColor(.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .onAppear {
                if let firstStation = stations.first {
                    region = MKCoordinateRegion(
                        center: firstStation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                }
            }
            .navigationTitle("マップから選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct StationSearchView_Previews: PreviewProvider {
    static var previews: some View {
        StationSearchView(
            setupData: AlertSetupData()
        )            { _ in }
        .environmentObject(LocationManager())
        .preferredColorScheme(.dark)
    }
}
#endif
