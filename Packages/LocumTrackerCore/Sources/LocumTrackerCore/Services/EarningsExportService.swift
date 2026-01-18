import Foundation

/// Export format options for earnings reports
public enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"

    public var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }

    public var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        }
    }
}

/// Data structure for an earnings report row
public struct EarningsReportRow: Codable, Sendable {
    public let date: Date
    public let locationName: String
    public let mmmClassification: Int
    public let sessionType: String
    public let hoursWorked: Double
    public let earnings: Double
    public let subsidyAmount: Double?
    public let notes: String?

    public init(
        date: Date,
        locationName: String,
        mmmClassification: Int,
        sessionType: String,
        hoursWorked: Double,
        earnings: Double,
        subsidyAmount: Double?,
        notes: String?
    ) {
        self.date = date
        self.locationName = locationName
        self.mmmClassification = mmmClassification
        self.sessionType = sessionType
        self.hoursWorked = hoursWorked
        self.earnings = earnings
        self.subsidyAmount = subsidyAmount
        self.notes = notes
    }
}

/// Summary data for earnings report
public struct EarningsReportSummary: Codable, Sendable {
    public let periodStart: Date
    public let periodEnd: Date
    public let totalEarnings: Double
    public let totalSubsidies: Double
    public let totalExpenses: Double
    public let netEarnings: Double
    public let totalHoursWorked: Double
    public let effectiveHourlyRate: Double

    public init(
        periodStart: Date,
        periodEnd: Date,
        totalEarnings: Double,
        totalSubsidies: Double,
        totalExpenses: Double,
        netEarnings: Double,
        totalHoursWorked: Double,
        effectiveHourlyRate: Double
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalEarnings = totalEarnings
        self.totalSubsidies = totalSubsidies
        self.totalExpenses = totalExpenses
        self.netEarnings = netEarnings
        self.totalHoursWorked = totalHoursWorked
        self.effectiveHourlyRate = effectiveHourlyRate
    }
}

/// Complete earnings report data
public struct EarningsReport: Codable, Sendable {
    public let generatedAt: Date
    public let summary: EarningsReportSummary
    public let rows: [EarningsReportRow]

    public init(generatedAt: Date, summary: EarningsReportSummary, rows: [EarningsReportRow]) {
        self.generatedAt = generatedAt
        self.summary = summary
        self.rows = rows
    }
}

/// Service for exporting earnings data to various formats
public struct EarningsExportService {

    /// Date formatter for CSV output (ISO 8601 date only)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Generates a CSV export of earnings data
    /// - Parameter report: The earnings report to export
    /// - Returns: CSV formatted string
    public static func exportToCSV(_ report: EarningsReport) -> String {
        var csv = ""

        // Header comment with generation info
        csv += "# Earnings Report generated \(dateFormatter.string(from: report.generatedAt))\n"
        csv += "# Period: \(dateFormatter.string(from: report.summary.periodStart)) to \(dateFormatter.string(from: report.summary.periodEnd))\n"
        csv += "#\n"

        // Summary section
        csv += "# SUMMARY\n"
        csv += "# Total Earnings: $\(String(format: "%.2f", report.summary.totalEarnings))\n"
        csv += "# Total Subsidies: $\(String(format: "%.2f", report.summary.totalSubsidies))\n"
        csv += "# Total Expenses: $\(String(format: "%.2f", report.summary.totalExpenses))\n"
        csv += "# Net Earnings: $\(String(format: "%.2f", report.summary.netEarnings))\n"
        csv += "# Total Hours: \(String(format: "%.1f", report.summary.totalHoursWorked))\n"
        csv += "# Effective Rate: $\(String(format: "%.2f", report.summary.effectiveHourlyRate))/hr\n"
        csv += "#\n"

        // Column headers
        csv += "Date,Location,MMM,Session Type,Hours,Earnings,Subsidy,Notes\n"

        // Data rows
        for row in report.rows {
            let date = dateFormatter.string(from: row.date)
            let location = escapeCSVField(row.locationName)
            let mmm = String(row.mmmClassification)
            let sessionType = row.sessionType
            let hours = String(format: "%.2f", row.hoursWorked)
            let earnings = String(format: "%.2f", row.earnings)
            let subsidy = row.subsidyAmount.map { String(format: "%.2f", $0) } ?? ""
            let notes = escapeCSVField(row.notes ?? "")

            csv += "\(date),\(location),\(mmm),\(sessionType),\(hours),\(earnings),\(subsidy),\(notes)\n"
        }

        return csv
    }

    /// Generates a JSON export of earnings data
    /// - Parameter report: The earnings report to export
    /// - Returns: JSON formatted string
    public static func exportToJSON(_ report: EarningsReport) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(report) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Exports earnings report in the specified format
    /// - Parameters:
    ///   - report: The earnings report to export
    ///   - format: The desired export format
    /// - Returns: Formatted string or nil if export fails
    public static func export(_ report: EarningsReport, format: ExportFormat) -> String? {
        switch format {
        case .csv:
            return exportToCSV(report)
        case .json:
            return exportToJSON(report)
        }
    }

    /// Generates a filename for the export
    /// - Parameters:
    ///   - report: The earnings report
    ///   - format: The export format
    /// - Returns: Suggested filename
    public static func suggestedFilename(for report: EarningsReport, format: ExportFormat) -> String {
        let start = dateFormatter.string(from: report.summary.periodStart)
        let end = dateFormatter.string(from: report.summary.periodEnd)
        return "earnings_\(start)_to_\(end).\(format.fileExtension)"
    }

    /// Escapes a field for CSV format
    /// - Parameter field: The field value to escape
    /// - Returns: Escaped string suitable for CSV
    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
