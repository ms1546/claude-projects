//
//  CalendarHelper.swift
//  TrainAlert
//
//  日付と曜日、祝日判定のヘルパークラス
//

import Foundation

@MainActor
class CalendarHelper {
    static let shared = CalendarHelper()
    
    private init() {}
    
    /// 指定された日付のODPTカレンダーIDを取得
    /// - Parameter date: 判定対象の日付
    /// - Returns: ODPTカレンダーID（例: "odpt.Calendar:Weekday", "odpt.Calendar:Saturday", "odpt.Calendar:SundayHoliday"）
    func getODPTCalendarId(for date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 日曜日（weekday = 1）または祝日の場合
        if weekday == 1 || isJapaneseHoliday(date) {
            return "odpt.Calendar:SundayHoliday"
        }
        // 土曜日（weekday = 7）の場合
        else if weekday == 7 {
            return "odpt.Calendar:Saturday"
        }
        // 平日の場合
        else {
            return "odpt.Calendar:Weekday"
        }
    }
    
    /// 日本の祝日かどうかを判定
    /// - Parameter date: 判定対象の日付
    /// - Returns: 祝日の場合はtrue
    func isJapaneseHoliday(_ date: Date) -> Bool {
        // TODO: 実際の祝日判定を実装
        // 現在は仮実装として、以下の固定祝日のみチェック
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        guard let month = components.month, let day = components.day else {
            return false
        }
        
        // 2025年の固定祝日（仮実装）
        let fixedHolidays = [
            (1, 1),   // 元日
            (1, 13),  // 成人の日（2025年）
            (2, 11),  // 建国記念の日
            (2, 23),  // 天皇誕生日
            (2, 24),  // 振替休日（2025年）
            (3, 20),  // 春分の日
            (4, 29),  // 昭和の日
            (5, 3),   // 憲法記念日
            (5, 4),   // みどりの日
            (5, 5),   // こどもの日
            (5, 6),   // 振替休日（2025年）
            (7, 21),  // 海の日（2025年）
            (8, 11),  // 山の日
            (9, 15),  // 敬老の日（2025年）
            (9, 23),  // 秋分の日
            (10, 13), // スポーツの日（2025年）
            (11, 3),  // 文化の日
            (11, 23), // 勤労感謝の日
            (11, 24)  // 振替休日（2025年）
        ]
        
        return fixedHolidays.contains { $0.0 == month && $0.1 == day }
    }
    
    /// 曜日を表す文字列を取得
    /// - Parameter date: 対象の日付
    /// - Returns: 曜日の文字列（例: "月", "火"）
    func weekdayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    /// 日付の色を取得（週末・祝日は色分け）
    /// - Parameter date: 対象の日付
    /// - Returns: 表示色
    func dateColor(for date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        if weekday == 1 || isJapaneseHoliday(date) {
            return "red"  // 日曜・祝日
        } else if weekday == 7 {
            return "blue" // 土曜
        } else {
            return "default" // 平日
        }
    }
}
