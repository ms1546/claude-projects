//
//  MigrationPolicy.swift
//  TrainAlert
//
//  Core Dataマイグレーションポリシー
//

import CoreData
import Foundation

class CoreDataMigrationManager {
    static func migrateCoreDataIfNeeded() {
        // アプリケーションサポートディレクトリのパス
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let storeURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("TrainAlert.sqlite")
        
        // ストアが存在する場合は削除（開発環境のみ）
        #if DEBUG
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                try FileManager.default.removeItem(at: storeURL)
                try FileManager.default.removeItem(at: storeURL.appendingPathExtension("sqlite-shm"))
                try FileManager.default.removeItem(at: storeURL.appendingPathExtension("sqlite-wal"))
                // 🗑️ Deleted existing Core Data store for fresh start
            } catch {
                // ❌ Failed to delete Core Data store: \(error)
            }
        }
        #endif
    }
}
