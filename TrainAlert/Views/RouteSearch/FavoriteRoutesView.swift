//
//  FavoriteRoutesView.swift
//  TrainAlert
//
//  よく使う経路の管理画面
//

import CoreData
import SwiftUI

struct FavoriteRoutesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        entity: RouteAlert.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \RouteAlert.createdAt, ascending: false)
        ],
        predicate: NSPredicate(format: "isActive == YES")
    )
    private var favoriteRoutes: FetchedResults<RouteAlert>
    
    var body: some View {
        NavigationView {
            Group {
                if favoriteRoutes.isEmpty {
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
            ForEach(favoriteRoutes) { route in
                routeRow(route)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
            }
            .onDelete(perform: deleteRoutes)
        }
        .listStyle(PlainListStyle())
        .background(Color(red: 250 / 255, green: 251 / 255, blue: 252 / 255))
    }
    
    private func routeRow(_ route: RouteAlert) -> some View {
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
                    Text(route.departureTimeString)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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
                    Text(route.arrivalTimeString)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // 通知設定
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("\(route.notificationMinutes)分前に通知")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let trainType = route.trainType {
                    Text(trainType)
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
    
    // MARK: - Actions
    
    private func deleteRoutes(at offsets: IndexSet) {
        withAnimation {
            offsets.map { favoriteRoutes[$0] }.forEach { route in
                route.isActive = false
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete route: \(error)")
            }
        }
    }
}

// MARK: - Preview

struct FavoriteRoutesView_Previews: PreviewProvider {
    static var previews: some View {
        FavoriteRoutesView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
