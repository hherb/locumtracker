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
    @Query private var allLocations: [Location]

    @Binding var isPresented: Bool
    let assignment: Assignment
    let mmmClassification: Int
    let location: Location?

    @State private var sessionDate: Date
    @State private var endSessionDate: Date
    @State private var isDateRangeMode: Bool = false
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var sessionType: SessionType = .regular
    @State private var travelMinutes: Int = 0
    @State private var notes: String = ""

    // Track which templates are selected for batch creation
    @State private var selectedTemplateIndices: Set<Int> = []

    // Mode: single custom session vs batch from templates
    @State private var isTemplateMode: Bool = false

    // Split session state
    @State private var isSplitMode: Bool = false
    @State private var firstSessionEndTime: Date = Date()
    @State private var secondSessionStartTime: Date = Date()
    @State private var secondSessionType: SessionType = .regular
    @State private var secondSessionNotes: String = ""

    // Multi-location support: nil means use assignment's primary location
    @State private var selectedLocationId: UUID?
    @State private var preferLocationTemplates: Bool = false

    init(isPresented: Binding<Bool>, assignment: Assignment, mmmClassification: Int, location: Location? = nil) {
        self._isPresented = isPresented
        self.assignment = assignment
        self.mmmClassification = mmmClassification
        self.location = location

        // Initialize with sensible defaults or first template
        let now = Date()
        let calendar = Calendar.current
        _sessionDate = State(initialValue: now)
        _endSessionDate = State(initialValue: now)

        // Resolve templates: assignment templates take priority, fall back to location templates
        let assignmentTemplates = assignment.defaultSessionTemplates
        let locationTemplates = location?.defaultSessionTemplates ?? []
        let effectiveTemplates = SessionTemplateService.resolveTemplates(
            assignmentTemplates: assignmentTemplates,
            locationTemplates: locationTemplates
        )

        // Use first effective template if available, and start in template mode if templates exist
        if let firstTemplate = effectiveTemplates.first {
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
            // Select all templates by default for quick batch creation
            let allIndices = Set(effectiveTemplates.indices)
            _selectedTemplateIndices = State(initialValue: allIndices)
            _isTemplateMode = State(initialValue: true)
        } else {
            _startTime = State(initialValue: calendar.date(
                bySettingHour: TimeConstants.defaultStartHour,
                minute: TimeConstants.defaultMinute,
                second: 0,
                of: now
            ) ?? now)
            _endTime = State(initialValue: calendar.date(
                bySettingHour: TimeConstants.defaultEndHour,
                minute: TimeConstants.defaultMinute,
                second: 0,
                of: now
            ) ?? now)
            _selectedTemplateIndices = State(initialValue: [])
            _isTemplateMode = State(initialValue: false)
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
        let hours = Int(interval) / TimeConstants.secondsPerHour
        let minutes = (Int(interval) % TimeConstants.secondsPerHour) / TimeConstants.secondsPerMinute
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
        let durationHours = duration / Double(TimeConstants.secondsPerHour)
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
        if isTemplateMode {
            return !selectedTemplateIndices.isEmpty
        } else if isSplitMode {
            return isValidSplitDurations && isValidGap
        } else {
            return isValidDuration
        }
    }

    /// Available session templates, resolved from assignment and location
    private var sessionTemplates: [DefaultSessionTemplate] {
        SessionTemplateService.resolveTemplates(
            assignmentTemplates: assignment.defaultSessionTemplates,
            locationTemplates: location?.defaultSessionTemplates ?? [],
            preferLocationTemplates: preferLocationTemplates
        )
    }

    /// Source of the current templates (for display purposes)
    private var templateSource: TemplateSource {
        SessionTemplateService.resolveTemplateSource(
            assignmentTemplates: assignment.defaultSessionTemplates,
            locationTemplates: location?.defaultSessionTemplates ?? [],
            preferLocationTemplates: preferLocationTemplates
        )
    }

    /// Available locations for this assignment (primary + additional)
    private var availableLocations: [Location] {
        allLocations.filter { assignment.allLocationIds.contains($0.id) }
    }

    /// Whether this assignment has multiple locations to choose from
    private var hasMultipleLocations: Bool {
        availableLocations.count > 1
    }

    /// The effective location for the session (selected or primary)
    private var effectiveLocation: Location? {
        if let selectedId = selectedLocationId {
            return availableLocations.first { $0.id == selectedId }
        }
        return location
    }

    /// MMM classification for the effective location
    private var effectiveMMMClassification: Int {
        effectiveLocation?.mmmClassification ?? mmmClassification
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasMultipleLocations {
                    locationSection
                }
                dateSection
                if !sessionTemplates.isEmpty {
                    templateSection
                }
                if !isTemplateMode {
                    timeSection
                    splitSessionSection
                    if !isSplitMode {
                        sessionTypeSection
                    }
                }
                travelSection
                if !isTemplateMode {
                    notesSection
                }
            }
            .navigationTitle(isTemplateMode ? "Add Sessions" : "Add Session")
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
                    Button(saveButtonTitle) {
                        saveSession()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var saveButtonTitle: String {
        if isTemplateMode {
            let totalSessions = totalSessionCount
            return totalSessions == 1 ? "Add 1 Session" : "Add \(totalSessions) Sessions"
        }
        return "Save"
    }

    /// Calculate total number of sessions to be created
    private var totalSessionCount: Int {
        let templateCount = selectedTemplateIndices.count
        if isDateRangeMode {
            return templateCount * numberOfDaysInRange
        }
        return templateCount
    }

    /// Number of days in the selected date range
    private var numberOfDaysInRange: Int {
        guard isDateRangeMode else { return 1 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: sessionDate)
        let end = calendar.startOfDay(for: endSessionDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(1, (components.day ?? 0) + 1)
    }

    // MARK: - View Components

    private var locationSection: some View {
        Section {
            Picker("Location", selection: $selectedLocationId) {
                // Primary location (nil = use assignment's primary)
                if let primaryLocation = location {
                    HStack {
                        Text(primaryLocation.name)
                        Spacer()
                        MMMBadge(classification: primaryLocation.mmmClassification)
                    }
                    .tag(nil as UUID?)
                }

                // Additional locations
                ForEach(availableLocations.filter { $0.id != location?.id }) { loc in
                    HStack {
                        Text(loc.name)
                        Spacer()
                        MMMBadge(classification: loc.mmmClassification)
                    }
                    .tag(loc.id as UUID?)
                }
            }
            .pickerStyle(.navigationLink)

            // Show effective MMM classification
            if let effectiveLoc = effectiveLocation {
                LabeledContent("MMM Classification") {
                    Text("MMM \(effectiveLoc.mmmClassification)")
                        .foregroundStyle(effectiveLoc.mmmClassification >= 3 ? .green : .secondary)
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Select the location where this session will be worked")
        }
    }

    private var dateSection: some View {
        Section {
            if isTemplateMode {
                // Toggle between single date and date range
                Picker("Date Mode", selection: $isDateRangeMode) {
                    Text("Single Day").tag(false)
                    Text("Date Range").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if isDateRangeMode && isTemplateMode {
                DateRangePicker(
                    startLabel: "Start Date",
                    endLabel: "End Date",
                    startDate: $sessionDate,
                    endDate: $endSessionDate
                )
                .onChange(of: sessionDate) { _, newValue in
                    // Ensure end date is not before start date
                    if endSessionDate < newValue {
                        endSessionDate = newValue
                    }
                    // Clamp to assignment range
                    if newValue < assignment.startDate {
                        sessionDate = assignment.startDate
                    }
                    if newValue > assignment.endDate {
                        sessionDate = assignment.endDate
                    }
                }
                .onChange(of: endSessionDate) { _, newValue in
                    // Clamp to assignment range
                    if newValue > assignment.endDate {
                        endSessionDate = assignment.endDate
                    }
                    if newValue < sessionDate {
                        endSessionDate = sessionDate
                    }
                }

                if numberOfDaysInRange > 1 {
                    LabeledContent("Days") {
                        Text("\(numberOfDaysInRange) days")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                AutoDismissDatePicker(
                    label: "Session Date",
                    selection: $sessionDate,
                    range: assignment.dateRange
                )
            }
        } header: {
            Text("Date")
        }
    }

    private var templateSection: some View {
        Section {
            ForEach(Array(sessionTemplates.enumerated()), id: \.element.id) { index, template in
                Button {
                    toggleTemplate(at: index)
                } label: {
                    HStack {
                        Image(systemName: selectedTemplateIndices.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTemplateIndices.contains(index) ? .blue : .secondary)
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

            // Option to switch to custom time entry
            Button {
                switchToCustomMode()
            } label: {
                HStack {
                    Image(systemName: isTemplateMode ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(isTemplateMode ? Color.secondary : Color.blue)
                    Text("Custom Time")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Sessions")
        } footer: {
            if isTemplateMode {
                Text("Select one or more sessions to add")
            } else {
                Text("Enter custom start and end times below")
            }
        }
    }

    private func toggleTemplate(at index: Int) {
        if selectedTemplateIndices.contains(index) {
            selectedTemplateIndices.remove(index)
        } else {
            selectedTemplateIndices.insert(index)
        }
        // Stay in template mode if any templates selected
        isTemplateMode = !selectedTemplateIndices.isEmpty
    }

    private func switchToCustomMode() {
        selectedTemplateIndices.removeAll()
        isTemplateMode = false
        isSplitMode = false

        // Reset to default times
        let calendar = Calendar.current
        let now = Date()
        startTime = calendar.date(
            bySettingHour: TimeConstants.defaultStartHour,
            minute: TimeConstants.defaultMinute,
            second: 0,
            of: now
        ) ?? now
        endTime = calendar.date(
            bySettingHour: TimeConstants.defaultEndHour,
            minute: TimeConstants.defaultMinute,
            second: 0,
            of: now
        ) ?? now
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
        let firstSessionSeconds = SessionSplitConstants.firstSessionDefaultHours * Double(TimeConstants.secondsPerHour)
        let gapSeconds = Double(SessionSplitConstants.defaultGapMinutes * TimeConstants.secondsPerMinute)

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
        let calendar = Calendar.current

        if isTemplateMode && isDateRangeMode {
            // Save sessions for each day in the range
            let affectedRecords = saveTemplatedSessionsForDateRange(calendar: calendar)

            // Recalculate earnings for all affected daily records
            for record in affectedRecords {
                EarningsCalculator.recalculateEarnings(
                    for: record,
                    assignment: assignment,
                    in: modelContext
                )
            }
        } else {
            // Single day mode
            let dailyRecord = findOrCreateDailyRecord(for: sessionDate, calendar: calendar)

            if isTemplateMode {
                saveTemplatedSessions(dailyRecord: dailyRecord, calendar: calendar, date: sessionDate, isFirstDay: true)
            } else if isSplitMode {
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
        }

        isPresented = false
    }

    private func saveTemplatedSessionsForDateRange(calendar: Calendar) -> [DailyRecord] {
        var affectedRecords: [DailyRecord] = []
        var currentDate = calendar.startOfDay(for: sessionDate)
        let endDate = calendar.startOfDay(for: endSessionDate)
        var isFirstDay = true

        while currentDate <= endDate {
            let dailyRecord = findOrCreateDailyRecord(for: currentDate, calendar: calendar)
            saveTemplatedSessions(dailyRecord: dailyRecord, calendar: calendar, date: currentDate, isFirstDay: isFirstDay)
            affectedRecords.append(dailyRecord)

            isFirstDay = false
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return affectedRecords
    }

    private func saveTemplatedSessions(dailyRecord: DailyRecord, calendar: Calendar, date: Date, isFirstDay: Bool) {
        // Sort indices to save sessions in chronological order
        let sortedIndices = selectedTemplateIndices.sorted()
        var isFirstSession = isFirstDay

        for index in sortedIndices {
            guard index < sessionTemplates.count else { continue }
            let template = sessionTemplates[index]

            let sessionStartTime = template.startDate(on: date)
            let sessionEndTime = template.endDate(on: date)

            let session = Session(
                dailyRecordId: dailyRecord.id,
                startTime: sessionStartTime,
                endTime: sessionEndTime,
                sessionType: sessionType,
                mmmClassification: effectiveMMMClassification,
                travelTime: isFirstSession && travelMinutes > 0 ? Double(travelMinutes * TimeConstants.secondsPerMinute) : nil,
                locationId: selectedLocationId
            )

            modelContext.insert(session)
            isFirstSession = false
        }
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
            mmmClassification: effectiveMMMClassification,
            travelTime: travelMinutes > 0 ? Double(travelMinutes * TimeConstants.secondsPerMinute) : nil,
            locationId: selectedLocationId
        )

        if !notes.isEmpty {
            session.notes = notes
        }

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
            mmmClassification: effectiveMMMClassification,
            travelTime: travelMinutes > 0 ? Double(travelMinutes * TimeConstants.secondsPerMinute) : nil,
            locationId: selectedLocationId
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
            mmmClassification: effectiveMMMClassification,
            travelTime: nil,  // Travel time only applies to first session
            locationId: selectedLocationId
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

private enum TimeConstants {
    /// Seconds per hour for time calculations
    static let secondsPerHour = 3600
    /// Seconds per minute for time calculations
    static let secondsPerMinute = 60
    /// Default start hour for custom sessions
    static let defaultStartHour = 8
    /// Default end hour for custom sessions
    static let defaultEndHour = 17
    /// Default minute value
    static let defaultMinute = 0
}

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
