//
//  LocationTestView.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import CoreLocation
import SwiftUI

struct LocationTestView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var logs: [String] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("位置情報テスト")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("権限状態:")
                        Text(authorizationStatusText)
                            .foregroundColor(authorizationStatusColor)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("現在地:")
                        if let location = locationManager.location {
                            Text("緯度: \(location.coordinate.latitude, specifier: "%.6f"), 経度: \(location.coordinate.longitude, specifier: "%.6f")")
                                .font(.caption)
                        } else {
                            Text("取得中...")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = locationManager.lastError {
                        Text("エラー: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button(action: requestPermission) {
                        Label("権限をリクエスト", systemImage: "location.circle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: startLocationUpdates) {
                        Label("位置情報の更新を開始", systemImage: "location.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(locationManager.isUpdatingLocation ? Color.gray : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(locationManager.isUpdatingLocation)
                    
                    Button(action: stopLocationUpdates) {
                        Label("位置情報の更新を停止", systemImage: "location.slash")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!locationManager.isUpdatingLocation ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!locationManager.isUpdatingLocation)
                }
                
                // Logs
                VStack(alignment: .leading) {
                    Text("ログ:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(logs.reversed(), id: \.self) { log in
                                Text(log)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("位置情報デバッグ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ログをクリア") {
                        logs.removeAll()
                    }
                }
            }
        }
        .onAppear {
            addLog("ビューが表示されました")
            addLog("現在の権限状態: \(locationManager.authorizationStatus.rawValue)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            addLog("アプリがアクティブになりました")
            addLog("権限状態を再確認: \(locationManager.authorizationStatus.rawValue)")
        }
    }
    
    private var authorizationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "未決定"
        case .restricted:
            return "制限"
        case .denied:
            return "拒否"
        case .authorizedAlways:
            return "常に許可"
        case .authorizedWhenInUse:
            return "使用中のみ"
        @unknown default:
            return "不明"
        }
    }
    
    private var authorizationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private func requestPermission() {
        addLog("権限リクエストを開始")
        locationManager.requestAuthorization()
        
        // 結果を監視
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            addLog("権限リクエスト後の状態: \(locationManager.authorizationStatus.rawValue)")
        }
    }
    
    private func startLocationUpdates() {
        addLog("位置情報の更新を開始")
        locationManager.startUpdatingLocation()
    }
    
    private func stopLocationUpdates() {
        addLog("位置情報の更新を停止")
        locationManager.stopUpdatingLocation()
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.append("[\(timestamp)] \(message)")
    }
}

#if DEBUG
struct LocationTestView_Previews: PreviewProvider {
    static var previews: some View {
        LocationTestView()
            .environmentObject(LocationManager())
    }
}
#endif

