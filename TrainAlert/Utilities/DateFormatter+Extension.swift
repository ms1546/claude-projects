//
//  DateFormatter+Extension.swift
//  TrainAlert
//
//  DateFormatterの拡張
//

import Foundation

extension DateFormatter {
    /// TrainAlert用の共通DateFormatterを作成
    static func trainAlertFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return formatter
    }
    
    /// 時刻のみのフォーマット（HH:mm）
    static let timeOnly: DateFormatter = {
        let formatter = trainAlertFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    /// 日付と時刻のフォーマット（M月d日(E) HH:mm）
    static let dateTimeWithWeekday: DateFormatter = {
        let formatter = trainAlertFormatter()
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter
    }()
    
    /// 短い日付フォーマット（M/d）
    static let shortDate: DateFormatter = {
        let formatter = trainAlertFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
    
    /// 相対的な日付時刻フォーマット
    static func relativeDateTime(from date: Date) -> String {
        let calendar = Calendar.current
        let formatter = trainAlertFormatter()
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'今日' HH:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'明日' HH:mm"
        } else if let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: Date()),
                  calendar.isDate(date, inSameDayAs: dayAfterTomorrow) {
            formatter.dateFormat = "'明後日' HH:mm"
        } else {
            // それ以外は通常の日付表示
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    /// アラート表示用のフォーマット
    static func alertDisplayFormat(from date: Date) -> String {
        let calendar = Calendar.current
        let formatter = trainAlertFormatter()
        
        // 今日の場合は時刻のみ
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            // それ以外は日付も含める
            formatter.dateFormat = "M/d HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Extension

extension Calendar {
    /// 明後日かどうかを判定
    func isDateInDayAfterTomorrow(_ date: Date) -> Bool {
        guard let dayAfterTomorrow = self.date(byAdding: .day, value: 2, to: Date()) else {
            return false
        }
        return isDate(date, inSameDayAs: dayAfterTomorrow)
    }
}
