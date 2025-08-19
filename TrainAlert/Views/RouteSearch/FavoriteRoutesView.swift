//
//  FavoriteRoutesView.swift
//  TrainAlert
//
//  よく使う経路の管理画面
//

import CoreData
import SwiftUI

struct FavoriteRoutesView: View {
    @StateObject private var viewModel = FavoriteRoutesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToAlertSetup = false
    @State private var selectedRouteData: RouteSearchResult?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色をHomeViewと統一
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                Group {
                    if viewModel.filteredRoutes.isEmpty {
                        emptyStateView
                    } else {
                        routesList
                    }
                }
            }
            .navigationTitle("よく使う経路")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .foregroundColor(Color.trainSoftBlue)
                }
            }
        }
    }
    
    // MARK: - Routes List
    
    private var routesList: some View {
        List {
            ForEach(viewModel.filteredRoutes) { route in
                ZStack {
                    if let routeData = viewModel.useFavoriteRoute(route) {
                        NavigationLink(destination: TimetableAlertSetupView(route: routeData)) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    
                    routeRow(route)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation {
                            viewModel.deleteFavoriteRoute(route)
                        }
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color.backgroundPrimary)
    }
    
    private func routeRow(_ route: FavoriteRoute) -> some View {
        VStack(spacing: 12) {
            HStack {
                // 出発駅
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.trainSoftBlue)
                        Text(route.departureStation ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.textPrimary)
                    }
                    if let departureTime = route.departureTime {
                        Text(formatTime(departureTime))
                            .font(.system(size: 14))
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Spacer()
                
                // 矢印
                Image(systemName: "arrow.forward")
                    .font(.system(size: 16))
                    .foregroundColor(Color.trainSoftBlue)
                
                Spacer()
                
                // 到着駅
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(route.arrivalStation ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.textPrimary)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.warmOrange)
                    }
                    if let arrivalTime = getArrivalTime(from: route) {
                        Text(formatTime(arrivalTime))
                            .font(.system(size: 14))
                            .foregroundColor(Color.textSecondary)
                    } else {
                        Text("到着時刻")
                            .font(.system(size: 14))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            
            // 区切り線
            Divider()
                .background(Color.trainLightGray.opacity(0.2))
            
            // ニックネームまたは追加情報
            HStack {
                if let nickName = route.nickName {
                    Label(nickName, systemImage: "tag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.textSecondary)
                } else {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color.textSecondary)
                    Text("お気に入り")
                        .font(.system(size: 12))
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                if let lastUsedAt = route.lastUsedAt {
                    Text("最終利用: \(formatDate(lastUsedAt))")
                        .font(.system(size: 12))
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.backgroundCard)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.trainLightGray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundColor(Color.trainLightGray.opacity(0.5))
            
            Text("よく使う経路がありません")
                .font(.headline)
                .foregroundColor(Color.textPrimary)
            
            Text("経路検索から保存できます")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter.string(from: date)
    }
    
    private func getArrivalTime(from route: FavoriteRoute) -> Date? {
        guard let routeData = route.routeData else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let decodedRoute = try? decoder.decode(RouteSearchResult.self, from: routeData) {
            return decodedRoute.arrivalTime
        }
        
        return nil
    }
}

// MARK: - Preview

struct FavoriteRoutesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoriteRoutesView()
    }
}
