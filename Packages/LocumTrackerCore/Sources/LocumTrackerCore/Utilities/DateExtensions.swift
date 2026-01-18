import Foundation

/// Date extensions for common date operations
public extension Date {
    
    /// Formats date for display (medium style with time)
    public var formattedWithTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Formats date for display (medium style, date only)
    public var formattedDateOnly: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Formats date for short display (dd/MM/yyyy)
    public var formattedShortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: self)
    }
    
    /// Returns first day of the quarter this date belongs to
    public var startOfQuarter: Date {
        let calendar = Calendar.current
        let quarter = calendar.component(.quarter, from: self)
        let year = calendar.component(.year, from: self)
        
        guard let startOfQuarter = calendar.date(from: DateComponents(
            year: year,
            month: (quarter - 1) * 3 + 1,
            day: 1
        )) else {
            return self
        }
        
        return startOfQuarter
    }
    
    /// Returns end date of the quarter this date belongs to
    public var endOfQuarter: Date {
        let calendar = Calendar.current
        let quarter = calendar.component(.quarter, from: self)
        let year = calendar.component(.year, from: self)
        
        guard let startOfNextQuarter = calendar.date(from: DateComponents(
            year: quarter == 4 ? year + 1 : year,
            month: quarter == 4 ? 1 : (quarter * 3) + 1,
            day: 1
        )) else {
            return self
        }
        
        return startOfNextQuarter.addingTimeInterval(-86400) // Minus 1 day
    }
    
    /// Returns true if date is weekend (Saturday or Sunday)
    public var isWeekend: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    }
    
    /// Returns true if date is public holiday in Australia
    /// Note: This would need to be updated with actual public holidays
    public var isPublicHoliday: Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .month, .year], from: self)
        
        guard let day = components.day, let month = components.month, let year = components.year else {
            return false
        }
        
        // Major Australian public holidays (simplified - would need comprehensive list)
let holidays: [(String: [(Int, Int)])] = [
            "01/01": [(1, 1)], // New Year's Day
            "01/26": [(26, 1)], // Australia Day
            "04/25": [(25, 4)], // ANZAC Day
            "12/25": [(25, 12)], // Christmas Day
            "12/26": [(26, 12)], // Boxing Day
        ]
        
        for (date, dates) in holidays {
            for (holidayDay, holidayMonth) in dates {
                if day == holidayDay && month == holidayMonth {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Returns true if date is in the past
    public var isInPast: Bool {
        return self < Date()
    }
    
    /// Returns true if date is today
    public var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: Date())
    }
    
    /// Returns true if date is within current quarter
    public var isInCurrentQuarter: Bool {
        let now = Date()
        let currentQuarterRange = now.startOfQuarter...now.endOfQuarter
        return currentQuarterRange.contains(self)
    }
    
    /// Adds days to date
    /// - Parameter days: Number of days to add
    /// - Returns: New date with days added
    public func addingDays(_ days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// Subtracts days from date
    /// - Parameter days: Number of days to subtract
    /// - Returns: New date with days subtracted
    public func subtractingDays(_ days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -days, to: self) ?? self
    }
    
    /// Returns date with time components set to start of day
    public var startOfDay: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: self)
    }
    
    /// Returns date with time components set to end of day
    public var endOfDay: Date {
        let calendar = Calendar.current
        let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: self.startOfDay) ?? self
        return startOfNextDay.addingTimeInterval(-1) // Minus 1 second
    }
}

/// TimeInterval extensions for duration formatting
public extension TimeInterval {
    
    /// Formats time interval as hours and minutes (e.g., "2h 30m")
    public var formattedDuration: String {
        let seconds = Int(self)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 && minutes > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if hours > 0 {
            return String(format: "%dh", hours)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    /// Formats time interval as decimal hours
    public var formattedHours: String {
        let hours = self / 3600
        return String(format: "%.2f hours", hours)
    }
    
    /// Formats time interval as currency (assuming $X per hour rate)
    /// - Parameter hourlyRate: Hourly rate to multiply by
    /// - Returns: Formatted currency amount
    public func asCurrency(at hourlyRate: Double) -> String {
        let amount = (self / 3600) * hourlyRate
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
    
    /// Returns time interval in hours (rounded to 2 decimal places)
    public var hours: Double {
        return round(self / 3600 * 100) / 100
    }
    
    /// Returns time interval in minutes (rounded)
    public var minutes: Int {
        return Int(round(self / 60))
    }
}