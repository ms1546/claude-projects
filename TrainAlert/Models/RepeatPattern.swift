//
//  RepeatPattern.swift
//  TrainAlert
//
//  Created by Claude Code on 2025/08/19.
//

import Foundation

/// 繰り返し設定のパターン
enum RepeatPattern: String, CaseIterable {
    case none = "none"          // 繰り返しなし
    case daily = "daily"        // 毎日
    case weekdays = "weekdays"  // 平日（月〜金）
    case weekends = "weekends"  // 週末（土日）
    case custom = "custom"      // カスタム（曜日指定）
    
    /// 表示名
    var displayName: String {
        switch self {
        case .none:
            return "繰り返しなし"
        case .daily:
            return "毎日"
        case .weekdays:
            return "平日"
        case .weekends:
            return "週末"
        case .custom:
            return "カスタム"
        }
    }
    
    /// 説明文
    var description: String {
        switch self {
        case .none:
            return "1回のみの通知"
        case .daily:
            return "毎日同じ時刻に通知"
        case .weekdays:
            return "月曜日〜金曜日に通知"
        case .weekends:
            return "土曜日・日曜日に通知"
        case .custom:
            return "指定した曜日に通知"
        }
    }
    
    /// パターンに含まれる曜日を取得
    /// - Returns: 曜日の配列（1=日曜日, 2=月曜日, ..., 7=土曜日）
    func getDays() -> [Int] {
        switch self {
        case .none:
            return []
        case .daily:
            return [1, 2, 3, 4, 5, 6, 7]
        case .weekdays:
            return [2, 3, 4, 5, 6] // 月〜金
        case .weekends:
            return [1, 7] // 日、土
        case .custom:
            return [] // カスタムの場合は別途指定
        }
    }
    
    /// 次の通知日時を計算
    /// - Parameters:
    ///   - baseTime: 基準となる時刻（時・分のみ使用）
    ///   - customDays: カスタムパターンの場合の曜日配列
    ///   - from: 計算開始日時（デフォルトは現在）
    /// - Returns: 次の通知日時
    func nextNotificationDate(baseTime: Date, customDays: [Int] = [], from: Date = Date()) -> Date? {
        guard self != .none else { return nil }
        
        let calendar = Calendar.current
        let days = self == .custom ? customDays : getDays()
        guard !days.isEmpty else { return nil }
        
        // 基準時刻から時・分を取得
        let components = calendar.dateComponents([.hour, .minute], from: baseTime)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        
        // 今日から7日間をチェック
        for dayOffset in 0..<7 {
            guard let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: from) else { continue }
            let weekday = calendar.component(.weekday, from: checkDate)
            
            if days.contains(weekday) {
                // その日の指定時刻を作成
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.second = 0
                
                if let notificationDate = calendar.date(from: dateComponents) {
                    // 現在時刻より後の場合のみ返す
                    if notificationDate > from {
                        return notificationDate
                    } else if dayOffset == 0 {
                        // 今日の場合で時刻が過ぎている場合は次の該当日を探す
                        continue
                    }
                }
            }
        }
        
        return nil
    }
}

/// 曜日の列挙型
enum DayOfWeek: Int, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    /// 短縮表示名
    var shortName: String {
        switch self {
        case .sunday: return "日"
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        }
    }
    
    /// フル表示名
    var fullName: String {
        switch self {
        case .sunday: return "日曜日"
        case .monday: return "月曜日"
        case .tuesday: return "火曜日"
        case .wednesday: return "水曜日"
        case .thursday: return "木曜日"
        case .friday: return "金曜日"
        case .saturday: return "土曜日"
        }
    }
}
