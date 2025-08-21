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
    
    // 祝日データのキャッシュ
    private var holidayCache: [String: String] = [:]
    private let cacheKey = "jp.holidays.cache"
    private let cacheExpiryKey = "jp.holidays.cache.expiry"
    private let cacheExpiryDays = 30 // 30日ごとに更新
    
    private init() {
        loadCachedHolidays()
        Task {
            await updateHolidaysIfNeeded()
        }
    }
    
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let dateString = formatter.string(from: date)
        
        return holidayCache[dateString] != nil
    }
    
    /// 祝日名を取得
    /// - Parameter date: 対象の日付
    /// - Returns: 祝日名（祝日でない場合はnil）
    func holidayName(for date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        let dateString = formatter.string(from: date)
        
        return holidayCache[dateString]
    }
    
    // MARK: - Private Methods
    
    /// キャッシュされた祝日データを読み込み
    private func loadCachedHolidays() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cache = try? JSONDecoder().decode([String: String].self, from: data) {
            holidayCache = cache
        }
    }
    
    /// 祝日データをキャッシュに保存
    private func saveCacheHolidays() {
        if let data = try? JSONEncoder().encode(holidayCache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheExpiryKey)
        }
    }
    
    /// 必要に応じて祝日データを更新
    private func updateHolidaysIfNeeded() async {
        // キャッシュの有効期限を確認
        if let lastUpdate = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date {
            let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdate, to: Date()).day ?? 0
            if daysSinceUpdate < cacheExpiryDays && !holidayCache.isEmpty {
                return // キャッシュが有効
            }
        }
        
        // holidays-jp APIからデータを取得
        await fetchHolidaysFromAPI()
    }
    
    /// holidays-jp APIから祝日データを取得
    private func fetchHolidaysFromAPI() async {
        guard let url = URL(string: "https://holidays-jp.github.io/api/v1/date.json") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let holidays = try? JSONDecoder().decode([String: String].self, from: data) {
                holidayCache = holidays
                saveCacheHolidays()
                // CalendarHelper: Updated holiday data from API
            }
        } catch {
            // CalendarHelper: Failed to fetch holidays - \(error)
        }
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
