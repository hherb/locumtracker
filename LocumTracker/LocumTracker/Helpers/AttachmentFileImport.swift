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
import UniformTypeIdentifiers
import LocumTrackerCore

/// A file picked by the user, read into memory and ready to become a receipt attachment
struct ImportedAttachmentFile {
    let data: Data
    let type: AttachmentType
    let filename: String
}

/// File types accepted as receipt attachments
enum AttachmentFileImport {
    static let allowedContentTypes: [UTType] = [.pdf, .image, .jpeg, .png, .heic]

    /// Reads a user-selected file (from a file picker or drag and drop).
    /// - Parameter url: File URL, possibly security-scoped
    /// - Returns: The file contents and inferred type, or nil if it can't be read
    static func load(from url: URL) -> ImportedAttachmentFile? {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer { if isScoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            return ImportedAttachmentFile(
                data: data,
                type: AttachmentType(fromExtension: url.pathExtension),
                filename: url.lastPathComponent
            )
        } catch {
            print("Failed to read attachment file \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}

/// Minimum size for attachment viewer sheets on macOS, where sheets otherwise
/// shrink to their content's ideal size
enum MacSheetSize {
    static let minWidth: CGFloat = 640
    static let minHeight: CGFloat = 520
}

#if os(macOS)
extension View {
    /// Adds a macOS open panel and Finder drag-and-drop for receipt attachments.
    /// - Parameters:
    ///   - isPresented: Binding that shows the open panel
    ///   - onImport: Called once for each file successfully read
    /// - Returns: The modified view
    func attachmentFileImport(
        isPresented: Binding<Bool>,
        onImport: @escaping (ImportedAttachmentFile) -> Void
    ) -> some View {
        self
            .fileImporter(
                isPresented: isPresented,
                allowedContentTypes: AttachmentFileImport.allowedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                urls.compactMap(AttachmentFileImport.load).forEach(onImport)
            }
            .dropDestination(for: URL.self) { urls, _ in
                let files = urls.compactMap(AttachmentFileImport.load)
                files.forEach(onImport)
                return !files.isEmpty
            }
    }
}
#endif
