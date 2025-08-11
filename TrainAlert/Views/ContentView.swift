//
//  ContentView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("履歴")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(2)
        }
    }
}
