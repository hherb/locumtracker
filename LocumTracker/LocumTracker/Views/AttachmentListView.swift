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
import QuickLook
import LocumTrackerCore

/// Displays attachments for an Assignment or Receipt
struct AttachmentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var attachments: [Attachment]

    let title: String
    private let assignmentId: UUID?
    private let receiptId: UUID?

    @State private var previewURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var attachmentToDelete: Attachment?

    /// Initialize for Assignment attachments
    init(assignmentId: UUID) {
        self.assignmentId = assignmentId
        self.receiptId = nil
        self.title = "Attachments"

        let id = assignmentId
        _attachments = Query(
            filter: #Predicate<Attachment> { $0.assignmentId == id },
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    /// Initialize for Receipt attachments
    init(receiptId: UUID) {
        self.assignmentId = nil
        self.receiptId = receiptId
        self.title = "Attachments"

        let id = receiptId
        _attachments = Query(
            filter: #Predicate<Attachment> { $0.receiptId == id },
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        List {
            if attachments.isEmpty {
                emptyStateView
            } else {
                ForEach(attachments) { attachment in
                    AttachmentRow(attachment: attachment) {
                        previewAttachment(attachment)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            attachmentToDelete = attachment
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .quickLookPreview($previewURL)
        .confirmationDialog(
            "Delete Attachment",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let attachment = attachmentToDelete {
                    deleteAttachment(attachment)
                }
            }
            Button("Cancel", role: .cancel) {
                attachmentToDelete = nil
            }
        } message: {
            if let attachment = attachmentToDelete {
                Text("Are you sure you want to delete '\(attachment.filename)'? This cannot be undone.")
            }
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Attachments", systemImage: "paperclip")
        } description: {
            Text("Share files from other apps using the iOS Share Sheet to attach them here.")
        }
    }

    // MARK: - Actions

    private func previewAttachment(_ attachment: Attachment) {
        guard let data = attachment.fileData else {
            print("No file data available for attachment")
            return
        }

        // Write to temp file for QuickLook
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(attachment.filename)

        do {
            // Remove existing temp file if present
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try data.write(to: tempURL)
            previewURL = tempURL
        } catch {
            print("Failed to write temp file for preview: \(error)")
        }
    }

    private func deleteAttachment(_ attachment: Attachment) {
        modelContext.delete(attachment)
        attachmentToDelete = nil
    }
}

// MARK: - Attachment Row

/// Individual row displaying attachment info
struct AttachmentRow: View {
    let attachment: Attachment
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // File type icon
                Image(systemName: attachment.fileType.systemImage)
                    .foregroundStyle(.blue)
                    .font(.title2)
                    .frame(width: 32)

                // File info
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(attachment.fileType.displayName)
                        Text("·")
                        Text(attachment.fileSizeFormatted)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let notes = attachment.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Preview indicator
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Attachment Summary

/// Compact view showing attachment count with navigation link
struct AttachmentsSummaryView: View {
    let assignmentId: UUID
    @Query private var attachments: [Attachment]

    init(assignmentId: UUID) {
        self.assignmentId = assignmentId
        let id = assignmentId
        _attachments = Query(
            filter: #Predicate<Attachment> { $0.assignmentId == id }
        )
    }

    var body: some View {
        NavigationLink {
            AttachmentListView(assignmentId: assignmentId)
        } label: {
            HStack {
                Label("Attachments", systemImage: "paperclip")

                Spacer()

                if !attachments.isEmpty {
                    Text("\(attachments.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Attachments") {
    NavigationStack {
        AttachmentListView(assignmentId: UUID())
    }
    .modelContainer(for: Attachment.self, inMemory: true)
}

#Preview("Empty State") {
    NavigationStack {
        AttachmentListView(assignmentId: UUID())
    }
    .modelContainer(for: Attachment.self, inMemory: true)
}
