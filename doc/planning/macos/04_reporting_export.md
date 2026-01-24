# Phase 4: Reporting & Export

*LocumTrackerReporting package, CSV/Excel export, PDF invoices, and print support*

## Objectives

- Create new LocumTrackerReporting package with pure functions
- Implement CSV and Excel export services
- Build PDF invoice and report generation
- Add print support for professional output
- Create reporting views in macOS app

## Package Design: LocumTrackerReporting

This package contains pure functions for report generation and export, with no UI dependencies.

### Package Structure

```
Packages/LocumTrackerReporting/
├── Package.swift
├── Sources/
│   └── LocumTrackerReporting/
│       ├── LocumTrackerReporting.swift       # Public API
│       ├── Export/
│       │   ├── CSVExporter.swift
│       │   ├── ExcelExporter.swift
│       │   └── PDFExporter.swift
│       ├── Reports/
│       │   ├── EarningsReportGenerator.swift
│       │   ├── FPSComplianceReportGenerator.swift
│       │   ├── TaxSummaryReportGenerator.swift
│       │   └── ExpenseReportGenerator.swift
│       ├── Invoices/
│       │   ├── InvoiceGenerator.swift
│       │   └── InvoiceTemplate.swift
│       └── Models/
│           ├── ReportData.swift
│           ├── ExportFormat.swift
│           └── InvoiceData.swift
└── Tests/
    └── LocumTrackerReportingTests/
        ├── CSVExporterTests.swift
        ├── EarningsReportTests.swift
        └── InvoiceGeneratorTests.swift
```

## Implementation Steps

### Step 1: Package Setup

**Packages/LocumTrackerReporting/Package.swift**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocumTrackerReporting",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocumTrackerReporting",
            targets: ["LocumTrackerReporting"]),
    ],
    dependencies: [
        .package(path: "../LocumTrackerCore"),
    ],
    targets: [
        .target(
            name: "LocumTrackerReporting",
            dependencies: ["LocumTrackerCore"]),
        .testTarget(
            name: "LocumTrackerReportingTests",
            dependencies: ["LocumTrackerReporting"]),
    ]
)
```

### Step 2: Export Models

**Sources/LocumTrackerReporting/Models/ExportFormat.swift**
```swift
import Foundation

/// Supported export formats
public enum ExportFormat: String, CaseIterable, Sendable {
    case csv = "CSV"
    case excel = "Excel"
    case pdf = "PDF"

    public var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .excel: return "xlsx"
        case .pdf: return "pdf"
        }
    }

    public var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .excel: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .pdf: return "application/pdf"
        }
    }
}

/// Configuration for report generation
public struct ReportConfiguration: Sendable {
    public let reportType: ReportType
    public let startDate: Date
    public let endDate: Date
    public let groupBy: GroupingOption
    public let includeSubtotals: Bool

    public init(
        reportType: ReportType,
        startDate: Date,
        endDate: Date,
        groupBy: GroupingOption = .month,
        includeSubtotals: Bool = true
    ) {
        self.reportType = reportType
        self.startDate = startDate
        self.endDate = endDate
        self.groupBy = groupBy
        self.includeSubtotals = includeSubtotals
    }
}

public enum ReportType: String, CaseIterable, Sendable {
    case earnings = "Earnings Report"
    case expenses = "Expense Report"
    case fpsCompliance = "FPS Compliance Report"
    case taxSummary = "Tax Summary"
    case fullActivity = "Full Activity Report"
}

public enum GroupingOption: String, CaseIterable, Sendable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
    case quarter = "Quarterly"
    case year = "Yearly"
    case assignment = "By Assignment"
    case location = "By Location"
}
```

**Sources/LocumTrackerReporting/Models/ReportData.swift**
```swift
import Foundation
import LocumTrackerCore

/// Generic report data container
public struct ReportData: Sendable {
    public let title: String
    public let subtitle: String?
    public let generatedDate: Date
    public let period: DateInterval
    public let sections: [ReportSection]
    public let summary: ReportSummary

    public init(
        title: String,
        subtitle: String? = nil,
        generatedDate: Date = Date(),
        period: DateInterval,
        sections: [ReportSection],
        summary: ReportSummary
    ) {
        self.title = title
        self.subtitle = subtitle
        self.generatedDate = generatedDate
        self.period = period
        self.sections = sections
        self.summary = summary
    }
}

public struct ReportSection: Sendable {
    public let title: String
    public let rows: [ReportRow]
    public let subtotal: Decimal?

    public init(title: String, rows: [ReportRow], subtotal: Decimal? = nil) {
        self.title = title
        self.rows = rows
        self.subtotal = subtotal
    }
}

public struct ReportRow: Sendable {
    public let columns: [String]
    public let values: [ReportValue]

    public init(columns: [String], values: [ReportValue]) {
        self.columns = columns
        self.values = values
    }
}

public enum ReportValue: Sendable {
    case text(String)
    case currency(Decimal)
    case number(Int)
    case percentage(Double)
    case date(Date)

    public var stringValue: String {
        switch self {
        case .text(let s): return s
        case .currency(let d):
            return NumberFormatter.currencyFormatter.string(from: d as NSDecimalNumber) ?? ""
        case .number(let n): return "\(n)"
        case .percentage(let p): return String(format: "%.1f%%", p * 100)
        case .date(let d):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: d)
        }
    }
}

public struct ReportSummary: Sendable {
    public let items: [SummaryItem]

    public init(items: [SummaryItem]) {
        self.items = items
    }
}

public struct SummaryItem: Sendable {
    public let label: String
    public let value: ReportValue

    public init(label: String, value: ReportValue) {
        self.label = label
        self.value = value
    }
}

extension NumberFormatter {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter
    }()
}
```

### Step 3: CSV Exporter

**Sources/LocumTrackerReporting/Export/CSVExporter.swift**
```swift
import Foundation

/// CSV export service with pure functions
public enum CSVExporter {
    /// Generate CSV data from report
    /// - Parameter report: The report data to export
    /// - Returns: CSV formatted data
    public static func export(_ report: ReportData) -> Data {
        var lines: [String] = []

        // Header
        lines.append(escapeCSV(report.title))
        if let subtitle = report.subtitle {
            lines.append(escapeCSV(subtitle))
        }
        lines.append("Generated: \(formatDate(report.generatedDate))")
        lines.append("Period: \(formatDate(report.period.start)) - \(formatDate(report.period.end))")
        lines.append("")

        // Sections
        for section in report.sections {
            lines.append(escapeCSV(section.title))

            // Column headers from first row
            if let firstRow = section.rows.first {
                lines.append(firstRow.columns.map { escapeCSV($0) }.joined(separator: ","))
            }

            // Data rows
            for row in section.rows {
                let values = row.values.map { escapeCSV($0.stringValue) }
                lines.append(values.joined(separator: ","))
            }

            // Subtotal
            if let subtotal = section.subtotal {
                lines.append("Subtotal,\(formatCurrency(subtotal))")
            }

            lines.append("")
        }

        // Summary
        lines.append("Summary")
        for item in report.summary.items {
            lines.append("\(escapeCSV(item.label)),\(escapeCSV(item.value.stringValue))")
        }

        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    /// Export sessions to CSV
    public static func exportSessions(_ sessions: [SessionExportData]) -> Data {
        var lines: [String] = []

        // Header
        lines.append("Date,Start Time,End Time,Duration (hrs),Type,Location,MMM,Earnings,FPS Eligible,Notes")

        // Rows
        for session in sessions {
            let row = [
                formatDate(session.date),
                session.startTime ?? "",
                session.endTime ?? "",
                String(format: "%.2f", session.durationHours),
                session.sessionType,
                escapeCSV(session.locationName),
                "MMM\(session.mmmClassification)",
                formatCurrency(session.earnings),
                session.isFPSEligible ? "Yes" : "No",
                escapeCSV(session.notes ?? "")
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    /// Export receipts to CSV
    public static func exportReceipts(_ receipts: [ReceiptExportData]) -> Data {
        var lines: [String] = []

        // Header
        lines.append("Date,Merchant,Category,Amount,Tax Deductible,Assignment,Notes")

        // Rows
        for receipt in receipts {
            let row = [
                formatDate(receipt.date),
                escapeCSV(receipt.merchant ?? "Unknown"),
                receipt.category,
                formatCurrency(receipt.amount),
                receipt.isTaxDeductible ? "Yes" : "No",
                escapeCSV(receipt.assignmentName ?? ""),
                escapeCSV(receipt.notes ?? "")
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    // MARK: - Private Helpers

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func formatCurrency(_ amount: Decimal) -> String {
        return NumberFormatter.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Export Data Types

public struct SessionExportData: Sendable {
    public let date: Date
    public let startTime: String?
    public let endTime: String?
    public let durationHours: Double
    public let sessionType: String
    public let locationName: String
    public let mmmClassification: Int
    public let earnings: Decimal
    public let isFPSEligible: Bool
    public let notes: String?

    public init(
        date: Date,
        startTime: String?,
        endTime: String?,
        durationHours: Double,
        sessionType: String,
        locationName: String,
        mmmClassification: Int,
        earnings: Decimal,
        isFPSEligible: Bool,
        notes: String?
    ) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.durationHours = durationHours
        self.sessionType = sessionType
        self.locationName = locationName
        self.mmmClassification = mmmClassification
        self.earnings = earnings
        self.isFPSEligible = isFPSEligible
        self.notes = notes
    }
}

public struct ReceiptExportData: Sendable {
    public let date: Date
    public let merchant: String?
    public let category: String
    public let amount: Decimal
    public let isTaxDeductible: Bool
    public let assignmentName: String?
    public let notes: String?

    public init(
        date: Date,
        merchant: String?,
        category: String,
        amount: Decimal,
        isTaxDeductible: Bool,
        assignmentName: String?,
        notes: String?
    ) {
        self.date = date
        self.merchant = merchant
        self.category = category
        self.amount = amount
        self.isTaxDeductible = isTaxDeductible
        self.assignmentName = assignmentName
        self.notes = notes
    }
}
```

### Step 4: PDF Invoice Generator

**Sources/LocumTrackerReporting/Invoices/InvoiceGenerator.swift**
```swift
import Foundation
import PDFKit
import LocumTrackerCore

/// Invoice generation service
public enum InvoiceGenerator {
    /// Generate PDF invoice
    /// - Parameter invoice: Invoice data
    /// - Returns: PDF document data
    public static func generatePDF(_ invoice: InvoiceData) -> Data {
        let pdfDocument = PDFDocument()

        // Create page with A4 dimensions
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 in points

        // Render invoice content
        let renderer = InvoiceRenderer(invoice: invoice, pageRect: pageRect)
        let pages = renderer.render()

        for (index, page) in pages.enumerated() {
            pdfDocument.insert(page, at: index)
        }

        return pdfDocument.dataRepresentation() ?? Data()
    }

    /// Generate plain text invoice (for email)
    public static func generateText(_ invoice: InvoiceData) -> String {
        var lines: [String] = []

        // Header
        lines.append("TAX INVOICE")
        lines.append("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
        lines.append("")
        lines.append("Invoice Number: \(invoice.invoiceNumber)")
        lines.append("Date: \(formatDate(invoice.date))")
        lines.append("")

        // From
        lines.append("FROM:")
        lines.append(invoice.from.name)
        if let abn = invoice.from.abn {
            lines.append("ABN: \(abn)")
        }
        lines.append(invoice.from.address ?? "")
        lines.append("")

        // To
        lines.append("TO:")
        lines.append(invoice.to.name)
        if let abn = invoice.to.abn {
            lines.append("ABN: \(abn)")
        }
        lines.append(invoice.to.address ?? "")
        lines.append("")

        // Line items
        lines.append("-".padding(toLength: 60, withPad: "-", startingAt: 0))
        lines.append(String(format: "%-30s %10s %15s", "Description", "Qty", "Amount"))
        lines.append("-".padding(toLength: 60, withPad: "-", startingAt: 0))

        for item in invoice.lineItems {
            let description = item.description.prefix(30).padding(toLength: 30, withPad: " ", startingAt: 0)
            let qty = String(format: "%10.1f", item.quantity)
            let amount = formatCurrency(item.total)
            lines.append("\(description) \(qty) \(amount.padding(toLength: 15, withPad: " ", startingAt: 0))")
        }

        lines.append("-".padding(toLength: 60, withPad: "-", startingAt: 0))

        // Totals
        lines.append(String(format: "%45s %15s", "Subtotal:", formatCurrency(invoice.subtotal)))
        if invoice.gstAmount > 0 {
            lines.append(String(format: "%45s %15s", "GST (10%):", formatCurrency(invoice.gstAmount)))
        }
        lines.append(String(format: "%45s %15s", "TOTAL:", formatCurrency(invoice.total)))
        lines.append("")

        // Payment details
        lines.append("PAYMENT DETAILS:")
        if let bankName = invoice.paymentDetails?.bankName {
            lines.append("Bank: \(bankName)")
        }
        if let bsb = invoice.paymentDetails?.bsb {
            lines.append("BSB: \(bsb)")
        }
        if let accountNumber = invoice.paymentDetails?.accountNumber {
            lines.append("Account: \(accountNumber)")
        }
        lines.append("")
        lines.append("Payment due within \(invoice.paymentTermsDays) days")

        return lines.joined(separator: "\n")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private static func formatCurrency(_ amount: Decimal) -> String {
        return NumberFormatter.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Invoice Data Models

public struct InvoiceData: Sendable {
    public let invoiceNumber: String
    public let date: Date
    public let dueDate: Date
    public let from: BusinessEntity
    public let to: BusinessEntity
    public let lineItems: [InvoiceLineItem]
    public let subtotal: Decimal
    public let gstAmount: Decimal
    public let total: Decimal
    public let paymentDetails: PaymentDetails?
    public let paymentTermsDays: Int
    public let notes: String?

    public init(
        invoiceNumber: String,
        date: Date,
        dueDate: Date,
        from: BusinessEntity,
        to: BusinessEntity,
        lineItems: [InvoiceLineItem],
        subtotal: Decimal,
        gstAmount: Decimal,
        total: Decimal,
        paymentDetails: PaymentDetails?,
        paymentTermsDays: Int = 14,
        notes: String? = nil
    ) {
        self.invoiceNumber = invoiceNumber
        self.date = date
        self.dueDate = dueDate
        self.from = from
        self.to = to
        self.lineItems = lineItems
        self.subtotal = subtotal
        self.gstAmount = gstAmount
        self.total = total
        self.paymentDetails = paymentDetails
        self.paymentTermsDays = paymentTermsDays
        self.notes = notes
    }
}

public struct BusinessEntity: Sendable {
    public let name: String
    public let abn: String?
    public let address: String?
    public let email: String?
    public let phone: String?

    public init(name: String, abn: String? = nil, address: String? = nil,
                email: String? = nil, phone: String? = nil) {
        self.name = name
        self.abn = abn
        self.address = address
        self.email = email
        self.phone = phone
    }
}

public struct InvoiceLineItem: Sendable {
    public let description: String
    public let quantity: Double
    public let unitPrice: Decimal
    public let total: Decimal

    public init(description: String, quantity: Double, unitPrice: Decimal) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.total = unitPrice * Decimal(quantity)
    }
}

public struct PaymentDetails: Sendable {
    public let bankName: String?
    public let bsb: String?
    public let accountNumber: String?
    public let accountName: String?

    public init(bankName: String? = nil, bsb: String? = nil,
                accountNumber: String? = nil, accountName: String? = nil) {
        self.bankName = bankName
        self.bsb = bsb
        self.accountNumber = accountNumber
        self.accountName = accountName
    }
}
```

**Sources/LocumTrackerReporting/Invoices/InvoiceRenderer.swift**
```swift
import Foundation
import PDFKit
import CoreGraphics
import CoreText

/// Renders invoice content to PDF pages
class InvoiceRenderer {
    let invoice: InvoiceData
    let pageRect: CGRect
    let margin: CGFloat = 50

    init(invoice: InvoiceData, pageRect: CGRect) {
        self.invoice = invoice
        self.pageRect = pageRect
    }

    func render() -> [PDFPage] {
        var pages: [PDFPage] = []

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, pageRect, nil)
        UIGraphicsBeginPDFPage()

        guard let context = UIGraphicsGetCurrentContext() else {
            return pages
        }

        var yPosition = pageRect.height - margin

        // Header
        yPosition = drawHeader(context: context, y: yPosition)

        // From/To
        yPosition = drawParties(context: context, y: yPosition)

        // Line Items Table
        yPosition = drawLineItems(context: context, y: yPosition)

        // Totals
        yPosition = drawTotals(context: context, y: yPosition)

        // Payment Details
        yPosition = drawPaymentDetails(context: context, y: yPosition)

        // Footer
        drawFooter(context: context)

        UIGraphicsEndPDFContext()

        if let pdfDoc = PDFDocument(data: data as Data) {
            for i in 0..<pdfDoc.pageCount {
                if let page = pdfDoc.page(at: i) {
                    pages.append(page)
                }
            }
        }

        return pages
    }

    private func drawHeader(context: CGContext, y: CGFloat) -> CGFloat {
        var currentY = y

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        let title = "TAX INVOICE"
        title.draw(at: CGPoint(x: margin, y: currentY - 30), withAttributes: titleAttributes)

        currentY -= 50

        // Invoice details (right aligned)
        let detailsAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.darkGray
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        let details = [
            "Invoice #: \(invoice.invoiceNumber)",
            "Date: \(dateFormatter.string(from: invoice.date))",
            "Due: \(dateFormatter.string(from: invoice.dueDate))"
        ]

        for detail in details {
            let size = detail.size(withAttributes: detailsAttributes)
            detail.draw(at: CGPoint(x: pageRect.width - margin - size.width, y: currentY),
                       withAttributes: detailsAttributes)
            currentY -= 16
        }

        return currentY - 20
    }

    private func drawParties(context: CGContext, y: CGFloat) -> CGFloat {
        var currentY = y

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.darkGray
        ]

        // From (left side)
        "FROM:".draw(at: CGPoint(x: margin, y: currentY), withAttributes: headerAttributes)
        currentY -= 18
        invoice.from.name.draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttributes)
        currentY -= 14
        if let abn = invoice.from.abn {
            "ABN: \(abn)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttributes)
            currentY -= 14
        }
        if let address = invoice.from.address {
            address.draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttributes)
        }

        // To (right side) - reset Y for right column
        var rightY = y
        let rightX = pageRect.width / 2

        "TO:".draw(at: CGPoint(x: rightX, y: rightY), withAttributes: headerAttributes)
        rightY -= 18
        invoice.to.name.draw(at: CGPoint(x: rightX, y: rightY), withAttributes: bodyAttributes)
        rightY -= 14
        if let abn = invoice.to.abn {
            "ABN: \(abn)".draw(at: CGPoint(x: rightX, y: rightY), withAttributes: bodyAttributes)
            rightY -= 14
        }
        if let address = invoice.to.address {
            address.draw(at: CGPoint(x: rightX, y: rightY), withAttributes: bodyAttributes)
        }

        return min(currentY, rightY) - 30
    }

    private func drawLineItems(context: CGContext, y: CGFloat) -> CGFloat {
        // Table implementation
        // Draw headers, rows, and borders
        return y - 200 // Placeholder
    }

    private func drawTotals(context: CGContext, y: CGFloat) -> CGFloat {
        // Totals section
        return y - 60
    }

    private func drawPaymentDetails(context: CGContext, y: CGFloat) -> CGFloat {
        // Payment details section
        return y - 80
    }

    private func drawFooter(context: CGContext) {
        // Footer with thank you message
    }
}

#if os(macOS)
import AppKit
typealias NSFont = AppKit.NSFont
typealias NSColor = AppKit.NSColor
#else
import UIKit
typealias NSFont = UIFont
typealias NSColor = UIColor
#endif
```

### Step 5: Report Generators

**Sources/LocumTrackerReporting/Reports/EarningsReportGenerator.swift**
```swift
import Foundation
import LocumTrackerCore

/// Generates earnings reports from assignment and session data
public enum EarningsReportGenerator {
    /// Generate earnings report
    /// - Parameters:
    ///   - sessions: Session data to include
    ///   - config: Report configuration
    /// - Returns: Report data ready for export
    public static func generate(
        sessions: [SessionExportData],
        assignments: [AssignmentExportData],
        config: ReportConfiguration
    ) -> ReportData {
        let sections = groupSessions(sessions, by: config.groupBy)
        let summary = calculateSummary(sessions: sessions, assignments: assignments)

        return ReportData(
            title: "Earnings Report",
            subtitle: "Period: \(formatDateRange(config.startDate, config.endDate))",
            period: DateInterval(start: config.startDate, end: config.endDate),
            sections: sections,
            summary: summary
        )
    }

    private static func groupSessions(
        _ sessions: [SessionExportData],
        by grouping: GroupingOption
    ) -> [ReportSection] {
        switch grouping {
        case .month:
            return groupByMonth(sessions)
        case .assignment:
            return groupByAssignment(sessions)
        case .location:
            return groupByLocation(sessions)
        default:
            return groupByMonth(sessions)
        }
    }

    private static func groupByMonth(_ sessions: [SessionExportData]) -> [ReportSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfMonth(for: session.date)
        }

        return grouped.sorted { $0.key < $1.key }.map { (month, sessions) in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"

            let rows = sessions.map { session in
                ReportRow(
                    columns: ["Date", "Location", "Hours", "Type", "Earnings"],
                    values: [
                        .date(session.date),
                        .text(session.locationName),
                        .number(Int(session.durationHours)),
                        .text(session.sessionType),
                        .currency(session.earnings)
                    ]
                )
            }

            let subtotal = sessions.reduce(Decimal.zero) { $0 + $1.earnings }

            return ReportSection(
                title: formatter.string(from: month),
                rows: rows,
                subtotal: subtotal
            )
        }
    }

    private static func groupByAssignment(_ sessions: [SessionExportData]) -> [ReportSection] {
        // Similar implementation grouped by assignment
        return []
    }

    private static func groupByLocation(_ sessions: [SessionExportData]) -> [ReportSection] {
        // Similar implementation grouped by location
        return []
    }

    private static func calculateSummary(
        sessions: [SessionExportData],
        assignments: [AssignmentExportData]
    ) -> ReportSummary {
        let totalEarnings = sessions.reduce(Decimal.zero) { $0 + $1.earnings }
        let totalHours = sessions.reduce(0.0) { $0 + $1.durationHours }
        let fpsEligible = sessions.filter { $0.isFPSEligible }.count

        return ReportSummary(items: [
            SummaryItem(label: "Total Sessions", value: .number(sessions.count)),
            SummaryItem(label: "Total Hours", value: .number(Int(totalHours))),
            SummaryItem(label: "Total Earnings", value: .currency(totalEarnings)),
            SummaryItem(label: "FPS Eligible Sessions", value: .number(fpsEligible)),
            SummaryItem(label: "Average per Session", value: .currency(sessions.isEmpty ? 0 : totalEarnings / Decimal(sessions.count)))
        ])
    }

    private static func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

public struct AssignmentExportData: Sendable {
    public let id: UUID
    public let name: String
    public let locationName: String
    public let startDate: Date
    public let endDate: Date
    public let totalEarnings: Decimal
    public let sessionCount: Int

    public init(
        id: UUID,
        name: String,
        locationName: String,
        startDate: Date,
        endDate: Date,
        totalEarnings: Decimal,
        sessionCount: Int
    ) {
        self.id = id
        self.name = name
        self.locationName = locationName
        self.startDate = startDate
        self.endDate = endDate
        self.totalEarnings = totalEarnings
        self.sessionCount = sessionCount
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}
```

### Step 6: macOS Report Views

**LocumTrackerMac/Views/Reports/ReportsView.swift**
```swift
import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerReporting

struct ReportsView: View {
    @Bindable var navigationState: NavigationState
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]
    @Query private var sessions: [Session]
    @Query private var receipts: [Receipt]

    @State private var selectedReportType: ReportType = .earnings
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var groupBy: GroupingOption = .month
    @State private var generatedReport: ReportData?

    var body: some View {
        HSplitView {
            // Configuration panel
            Form {
                Section("Report Type") {
                    Picker("Type", selection: $selectedReportType) {
                        ForEach(ReportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                }

                Section("Date Range") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }

                Section("Grouping") {
                    Picker("Group by", selection: $groupBy) {
                        ForEach(GroupingOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                }

                Section {
                    Button("Generate Report") {
                        generateReport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(width: 250)
            .padding()

            // Report preview
            if let report = generatedReport {
                ReportPreviewView(report: report)
            } else {
                ContentUnavailableView(
                    "No Report Generated",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Configure options and click Generate Report")
                )
            }
        }
        .navigationTitle("Reports")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if generatedReport != nil {
                    Menu("Export") {
                        Button("Export as CSV") { exportReport(format: .csv) }
                        Button("Export as PDF") { exportReport(format: .pdf) }
                    }

                    Button(action: printReport) {
                        Label("Print", systemImage: "printer")
                    }
                }
            }
        }
    }

    private func generateReport() {
        let sessionData = sessions
            .filter { $0.date >= startDate && $0.date <= endDate }
            .map { session in
                SessionExportData(
                    date: session.date,
                    startTime: session.startTime,
                    endTime: session.endTime,
                    durationHours: Double(session.durationMinutes) / 60,
                    sessionType: session.sessionType.rawValue,
                    locationName: session.locationName ?? "Unknown",
                    mmmClassification: session.mmmClassification,
                    earnings: session.earnings,
                    isFPSEligible: session.isFPSEligible,
                    notes: session.notes
                )
            }

        let assignmentData = assignments.map { assignment in
            AssignmentExportData(
                id: assignment.id,
                name: assignment.name ?? "Unnamed",
                locationName: "Unknown", // Would resolve from locations
                startDate: assignment.startDate,
                endDate: assignment.endDate,
                totalEarnings: EarningsAggregationService.totalEarnings(for: assignment),
                sessionCount: assignment.sessions.count
            )
        }

        let config = ReportConfiguration(
            reportType: selectedReportType,
            startDate: startDate,
            endDate: endDate,
            groupBy: groupBy
        )

        generatedReport = EarningsReportGenerator.generate(
            sessions: sessionData,
            assignments: assignmentData,
            config: config
        )
    }

    private func exportReport(format: ExportFormat) {
        guard let report = generatedReport else { return }

        let data: Data
        switch format {
        case .csv:
            data = CSVExporter.export(report)
        case .pdf:
            // Convert report to invoice format or use dedicated PDF exporter
            data = Data()
        default:
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: format.fileExtension)!]
        savePanel.nameFieldStringValue = "report.\(format.fileExtension)"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? data.write(to: url)
            }
        }
    }

    private func printReport() {
        // Print implementation
    }
}

struct ReportPreviewView: View {
    let report: ReportData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading) {
                    Text(report.title)
                        .font(.title)
                        .fontWeight(.bold)
                    if let subtitle = report.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // Sections
                ForEach(Array(report.sections.enumerated()), id: \.offset) { _, section in
                    ReportSectionView(section: section)
                }

                Divider()

                // Summary
                ReportSummaryView(summary: report.summary)
            }
            .padding()
        }
    }
}

struct ReportSectionView: View {
    let section: ReportSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.headline)

            if let firstRow = section.rows.first {
                // Header row
                HStack {
                    ForEach(firstRow.columns, id: \.self) { column in
                        Text(column)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                        Text(value.stringValue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if let subtotal = section.subtotal {
                HStack {
                    Spacer()
                    Text("Subtotal: \(subtotal, format: .currency(code: "AUD"))")
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ReportSummaryView: View {
    let summary: ReportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                ForEach(Array(summary.items.enumerated()), id: \.offset) { _, item in
                    GridRow {
                        Text(item.label)
                            .foregroundStyle(.secondary)
                        Text(item.value.stringValue)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

### Step 7: Print Support

**LocumTrackerMac/Utilities/PrintService.swift**
```swift
import AppKit
import LocumTrackerReporting

enum PrintService {
    static func printReport(_ report: ReportData) {
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic

        let printView = ReportPrintView(report: report)
        let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }

    static func printInvoice(_ invoice: InvoiceData) {
        let pdfData = InvoiceGenerator.generatePDF(invoice)

        guard let pdfDocument = PDFDocument(data: pdfData),
              let page = pdfDocument.page(at: 0) else { return }

        let printInfo = NSPrintInfo.shared
        let printOperation = page.print(with: printInfo, autoRotate: true)
        printOperation.showsPrintPanel = true
        printOperation.run()
    }
}

class ReportPrintView: NSView {
    let report: ReportData

    init(report: ReportData) {
        self.report = report
        super.init(frame: NSRect(x: 0, y: 0, width: 595, height: 842))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw report content for printing
        // Similar to PDF rendering but using NSGraphicsContext
    }
}
```

## Testing Phase 4

### Unit Tests

```swift
// CSVExporterTests.swift
import XCTest
@testable import LocumTrackerReporting

final class CSVExporterTests: XCTestCase {
    func testExportReportToCSV() {
        let report = ReportData(
            title: "Test Report",
            period: DateInterval(start: Date(), duration: 86400),
            sections: [
                ReportSection(
                    title: "Section 1",
                    rows: [
                        ReportRow(columns: ["A", "B"], values: [.text("1"), .currency(100)])
                    ],
                    subtotal: 100
                )
            ],
            summary: ReportSummary(items: [
                SummaryItem(label: "Total", value: .currency(100))
            ])
        )

        let data = CSVExporter.export(report)
        let csv = String(data: data, encoding: .utf8)!

        XCTAssertTrue(csv.contains("Test Report"))
        XCTAssertTrue(csv.contains("Section 1"))
        XCTAssertTrue(csv.contains("$100.00"))
    }
}
```

### Manual Testing Checklist

- [ ] Reports generate correctly for all types
- [ ] CSV export produces valid CSV files
- [ ] PDF invoices render properly
- [ ] Print preview shows correct content
- [ ] Date range filtering works
- [ ] Grouping options produce correct output
- [ ] Export save dialog works

## Files Created

```
Packages/LocumTrackerReporting/
├── Package.swift
└── Sources/LocumTrackerReporting/
    ├── Export/
    │   ├── CSVExporter.swift
    │   └── PDFExporter.swift
    ├── Reports/
    │   ├── EarningsReportGenerator.swift
    │   └── FPSComplianceReportGenerator.swift
    ├── Invoices/
    │   ├── InvoiceGenerator.swift
    │   └── InvoiceRenderer.swift
    └── Models/
        ├── ExportFormat.swift
        ├── ReportData.swift
        └── InvoiceData.swift

LocumTrackerMac/
├── Views/Reports/
│   └── ReportsView.swift
├── Windows/
│   └── ReportWindowView.swift
└── Utilities/
    └── PrintService.swift
```

## Estimated Scope

- **New package files**: ~15
- **macOS app files**: ~5
- **Test files**: ~5
- **Total lines**: ~2000-2500

## Next Phase

Proceed to [Phase 5: Polish & Integration](05_polish_integration.md) for final refinements and TestFlight preparation.
