//
//  DateTimePickerView.swift
//  TrainAlert
//
//  出発日時の詳細設定用ピッカービュー
//

import SwiftUI

struct DateTimePickerView: View {
    @Binding var selectedDateTime: Date
    @Binding var isPresented: Bool
    
    // クイック選択用の日付オプション
    private let quickDateOptions = [
        ("今日", 0),
        ("明日", 1),
        ("明後日", 2)
    ]
    
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タブ切り替え
                Picker("", selection: $selectedTab) {
                    Text("日付").tag(0)
                    Text("時刻").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedTab == 0 {
                    // 日付選択タブ
                    dateSelectionView
                } else {
                    // 時刻選択タブ
                    timeSelectionView
                }
                
                // 選択した日時の表示
                selectedDateTimeDisplay
                    .padding()
                
                Spacer()
            }
            .navigationTitle("出発日時を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        // 選択した日付と時刻を組み合わせる
                        let calendar = Calendar.current
                        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
                        
                        var combinedComponents = DateComponents()
                        combinedComponents.year = dateComponents.year
                        combinedComponents.month = dateComponents.month
                        combinedComponents.day = dateComponents.day
                        combinedComponents.hour = timeComponents.hour
                        combinedComponents.minute = timeComponents.minute
                        
                        if let combinedDate = calendar.date(from: combinedComponents) {
                            selectedDateTime = combinedDate
                        }
                        
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedDate = selectedDateTime
            selectedTime = selectedDateTime
        }
    }
    
    private var dateSelectionView: some View {
        VStack(spacing: 20) {
            // クイック選択ボタン
            HStack(spacing: 12) {
                ForEach(quickDateOptions, id: \.1) { option in
                    Button(action: {
                        let calendar = Calendar.current
                        if let newDate = calendar.date(byAdding: .day, value: option.1, to: Date()) {
                            selectedDate = newDate
                        }
                    }) {
                        Text(option.0)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isQuickOptionSelected(daysFromToday: option.1) ? .white : Color.trainSoftBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                isQuickOptionSelected(daysFromToday: option.1) ?
                                Color.trainSoftBlue : Color.trainSoftBlue.opacity(0.1)
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            
            // カレンダーピッカー
            DatePicker(
                "日付を選択",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: [.date]
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding(.horizontal)
            
            // 選択した日付の曜日とカレンダー情報
            HStack {
                Image(systemName: getCalendarIcon(for: selectedDate))
                    .foregroundColor(getCalendarColor(for: selectedDate))
                Text(formatDateWithWeekday(selectedDate))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(getCalendarColor(for: selectedDate))
            }
            .padding(.horizontal)
        }
    }
    
    private var timeSelectionView: some View {
        VStack {
            DatePicker(
                "時刻を選択",
                selection: $selectedTime,
                displayedComponents: [.hourAndMinute]
            )
            .datePickerStyle(WheelDatePickerStyle())
            .labelsHidden()
            .padding()
        }
    }
    
    private var selectedDateTimeDisplay: some View {
        VStack(spacing: 8) {
            Text("選択した出発日時")
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(Color.trainSoftBlue)
                Text(formatFullDateTime())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.backgroundCard)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isQuickOptionSelected(daysFromToday: Int) -> Bool {
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: daysFromToday, to: Date()) else {
            return false
        }
        return calendar.isDate(selectedDate, inSameDayAs: targetDate)
    }
    
    private func getCalendarIcon(for date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 週末の判定
        if weekday == 1 { // 日曜日
            return "calendar.badge.exclamationmark"
        } else if weekday == 7 { // 土曜日
            return "calendar.badge.plus"
        }
        
        // TODO: 祝日判定を追加
        return "calendar"
    }
    
    private func getCalendarColor(for date: Date) -> Color {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // 週末の色分け
        if weekday == 1 { // 日曜日
            return .red
        } else if weekday == 7 { // 土曜日
            return .blue
        }
        
        // TODO: 祝日は赤色にする
        return Color.textPrimary
    }
    
    private func formatDateWithWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }
    
    private func formatFullDateTime() -> String {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        guard let combinedDate = calendar.date(from: combinedComponents) else {
            return "選択エラー"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        // 相対的な日付表示
        if calendar.isDateInToday(combinedDate) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(combinedDate) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        
        return formatter.string(from: combinedDate)
    }
}

// MARK: - Preview

struct DateTimePickerView_Previews: PreviewProvider {
    static var previews: some View {
        DateTimePickerView(
            selectedDateTime: .constant(Date()),
            isPresented: .constant(true)
        )
    }
}
