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

/// Sheet view for logging a call-out during on-call duty
struct AddCalloutSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var dailyRecords: [DailyRecord]

    @Binding var isPresented: Bool
    let assignment: Assignment
    let mmmClassification: Int

    @State private var startDateTime: Date = Date()
    @State private var endDateTime: Date = Date().addingTimeInterval(3600) // Default 1 hour later
    @State private var notes: String = ""

    init(isPresented: Binding<Bool>, assignment: Assignment, mmmClassification: Int) {
        self._isPresented = isPresented
        self.assignment = assignment
        self.mmmClassification = mmmClassification

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
        endDateTime.timeIntervalSince(startDateTime)
    }

    /// Whether the duration is valid (positive)
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

    /// Whether the callout spans multiple days
    private var spansMultipleDays: Bool {
        let calendar = Calendar.current
        return !calendar.isDate(startDateTime, inSameDayAs: endDateTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                startSection
                endSection
                durationSection
                notesSection
            }
            .navigationTitle("Log Call-Out")
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
                        saveCallout()
                    }
                    .disabled(!isValidDuration)
                }
            }
        }
    }

    // MARK: - View Components

    private var startSection: some View {
        Section("Called Out") {
            DatePicker(
                "Start",
                selection: $startDateTime,
                in: assignment.dateRange,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }

    private var endSection: some View {
        Section("Finished") {
            DatePicker(
                "End",
                selection: $endDateTime,
                in: startDateTime...,
                displayedComponents: [.date, .hourAndMinute]
            )

            if spansMultipleDays {
                HStack {
                    Image(systemName: "moon.stars")
                        .foregroundStyle(.orange)
                    Text("Overnight call-out")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var durationSection: some View {
        Section {
            LabeledContent("Duration") {
                Text(durationText)
                    .foregroundStyle(isValidDuration ? Color.primary : Color.red)
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

    private func saveCallout() {
        let calendar = Calendar.current

        // Find or create daily record for the start date
        let dailyRecord = findOrCreateDailyRecord(for: startDateTime, calendar: calendar)

        // Create session with callOut type
        let session = Session(
            dailyRecordId: dailyRecord.id,
            startTime: startDateTime,
            endTime: endDateTime,
            sessionType: .callOut,
            mmmClassification: mmmClassification
        )

        if !notes.isEmpty {
            session.notes = notes
        }

        modelContext.insert(session)

        // Recalculate daily earnings after adding the call-out
        EarningsCalculator.recalculateEarnings(
            for: dailyRecord,
            assignment: assignment,
            in: modelContext
        )

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

    return AddCalloutSheet(
        isPresented: .constant(true),
        assignment: assignment,
        mmmClassification: location.mmmClassification
    )
    .modelContainer(container)
}
