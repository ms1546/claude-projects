//
//  HistoryView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                    .padding()
                
                Text("履歴")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("目覚まし履歴がここに表示されます")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("履歴")
        }
    }
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
#endif

