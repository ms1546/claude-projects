//
//  SettingsView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                    .padding()
                
                Text("設定")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("アプリの設定がここに表示されます")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("設定")
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
