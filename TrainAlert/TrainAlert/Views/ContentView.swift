//
//  ContentView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "tram.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("TrainAlert")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("電車寝過ごし防止アプリ")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}