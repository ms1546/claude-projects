//
//  RouteSearchView.swift
//  TrainAlert
//
//  経路検索画面
//

import CoreLocation
import SwiftUI

struct RouteSearchView: View {
    @StateObject private var viewModel = RouteSearchViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDatePicker = false
    @State private var showingFavoriteRoutes = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case departure
        case arrival
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 0) {
                    // 検索フォーム
                    searchForm
                        .padding()
                        .background(Color.backgroundSecondary)
                    
                    // 検索結果
                    if viewModel.isSearching {
                        LoadingIndicator(text: "経路を検索中...")
                            .frame(minHeight: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.backgroundPrimary)
                    } else if viewModel.searchResults.isEmpty {
                        emptyStateView
                            .frame(minHeight: 300)
                            .background(Color.backgroundPrimary)
                            .onAppear {
                                print("Empty state view appeared")
                            }
                    } else {
                        searchResultsContent
                            .background(Color.backgroundPrimary)
                            .onAppear {
                                print("Search results content appeared with \(viewModel.searchResults.count) results")
                            }
                    }
                }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationTitle("経路検索")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFavoriteRoutes = true }) {
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(Color.trainSoftBlue)
                    }
                }
            }
            .sheet(isPresented: $showingFavoriteRoutes) {
                FavoriteRoutesView()
            }
            .alert("エラー", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "不明なエラーが発生しました")
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseRouteSearch"))) { _ in
                dismiss()
            }
        }
    }
    
    // MARK: - Search Form
    
    private var searchForm: some View {
        VStack(spacing: 16) {
            // 出発駅
            VStack(alignment: .leading, spacing: 8) {
                Label("出発駅", systemImage: "location.circle")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .onTapGesture {
                        focusedField = .departure
                    }
                
                HStack {
                    if viewModel.selectedDepartureStation != nil {
                        // 選択された駅を表示
                        selectedStationView(
                            station: viewModel.selectedDepartureStation!
                        ) {
                                viewModel.departureStation = ""
                                viewModel.selectedDepartureStation = nil
                                focusedField = .departure
                        }
                    } else {
                        // 入力フィールド
                        TextField("駅名を入力", text: $viewModel.departureStation)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.backgroundCard)
                            .cornerRadius(8)
                            .foregroundColor(Color.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .departure)
                            .onTapGesture {
                                focusedField = .departure
                            }
                            .onSubmit {
                                viewModel.searchDepartureStation(viewModel.departureStation)
                                focusedField = .arrival
                            }
                            .onChange(of: viewModel.departureStation) { newValue in
                                viewModel.searchDepartureStation(newValue)
                            }
                    }
                    
                    Button(action: {
                        if locationManager.authorizationStatus == .notDetermined {
                            locationManager.requestAuthorization()
                        } else if let location = locationManager.currentLocation {
                            viewModel.setNearbyStation(for: .departure, location: location)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(Color.trainSoftBlue)
                    }
                    .disabled(locationManager.authorizationStatus == .denied || 
                             locationManager.authorizationStatus == .restricted)
                }
                
                if viewModel.isSearchingDepartureStation {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("駅を検索中...")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.vertical, 8)
                } else if !viewModel.departureStationSuggestions.isEmpty {
                    stationSuggestions(
                        stations: viewModel.departureStationSuggestions,
                        onSelect: viewModel.selectDepartureStation
                    )
                }
            }
            
            // 入れ替えボタン
            HStack {
                Spacer()
                Button(action: swapStations) {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.trainSoftBlue)
                }
                Spacer()
            }
            
            // 到着駅
            VStack(alignment: .leading, spacing: 8) {
                Label("到着駅", systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                
                HStack {
                    if viewModel.selectedArrivalStation != nil {
                        // 選択された駅を表示
                        selectedStationView(
                            station: viewModel.selectedArrivalStation!
                        ) {
                                viewModel.arrivalStation = ""
                                viewModel.selectedArrivalStation = nil
                                focusedField = .arrival
                        }
                    } else {
                        // 入力フィールド
                        TextField("駅名を入力", text: $viewModel.arrivalStation)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.backgroundCard)
                            .cornerRadius(8)
                            .foregroundColor(Color.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .arrival)
                            .onSubmit {
                                viewModel.searchArrivalStation(viewModel.arrivalStation)
                                focusedField = nil
                            }
                            .onChange(of: viewModel.arrivalStation) { newValue in
                                viewModel.searchArrivalStation(newValue)
                            }
                    }
                    
                    Button(action: {
                        if locationManager.authorizationStatus == .notDetermined {
                            locationManager.requestAuthorization()
                        } else if let location = locationManager.currentLocation {
                            viewModel.setNearbyStation(for: .arrival, location: location)
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .foregroundColor(Color.trainSoftBlue)
                    }
                    .disabled(locationManager.authorizationStatus == .denied || 
                             locationManager.authorizationStatus == .restricted)
                }
                
                if viewModel.isSearchingArrivalStation {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("駅を検索中...")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.vertical, 8)
                } else if !viewModel.arrivalStationSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        stationSuggestions(
                            stations: viewModel.arrivalStationSuggestions,
                            onSelect: viewModel.selectArrivalStation
                        )
                        
                        // 制約メッセージ表示
                        if let constraintMessage = viewModel.searchConstraintMessage {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                Text(constraintMessage)
                                    .font(.caption2)
                                    .foregroundColor(Color.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.opacity(0.2))
                            )
                        }
                    }
                }
            }
            
            // 出発時刻
            HStack {
                Label("出発時刻", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                
                Spacer()
                
                Button(action: { showingDatePicker.toggle() }) {
                    Text(viewModel.formattedDepartureTime)
                        .font(.headline)
                        .foregroundColor(Color.textPrimary)
                }
            }
            
            // 検索ボタン
            Button(action: viewModel.searchRoute) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text("経路を検索")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.trainSoftBlue,
                                    Color.trainSoftBlue.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(viewModel.canSearch && !viewModel.isSearching ? 1.0 : 0.5)
                )
                .shadow(color: Color.trainSoftBlue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(!viewModel.canSearch || viewModel.isSearching)
        }
        .sheet(isPresented: $showingDatePicker) {
            DateTimePickerView(
                selectedDateTime: $viewModel.departureTime,
                isPresented: $showingDatePicker
            )
        }
    }
    
    // MARK: - Station Suggestions
    
    private func stationSuggestions(
        stations: [ODPTStation],
        onSelect: @escaping (ODPTStation) -> Void
    ) -> some View {
        VStack(spacing: 6) {
            ForEach(stations, id: \.sameAs) { station in
                stationRow(station: station, onSelect: onSelect)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundCard)
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
        )
    }
    
    private func stationRow(station: ODPTStation, onSelect: @escaping (ODPTStation) -> Void) -> some View {
        Button(action: { onSelect(station) }) {
            HStack(spacing: 12) {
                lineColorIndicator(for: station.railway)
                stationInfo(station: station)
                Spacer()
                chevronIcon
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.trainLightGray.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func lineColorIndicator(for railway: String) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(getLineColor(for: railway))
            .frame(width: 4, height: 44)
    }
    
    private func stationInfo(station: ODPTStation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(station.stationTitle?.ja ?? station.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.textPrimary)
            
            railwayInfo(station: station)
        }
    }
    
    private func railwayInfo(station: ODPTStation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tram.fill")
                .font(.system(size: 11))
                .foregroundColor(Color.textSecondary)
            
            Text(station.railwayTitle?.ja ?? station.railway)
                .font(.system(size: 13))
                .foregroundColor(Color.textSecondary)
                .lineLimit(1)
            
            if let code = station.stationCode {
                Text("[\(code)]")
                    .font(.system(size: 11))
                    .foregroundColor(Color.textSecondary.opacity(0.6))
            }
        }
    }
    
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundColor(Color.textSecondary.opacity(0.6))
    }
    
    // MARK: - Selected Station View
    
    private func selectedStationView(station: ODPTStation, onClear: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 10) {
                // 路線カラー
                RoundedRectangle(cornerRadius: 2)
                    .fill(getLineColor(for: station.railway))
                    .frame(width: 3, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.stationTitle?.ja ?? station.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.textPrimary)
                    
                    Text(station.railwayTitle?.ja ?? station.railway)
                        .font(.system(size: 11))
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                // クリアボタン
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.backgroundCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(getLineColor(for: station.railway).opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: getLineColor(for: station.railway).opacity(0.2), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsContent: some View {
        VStack(spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.offset) { _, route in
                    NavigationLink(destination: TimetableAlertSetupView(route: route)) {
                        routeCard(route)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
    }
    
    private func routeCard(_ route: RouteSearchResult) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 出発時刻と駅
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(route.departureTime))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                    Text(route.departureStation)
                        .font(.system(size: 14))
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 矢印と所要時間
                VStack(spacing: 2) {
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.trainSoftBlue)
                    VStack(spacing: 2) {
                        Text("\(calculateDuration(from: route.departureTime, to: route.arrivalTime))分")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.trainSoftBlue)
                        if !route.isActualArrivalTime {
                            Text("目安")
                                .font(.system(size: 10))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // 到着時刻と駅
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTime(route.arrivalTime))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                    Text(route.arrivalStation)
                        .font(.system(size: 14))
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.backgroundCard)
            
            // 乗り換え詳細表示
            if route.transferCount > 0 && route.sections.count > 1 {
                VStack(spacing: 0) {
                    // 区間ごとの詳細
                    ForEach(Array(route.sections.enumerated()), id: \.offset) { index, section in
                        VStack(spacing: 0) {
                            // 区間情報
                            HStack {
                                // 路線カラー
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(getLineColor(for: section.railway ?? ""))
                                    .frame(width: 4, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(section.railway ?? "")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.textPrimary)
                                    
                                    HStack(spacing: 4) {
                                        Text(section.departureStation)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.textSecondary)
                                        
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9))
                                            .foregroundColor(Color.textSecondary)
                                        
                                        Text(section.arrivalStation)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // 時刻
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(formatTime(section.departureTime))-\(formatTime(section.arrivalTime))")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.textPrimary)
                                    
                                    Text("\(Int(section.arrivalTime.timeIntervalSince(section.departureTime) / 60))分")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.textSecondary)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            
                            // 乗り換え情報（最後の区間以外）
                            if index < route.sections.count - 1 {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.warmOrange)
                                    
                                    Text("\(section.arrivalStation)で乗り換え")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.warmOrange)
                                    
                                    Spacer()
                                    
                                    if index < route.sections.count - 1 {
                                        let transferTime = StationConnectionManager.shared.getTransferTime(for: section.arrivalStation)
                                        Text("乗換時間: 約\(transferTime)分")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color.textSecondary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.warmOrange.opacity(0.1))
                            }
                        }
                    }
                }
                .background(Color.backgroundSecondary)
            }
            
            // 下部の追加情報
            HStack {
                if route.trainType != nil {
                    Label(route.trainType!, systemImage: "tram.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                if route.transferCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.turn.up.right.circle")
                            .font(.system(size: 12))
                        Text("乗換\(route.transferCount)回")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color.warmOrange)
                }
                
                
                // お気に入り保存ボタン
                Button(action: {
                    let result = viewModel.toggleFavoriteRoute(route)
                    if let wasAdded = result {
                        if wasAdded {
                            // 保存成功のフィードバック
                            print("お気に入りに保存しました")
                        } else {
                            // 削除成功のフィードバック
                            print("お気に入りから削除しました")
                        }
                    } else {
                        // エラー（上限など）
                        print("お気に入りの操作に失敗しました")
                    }
                }) {
                    Image(systemName: viewModel.isFavoriteRoute(route) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.isFavoriteRoute(route) ? Color.warmOrange : Color.trainSoftBlue)
                }
                .disabled(!viewModel.isFavoriteRoute(route) && !viewModel.canAddFavorite)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.backgroundSecondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.trainLightGray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tram.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.trainLightGray)
            
            if viewModel.selectedDepartureStation != nil || viewModel.selectedArrivalStation != nil {
                Text("検索結果がありません")
                    .font(.headline)
                    .foregroundColor(Color.textSecondary)
                
                Text("正確な到着時刻が取得できる列車が見つかりませんでした")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("経路を検索してください")
                    .font(.headline)
                    .foregroundColor(Color.textSecondary)
                
                Text("出発駅と到着駅を入力して\n経路を検索できます")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func swapStations() {
        withAnimation {
            swap(&viewModel.departureStation, &viewModel.arrivalStation)
            swap(&viewModel.selectedDepartureStation, &viewModel.selectedArrivalStation)
            viewModel.departureStationSuggestions = []
            viewModel.arrivalStationSuggestions = []
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    
    private func calculateDuration(from: Date, to: Date) -> Int {
        let duration = to.timeIntervalSince(from)
        let minutes = Int(duration / 60)
        
        // 負の値の場合はデフォルト値を返す
        if minutes <= 0 {
            print("⚠️ Warning: Invalid duration detected. from: \(from), to: \(to), duration: \(minutes) minutes")
            return 30 // デフォルト値として30分を返す
        }
        
        return minutes
    }
    
    // MARK: - Helpers
    
    private func getLineColor(for railway: String) -> Color {
        let line = railway.lowercased()
        
        // JR線
        if line.contains("yamanote") || line.contains("山手") {
            return Color(red: 154 / 255, green: 205 / 255, blue: 50 / 255) // 黄緑
        } else if line.contains("chuo") || line.contains("中央") {
            return Color(red: 255 / 255, green: 100 / 255, blue: 0 / 255) // オレンジ
        } else if line.contains("keihin") || line.contains("京浜") {
            return Color(red: 0 / 255, green: 178 / 255, blue: 229 / 255) // 水色
        } else if line.contains("sobu") || line.contains("総武") {
            return Color(red: 255 / 255, green: 211 / 255, blue: 0 / 255) // 黄色
        } else if line.contains("saikyo") || line.contains("埼京") {
            return Color(red: 26 / 255, green: 173 / 255, blue: 98 / 255) // 緑
        }
        
        // 私鉄
        else if line.contains("tokyu") || line.contains("東急") {
            return Color(red: 238 / 255, green: 51 / 255, blue: 78 / 255) // 赤
        } else if line.contains("keio") || line.contains("京王") {
            return Color(red: 221 / 255, green: 0 / 255, blue: 119 / 255) // ピンク
        } else if line.contains("odakyu") || line.contains("小田急") {
            return Color(red: 0 / 255, green: 138 / 255, blue: 206 / 255) // 青
        } else if line.contains("seibu") || line.contains("西武") {
            return Color(red: 0 / 255, green: 128 / 255, blue: 255 / 255) // 青
        } else if line.contains("tobu") || line.contains("東武") {
            return Color(red: 0 / 255, green: 102 / 255, blue: 204 / 255) // 青
        }
        
        // 地下鉄
        else if line.contains("ginza") || line.contains("銀座") {
            return Color(red: 255 / 255, green: 128 / 255, blue: 0 / 255) // オレンジ
        } else if line.contains("marunouchi") || line.contains("丸ノ内") {
            return Color(red: 237 / 255, green: 27 / 255, blue: 36 / 255) // 赤
        } else if line.contains("hibiya") || line.contains("日比谷") {
            return Color(red: 181 / 255, green: 181 / 255, blue: 181 / 255) // 銀
        } else if line.contains("tozai") || line.contains("東西") {
            return Color(red: 0 / 255, green: 183 / 255, blue: 238 / 255) // 水色
        }
        
        // デフォルト
        else {
            return Color(red: 128 / 255, green: 128 / 255, blue: 128 / 255) // グレー
        }
    }
}

// MARK: - Preview

struct RouteSearchView_Previews: PreviewProvider {
    static var previews: some View {
        RouteSearchView()
            .environmentObject(LocationManager())
    }
}
