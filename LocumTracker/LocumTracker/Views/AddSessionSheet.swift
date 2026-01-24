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

/// Sheet view for adding a new work session
struct AddSessionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dailyRecords: [DailyRecord]

    @Binding var isPresented: Bool
    let assignment: Assignment
    let mmmClassification: Int
    let location: Location?

    @State private var sessionDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var sessionType: SessionType = .regular
    @State private var travelMinutes: Int = 0
    @State private var notes: String = ""

    // Track which template is selected (if any)
    @State private var selectedTemplateIndex: Int?

    // Split session state
    @State private var isSplitMode: Bool = false
    @State private var firstSessionEndTime: Date = Date()
    @State private var secondSessionStartTime: Date = Date()
    @State private var secondSessionType: SessionType = .regular
    @State private var secondSessionNotes: String = ""

    init(isPresented: Binding<Bool>, assignment: Assignment, mmmClassification: Int, location: Location? = nil) {
        self._isPresented = isPresented
        self.assignment = assignment
        self.mmmClassification = mmmClassification
        self.location = location

        // Initialize with sensible defaults or first template
        let now = Date()
        let calendar = Calendar.current
        _sessionDate = State(initialValue: now)

        // Use first default session template if available
        if let location = location,
           let firstTemplate = location.defaultSessionTemplates.first {
            _startTime = State(initialValue: calendar.date(
                bySettingHour: firstTemplate.startHour,
                minute: firstTemplate.startMinute,
                second: 0,
                of: now
            ) ?? now)
            _endTime = State(initialValue: calendar.date(
                bySettingHour: firstTemplate.endHour,
                minute: firstTemplate.endMinute,
                second: 0,
                of: now
            ) ?? now)
            _selectedTemplateIndex = State(initialValue: 0)
        } else {
            _startTime = State(initialValue: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now)
            _endTime = State(initialValue: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now)
            _selectedTemplateIndex = State(initialValue: nil)
        }

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
        return formatDuration(duration)
    }

    /// Format a duration as human-readable string
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    /// Whether the total duration exceeds the split threshold
    private var shouldSuggestSplit: Bool {
        let durationHours = duration / 3600
        return durationHours > SessionSplitConstants.splitThresholdHours
    }

    /// Duration of the first session in split mode
    private var firstSessionDuration: TimeInterval {
        firstSessionEndTime.timeIntervalSince(startTime)
    }

    /// Duration of the second session in split mode
    private var secondSessionDuration: TimeInterval {
        endTime.timeIntervalSince(secondSessionStartTime)
    }

    /// Whether the first session duration is valid
    private var isValidFirstSessionDuration: Bool {
        firstSessionDuration > 0
    }

    /// Whether the second session duration is valid
    private var isValidSecondSessionDuration: Bool {
        secondSessionDuration > 0
    }

    /// Whether all split sessions have valid durations
    private var isValidSplitDurations: Bool {
        isValidFirstSessionDuration && isValidSecondSessionDuration
    }

    /// Gap between first and second session
    private var gapDuration: TimeInterval {
        secondSessionStartTime.timeIntervalSince(firstSessionEndTime)
    }

    /// Whether the gap between sessions is valid (non-negative)
    private var isValidGap: Bool {
        gapDuration >= 0
    }

    /// Whether the form can be saved
    private var canSave: Bool {
        if isSplitMode {
            return isValidSplitDurations && isValidGap
        } else {
            return isValidDuration
        }
    }

    /// Available session templates from location
    private var sessionTemplates: [DefaultSessionTemplate] {
        location?.defaultSessionTemplates ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                if !sessionTemplates.isEmpty {
                    templateSection
                }
                timeSection
                splitSessionSection
                if !isSplitMode {
                    sessionTypeSection
                }
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
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - View Components

    private var dateSection: some View {
        Section("Date") {
            AutoDismissDatePicker(
                label: "Session Date",
                selection: $sessionDate,
                range: assignment.dateRange
            )
        }
    }

    private var templateSection: some View {
        Section {
            ForEach(Array(sessionTemplates.enumerated()), id: \.element.id) { index, template in
                Button {
                    applyTemplate(template, at: index)
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
                        if selectedTemplateIndex == index {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
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

    private func applyTemplate(_ template: DefaultSessionTemplate, at index: Int) {
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

        selectedTemplateIndex = index

        // Check if we should suggest split mode
        updateSplitSuggestion()
    }

    /// Updates split mode suggestion based on current duration
    private func updateSplitSuggestion() {
        if shouldSuggestSplit && !isSplitMode {
            enableSplitMode()
        }
    }

    /// Enables split mode with default split times
    private func enableSplitMode() {
        isSplitMode = true
        calculateDefaultSplitTimes()
    }

    /// Disables split mode
    private func disableSplitMode() {
        isSplitMode = false
    }

    /// Calculates default split times: first session 4 hours, 30 min gap
    private func calculateDefaultSplitTimes() {
        let firstSessionSeconds = SessionSplitConstants.firstSessionDefaultHours * 3600
        let gapSeconds = Double(SessionSplitConstants.defaultGapMinutes * 60)

        firstSessionEndTime = startTime.addingTimeInterval(firstSessionSeconds)
        secondSessionStartTime = firstSessionEndTime.addingTimeInterval(gapSeconds)
        secondSessionType = sessionType
    }

    private var timeSection: some View {
        Section("Time") {
            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                .onChange(of: startTime) { _, _ in
                    if isSplitMode {
                        calculateDefaultSplitTimes()
                    } else {
                        updateSplitSuggestion()
                    }
                }
            DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                .onChange(of: endTime) { _, _ in
                    updateSplitSuggestion()
                }
            LabeledContent("Duration") {
                Text(durationText)
                    .foregroundStyle(isValidDuration ? Color.primary : Color.red)
            }

            if shouldSuggestSplit && !isSplitMode {
                Button {
                    enableSplitMode()
                } label: {
                    Label("Split into two sessions", systemImage: "arrow.triangle.branch")
                }
                .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder
    private var splitSessionSection: some View {
        if isSplitMode {
            Section {
                HStack {
                    Text("Session will be split into two")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel Split") {
                        disableSplitMode()
                    }
                    .font(.subheadline)
                }
            }

            Section("Session 1") {
                LabeledContent("Start") {
                    Text(startTime, style: .time)
                }
                DatePicker("End", selection: $firstSessionEndTime, displayedComponents: .hourAndMinute)
                LabeledContent("Duration") {
                    Text(formatDuration(firstSessionDuration))
                        .foregroundStyle(isValidFirstSessionDuration ? Color.primary : Color.red)
                }
            }

            Section("Session 2") {
                DatePicker("Start", selection: $secondSessionStartTime, displayedComponents: .hourAndMinute)
                LabeledContent("End") {
                    Text(endTime, style: .time)
                }
                LabeledContent("Duration") {
                    Text(formatDuration(secondSessionDuration))
                        .foregroundStyle(isValidSecondSessionDuration ? Color.primary : Color.red)
                }
                Picker("Type", selection: $secondSessionType) {
                    ForEach(SessionType.allCases, id: \.self) { type in
                        Text(type.description).tag(type)
                    }
                }
            }

            Section {
                LabeledContent("Break Duration") {
                    Text(formatDuration(gapDuration))
                        .foregroundStyle(isValidGap ? Color.secondary : Color.red)
                }
                if !isValidGap {
                    Text("Session 2 must start after Session 1 ends")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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

        if isSplitMode {
            saveSplitSessions(dailyRecord: dailyRecord, calendar: calendar)
        } else {
            saveSingleSession(dailyRecord: dailyRecord, calendar: calendar)
        }

        // Recalculate daily earnings after adding the session(s)
        EarningsCalculator.recalculateEarnings(
            for: dailyRecord,
            assignment: assignment,
            in: modelContext
        )

        isPresented = false
    }

    private func saveSingleSession(dailyRecord: DailyRecord, calendar: Calendar) {
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
    }

    private func saveSplitSessions(dailyRecord: DailyRecord, calendar: Calendar) {
        // First session: startTime to firstSessionEndTime
        let firstStart = combineDateWithTime(date: sessionDate, time: startTime, calendar: calendar)
        let firstEnd = combineDateWithTime(date: sessionDate, time: firstSessionEndTime, calendar: calendar)

        let firstSession = Session(
            dailyRecordId: dailyRecord.id,
            startTime: firstStart,
            endTime: firstEnd,
            sessionType: sessionType,
            mmmClassification: mmmClassification,
            travelTime: travelMinutes > 0 ? Double(travelMinutes * 60) : nil
        )

        if !notes.isEmpty {
            firstSession.notes = notes
        }

        modelContext.insert(firstSession)

        // Second session: secondSessionStartTime to endTime
        let secondStart = combineDateWithTime(date: sessionDate, time: secondSessionStartTime, calendar: calendar)
        let secondEnd = combineDateWithTime(date: sessionDate, time: endTime, calendar: calendar)

        let secondSession = Session(
            dailyRecordId: dailyRecord.id,
            startTime: secondStart,
            endTime: secondEnd,
            sessionType: secondSessionType,
            mmmClassification: mmmClassification,
            travelTime: nil  // Travel time only applies to first session
        )

        if !secondSessionNotes.isEmpty {
            secondSession.notes = secondSessionNotes
        }

        modelContext.insert(secondSession)
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

private enum SessionSplitConstants {
    /// Sessions exceeding this duration (in hours) will be automatically split
    static let splitThresholdHours: Double = 5.0
    /// Default duration for the first session when splitting (in hours)
    static let firstSessionDefaultHours: Double = 4.0
    /// Default gap between first and second session (in minutes)
    static let defaultGapMinutes: Int = 30
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
