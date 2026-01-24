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

/// A date picker that automatically dismisses when a single date is selected.
///
/// Use this for selecting individual dates (session date, receipt date).
/// The picker expands inline in the form and collapses when a date is tapped.
struct AutoDismissDatePicker: View {
    let label: String
    @Binding var selection: Date
    var range: ClosedRange<Date>?

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let range = range {
                DatePicker(
                    "",
                    selection: $selection,
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .onChange(of: selection) { _, _ in
                    withAnimation {
                        isExpanded = false
                    }
                }
            } else {
                DatePicker(
                    "",
                    selection: $selection,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .onChange(of: selection) { _, _ in
                    withAnimation {
                        isExpanded = false
                    }
                }
            }
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text(selection, style: .date)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    Form {
        AutoDismissDatePicker(
            label: "Session Date",
            selection: .constant(Date())
        )
    }
}
