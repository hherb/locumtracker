import SwiftUI
import SwiftData
import LocumTrackerCore

/// Sheet view for adding a new work session
struct AddSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dailyRecords: [DailyRecord]

    @Binding var isPresented: Bool
    let assignment: Assignment
    let mmmClassification: Int

    @State private var sessionDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var sessionType: SessionType = .regular
    @State private var travelMinutes: Int = 0
    @State private var notes: String = ""

    init(isPresented: Binding<Bool>, assignment: Assignment, mmmClassification: Int) {
        self._isPresented = isPresented
        self.assignment = assignment
        self.mmmClassification = mmmClassification

        // Initialize with sensible defaults
        let now = Date()
        let calendar = Calendar.current
        _sessionDate = State(initialValue: now)
        _startTime = State(initialValue: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now)
        _endTime = State(initialValue: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now)

        // Filter daily records for this assignment
        let assignmentId = assignment.id
        _dailyRecords = Query(
            filter: #Predicate<DailyRecord> { $0.assignmentId == assignmentId },
            sort: \DailyRecord.date,
            order: .reverse
        )
    }

    /// Calculated duration based on selected times
    private var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Whether the session duration is valid (positive)
    private var isValidDuration: Bool {
        duration > 0
    }

    /// Duration formatted as human-readable string
    private var durationText: String {
        guard isValidDuration else { return "Invalid" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                timeSection
                sessionTypeSection
                travelSection
                notesSection
            }
            .navigationTitle("Add Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                    }
                    .disabled(!isValidDuration)
                }
            }
        }
    }

    // MARK: - View Components

    private var dateSection: some View {
        Section("Date") {
            DatePicker(
                "Session Date",
                selection: $sessionDate,
                in: assignment.dateRange,
                displayedComponents: .date
            )
        }
    }

    private var timeSection: some View {
        Section("Time") {
            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
            LabeledContent("Duration") {
                Text(durationText)
                    .foregroundStyle(isValidDuration ? Color.primary : Color.red)
            }
        }
    }

    private var sessionTypeSection: some View {
        Section("Session Type") {
            Picker("Type", selection: $sessionType) {
                ForEach(SessionType.allCases, id: \.self) { type in
                    Text(type.description).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Text(sessionTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sessionTypeDescription: String {
        switch sessionType {
        case .regular:
            return "Standard working hours at the facility"
        case .onCall:
            return "On-call hours, typically paid at reduced rate"
        case .callOut:
            return "Called out during on-call period, paid at premium rate"
        }
    }

    private var travelSection: some View {
        Section("Travel Time") {
            Stepper(
                "\(travelMinutes) minutes",
                value: $travelMinutes,
                in: 0...TravelConstants.maxMinutes,
                step: TravelConstants.stepMinutes
            )

            if travelMinutes > 0 {
                if travelMinutes > TravelConstants.eligibleThresholdMinutes {
                    Text("Eligible for subsidy (travel > 1 hour)")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Travel must exceed 1 hour for subsidy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Actions

    private func saveSession() {
        // Find or create daily record for this date
        let calendar = Calendar.current
        let dailyRecord = findOrCreateDailyRecord(for: sessionDate, calendar: calendar)

        // Combine session date with times
        let sessionStartTime = combineDateWithTime(date: sessionDate, time: startTime, calendar: calendar)
        let sessionEndTime = combineDateWithTime(date: sessionDate, time: endTime, calendar: calendar)

        let session = Session(
            dailyRecordId: dailyRecord.id,
            startTime: sessionStartTime,
            endTime: sessionEndTime,
            sessionType: sessionType,
            mmmClassification: mmmClassification,
            travelTime: travelMinutes > 0 ? Double(travelMinutes * 60) : nil
        )

        if !notes.isEmpty {
            session.notes = notes
        }

        // Note: FPS uses annual payments based on session count, not per-session amounts.
        // The subsidyAmount field is no longer used for FPS calculations.
        // Sessions are tracked in QuarterlyQuota for FPS eligibility.

        modelContext.insert(session)
        isPresented = false
    }

    private func findOrCreateDailyRecord(for date: Date, calendar: Calendar) -> DailyRecord {
        // Check if a daily record already exists for this date
        let startOfDay = calendar.startOfDay(for: date)
        if let existingRecord = dailyRecords.first(where: {
            calendar.isDate($0.date, inSameDayAs: startOfDay)
        }) {
            return existingRecord
        }

        // Create new daily record
        let newRecord = DailyRecord(
            assignmentId: assignment.id,
            date: startOfDay
        )
        modelContext.insert(newRecord)
        return newRecord
    }

    private func combineDateWithTime(date: Date, time: Date, calendar: Calendar) -> Date {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}

// MARK: - Constants

private enum TravelConstants {
    static let maxMinutes = 240
    static let stepMinutes = 15
    static let eligibleThresholdMinutes = 60
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([Location.self, Assignment.self, DailyRecord.self, Session.self])
    let container = try! ModelContainer(for: schema, configurations: config)

    let location = Location(
        name: "Cooktown Hospital",
        address: "123 Main St",
        mmmClassification: 6
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

    return AddSessionSheet(
        isPresented: .constant(true),
        assignment: assignment,
        mmmClassification: location.mmmClassification
    )
    .modelContainer(container)
}
