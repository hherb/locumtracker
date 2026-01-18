import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// View displaying sessions for an assignment grouped by daily record
struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var dailyRecords: [DailyRecord]

    let assignment: Assignment
    let location: Location?

    @State private var showingAddSession = false

    init(assignment: Assignment, location: Location?) {
        self.assignment = assignment
        self.location = location

        // Filter sessions and daily records by assignment
        let assignmentId = assignment.id
        _dailyRecords = Query(
            filter: #Predicate<DailyRecord> { $0.assignmentId == assignmentId },
            sort: \DailyRecord.date,
            order: .reverse
        )
        _sessions = Query(sort: \Session.startTime, order: .reverse)
    }

    /// Sessions grouped by their daily record
    private var sessionsByRecord: [UUID: [Session]] {
        let recordIds = Set(dailyRecords.map(\.id))
        return Dictionary(grouping: sessions.filter { recordIds.contains($0.dailyRecordId) }) {
            $0.dailyRecordId
        }
    }

    var body: some View {
        List {
            if dailyRecords.isEmpty {
                emptyStateView
            } else {
                ForEach(dailyRecords) { record in
                    Section {
                        if let recordSessions = sessionsByRecord[record.id], !recordSessions.isEmpty {
                            ForEach(recordSessions) { session in
                                SessionRowView(session: session)
                            }
                            .onDelete { offsets in
                                deleteSessions(at: offsets, from: record)
                            }
                        } else {
                            Text("No sessions recorded")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    } header: {
                        DailyRecordHeaderView(record: record)
                    }
                }
            }
        }
        .navigationTitle("Sessions")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSession = true
                } label: {
                    Label("Add Session", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSession) {
            AddSessionSheet(
                isPresented: $showingAddSession,
                assignment: assignment,
                mmmClassification: location?.mmmClassification ?? 1
            )
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sessions", systemImage: "clock.badge.questionmark")
        } description: {
            Text("Record your first work session for this assignment.")
        } actions: {
            Button("Add Session") {
                showingAddSession = true
            }
        }
    }

    private func deleteSessions(at offsets: IndexSet, from record: DailyRecord) {
        guard let recordSessions = sessionsByRecord[record.id] else { return }
        for index in offsets {
            modelContext.delete(recordSessions[index])
        }
    }
}

// MARK: - Session Row View

/// Row view displaying a single session
struct SessionRowView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: RowConstants.verticalSpacing) {
            HStack {
                SessionTypeBadge(type: session.sessionType)
                Spacer()
                Text(session.durationFormatted)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timeRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let travelTime = session.travelTime, travelTime > 0 {
                    Spacer()
                    Image(systemName: "car")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formatTravelTime(travelTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if session.isSubsidyEligible, let subsidy = session.subsidyAmount {
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Subsidy: \(CurrencyFormatter.format(subsidy))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, RowConstants.rowVerticalPadding)
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: session.startTime)) - \(formatter.string(from: session.endTime))"
    }

    private func formatTravelTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m travel" : "\(hours)h travel"
        }
        return "\(minutes)m travel"
    }
}

// MARK: - Daily Record Header View

struct DailyRecordHeaderView: View {
    let record: DailyRecord

    var body: some View {
        HStack {
            Text(record.date, style: .date)
            Spacer()
            if record.totalEarnings > 0 {
                Text(CurrencyFormatter.format(record.totalEarnings))
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Session Type Badge

struct SessionTypeBadge: View {
    let type: SessionType

    var body: some View {
        Text(type.description)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, BadgeConstants.horizontalPadding)
            .padding(.vertical, BadgeConstants.verticalPadding)
            .background(typeColor.opacity(BadgeConstants.backgroundOpacity))
            .foregroundStyle(typeColor)
            .clipShape(Capsule())
    }

    private var typeColor: Color {
        switch type {
        case .regular: return .blue
        case .onCall: return .orange
        case .callOut: return .purple
        }
    }
}

// MARK: - Constants

private enum RowConstants {
    static let verticalSpacing: CGFloat = 4
    static let rowVerticalPadding: CGFloat = 4
}

private enum BadgeConstants {
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
    static let backgroundOpacity: Double = 0.15
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([Location.self, Assignment.self, DailyRecord.self, Session.self])
    let container = try! ModelContainer(for: schema, configurations: config)

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
        startDate: Date(),
        endDate: Date().addingTimeInterval(14 * secondsPerDay)
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
        endTime: Calendar.current.date(bySettingHour: 16, minute: 30, second: 0, of: Date())!,
        sessionType: .regular,
        mmmClassification: 5,
        travelTime: 3900 // 65 minutes
    )
    session.subsidyAmount = 212.50
    container.mainContext.insert(session)

    return NavigationStack {
        SessionListView(assignment: assignment, location: location)
    }
    .modelContainer(container)
}
