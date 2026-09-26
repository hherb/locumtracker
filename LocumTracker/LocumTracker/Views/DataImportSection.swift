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
import UniformTypeIdentifiers
import LocumTrackerStorage

/// Settings section for importing a JSON data bundle (see `ImportBundle`)
struct DataImportSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingImporter = false
    @State private var resultMessage: String?
    @State private var resultTitle = ""

    var body: some View {
        Section {
            Button("Import Data…") {
                showingImporter = true
            }
            .accessibilityIdentifier("importDataButton")
        } header: {
            Text("Data")
        } footer: {
            Text("Imports locations, assignments, sessions, receipts and documents from a LocumTracker JSON import file. Records already present are skipped.")
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert(resultTitle, isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            let bundle = try DataImporter.decode(Data(contentsOf: url))
            let summary = try DataImporter.importBundle(bundle, into: modelContext)
            resultTitle = "Import Complete"
            resultMessage = summary.description
        } catch {
            resultTitle = "Import Failed"
            resultMessage = error.localizedDescription
        }
    }
}
