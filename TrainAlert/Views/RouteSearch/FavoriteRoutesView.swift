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
    @State private var selectedRoute: FavoriteRoute?
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.filteredRoutes.isEmpty {
                    emptyStateView
                } else {
                    routesList
                }
            }
            .navigationTitle("よく使う経路")
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
    
    // MARK: - Routes List
    
    private var routesList: some View {
        List {
            ForEach(viewModel.filteredRoutes) { route in
                routeRow(route)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                    .onTapGesture {
                        if let routeData = viewModel.useFavoriteRoute(route) {
                            // 経路が選択されたら、検索画面を閉じて経路設定画面へ遷移
                            dismiss()
                            // NavigationLinkで遷移させる処理を追加
                        }
                    }
            }
            .onDelete(perform: viewModel.deleteFavoriteRoutes)
            .onMove(perform: viewModel.moveRoute)
        }
        .listStyle(PlainListStyle())
        .background(Color(red: 250 / 255, green: 251 / 255, blue: 252 / 255))
        .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
    }
    
    private func routeRow(_ route: FavoriteRoute) -> some View {
        VStack(spacing: 0) {
            HStack {
                // 出発駅
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                        Text(route.departureStation ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    if let departureTime = route.departureTime {
                        Text(formatTime(departureTime))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 矢印
                Image(systemName: "arrow.forward")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255))
                
                Spacer()
                
                // 到着駅
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(route.arrivalStation ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                    Text("到着時刻")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // ニックネームまたは追加情報
            HStack {
                if let nickName = route.nickName {
                    Label(nickName, systemImage: "tag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("お気に入り")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let lastUsedAt = route.lastUsedAt {
                    Text("最終利用: \(formatDate(lastUsedAt))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("よく使う経路がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("経路検索から保存できます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 250 / 255, green: 251 / 255, blue: 252 / 255))
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
}

// MARK: - Preview

struct FavoriteRoutesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoriteRoutesView()
    }
}
