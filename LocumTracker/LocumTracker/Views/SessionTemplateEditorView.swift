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
import LocumTrackerCore

// MARK: - Constants

private enum TemplateEditorConstants {
    static let defaultStartHour = 8
    static let defaultEndHour = 12
    static let defaultMinute = 0
    static let secondsPerHour = 3600
    static let secondsPerMinute = 60
}

/// A sheet view for adding a new session template
struct SessionTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var templates: [DefaultSessionTemplate]

    @State private var startTime: Date
    @State private var endTime: Date
    @State private var label: String = ""

    init(templates: Binding<[DefaultSessionTemplate]>) {
        self._templates = templates

        // Default to 8:00 - 12:00 for new template
        let calendar = Calendar.current
        let now = Date()
        _startTime = State(initialValue: calendar.date(
            bySettingHour: TemplateEditorConstants.defaultStartHour,
            minute: TemplateEditorConstants.defaultMinute,
            second: 0,
            of: now
        ) ?? now)
        _endTime = State(initialValue: calendar.date(
            bySettingHour: TemplateEditorConstants.defaultEndHour,
            minute: TemplateEditorConstants.defaultMinute,
            second: 0,
            of: now
        ) ?? now)
    }

    /// Calculated duration based on selected times
    private var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Whether the duration is valid (positive)
    private var isValidDuration: Bool {
        duration > 0
    }

    /// Duration formatted as human-readable string
    private var durationText: String {
        guard isValidDuration else { return "Invalid" }
        let hours = Int(duration) / TemplateEditorConstants.secondsPerHour
        let minutes = (Int(duration) % TemplateEditorConstants.secondsPerHour) / TemplateEditorConstants.secondsPerMinute
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
                Section("Session Times") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                    LabeledContent("Duration") {
                        Text(durationText)
                            .foregroundStyle(isValidDuration ? Color.primary : Color.red)
                    }
                }

                Section("Label (Optional)") {
                    TextField("e.g., Morning, Afternoon, Night Shift", text: $label)
                }

                Section {
                    Button {
                        addQuickTemplates()
                    } label: {
                        Label("Add Morning & Afternoon", systemImage: "sun.and.horizon")
                    }
                } footer: {
                    Text("Adds Morning (8:00-12:00) and Afternoon (13:00-17:00) sessions")
                }
            }
            .navigationTitle("Add Session Template")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTemplate()
                    }
                    .disabled(!isValidDuration)
                }
            }
        }
    }

    private func addTemplate() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        let template = DefaultSessionTemplate(
            startHour: startComponents.hour ?? TemplateEditorConstants.defaultStartHour,
            startMinute: startComponents.minute ?? TemplateEditorConstants.defaultMinute,
            endHour: endComponents.hour ?? TemplateEditorConstants.defaultEndHour,
            endMinute: endComponents.minute ?? TemplateEditorConstants.defaultMinute,
            label: label.isEmpty ? nil : label
        )

        templates.append(template)
        dismiss()
    }

    private func addQuickTemplates() {
        templates.append(.morningSession())
        templates.append(.afternoonSession())
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    SessionTemplateEditorView(templates: .constant([]))
}
