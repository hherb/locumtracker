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

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import LocumTrackerCore

// MARK: - Constants

private enum ShareExtensionConstants {
    /// JPEG compression quality for image fallback
    static let jpegCompressionQuality: CGFloat = 0.8
}

/// Main entry point for the Share Extension
@objc(ShareViewController)
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract shared items from extension context
        guard let extensionContext = extensionContext,
              let items = extensionContext.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        // Process attachments asynchronously
        Task {
            let sharedFiles = await extractSharedFiles(from: items)
            await presentShareUI(with: sharedFiles)
        }
    }

    /// Extract file data from shared items
    private func extractSharedFiles(from items: [NSExtensionItem]) async -> [SharedFile] {
        var files: [SharedFile] = []

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if let file = await loadFile(from: provider) {
                    files.append(file)
                }
            }
        }

        return files
    }

    /// Load a single file from an item provider
    private func loadFile(from provider: NSItemProvider) async -> SharedFile? {
        // Supported types in order of preference
        let supportedTypes: [(UTType, AttachmentType)] = [
            (.pdf, .pdf),
            (UTType("com.microsoft.word.doc") ?? .data, .wordDoc),
            (UTType("org.openxmlformats.wordprocessingml.document") ?? .data, .wordDocx),
            (.jpeg, .jpeg),
            (.png, .png),
            (.heic, .heic),
            (UTType("com.apple.mail.email") ?? .data, .email)
        ]

        for (utType, attachmentType) in supportedTypes {
            if provider.hasItemConformingToTypeIdentifier(utType.identifier) {
                do {
                    if let url = try await loadFileURL(from: provider, type: utType) {
                        let data = try Data(contentsOf: url)
                        return SharedFile(
                            filename: url.lastPathComponent,
                            fileType: attachmentType,
                            data: data
                        )
                    }
                } catch {
                    print("Failed to load file: \(error)")
                }
            }
        }

        // Fallback for images via UIImage
        if provider.canLoadObject(ofClass: UIImage.self) {
            if let image = await loadImage(from: provider),
               let data = image.jpegData(compressionQuality: ShareExtensionConstants.jpegCompressionQuality) {
                return SharedFile(
                    filename: "image_\(Int(Date().timeIntervalSince1970)).jpg",
                    fileType: .jpeg,
                    data: data
                )
            }
        }

        return nil
    }

    /// Load UIImage from item provider
    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, error in
                if let error = error {
                    print("Failed to load image: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    /// Load file URL from item provider
    private func loadFileURL(from provider: NSItemProvider, type: UTType) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url = url else {
                    continuation.resume(returning: nil)
                    return
                }

                // Copy to temp location since original URL is only valid during callback
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Present the SwiftUI share UI
    @MainActor
    private func presentShareUI(with files: [SharedFile]) {
        if files.isEmpty {
            // No supported files found
            showError("No supported files found. LocumTracker supports PDF, Word, images, and email files.")
            return
        }

        let shareView = ShareExtensionView(
            sharedFiles: files,
            onSave: { [weak self] result in
                self?.saveAndClose(result: result)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.backgroundColor = .systemBackground

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    /// Save pending attachments and close extension
    private func saveAndClose(result: ShareResult) {
        for file in result.files {
            let fileDataFilename = "\(UUID().uuidString)_\(file.filename)"
            let pending = PendingAttachment(
                targetType: result.targetType,
                targetId: result.targetId,
                filename: file.filename,
                fileType: file.fileType.rawValue,
                fileDataFilename: fileDataFilename,
                notes: result.notes
            )

            do {
                try SharedDataService.writePendingAttachment(pending, fileData: file.data)
            } catch {
                print("Failed to save pending attachment: \(error)")
            }
        }

        close()
    }

    /// Show error alert
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Cannot Share",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.close()
        })
        present(alert, animated: true)
    }

    /// Close the extension
    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

// MARK: - Supporting Types

/// Represents a file being shared
struct SharedFile: Identifiable {
    let id = UUID()
    let filename: String
    let fileType: AttachmentType
    let data: Data
}

/// Result of the share operation
struct ShareResult {
    let files: [SharedFile]
    let targetType: PendingAttachment.TargetType
    let targetId: UUID?
    let notes: String?
}
