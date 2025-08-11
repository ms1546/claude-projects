//
//  ContentView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct ContentView: View {
    
    // MARK: - State
    
    @State private var selectedTab: Tab = .home
    
    // MARK: - Tab Enum
    
    enum Tab {
        case home
        case history
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == .home ? "house.fill" : "house")
                    Text("ホーム")
                }
                .tag(Tab.home)
            
            // History Tab
            HistoryView()
                .tabItem {
                    Image(systemName: selectedTab == .history ? "clock.fill" : "clock")
                    Text("履歴")
                }
                .tag(Tab.history)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == .settings ? "gearshape.fill" : "gearshape")
                    Text("設定")
                }
                .tag(Tab.settings)
        }
        .tint(Color.trainSoftBlue)
        .onAppear {
            configureTabBarAppearance()
        }
    }
    
    // MARK: - Tab Bar Configuration
    
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.uiCharcoalGray
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.uiLightGray
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.uiLightGray
        
        // Selected state
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.uiSoftBlue
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.uiSoftBlue
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
            .previewDisplayName("ContentView - Dark")
    }
}
#endif
