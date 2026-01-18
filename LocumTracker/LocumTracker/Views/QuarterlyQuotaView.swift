import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// View displaying quarterly WIP FPS session quota progress
struct QuarterlyQuotaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]
    @Query(sort: \Location.name) private var locations: [Location]
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    /// Sessions in the current quarter that meet FPS requirements (3+ hours, MMM 3-7)
    private var currentQuarterSessions: [Session] {
        let calendar = Calendar.current
        guard let quarterInterval = calendar.dateInterval(of: .quarter, for: Date()) else {
            return []
        }

        return sessions.filter { session in
            // Check session is in current quarter
            guard session.startTime >= quarterInterval.start,
                  session.startTime < quarterInterval.end else {
                return false
            }

            // Check session meets FPS requirements
            let isValidDuration = session.durationHours >= RuralSubsidyService.minimumSessionHours
            let isEligibleLocation = RuralSubsidyService.isEligible(mmmClassification: session.mmmClassification)

            return isValidDuration && isEligibleLocation
        }
    }

    /// Session count capped at 104
    private var countedSessions: Int {
        RuralSubsidyService.countedSessionsForQuarter(currentQuarterSessions.count)
    }

    /// Progress percentage toward 21-session minimum
    private var progressPercentage: Double {
        Double(countedSessions) / Double(QuarterlyQuota.minimumSessions) * 100
    }

    /// Whether quota is met
    private var quotaMet: Bool {
        RuralSubsidyService.isActiveQuarter(sessions: countedSessions)
    }

    /// Sessions grouped by MMM classification
    private var sessionsByMMM: [Int: Int] {
        var counts: [Int: Int] = [:]
        for session in currentQuarterSessions {
            counts[session.mmmClassification, default: 0] += 1
        }
        return counts
    }

    /// Sessions grouped by date (for per-day validation)
    private var sessionsPerDay: [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for session in currentQuarterSessions {
            let day = calendar.startOfDay(for: session.startTime)
            counts[day, default: 0] += 1
        }
        return counts
    }

    /// Days with more than 2 sessions (exceeds FPS limit)
    private var daysExceedingLimit: Int {
        sessionsPerDay.values.filter { $0 > QuarterlyQuota.maximumSessionsPerDay }.count
    }

    /// Predominant MMM classification
    private var predominantMMM: Int {
        sessionsByMMM.max { $0.value < $1.value }?.key ?? 0
    }

    /// Current quarter string
    private var quarterString: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let quarter = (month - 1) / 3 + 1
        let year = calendar.component(.year, from: Date())
        return "\(year) Q\(quarter)"
    }

    /// Days remaining in quarter
    private var daysRemaining: Int {
        let calendar = Calendar.current
        guard let quarterInterval = calendar.dateInterval(of: .quarter, for: Date()) else {
            return 0
        }
        let components = calendar.dateComponents([.day], from: Date(), to: quarterInterval.end)
        return max(0, components.day ?? 0)
    }

    var body: some View {
        List {
            progressSection
            summarySection
            if !sessionsByMMM.isEmpty {
                mmmBreakdownSection
            }
            if daysExceedingLimit > 0 {
                warningsSection
            }
            paymentInfoSection
            quarterHistoryLinkSection
        }
        .navigationTitle("FPS Quota")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - View Components

    private var progressSection: some View {
        Section {
            VStack(spacing: ProgressConstants.sectionSpacing) {
                // Quarter label
                Text(quarterString)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(
                            Color.gray.opacity(ProgressConstants.ringBackgroundOpacity),
                            lineWidth: ProgressConstants.ringLineWidth
                        )

                    Circle()
                        .trim(from: 0, to: min(1, progressPercentage / 100))
                        .stroke(
                            progressColor,
                            style: StrokeStyle(lineWidth: ProgressConstants.ringLineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: progressPercentage)

                    VStack(spacing: ProgressConstants.labelSpacing) {
                        Text("\(countedSessions)")
                            .font(.system(size: ProgressConstants.countFontSize, weight: .bold))
                        Text("of \(QuarterlyQuota.minimumSessions)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: ProgressConstants.ringSize, height: ProgressConstants.ringSize)
                .padding(.vertical)

                // Status message
                statusMessage
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private var statusMessage: some View {
        HStack {
            Image(systemName: quotaMet ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .foregroundStyle(quotaMet ? .green : .orange)
            Text(quotaMet ? "Quarter quota met!" : "\(QuarterlyQuota.minimumSessions - countedSessions) more sessions needed")
                .font(.headline)
                .foregroundStyle(quotaMet ? .green : .primary)
        }
    }

    private var progressColor: Color {
        if quotaMet {
            return .green
        } else if progressPercentage >= 75 {
            return .blue
        } else if progressPercentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    private var summarySection: some View {
        Section("Quarter Summary") {
            LabeledContent("Valid Sessions") {
                Text("\(currentQuarterSessions.count)")
            }

            LabeledContent("Counted Sessions") {
                Text("\(countedSessions)")
                if currentQuarterSessions.count > QuarterlyQuota.maximumSessions {
                    Text("(capped)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Days Remaining") {
                Text("\(daysRemaining)")
            }

            if predominantMMM > 0 {
                LabeledContent("Predominant MMM") {
                    MMMBadge(classification: predominantMMM)
                }
            }
        }
    }

    private var mmmBreakdownSection: some View {
        Section("Sessions by MMM") {
            ForEach([3, 4, 5, 6, 7], id: \.self) { mmm in
                let count = sessionsByMMM[mmm] ?? 0
                if count > 0 {
                    HStack {
                        MMMBadge(classification: mmm)
                        Spacer()
                        Text("\(count) session\(count == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)

                        // Progress bar
                        GeometryReader { geometry in
                            let percentage = Double(count) / Double(max(1, countedSessions))
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: BreakdownConstants.barCornerRadius)
                                    .fill(Color.gray.opacity(BreakdownConstants.barBackgroundOpacity))
                                    .frame(height: BreakdownConstants.barHeight)

                                RoundedRectangle(cornerRadius: BreakdownConstants.barCornerRadius)
                                    .fill(MMMColors.color(for: mmm))
                                    .frame(width: geometry.size.width * percentage, height: BreakdownConstants.barHeight)
                            }
                        }
                        .frame(width: BreakdownConstants.barWidth, height: BreakdownConstants.barHeight)
                    }
                }
            }
        }
    }

    private var warningsSection: some View {
        Section {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("\(daysExceedingLimit) day\(daysExceedingLimit == 1 ? "" : "s") with >2 sessions")
                        .font(.subheadline)
                    Text("Only 2 sessions per day are counted for FPS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Warnings")
        }
    }

    private var paymentInfoSection: some View {
        Section("Potential Annual Payment") {
            if predominantMMM > 0 {
                let vrPayment = RuralSubsidyService.getAnnualPayment(
                    yearLevel: 1,
                    mmmClassification: predominantMMM,
                    registrationStatus: .vocationallyRegistered
                )
                let nonVRPayment = RuralSubsidyService.getAnnualPayment(
                    yearLevel: 1,
                    mmmClassification: predominantMMM,
                    registrationStatus: .nonVocational
                )

                LabeledContent("VR/Training (Year 1)") {
                    Text(CurrencyFormatter.format(vrPayment))
                        .foregroundStyle(.green)
                }

                LabeledContent("Non-VR (Year 1)") {
                    Text(CurrencyFormatter.format(nonVRPayment))
                        .foregroundStyle(.green)
                }

                Text("Based on predominant MMM\(predominantMMM). Actual payment depends on registration status and year level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Record sessions to see potential payments")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quarterHistoryLinkSection: some View {
        Section {
            NavigationLink {
                ActiveQuarterHistoryView()
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Quarter History")
                            .font(.headline)
                        Text("Track eligibility across multiple quarters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Constants

private enum ProgressConstants {
    static let ringSize: CGFloat = 180
    static let ringLineWidth: CGFloat = 16
    static let ringBackgroundOpacity: Double = 0.2
    static let countFontSize: CGFloat = 48
    static let labelSpacing: CGFloat = 4
    static let sectionSpacing: CGFloat = 16
}

private enum BreakdownConstants {
    static let barWidth: CGFloat = 80
    static let barHeight: CGFloat = 8
    static let barCornerRadius: CGFloat = 4
    static let barBackgroundOpacity: Double = 0.2
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        Location.self,
        Assignment.self,
        DailyRecord.self,
        Session.self
    ])
    let container = try! ModelContainer(for: schema, configurations: config)

    // Create sample data
    let location = Location(
        name: "Royal Darwin Hospital",
        address: "Rocklands Dr, Tiwi NT 0810",
        mmmClassification: 5
    )
    container.mainContext.insert(location)

    let assignment = Assignment(
        locationId: location.id,
        rateStructure: .hourlyRate,
        hourlyRate: 150.0,
        startDate: Date().addingTimeInterval(-30 * 86400),
        endDate: Date().addingTimeInterval(60 * 86400),
        status: .active
    )
    container.mainContext.insert(assignment)

    let dailyRecord = DailyRecord(
        assignmentId: assignment.id,
        date: Date()
    )
    container.mainContext.insert(dailyRecord)

    // Add sample sessions
    for i in 0..<15 {
        let session = Session(
            dailyRecordId: dailyRecord.id,
            startTime: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
            endTime: Calendar.current.date(byAdding: .hour, value: 8, to: Calendar.current.date(byAdding: .day, value: -i, to: Date())!)!,
            sessionType: .regular,
            mmmClassification: i % 3 == 0 ? 6 : 5
        )
        container.mainContext.insert(session)
    }

    return NavigationStack {
        QuarterlyQuotaView()
    }
    .modelContainer(container)
}
