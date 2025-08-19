//
//  Alert+Extension.swift
//  TrainAlert
//
//  Created by Claude Code on 2025/08/19.
//

import CoreData
import Foundation

extension Alert {
    // MARK: - Repeat Settings Properties
    
    /// 繰り返し設定のパターン
    var repeatPattern: RepeatPattern {
        get {
            guard let patternString = self.repeatPatternString else { return .none }
            return RepeatPattern(rawValue: patternString) ?? .none
        }
        set {
            self.repeatPatternString = newValue.rawValue
        }
    }
    
    /// 繰り返しが有効かどうか
    var isRepeatingEnabled: Bool {
        get {
            self.repeatPattern != .none
        }
    }
    
    /// カスタム曜日の配列（1=日曜日, 2=月曜日, ..., 7=土曜日）
    var repeatCustomDays: [Int] {
        get {
            guard let daysData = self.repeatCustomDaysData,
                  let days = try? JSONDecoder().decode([Int].self, from: daysData) else {
                return []
            }
            return days
        }
        set {
            self.repeatCustomDaysData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 次の通知日時を計算
    /// - Parameter from: 計算開始日時（デフォルトは現在）
    /// - Returns: 次の通知日時
    func nextNotificationDate(from: Date = Date()) -> Date? {
        guard let baseTime = self.arrivalTime else { return nil }
        
        if isRepeatingEnabled {
            return repeatPattern.nextNotificationDate(
                baseTime: baseTime,
                customDays: repeatCustomDays,
                from: from
            )
        } else {
            // 繰り返しなしの場合は、設定された日時が未来ならそれを返す
            if baseTime > from {
                return baseTime
            }
            return nil
        }
    }
    
    /// 繰り返し設定の説明文を取得
    func repeatSettingDescription() -> String {
        switch repeatPattern {
        case .none:
            return "繰り返しなし"
        case .daily:
            return "毎日"
        case .weekdays:
            return "平日"
        case .weekends:
            return "週末"
        case .custom:
            let dayNames = repeatCustomDays.compactMap { DayOfWeek(rawValue: $0)?.shortName }
            return dayNames.isEmpty ? "カスタム" : dayNames.joined(separator: "・")
        }
    }
    
    /// 次回通知予定の説明文を取得
    func nextNotificationDescription() -> String? {
        guard let nextDate = nextNotificationDate() else { return nil }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(nextDate) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(nextDate) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        
        return "次回: " + formatter.string(from: nextDate)
    }
    
    /// 通知識別子を生成（繰り返し設定を考慮）
    func notificationIdentifier(for date: Date? = nil) -> String {
        let baseId = self.alertId?.uuidString ?? UUID().uuidString
        
        if isRepeatingEnabled, let date = date {
            // 繰り返しの場合は日付を含める
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            return "\(baseId)_\(formatter.string(from: date))"
        }
        
        return baseId
    }
}

// MARK: - Core Data Managed Properties (Placeholders)
// Note: これらのプロパティは実際にはCore Dataモデルで定義される必要があります
// Xcodeでxcdatamodeldファイルを編集して以下のプロパティを追加してください：
// - repeatPatternString: String? (optional)
// - repeatCustomDaysData: Data? (optional, Binary Data)

// 一時的な実装（実際のCore Dataモデルが更新されるまで）
private var repeatPatternAssociatedKey: UInt8 = 0
private var repeatCustomDaysAssociatedKey: UInt8 = 1

extension Alert {
    var repeatPatternString: String? {
        get {
            objc_getAssociatedObject(self, &repeatPatternAssociatedKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &repeatPatternAssociatedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var repeatCustomDaysData: Data? {
        get {
            objc_getAssociatedObject(self, &repeatCustomDaysAssociatedKey) as? Data
        }
        set {
            objc_setAssociatedObject(self, &repeatCustomDaysAssociatedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
