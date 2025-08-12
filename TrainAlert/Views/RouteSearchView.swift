//
//  RouteSearchView.swift
//  TrainAlert
//
//  経路検索画面
//

import SwiftUI

struct RouteSearchView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = RouteSearchViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    
    // MARK: - State
    @State private var departureStation = ""
    @State private var arrivalStation = ""
    @State private var selectedDate = Date()
    @State private var isSearchingDeparture = false
    @State private var isSearchingArrival = false
    @State private var showingDatePicker = false
    @State private var searchType: SearchType = .departure
    @FocusState private var focusedField: Field?
    
    // Callback
    let onRouteSelected: (RouteSearchResult) -> Void
    
    enum SearchType {
        case departure
        case arrival
    }
    
    enum Field {
        case departure
        case arrival
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Station Input Section
                    VStack(spacing: 16) {
                        // 出発駅
                        VStack(alignment: .leading, spacing: 8) {
                            Label("出発駅", systemImage: "circle")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            
                            HStack {
                                TextField("駅名を入力", text: $departureStation)
                                    .textFieldStyle(RoundedTextFieldStyle())
                                    .focused($focusedField, equals: .departure)
                                    .onSubmit {
                                        focusedField = .arrival
                                    }
                                
                                if !departureStation.isEmpty {
                                    Button(action: { departureStation = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        
                        // 入れ替えボタン
                        Button(action: swapStations) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundColor(.trainSoftBlue)
                        }
                        
                        // 到着駅
                        VStack(alignment: .leading, spacing: 8) {
                            Label("到着駅", systemImage: "circle.fill")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            
                            HStack {
                                TextField("駅名を入力", text: $arrivalStation)
                                    .textFieldStyle(RoundedTextFieldStyle())
                                    .focused($focusedField, equals: .arrival)
                                    .onSubmit {
                                        searchRoutes()
                                    }
                                
                                if !arrivalStation.isEmpty {
                                    Button(action: { arrivalStation = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        
                        // 日時選択
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("出発時刻", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                                
                                Spacer()
                                
                                Picker("検索タイプ", selection: $searchType) {
                                    Text("出発").tag(SearchType.departure)
                                    Text("到着").tag(SearchType.arrival)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 120)
                            }
                            
                            Button(action: { showingDatePicker.toggle() }) {
                                HStack {
                                    Text(selectedDate, style: .date)
                                    Text(selectedDate, style: .time)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                    
                    // 検索ボタン
                    Button(action: searchRoutes) {
                        Label("経路を検索", systemImage: "magnifyingglass")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(searchButtonColor)
                            )
                    }
                    .disabled(!canSearch)
                    .padding(.horizontal)
                    
                    // 検索結果
                    if viewModel.isSearching {
                        Spacer()
                        ProgressView("経路を検索中...")
                            .padding()
                        Spacer()
                    } else if !viewModel.searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(viewModel.searchResults) { route in
                                    RouteResultCard(route: route) {
                                        onRouteSelected(route)
                                        dismiss()
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        Spacer()
                        
                        if viewModel.hasSearched {
                            VStack(spacing: 16) {
                                Image(systemName: "tram")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("経路が見つかりませんでした")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("経路検索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate, searchType: $searchType)
            }
            .onAppear {
                viewModel.setupODPTClient()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var canSearch: Bool {
        !departureStation.isEmpty && !arrivalStation.isEmpty
    }
    
    private var searchButtonColor: Color {
        canSearch ? .trainSoftBlue : Color(.systemGray4)
    }
    
    private func swapStations() {
        let temp = departureStation
        departureStation = arrivalStation
        arrivalStation = temp
    }
    
    private func searchRoutes() {
        guard canSearch else { return }
        
        focusedField = nil
        
        Task {
            await viewModel.searchRoutes(
                from: departureStation,
                to: arrivalStation,
                time: selectedDate,
                searchType: searchType
            )
        }
    }
}

// MARK: - Supporting Views

struct RouteResultCard: View {
    let route: RouteSearchResult
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // 時刻と所要時間
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.departureTime, style: .time)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(route.departureStation.title)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.textSecondary)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.arrivalTime, style: .time)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(route.arrivalStation.title)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(route.duration)分")
                            .font(.headline)
                            .foregroundColor(.trainSoftBlue)
                        
                        if route.transferCount > 0 {
                            Text("乗換\(route.transferCount)回")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        if let delay = route.totalDelay, delay > 0 {
                            Label("\(delay / 60)分遅延", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // 経路詳細
                HStack(spacing: 8) {
                    ForEach(route.sections.indices, id: \.self) { index in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: route.sections[index].railway.lineColor ?? "#999999"))
                                .frame(width: 8, height: 8)
                            Text(route.sections[index].railway.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
                
                // 運賃
                if let fare = route.fare {
                    Text("¥\(fare)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var searchType: RouteSearchView.SearchType
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("検索タイプ", selection: $searchType) {
                    Text("出発時刻").tag(RouteSearchView.SearchType.departure)
                    Text("到着時刻").tag(RouteSearchView.SearchType.arrival)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                DatePicker(
                    searchType == .departure ? "出発時刻" : "到着時刻",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                
                Spacer()
            }
            .navigationTitle(searchType == .departure ? "出発時刻" : "到着時刻")
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

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
    }
}

// MARK: - Preview

#if DEBUG
struct RouteSearchView_Previews: PreviewProvider {
    static var previews: some View {
        RouteSearchView { route in
            print("Selected route: \(route)")
        }
        .environmentObject(LocationManager())
    }
}
#endif
