// LocumTracker Share Extension
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

/// Main UI for the Share Extension
struct ShareExtensionView: View {
    let sharedFiles: [SharedFile]
    let onSave: (ShareResult) -> Void
    let onCancel: () -> Void

    @State private var targetType: TargetSelection = .assignment
    @State private var selectedAssignmentId: UUID?
    @State private var notes: String = ""

    private let cachedAssignments: [CachedAssignment]

    /// Target selection options
    enum TargetSelection: String, CaseIterable {
        case assignment = "Assignment"
        case receipt = "New Receipt"
    }

    init(
        sharedFiles: [SharedFile],
        onSave: @escaping (ShareResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sharedFiles = sharedFiles
        self.onSave = onSave
        self.onCancel = onCancel

        // Load cached assignments, filtering out cancelled ones
        self.cachedAssignments = SharedDataService.readAssignmentsCache()
            .filter { $0.status != "cancelled" }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationView {
            Form {
                filesPreviewSection
                targetSelectionSection

                if targetType == .assignment {
                    assignmentPickerSection
                }

                notesSection
            }
            .navigationTitle("Save to LocumTracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAttachments()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    /// Preview of files being shared
    private var filesPreviewSection: some View {
        Section {
            ForEach(sharedFiles) { file in
                HStack(spacing: 12) {
                    Image(systemName: file.fileType.systemImage)
                        .foregroundStyle(.blue)
                        .font(.title2)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(file.fileType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(
                        fromByteCount: Int64(file.data.count),
                        countStyle: .file
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Files (\(sharedFiles.count))")
        }
    }

    /// Destination type selection
    private var targetSelectionSection: some View {
        Section {
            Picker("Save to", selection: $targetType) {
                ForEach(TargetSelection.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Destination")
        } footer: {
            if targetType == .receipt {
                Text("A new receipt will be created with this attachment. You can edit details in the main app.")
            }
        }
    }

    /// Assignment picker for assignment destination
    private var assignmentPickerSection: some View {
        Section {
            if cachedAssignments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Active Assignments")
                        .font(.headline)
                    Text("Open LocumTracker to create an assignment first, or select 'New Receipt' to create a receipt instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(cachedAssignments) { assignment in
                    Button {
                        selectedAssignmentId = assignment.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(assignment.displayName)
                                    .foregroundStyle(.primary)
                                Text(assignment.dateRangeFormatted)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedAssignmentId == assignment.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Select Assignment")
        }
    }

    /// Optional notes input
    private var notesSection: some View {
        Section {
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Notes")
        }
    }

    // MARK: - Logic

    /// Whether save button should be enabled
    private var canSave: Bool {
        if sharedFiles.isEmpty { return false }

        switch targetType {
        case .assignment:
            return selectedAssignmentId != nil
        case .receipt:
            return true
        }
    }

    /// Save attachments and notify parent
    private func saveAttachments() {
        let result = ShareResult(
            files: sharedFiles,
            targetType: targetType == .assignment ? .assignment : .newReceipt,
            targetId: targetType == .assignment ? selectedAssignmentId : nil,
            notes: notes.isEmpty ? nil : notes
        )
        onSave(result)
    }
}

// MARK: - Preview

#Preview {
    ShareExtensionView(
        sharedFiles: [
            SharedFile(
                filename: "contract.pdf",
                fileType: .pdf,
                data: Data()
            ),
            SharedFile(
                filename: "receipt_photo.jpg",
                fileType: .jpeg,
                data: Data()
            )
        ],
        onSave: { _ in },
        onCancel: { }
    )
}
