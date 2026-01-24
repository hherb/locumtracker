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

/// A date range picker that allows selecting start and end dates from a single calendar.
///
/// Use this for assignment date ranges. The calendar stays open while selecting
/// both dates, allowing the user to tap start date then end date without
/// navigating between fields.
struct DateRangePicker: View {
    let startLabel: String
    let endLabel: String
    @Binding var startDate: Date
    @Binding var endDate: Date

    @State private var isExpanded = false
    @State private var editingField: EditingField = .start

    private enum EditingField {
        case start
        case end
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                fieldSelector
                calendarView
            }
            .padding(.vertical, 8)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(startLabel)
                    Spacer()
                    Text(startDate, style: .date)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(endLabel)
                    Spacer()
                    Text(endDate, style: .date)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var fieldSelector: some View {
        HStack(spacing: 12) {
            fieldButton(for: .start, label: startLabel, date: startDate)
            fieldButton(for: .end, label: endLabel, date: endDate)
        }
    }

    private func fieldButton(for field: EditingField, label: String, date: Date) -> some View {
        Button {
            withAnimation {
                editingField = field
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(editingField == field ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(editingField == field ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(editingField == field ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var calendarView: some View {
        Group {
            if editingField == .start {
                DatePicker(
                    "",
                    selection: $startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .onChange(of: startDate) { oldValue, newValue in
                    // If start date moves past end date, push end date forward
                    if newValue > endDate {
                        endDate = newValue
                    }
                    // Auto-advance to end date selection after picking start
                    withAnimation {
                        editingField = .end
                    }
                }
            } else {
                DatePicker(
                    "",
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
        }
    }
}

#Preview {
    Form {
        DateRangePicker(
            startLabel: "Start Date",
            endLabel: "End Date",
            startDate: .constant(Date()),
            endDate: .constant(Date().addingTimeInterval(7 * 86400))
        )
    }
}
