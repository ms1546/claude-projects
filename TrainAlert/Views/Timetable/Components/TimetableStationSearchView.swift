//
//  TimetableStationSearchView.swift
//  TrainAlert
//
//  時刻表検索用の駅選択ビュー
//

import SwiftUI

struct TimetableStationSearchView: View {
    let title: String
    let onSelect: (ODPTStation) -> Void
    
    @StateObject private var viewModel = StationSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 検索フィールド
                    searchField
                        .padding()
                        .background(Color.backgroundSecondary)
                    
                    // 検索結果
                    if viewModel.isSearching {
                        LoadingIndicator(text: "駅を検索中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.stations.isEmpty && !searchText.isEmpty {
                        emptySearchResult
                    } else {
                        stationList
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button(action: {
                    dismiss()
                }) {
                    Text("キャンセル")
                        .foregroundColor(Color.trainSoftBlue)
                }
            )
        }
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textSecondary)
            
            TextField("駅名を入力", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.textPrimary)
                .onChange(of: searchText) { newValue in
                    viewModel.searchStations(query: newValue)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.backgroundCard)
        .cornerRadius(12)
    }
    
    private var stationList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.stations, id: \.sameAs) { station in
                    Button(action: { onSelect(station) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.stationTitle?.ja ?? station.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.textPrimary)
                                
                                Text(station.railwayTitle?.ja ?? station.railway.railwayJapaneseName())
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.textSecondary)
                            }
                            
                            Spacer()
                            
                            if let code = station.stationCode {
                                Text(code)
                                    .font(.caption)
                                    .foregroundColor(Color.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.backgroundSecondary)
                                    .cornerRadius(6)
                            }
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
    
    private var emptySearchResult: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(Color.trainLightGray)
            
            Text("駅が見つかりませんでした")
                .font(.headline)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

