import Foundation

public extension Date {

    /// Start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the day (23:59:59)
    var endOfDay: Date {
        Calendar.current.date(byAdding: .second, value: -1, to: startOfDay.addingDays(1)) ?? self
    }

    /// First day of the quarter this date belongs to
    var startOfQuarter: Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let year = calendar.component(.year, from: self)
        let quarterMonth = ((month - 1) / 3) * 3 + 1
        return calendar.date(from: DateComponents(year: year, month: quarterMonth, day: 1)) ?? self
    }

    /// Last day of the quarter this date belongs to
    var endOfQuarter: Date {
        let calendar = Calendar.current
        guard let nextQuarter = calendar.date(byAdding: .month, value: 3, to: startOfQuarter) else {
            return self
        }
        return calendar.date(byAdding: .day, value: -1, to: nextQuarter) ?? self
    }

    /// Whether this date falls on a weekend
    var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: self)
        return weekday == 1 || weekday == 7
    }

    /// Whether this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Whether this date is in the past
    var isInPast: Bool {
        self < Date()
    }

    /// Adds days to this date
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Formatted as short date (dd/MM/yyyy)
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }

    /// Formatted as medium date
    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

public extension TimeInterval {

    /// Returns hours (decimal)
    var hours: Double {
        self / 3600
    }

    /// Returns minutes (rounded)
    var minutes: Int {
        Int(self / 60)
    }

    /// Formats as "Xh Ym"
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60

        if h > 0 && m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }

    /// Formats travel time as "Xh Ym travel" or "Xm travel"
    var travelTimeFormatted: String {
        let totalMinutes = Int(self / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m travel" : "\(hours)h travel"
        }
        return "\(totalMinutes)m travel"
    }
}

public extension Date {

    /// Calculates the number of days in a date range (inclusive of both start and end)
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    /// - Returns: Number of days including both start and end dates
    static func daysInRange(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1 // Include both start and end days
    }

    /// Formats a date range as a string using short date format
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    /// - Returns: Formatted string like "01/01/2026 - 15/01/2026"
    static func rangeText(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    /// Formats a duration text based on the number of days between two dates
    /// - Parameters:
    ///   - start: Start date
    ///   - end: End date
    /// - Returns: Formatted string like "1 day" or "5 days"
    static func durationText(from start: Date, to end: Date) -> String {
        let days = daysInRange(from: start, to: end)
        return days == 1 ? "1 day" : "\(days) days"
    }
}
