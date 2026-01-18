import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// Time period options for earnings filtering
enum EarningsPeriod: String, CaseIterable {
    case week = "This Week"
    case month = "This Month"
    case quarter = "This Quarter"
    case year = "This Year"
    case all = "All Time"

    /// Returns the start date for this period
    func startDate(from referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        case .quarter:
            return calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: referenceDate) ?? referenceDate
        case .all:
            return Date.distantPast
        }
    }
}

/// Dashboard view displaying earnings summary and breakdown
struct EarningsDashboardView: View {
    @Query(sort: \DailyRecord.date, order: .reverse) private var dailyRecords: [DailyRecord]
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]
    @Query(sort: \Location.name) private var locations: [Location]
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    @State private var selectedPeriod: EarningsPeriod = .month

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
                            .foregroundStyle(netEarnings >= 0 ? .primary : .red)
                    }
                }
                .padding(.vertical, SummaryConstants.cardPadding)

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
        }
        .padding(.vertical, RowConstants.rowPadding)
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
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
        }
        .padding(.vertical, RowConstants.rowPadding)
    }

    private var locationColor: Color {
        MMMColors.color(for: location.mmmClassification)
    }
}

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
