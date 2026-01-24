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

/// Sheet for adding a new provider location (clinic) to an assignment
struct AddProviderLocationSheet: View {
    @Binding var isPresented: Bool
    @Binding var providerLocations: [ProviderLocation]

    @State private var name: String = ""
    @State private var providerNumber: String = ""
    @State private var address: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !providerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Clinic Name", text: $name)
                    TextField("Provider Number", text: $providerNumber)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Required")
                } footer: {
                    Text("The Medicare provider number for this clinic location.")
                }

                Section("Address") {
                    TextField("Street Address (optional)", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Contact") {
                    TextField("Phone (optional)", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Clinic")
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
                    Button("Add") {
                        addProviderLocation()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addProviderLocation() {
        let location = ProviderLocation(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            providerNumber: providerNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        providerLocations.append(location)
        isPresented = false
    }
}

/// Sheet for editing an existing provider location (clinic)
struct EditProviderLocationSheet: View {
    @Binding var isPresented: Bool
    @Binding var providerLocations: [ProviderLocation]
    let editingIndex: Int

    @State private var name: String
    @State private var providerNumber: String
    @State private var address: String
    @State private var phone: String
    @State private var notes: String

    init(isPresented: Binding<Bool>, providerLocations: Binding<[ProviderLocation]>, editingIndex: Int) {
        self._isPresented = isPresented
        self._providerLocations = providerLocations
        self.editingIndex = editingIndex

        let location = providerLocations.wrappedValue[editingIndex]
        _name = State(initialValue: location.name)
        _providerNumber = State(initialValue: location.providerNumber)
        _address = State(initialValue: location.address ?? "")
        _phone = State(initialValue: location.phone ?? "")
        _notes = State(initialValue: location.notes ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !providerNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Clinic Name", text: $name)
                    TextField("Provider Number", text: $providerNumber)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Required")
                } footer: {
                    Text("The Medicare provider number for this clinic location.")
                }

                Section("Address") {
                    TextField("Street Address (optional)", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Contact") {
                    TextField("Phone (optional)", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Clinic")
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
                        saveProviderLocation()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveProviderLocation() {
        let location = ProviderLocation(
            id: providerLocations[editingIndex].id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            providerNumber: providerNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        providerLocations[editingIndex] = location
        isPresented = false
    }
}

// MARK: - Preview

#Preview("Add") {
    AddProviderLocationSheet(
        isPresented: .constant(true),
        providerLocations: .constant([])
    )
}

#Preview("Edit") {
    EditProviderLocationSheet(
        isPresented: .constant(true),
        providerLocations: .constant([
            ProviderLocation(
                name: "Main Street Clinic",
                providerNumber: "1234567A",
                address: "123 Main St, Brisbane QLD 4000",
                phone: "07 1234 5678"
            )
        ]),
        editingIndex: 0
    )
}
