import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// View displaying multi-quarter history for WIP FPS eligibility tracking
///
/// Shows historical quarters with their active/inactive status and tracks
/// progress toward the required active quarters for payment eligibility.
struct ActiveQuarterHistoryView: View {
    @Query(sort: \Session.startTime, order: .reverse) private var sessions: [Session]

    /// Participant status affects eligibility requirements
    @State private var isNewParticipant: Bool = true

    /// Predominant MMM classification affects requirements for new participants
    @State private var predominantMMM: Int = 5

    /// Scaled metric for Dynamic Type support on eligibility dots
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 16

    // MARK: - Computed Properties

    /// Sessions grouped by quarter
    private var sessionsByQuarter: [QuarterInfo] {
        let calendar = Calendar.current
        var quarterMap: [String: [Session]] = [:]

        for session in sessions {
            // Only count eligible sessions (3+ hours, MMM 3-7)
            let isValidDuration = session.durationHours >= RuralSubsidyService.minimumSessionHours
            let isEligibleLocation = RuralSubsidyService.isEligible(mmmClassification: session.mmmClassification)

            guard isValidDuration && isEligibleLocation else { continue }

            let quarterKey = quarterIdentifier(for: session.startTime)
            quarterMap[quarterKey, default: []].append(session)
        }

        // Generate quarter info for the reference period
        let referencePeriod = referenceQuarterCount
        var quarters: [QuarterInfo] = []
        let now = Date()

        for offset in 0..<referencePeriod {
            guard let quarterStart = calendar.date(byAdding: .month, value: -offset * 3, to: quarterStartDate(for: now)) else {
                continue
            }

            let key = quarterIdentifier(for: quarterStart)
            let sessionsInQuarter = quarterMap[key] ?? []
            let countedSessions = countSessionsForQuarter(sessionsInQuarter)

            quarters.append(QuarterInfo(
                identifier: key,
                startDate: quarterStart,
                sessions: countedSessions,
                isActive: RuralSubsidyService.isActiveQuarter(sessions: countedSessions)
            ))
        }

        return quarters
    }

    /// Number of quarters to show based on participant status and MMM
    private var referenceQuarterCount: Int {
        if isNewParticipant {
            return (3...5).contains(predominantMMM)
                ? RuralSubsidyService.newParticipantMMM35ReferencePeriod
                : RuralSubsidyService.newParticipantMMM67ReferencePeriod
        }
        return RuralSubsidyService.continuingReferencePeriod
    }

    /// Required active quarters for eligibility
    private var requiredActiveQuarters: Int {
        if isNewParticipant {
            return (3...5).contains(predominantMMM)
                ? RuralSubsidyService.newParticipantMMM35RequiredQuarters
                : RuralSubsidyService.newParticipantMMM67RequiredQuarters
        }
        return RuralSubsidyService.continuingRequiredQuarters
    }

    /// Number of active quarters in the reference period
    private var activeQuarterCount: Int {
        sessionsByQuarter.filter { $0.isActive }.count
    }

    /// Eligibility result from service
    private var eligibilityResult: EligibilityResult {
        RuralSubsidyService.checkEligibility(
            activeQuartersInPeriod: activeQuarterCount,
            isNewParticipant: isNewParticipant,
            predominantMMM: predominantMMM
        )
    }

    // MARK: - Body

    var body: some View {
        List {
            eligibilitySection
            settingsSection
            quarterHistorySection
        }
        .navigationTitle("Quarter History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    // MARK: - View Components

    private var eligibilitySection: some View {
        Section {
            VStack(spacing: EligibilityConstants.sectionSpacing) {
                // Progress indicator
                HStack(spacing: EligibilityConstants.progressSpacing) {
                    ForEach(0..<requiredActiveQuarters, id: \.self) { index in
                        Circle()
                            .fill(index < activeQuarterCount ? Color.green : Color.gray.opacity(EligibilityConstants.inactiveDotOpacity))
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .accessibilityHidden(true)

                // Status text
                Text("\(activeQuarterCount) of \(requiredActiveQuarters) active quarters")
                    .font(.headline)

                Text("in \(referenceQuarterCount)-quarter reference period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Eligibility status
                HStack {
                    Image(systemName: eligibilityResult.isEligible ? "checkmark.seal.fill" : "clock.badge.exclamationmark")
                        .foregroundStyle(eligibilityResult.isEligible ? .green : .orange)
                        .accessibilityHidden(true)
                    Text(eligibilityResult.progressDescription)
                        .font(.headline)
                        .foregroundStyle(eligibilityResult.isEligible ? .green : .primary)
                }
                .padding(.top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(eligibilityAccessibilityLabel)
            .accessibilityIdentifier("eligibilityStatus")
        }
    }

    /// Accessibility label for eligibility section
    private var eligibilityAccessibilityLabel: String {
        let status = eligibilityResult.isEligible ? "Eligible" : "Not yet eligible"
        return "\(status). \(activeQuarterCount) of \(requiredActiveQuarters) active quarters in \(referenceQuarterCount)-quarter reference period. \(eligibilityResult.progressDescription)"
    }

    private var settingsSection: some View {
        Section("Your Status") {
            Toggle("New Participant", isOn: $isNewParticipant)

            if isNewParticipant {
                Picker("Predominant MMM", selection: $predominantMMM) {
                    ForEach(3...7, id: \.self) { mmm in
                        HStack {
                            Text("MMM\(mmm)")
                            Text(mmmDescription(mmm))
                                .foregroundStyle(.secondary)
                        }
                        .tag(mmm)
                    }
                }
            }

            VStack(alignment: .leading, spacing: SettingsConstants.descriptionSpacing) {
                Text(requirementsDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quarterHistorySection: some View {
        Section("Quarter History") {
            ForEach(sessionsByQuarter) { quarter in
                HStack {
                    // Quarter identifier
                    Text(quarter.displayName)
                        .font(.headline)

                    Spacer()

                    // Session count
                    VStack(alignment: .trailing) {
                        Text("\(quarter.sessions) sessions")
                            .font(.subheadline)

                        if quarter.isActive {
                            Text("Active")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if quarter.sessions > 0 {
                            Text("\(QuarterlyQuota.minimumSessions - quarter.sessions) more needed")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("No eligible sessions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Status indicator
                    Image(systemName: quarter.isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(quarter.isActive ? .green : .gray)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, QuarterRowConstants.verticalPadding)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(quarterAccessibilityLabel(for: quarter))
                .accessibilityIdentifier("quarterHistoryRow_\(quarter.identifier)")
            }
        }
    }

    /// Accessibility label for a quarter row
    private func quarterAccessibilityLabel(for quarter: QuarterInfo) -> String {
        let status: String
        if quarter.isActive {
            status = "Active quarter"
        } else if quarter.sessions > 0 {
            status = "\(QuarterlyQuota.minimumSessions - quarter.sessions) more sessions needed"
        } else {
            status = "No eligible sessions"
        }
        return "\(quarter.displayName), \(quarter.sessions) sessions, \(status)"
    }

    // MARK: - Helper Methods

    /// Gets the quarter identifier string for a date
    private func quarterIdentifier(for date: Date) -> String {
        FPSQuarterService.quarterIdentifier(for: date)
    }

    /// Gets the start of the quarter for a date
    private func quarterStartDate(for date: Date) -> Date {
        FPSQuarterService.quarterStartDate(for: date)
    }

    /// Counts valid sessions for a quarter, enforcing 2 per day limit
    private func countSessionsForQuarter(_ sessions: [Session]) -> Int {
        let calendar = Calendar.current
        var sessionsPerDay: [Date: Int] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)
            sessionsPerDay[day, default: 0] += 1
        }

        return FPSQuarterService.countSessionsForQuarter(sessionsPerDay)
    }

    /// MMM classification description
    private func mmmDescription(_ mmm: Int) -> String {
        RuralSubsidyService.eligibleMMMDescription(mmm)
    }

    /// Requirements description based on current settings
    private var requirementsDescription: String {
        if isNewParticipant {
            if (3...5).contains(predominantMMM) {
                return "New participants in MMM 3-5 need 8 active quarters in 16 quarters"
            } else {
                return "New participants in MMM 6-7 need 4 active quarters in 8 quarters"
            }
        }
        return "Continuing participants need 4 active quarters in 8 quarters"
    }
}

// MARK: - Supporting Types

/// Information about a single quarter
struct QuarterInfo: Identifiable {
    let identifier: String
    let startDate: Date
    let sessions: Int
    let isActive: Bool

    var id: String { identifier }

    var displayName: String {
        let components = identifier.split(separator: "-")
        guard components.count == 2 else { return identifier }
        return "\(components[1]) \(components[0])"
    }
}

// MARK: - Constants

private enum EligibilityConstants {
    static let sectionSpacing: CGFloat = 12
    static let progressSpacing: CGFloat = 8
    static let dotSize: CGFloat = 16
    static let inactiveDotOpacity: Double = 0.3
}

private enum SettingsConstants {
    static let descriptionSpacing: CGFloat = 4
}

private enum QuarterRowConstants {
    static let verticalPadding: CGFloat = 4
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

    // Create sample sessions across multiple quarters
    let calendar = Calendar.current
    let now = Date()

    for quarterOffset in 0..<4 {
        guard let quarterStart = calendar.date(byAdding: .month, value: -quarterOffset * 3, to: now) else {
            continue
        }

        let sessionsThisQuarter = quarterOffset == 0 ? 15 : (quarterOffset == 1 ? 25 : (quarterOffset == 2 ? 8 : 22))

        for sessionIndex in 0..<sessionsThisQuarter {
            guard let sessionDate = calendar.date(byAdding: .day, value: sessionIndex, to: quarterStart) else {
                continue
            }

            let session = Session(
                dailyRecordId: UUID(),
                startTime: sessionDate,
                endTime: calendar.date(byAdding: .hour, value: 8, to: sessionDate)!,
                sessionType: .regular,
                mmmClassification: 5
            )
            container.mainContext.insert(session)
        }
    }

    return NavigationStack {
        ActiveQuarterHistoryView()
    }
    .modelContainer(container)
}
