// LocumTracker
// Copyright (C) 2025 Dr Horst Herb
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

// Note: EarningsPeriod is now imported from LocumTrackerCore

/// Dashboard view displaying earnings summary and breakdown
struct EarningsDashboardView: View {
    @Query(sort: \DailyRecord.date, order: .reverse) private var dailyRecords: [DailyRecord]
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]
    @Query(sort: \Location.name) private var locations: [Location]
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    @State private var selectedPeriod: EarningsPeriod = .month
    @State private var showingExportOptions = false
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false

    /// Filtered daily records based on selected period
    private var filteredRecords: [DailyRecord] {
        let startDate = selectedPeriod.startDate()
        return dailyRecords.filter { $0.date >= startDate }
    }

    /// Filtered sessions based on selected period
    private var filteredSessions: [Session] {
        let startDate = selectedPeriod.startDate()
        return sessions.filter { $0.startTime >= startDate }
    }

    /// Filtered receipts based on selected period
    private var filteredReceipts: [Receipt] {
        let startDate = selectedPeriod.startDate()
        return receipts.filter { $0.date >= startDate }
    }

    /// Total earnings for the period
    private var totalEarnings: Double {
        filteredRecords.reduce(0) { $0 + $1.totalEarnings }
    }

    /// Total expenses for the period
    private var totalExpenses: Double {
        filteredReceipts.reduce(0) { $0 + $1.amount }
    }

    /// Net earnings (earnings minus expenses)
    private var netEarnings: Double {
        totalEarnings - totalExpenses
    }

    /// Total hours worked for the period
    private var totalHoursWorked: Double {
        filteredSessions.reduce(0) { $0 + $1.durationHours }
    }

    /// Earnings breakdown by assignment
    private var earningsByAssignment: [(assignment: Assignment, location: Location?, earnings: Double)] {
        let recordsByAssignment = Dictionary(grouping: filteredRecords) { $0.assignmentId }

        return assignments.compactMap { assignment in
            let earnings = recordsByAssignment[assignment.id]?.reduce(0) { $0 + $1.totalEarnings } ?? 0
            guard earnings > 0 else { return nil }
            let location = locations.first { $0.id == assignment.locationId }
            return (assignment, location, earnings)
        }.sorted { $0.earnings > $1.earnings }
    }

    /// Earnings breakdown by location
    private var earningsByLocation: [(location: Location, earnings: Double)] {
        var locationEarnings: [UUID: Double] = [:]

        for assignment in assignments {
            let recordsByAssignment = filteredRecords.filter { $0.assignmentId == assignment.id }
            let earnings = recordsByAssignment.reduce(0) { $0 + $1.totalEarnings }
            locationEarnings[assignment.locationId, default: 0] += earnings
        }

        return locations.compactMap { location in
            let earnings = locationEarnings[location.id] ?? 0
            guard earnings > 0 else { return nil }
            return (location, earnings)
        }.sorted { $0.earnings > $1.earnings }
    }

    /// Total subsidy earnings for the period
    private var totalSubsidies: Double {
        filteredSessions.compactMap(\.subsidyAmount).reduce(0, +)
    }

    /// Generates the earnings report for export
    private func generateReport() -> EarningsReport {
        let periodStart = selectedPeriod.startDate()
        let periodEnd = Date()

        // Pre-group sessions by their daily record so a day's earnings can be
        // split across its sessions (a day may contain more than one session).
        let sessionsByRecord = Dictionary(grouping: filteredSessions, by: { $0.dailyRecordId })

        // Build report rows from sessions
        let rows: [EarningsReportRow] = filteredSessions.compactMap { session in
            // Find the assignment and location for this session
            guard let dailyRecord = filteredRecords.first(where: { $0.id == session.dailyRecordId }),
                  let assignment = assignments.first(where: { $0.id == dailyRecord.assignmentId }),
                  let location = locations.first(where: { $0.id == assignment.locationId }) else {
                return nil
            }

            // Split the day's total earnings across its sessions in proportion to
            // hours worked, so multi-session days are not double-counted and per-row
            // earnings stay reconciled with the summary total (see
            // EarningsAggregationService.proportionalSessionEarnings).
            let recordSessions = sessionsByRecord[session.dailyRecordId] ?? [session]
            let recordHours = recordSessions.reduce(0) { $0 + $1.durationHours }
            let earnings = EarningsAggregationService.proportionalSessionEarnings(
                dayTotal: dailyRecord.totalEarnings,
                sessionHours: session.durationHours,
                totalSessionHours: recordHours,
                sessionCount: recordSessions.count
            )

            return EarningsReportRow(
                date: session.startTime,
                locationName: location.name,
                mmmClassification: session.mmmClassification,
                sessionType: session.sessionType.description,
                hoursWorked: session.durationHours,
                earnings: earnings,
                subsidyAmount: session.subsidyAmount,
                notes: session.notes
            )
        }.sorted { $0.date < $1.date }

        let effectiveRate = totalHoursWorked > 0 ? totalEarnings / totalHoursWorked : 0

        let summary = EarningsReportSummary(
            periodStart: periodStart,
            periodEnd: periodEnd,
            totalEarnings: totalEarnings,
            totalSubsidies: totalSubsidies,
            totalExpenses: totalExpenses,
            netEarnings: netEarnings,
            totalHoursWorked: totalHoursWorked,
            effectiveHourlyRate: effectiveRate
        )

        return EarningsReport(generatedAt: Date(), summary: summary, rows: rows)
    }

    /// Exports the report to a temporary file and returns the URL
    private func exportReport(format: ExportFormat) -> URL? {
        let report = generateReport()
        guard let content = EarningsExportService.export(report, format: format) else { return nil }

        let filename = EarningsExportService.suggestedFilename(for: report, format: format)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    var body: some View {
        List {
            periodSelector
            summarySection
            if !earningsByAssignment.isEmpty {
                assignmentBreakdownSection
            }
            if !earningsByLocation.isEmpty {
                locationBreakdownSection
            }
            if filteredRecords.isEmpty && filteredSessions.isEmpty {
                emptyStateSection
            }
        }
        .navigationTitle("Earnings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        if let url = exportReport(format: .csv) {
                            exportedFileURL = url
                            showingShareSheet = true
                        }
                    } label: {
                        Label("Export CSV", systemImage: "tablecells")
                    }
                    Button {
                        if let url = exportReport(format: .json) {
                            exportedFileURL = url
                            showingShareSheet = true
                        }
                    } label: {
                        Label("Export JSON", systemImage: "curlybraces")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(filteredSessions.isEmpty)
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        #endif
    }

    // MARK: - View Components

    private var periodSelector: some View {
        Section {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(EarningsPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            VStack(spacing: SummaryConstants.cardSpacing) {
                // Main earnings card
                HStack {
                    VStack(alignment: .leading, spacing: SummaryConstants.labelSpacing) {
                        Text("Total Earnings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(totalEarnings))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: SummaryConstants.labelSpacing) {
                        Text("Hours Worked")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f hrs", totalHoursWorked))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, SummaryConstants.cardPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total earnings: \(CurrencyFormatter.format(totalEarnings)), Hours worked: \(String(format: "%.1f", totalHoursWorked)) hours")
                .accessibilityIdentifier("earningsSummaryMain")

                Divider()

                // Expenses and net
                HStack {
                    VStack(alignment: .leading, spacing: SummaryConstants.labelSpacing) {
                        Text("Expenses")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(totalExpenses))
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: SummaryConstants.labelSpacing) {
                        Text("Net Earnings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.format(netEarnings))
                            .font(.headline)
                            .foregroundColor(netEarnings >= 0 ? .primary : .red)
                    }
                }
                .padding(.vertical, SummaryConstants.cardPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Expenses: \(CurrencyFormatter.format(totalExpenses)), Net earnings: \(CurrencyFormatter.format(netEarnings))")
                .accessibilityIdentifier("earningsSummaryNet")

                // Effective hourly rate
                if totalHoursWorked > 0 {
                    Divider()

                    HStack {
                        Text("Effective Hourly Rate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.format(totalEarnings / totalHoursWorked) + "/hr")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, SummaryConstants.cardPadding)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Effective hourly rate: \(CurrencyFormatter.format(totalEarnings / totalHoursWorked)) per hour")
                    .accessibilityIdentifier("earningsSummaryRate")
                }
            }
        }
    }

    private var assignmentBreakdownSection: some View {
        Section("By Assignment") {
            ForEach(earningsByAssignment, id: \.assignment.id) { item in
                AssignmentEarningsRow(
                    assignment: item.assignment,
                    location: item.location,
                    earnings: item.earnings,
                    totalEarnings: totalEarnings
                )
            }
        }
    }

    private var locationBreakdownSection: some View {
        Section("By Location") {
            ForEach(earningsByLocation, id: \.location.id) { item in
                LocationEarningsRow(
                    location: item.location,
                    earnings: item.earnings,
                    totalEarnings: totalEarnings
                )
            }
        }
    }

    private var emptyStateSection: some View {
        Section {
            ContentUnavailableView {
                Label("No Earnings Data", systemImage: "chart.bar")
            } description: {
                Text("Record sessions for your assignments to see earnings here.")
            }
        }
    }
}

// MARK: - Assignment Earnings Row

/// Row displaying earnings for a single assignment
struct AssignmentEarningsRow: View {
    let assignment: Assignment
    let location: Location?
    let earnings: Double
    let totalEarnings: Double

    /// Cached date formatter for display
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    private var percentage: Double {
        totalEarnings > 0 ? (earnings / totalEarnings) * 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RowConstants.verticalSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: RowConstants.labelSpacing) {
                    Text(location?.name ?? "Unknown Location")
                        .font(.headline)

                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RowConstants.labelSpacing) {
                    Text(CurrencyFormatter.format(earnings))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(format: "%.1f%%", percentage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: RowConstants.barCornerRadius)
                        .fill(Color.gray.opacity(RowConstants.barBackgroundOpacity))
                        .frame(height: RowConstants.barHeight)

                    RoundedRectangle(cornerRadius: RowConstants.barCornerRadius)
                        .fill(Color.green)
                        .frame(
                            width: geometry.size.width * CGFloat(percentage / 100),
                            height: RowConstants.barHeight
                        )
                }
            }
            .frame(height: RowConstants.barHeight)
            .accessibilityHidden(true)
        }
        .padding(.vertical, RowConstants.rowPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location?.name ?? "Unknown Location"), \(dateRangeText), \(CurrencyFormatter.format(earnings)), \(String(format: "%.1f", percentage)) percent of total")
        .accessibilityIdentifier("assignmentEarningsRow_\(assignment.id)")
    }

    private var dateRangeText: String {
        let formatter = AssignmentEarningsRow.dateFormatter
        return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
    }
}

// MARK: - Location Earnings Row

/// Row displaying earnings for a single location
struct LocationEarningsRow: View {
    let location: Location
    let earnings: Double
    let totalEarnings: Double

    private var percentage: Double {
        totalEarnings > 0 ? (earnings / totalEarnings) * 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RowConstants.verticalSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: RowConstants.labelSpacing) {
                    HStack {
                        Text(location.name)
                            .font(.headline)
                        MMMBadge(classification: location.mmmClassification)
                    }

                    Text(location.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RowConstants.labelSpacing) {
                    Text(CurrencyFormatter.format(earnings))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(format: "%.1f%%", percentage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: RowConstants.barCornerRadius)
                        .fill(Color.gray.opacity(RowConstants.barBackgroundOpacity))
                        .frame(height: RowConstants.barHeight)

                    RoundedRectangle(cornerRadius: RowConstants.barCornerRadius)
                        .fill(locationColor)
                        .frame(
                            width: geometry.size.width * CGFloat(percentage / 100),
                            height: RowConstants.barHeight
                        )
                }
            }
            .frame(height: RowConstants.barHeight)
            .accessibilityHidden(true)
        }
        .padding(.vertical, RowConstants.rowPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.name), MMM\(location.mmmClassification), \(CurrencyFormatter.format(earnings)), \(String(format: "%.1f", percentage)) percent of total")
        .accessibilityIdentifier("locationEarningsRow_\(location.id)")
    }

    private var locationColor: Color {
        MMMColors.color(for: location.mmmClassification)
    }
}

// MARK: - Share Sheet

#if os(iOS)
import UIKit

/// UIKit wrapper for sharing files via UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Constants

private enum SummaryConstants {
    static let cardSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 4
    static let labelSpacing: CGFloat = 4
}

private enum RowConstants {
    static let verticalSpacing: CGFloat = 8
    static let labelSpacing: CGFloat = 2
    static let rowPadding: CGFloat = 4
    static let barHeight: CGFloat = 6
    static let barCornerRadius: CGFloat = 3
    static let barBackgroundOpacity: Double = 0.2
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        Location.self,
        Assignment.self,
        DailyRecord.self,
        Session.self,
        Receipt.self
    ])
    let container = try! ModelContainer(for: schema, configurations: config)

    // Create sample data
    let location = Location(
        name: "Royal Darwin Hospital",
        address: "Rocklands Dr, Tiwi NT 0810",
        mmmClassification: 5
    )
    container.mainContext.insert(location)

    let secondsPerDay: TimeInterval = 86400
    let assignment = Assignment(
        locationId: location.id,
        rateStructure: .hourlyRate,
        hourlyRate: 150.0,
        startDate: Date().addingTimeInterval(-14 * secondsPerDay),
        endDate: Date(),
        status: .active
    )
    container.mainContext.insert(assignment)

    let dailyRecord = DailyRecord(
        assignmentId: assignment.id,
        date: Date()
    )
    dailyRecord.totalEarnings = 1200.0
    container.mainContext.insert(dailyRecord)

    let session = Session(
        dailyRecordId: dailyRecord.id,
        startTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
        endTime: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date())!,
        sessionType: .regular,
        mmmClassification: 5
    )
    container.mainContext.insert(session)

    return NavigationStack {
        EarningsDashboardView()
    }
    .modelContainer(container)
}
