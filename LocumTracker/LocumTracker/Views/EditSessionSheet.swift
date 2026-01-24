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

/// Sheet view for editing an existing work session
struct EditSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dailyRecords: [DailyRecord]

    @Binding var isPresented: Bool
    @Bindable var session: Session
    let assignment: Assignment
    let location: Location?

    @State private var sessionDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var sessionType: SessionType
    @State private var travelMinutes: Int
    @State private var notes: String

    // Selected provider location (clinic) - nil means main location
    @State private var selectedProviderLocationId: UUID?

    init(isPresented: Binding<Bool>, session: Session, assignment: Assignment, location: Location? = nil) {
        self._isPresented = isPresented
        self.session = session
        self.assignment = assignment
        self.location = location

        // Initialize state from existing session
        _sessionDate = State(initialValue: session.startTime)
        _startTime = State(initialValue: session.startTime)
        _endTime = State(initialValue: session.endTime)
        _sessionType = State(initialValue: session.sessionType)
        _travelMinutes = State(initialValue: Int((session.travelTime ?? 0) / 60))
        _notes = State(initialValue: session.notes ?? "")
        _selectedProviderLocationId = State(initialValue: session.providerLocationId)

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

    /// Available session templates from location
    private var sessionTemplates: [DefaultSessionTemplate] {
        location?.defaultSessionTemplates ?? []
    }

    /// Available provider locations (clinics) from assignment
    private var providerLocations: [ProviderLocation] {
        assignment.providerLocations
    }

    /// Whether to show the clinic picker section
    private var hasProviderLocations: Bool {
        assignment.hasMainProviderNumber || !providerLocations.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                if hasProviderLocations {
                    clinicSection
                }
                if !sessionTemplates.isEmpty {
                    templateSection
                }
                timeSection
                sessionTypeSection
                travelSection
                notesSection
            }
            .navigationTitle("Edit Session")
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

    private var clinicSection: some View {
        Section {
            // Main location option
            Button {
                selectedProviderLocationId = nil
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Main Location")
                            .fontWeight(.medium)
                        if let mainNumber = assignment.mainProviderNumber {
                            Text(mainNumber)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if selectedProviderLocationId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)

            // Additional clinics
            ForEach(providerLocations) { location in
                Button {
                    selectedProviderLocationId = location.id
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(location.name)
                                .fontWeight(.medium)
                            Text(location.providerNumber)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedProviderLocationId == location.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Clinic")
        } footer: {
            Text("Select the clinic where this session takes place.")
        }
    }

    private var templateSection: some View {
        Section {
            ForEach(Array(sessionTemplates.enumerated()), id: \.element.id) { index, template in
                Button {
                    applyTemplate(template)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            if let label = template.label {
                                Text(label)
                                    .fontWeight(.medium)
                            }
                            Text(template.timeRangeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .foregroundStyle(.primary)
            }
        } header: {
            Text("Default Sessions")
        } footer: {
            Text("Tap a session to apply its times")
        }
    }

    private func applyTemplate(_ template: DefaultSessionTemplate) {
        let calendar = Calendar.current
        let now = Date()

        startTime = calendar.date(
            bySettingHour: template.startHour,
            minute: template.startMinute,
            second: 0,
            of: now
        ) ?? now

        endTime = calendar.date(
            bySettingHour: template.endHour,
            minute: template.endMinute,
            second: 0,
            of: now
        ) ?? now
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
        let calendar = Calendar.current

        // Track the original daily record ID before any changes
        let originalDailyRecordId = session.dailyRecordId

        // Check if date changed - may need to move to different daily record
        let originalDate = session.startTime
        let dateChanged = !calendar.isDate(originalDate, inSameDayAs: sessionDate)

        var newDailyRecord: DailyRecord?
        if dateChanged {
            // Find or create daily record for new date
            newDailyRecord = findOrCreateDailyRecord(for: sessionDate, calendar: calendar)
            session.dailyRecordId = newDailyRecord!.id
        }

        // Combine session date with times
        let sessionStartTime = combineDateWithTime(date: sessionDate, time: startTime, calendar: calendar)
        let sessionEndTime = combineDateWithTime(date: sessionDate, time: endTime, calendar: calendar)

        // Update session properties
        session.startTime = sessionStartTime
        session.endTime = sessionEndTime
        session.sessionType = sessionType
        session.travelTime = travelMinutes > 0 ? Double(travelMinutes * 60) : nil
        session.notes = notes.isEmpty ? nil : notes
        session.providerLocationId = selectedProviderLocationId

        // Recalculate earnings for affected daily records
        if dateChanged {
            // Recalculate the new daily record (where session was moved to)
            if let newRecord = newDailyRecord {
                EarningsCalculator.recalculateEarnings(
                    for: newRecord,
                    assignment: assignment,
                    in: modelContext
                )
            }

            // Recalculate the old daily record (where session was removed from)
            if let oldRecord = dailyRecords.first(where: { $0.id == originalDailyRecordId }) {
                EarningsCalculator.recalculateEarnings(
                    for: oldRecord,
                    assignment: assignment,
                    in: modelContext
                )
            }
        } else {
            // Date didn't change, just recalculate the current daily record
            if let currentRecord = dailyRecords.first(where: { $0.id == session.dailyRecordId }) {
                EarningsCalculator.recalculateEarnings(
                    for: currentRecord,
                    assignment: assignment,
                    in: modelContext
                )
            }
        }

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

    let dailyRecord = DailyRecord(
        assignmentId: assignment.id,
        date: Date()
    )
    container.mainContext.insert(dailyRecord)

    let session = Session(
        dailyRecordId: dailyRecord.id,
        startTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
        endTime: Calendar.current.date(bySettingHour: 16, minute: 30, second: 0, of: Date())!,
        sessionType: .regular,
        mmmClassification: 6,
        travelTime: 3900
    )
    session.notes = "Morning shift with procedures"
    container.mainContext.insert(session)

    return EditSessionSheet(
        isPresented: .constant(true),
        session: session,
        assignment: assignment,
        location: location
    )
    .modelContainer(container)
}
