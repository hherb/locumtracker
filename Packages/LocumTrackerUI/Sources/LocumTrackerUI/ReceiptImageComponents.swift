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
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
import AVFoundation
import PDFKit
#endif

// MARK: - Constants

/// Constants for receipt image handling
public enum ReceiptImageConstants {
    public static let maxPreviewHeight: CGFloat = 200
    public static let cornerRadius: CGFloat = 8
    public static let compressionQuality: CGFloat = 0.7
    /// Maximum dimension (width or height) for stored images to prevent memory issues
    public static let maxStoredImageDimension: CGFloat = 1920
}

// MARK: - Image Resizing

#if os(iOS)
/// Resizes a UIImage to fit within the specified maximum dimension while preserving aspect ratio
/// - Parameters:
///   - image: The original image to resize
///   - maxDimension: The maximum width or height for the resized image
/// - Returns: The resized image, or the original if it's already within bounds
public func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size

    // Check if resize is needed
    guard size.width > maxDimension || size.height > maxDimension else {
        return image
    }

    // Calculate new size maintaining aspect ratio
    let aspectRatio = size.width / size.height
    let newSize: CGSize
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
    } else {
        newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
    }

    // Render resized image
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

/// Converts a UIImage to JPEG data with standard compression
/// - Parameter image: The image to convert
/// - Returns: JPEG data or nil if conversion fails
public func imageToJPEGData(_ image: UIImage) -> Data? {
    let resized = resizeImage(image, maxDimension: ReceiptImageConstants.maxStoredImageDimension)
    return resized.jpegData(compressionQuality: ReceiptImageConstants.compressionQuality)
}
#endif

// MARK: - Receipt Image Preview

/// Reusable view for displaying receipt images with optional action buttons
public struct ReceiptImagePreview: View {
    /// The image data to display
    let imageData: Data

    /// Maximum height for the image
    let maxHeight: CGFloat

    /// Called when delete is tapped (nil hides the button)
    let onDelete: (() -> Void)?

    /// Called when crop is tapped (nil hides the button)
    let onCrop: (() -> Void)?

    /// Called when image is tapped for full view (nil disables tap)
    let onTap: (() -> Void)?

    public init(
        imageData: Data,
        maxHeight: CGFloat = ReceiptImageConstants.maxPreviewHeight,
        onDelete: (() -> Void)? = nil,
        onCrop: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.imageData = imageData
        self.maxHeight = maxHeight
        self.onDelete = onDelete
        self.onCrop = onCrop
        self.onTap = onTap
    }

    public var body: some View {
        VStack {
            imageView

            if onDelete != nil || onCrop != nil {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        #if os(iOS)
        if let uiImage = UIImage(data: imageData) {
            if let onTap = onTap {
                Button {
                    onTap()
                } label: {
                    imageContent(Image(uiImage: uiImage))
                }
                .buttonStyle(.plain)
            } else {
                imageContent(Image(uiImage: uiImage))
            }
        }
        #else
        if let nsImage = NSImage(data: imageData) {
            imageContent(Image(nsImage: nsImage))
        }
        #endif
    }

    @ViewBuilder
    private func imageContent(_ image: Image) -> some View {
        VStack {
            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius))

            if onTap != nil {
                Text("Tap to view full size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 20) {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            #if os(iOS)
            if let onCrop = onCrop {
                Button {
                    onCrop()
                } label: {
                    Label("Crop", systemImage: "crop")
                }
            }
            #endif
        }
        .font(.subheadline)
        .padding(.top, 8)
    }
}

// MARK: - Camera Permission Service

#if os(iOS)
/// Service to handle camera permission checks and requests
public enum CameraPermissionService {
    /// Current camera authorization status
    public static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Whether camera hardware is available on this device
    public static var isCameraHardwareAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Whether camera can be used (hardware available AND permission granted)
    public static var canUseCamera: Bool {
        isCameraHardwareAvailable && authorizationStatus == .authorized
    }

    /// Request camera permission asynchronously
    /// - Returns: true if permission was granted, false otherwise
    @MainActor
    public static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
#endif

// MARK: - Camera Capture Button

#if os(iOS)
/// A button that handles camera permission before capturing
///
/// Checks permission status and either:
/// - Requests permission if undetermined
/// - Shows camera if permitted
/// - Shows Settings alert if denied
public struct CameraCaptureButton: View {
    /// Called to present the camera picker
    let onPresentCamera: () -> Void

    @State private var showingPermissionAlert = false
    @State private var isRequestingPermission = false

    public init(onPresentCamera: @escaping () -> Void) {
        self.onPresentCamera = onPresentCamera
    }

    public var body: some View {
        Button {
            handleTakePhotoTapped()
        } label: {
            if isRequestingPermission {
                ProgressView()
            } else {
                Label("Take Photo", systemImage: "camera")
            }
        }
        .disabled(isRequestingPermission)
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to take receipt photos.")
        }
    }

    private func handleTakePhotoTapped() {
        print("[CameraCaptureButton] handleTakePhotoTapped called")
        guard CameraPermissionService.isCameraHardwareAvailable else {
            print("[CameraCaptureButton] Camera hardware not available")
            return
        }

        let status = CameraPermissionService.authorizationStatus
        print("[CameraCaptureButton] Authorization status: \(status.rawValue) (0=notDetermined, 1=restricted, 2=denied, 3=authorized)")

        switch status {
        case .authorized:
            print("[CameraCaptureButton] Status is .authorized, calling onPresentCamera()")
            onPresentCamera()
            print("[CameraCaptureButton] onPresentCamera() returned")

        case .notDetermined:
            print("[CameraCaptureButton] Status is .notDetermined, requesting permission")
            isRequestingPermission = true
            Task { @MainActor in
                let granted = await CameraPermissionService.requestPermission()
                print("[CameraCaptureButton] Permission request result: \(granted)")
                isRequestingPermission = false
                if granted {
                    print("[CameraCaptureButton] Permission granted, calling onPresentCamera()")
                    onPresentCamera()
                    print("[CameraCaptureButton] onPresentCamera() returned after permission grant")
                } else {
                    print("[CameraCaptureButton] Permission denied, showing alert")
                    showingPermissionAlert = true
                }
            }

        case .denied, .restricted:
            print("[CameraCaptureButton] Status is denied/restricted, showing alert")
            showingPermissionAlert = true

        @unknown default:
            print("[CameraCaptureButton] Unknown status, showing alert")
            showingPermissionAlert = true
        }
    }

    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}
#endif

// MARK: - Camera/Photo Picker

#if os(iOS)
/// Container view controller that hosts UIImagePickerController
///
/// This wrapper is needed because UIImagePickerController doesn't work well
/// when used directly as a UIViewControllerRepresentable in fullScreenCover.
public class ImagePickerHostController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public var sourceType: UIImagePickerController.SourceType = .camera
    public var onImagePicked: ((UIImage) -> Void)?
    public var onCancel: (() -> Void)?

    private var hasPresented = false

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Only present picker once
        guard !hasPresented else { return }
        hasPresented = true

        // For camera, ensure we have authorization before presenting
        if sourceType == .camera {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            print("[Camera Debug] Authorization status: \(status.rawValue)")
            print("[Camera Debug] Camera available: \(UIImagePickerController.isSourceTypeAvailable(.camera))")

            if status == .authorized && UIImagePickerController.isSourceTypeAvailable(.camera) {
                // Small delay to ensure view hierarchy is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.presentCameraPicker()
                }
            } else {
                // Fallback to photo library
                print("[Camera Debug] Falling back to photo library - status: \(status.rawValue)")
                presentPhotoLibraryPicker()
            }
        } else {
            presentPhotoLibraryPicker()
        }
    }

    private func presentCameraPicker() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.cameraCaptureMode = .photo
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.modalPresentationStyle = .fullScreen

        print("[Camera Debug] Presenting camera picker")
        present(imagePicker, animated: true) {
            print("[Camera Debug] Camera picker presented")
        }
    }

    private func presentPhotoLibraryPicker() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.allowsEditing = false

        present(imagePicker, animated: true)
    }

    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true) { [weak self] in
            if let image = info[.originalImage] as? UIImage {
                self?.onImagePicked?(image)
            }
            self?.onCancel?()
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }
}

/// UIKit camera/photo library picker wrapper for SwiftUI
///
/// Captures or selects an image and saves it directly (resized for OCR).
public struct ReceiptImagePicker: UIViewControllerRepresentable {
    /// Binding to store the captured image data
    @Binding var imageData: Data?

    /// Called when picker is dismissed (with or without image)
    let onDismiss: () -> Void

    /// The source type for the picker
    let sourceType: UIImagePickerController.SourceType

    /// Check if camera is available on this device
    public static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    public init(
        imageData: Binding<Data?>,
        sourceType: UIImagePickerController.SourceType,
        onDismiss: @escaping () -> Void
    ) {
        self._imageData = imageData
        self.sourceType = sourceType
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> ImagePickerHostController {
        print("[ReceiptImagePicker] makeUIViewController called with sourceType: \(sourceType.rawValue) (0=photoLibrary, 1=camera, 2=savedPhotosAlbum)")
        let host = ImagePickerHostController()
        host.sourceType = sourceType
        host.onImagePicked = { image in
            self.imageData = imageToJPEGData(image)
        }
        host.onCancel = {
            self.onDismiss()
        }
        return host
    }

    public func updateUIViewController(_ uiViewController: ImagePickerHostController, context: Context) {}
}
#endif

// MARK: - Crop View Wrapper

#if os(iOS)
/// Wrapper view to handle image data to UIImage conversion for cropping
///
/// Use this when presenting ImageCropView from a sheet/fullScreenCover
public struct ReceiptCropWrapper: View {
    @Binding var imageData: Data?
    let onDismiss: () -> Void

    public init(imageData: Binding<Data?>, onDismiss: @escaping () -> Void) {
        self._imageData = imageData
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            ImageCropView(
                originalImage: uiImage,
                onCrop: { croppedImage in
                    imageData = imageToJPEGData(croppedImage)
                    onDismiss()
                },
                onCancel: {
                    onDismiss()
                }
            )
        } else {
            // Fallback - should not happen but dismiss if it does
            Color.clear.onAppear {
                onDismiss()
            }
        }
    }
}
#endif

// MARK: - Attachment Preview

/// Preview view for a single attachment (image or PDF)
public struct AttachmentPreview: View {
    /// The attachment data
    public let data: Data

    /// The type of attachment
    public let attachmentType: AttachmentType

    /// Maximum height for the preview
    public let maxHeight: CGFloat

    /// Called when tapped for full view
    public let onTap: (() -> Void)?

    /// Called when delete is tapped
    public let onDelete: (() -> Void)?

    public init(
        data: Data,
        attachmentType: AttachmentType,
        maxHeight: CGFloat = ReceiptImageConstants.maxPreviewHeight,
        onTap: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.data = data
        self.attachmentType = attachmentType
        self.maxHeight = maxHeight
        self.onTap = onTap
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack {
            if attachmentType.isImage {
                imagePreview
            } else {
                pdfPreview
            }

            if onDelete != nil {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        #if os(iOS)
        if let uiImage = UIImage(data: data) {
            Button {
                onTap?()
            } label: {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
        }
        #else
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius))
        }
        #endif
    }

    @ViewBuilder
    private var pdfPreview: some View {
        #if os(iOS)
        PDFThumbnailView(data: data, maxHeight: maxHeight)
            .onTapGesture {
                onTap?()
            }
        #else
        // macOS: Show PDF icon placeholder
        VStack {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("PDF Document")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: maxHeight)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius))
        #endif
    }
}

// MARK: - PDF Thumbnail

#if os(iOS)
/// View that displays a thumbnail of a PDF's first page
public struct PDFThumbnailView: View {
    let data: Data
    let maxHeight: CGFloat

    public init(data: Data, maxHeight: CGFloat = ReceiptImageConstants.maxPreviewHeight) {
        self.data = data
        self.maxHeight = maxHeight
    }

    public var body: some View {
        Group {
            if let pdfDocument = PDFDocument(data: data),
               let pdfPage = pdfDocument.page(at: 0) {
                let pageRect = pdfPage.bounds(for: .mediaBox)
                let scale = min(maxHeight / pageRect.height, 300 / pageRect.width)
                let thumbnailSize = CGSize(
                    width: pageRect.width * scale,
                    height: pageRect.height * scale
                )

                if let thumbnail = pdfPage.thumbnail(of: thumbnailSize, for: .mediaBox) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: maxHeight)
                        .clipShape(RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            pdfBadge
                        }
                } else {
                    pdfPlaceholder
                }
            } else {
                pdfPlaceholder
            }
        }
    }

    private var pdfBadge: some View {
        Text("PDF")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red)
            .clipShape(Capsule())
            .padding(6)
    }

    private var pdfPlaceholder: some View {
        VStack {
            Image(systemName: "doc.richtext")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("PDF")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: maxHeight)
        .frame(maxWidth: 150)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: ReceiptImageConstants.cornerRadius))
    }
}
#endif

// MARK: - Multiple Attachments Grid

/// Grid view for displaying multiple attachments
public struct AttachmentsGridView: View {
    /// The attachments to display
    public let attachments: [ReceiptAttachment]

    /// Called when an attachment is tapped
    public let onSelect: ((ReceiptAttachment) -> Void)?

    /// Called when delete is tapped for an attachment
    public let onDelete: ((ReceiptAttachment) -> Void)?

    /// Whether editing is enabled
    public let isEditing: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
    ]

    public init(
        attachments: [ReceiptAttachment],
        isEditing: Bool = false,
        onSelect: ((ReceiptAttachment) -> Void)? = nil,
        onDelete: ((ReceiptAttachment) -> Void)? = nil
    ) {
        self.attachments = attachments
        self.isEditing = isEditing
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(attachments.sorted { $0.order < $1.order }) { attachment in
                AttachmentGridItem(
                    attachment: attachment,
                    isEditing: isEditing,
                    onTap: { onSelect?(attachment) },
                    onDelete: { onDelete?(attachment) }
                )
            }
        }
    }
}

/// Single item in the attachments grid
public struct AttachmentGridItem: View {
    let attachment: ReceiptAttachment
    let isEditing: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            AttachmentPreview(
                data: attachment.data,
                attachmentType: attachment.attachmentType,
                maxHeight: 100,
                onTap: onTap,
                onDelete: nil
            )

            if isEditing {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 8, y: -8)
            }
        }
    }
}

// MARK: - Document Picker

#if os(iOS)
/// Document picker for selecting files (PDFs, images)
public struct DocumentPicker: UIViewControllerRepresentable {
    /// Binding to store the picked file data
    @Binding var fileData: Data?

    /// Binding to store the picked file type
    @Binding var fileType: AttachmentType?

    /// Binding to store the filename
    @Binding var filename: String?

    /// Called when picker is dismissed
    let onDismiss: () -> Void

    /// Allowed content types
    let contentTypes: [UTType]

    public init(
        fileData: Binding<Data?>,
        fileType: Binding<AttachmentType?>,
        filename: Binding<String?>,
        contentTypes: [UTType] = [.pdf, .jpeg, .png, .heic],
        onDismiss: @escaping () -> Void
    ) {
        self._fileData = fileData
        self._fileType = fileType
        self._filename = filename
        self.contentTypes = contentTypes
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onDismiss()
                return
            }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                parent.onDismiss()
                return
            }

            defer {
                url.stopAccessingSecurityScopedResource()
            }

            do {
                let data = try Data(contentsOf: url)

                // Validate file size
                guard data.count <= maxAttachmentSize else {
                    parent.onDismiss()
                    return
                }

                parent.fileData = data
                parent.filename = url.lastPathComponent
                parent.fileType = AttachmentType.from(filename: url.lastPathComponent)
            } catch {
                // Failed to read file
            }

            parent.onDismiss()
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss()
        }
    }
}
#endif

// MARK: - Add Attachment Button

#if os(iOS)
/// Button with menu for adding attachments (camera, photo library, files)
public struct AddAttachmentButton: View {
    /// Called when camera is selected
    let onCamera: () -> Void

    /// Called when photo library is selected
    let onPhotoLibrary: () -> Void

    /// Called when files is selected
    let onFiles: () -> Void

    public init(
        onCamera: @escaping () -> Void,
        onPhotoLibrary: @escaping () -> Void,
        onFiles: @escaping () -> Void
    ) {
        self.onCamera = onCamera
        self.onPhotoLibrary = onPhotoLibrary
        self.onFiles = onFiles
    }

    public var body: some View {
        Menu {
            if CameraPermissionService.isCameraHardwareAvailable {
                Button {
                    onCamera()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            Button {
                onPhotoLibrary()
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                onFiles()
            } label: {
                Label("Browse Files", systemImage: "folder")
            }
        } label: {
            Label("Add Attachment", systemImage: "plus.circle")
        }
    }
}
#endif

// MARK: - PDF Viewer

#if os(iOS)
/// Full-screen PDF viewer
public struct PDFViewer: UIViewRepresentable {
    let data: Data

    public init(data: Data) {
        self.data = data
    }

    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        return pdfView
    }

    public func updateUIView(_ uiView: PDFView, context: Context) {}
}

/// Sheet wrapper for viewing a PDF
public struct PDFViewerSheet: View {
    let data: Data
    let filename: String?
    @Environment(\.dismiss) private var dismiss

    public init(data: Data, filename: String? = nil) {
        self.data = data
        self.filename = filename
    }

    public var body: some View {
        NavigationStack {
            PDFViewer(data: data)
                .navigationTitle(filename ?? "PDF Document")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pdfDataURL, preview: SharePreview(filename ?? "Document", image: Image(systemName: "doc.richtext")))
                    }
                }
        }
    }

    private var pdfDataURL: URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename ?? "document.pdf")
        try? data.write(to: tempURL)
        return tempURL
    }
}
#endif

// MARK: - Attachment Viewer

#if os(iOS)
/// View for displaying an attachment full-screen (handles both images and PDFs)
public struct AttachmentViewer: View {
    let attachment: ReceiptAttachment
    @Environment(\.dismiss) private var dismiss

    public init(attachment: ReceiptAttachment) {
        self.attachment = attachment
    }

    public var body: some View {
        NavigationStack {
            Group {
                if attachment.isImage {
                    imageViewer
                } else {
                    PDFViewer(data: attachment.data)
                }
            }
            .navigationTitle(attachment.filename ?? attachment.attachmentType.description)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    shareButton
                }
            }
        }
    }

    @ViewBuilder
    private var imageViewer: some View {
        if let uiImage = UIImage(data: attachment.data) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
        } else {
            ContentUnavailableView("Unable to load image", systemImage: "photo")
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(attachment.filename ?? "attachment.\(attachment.attachmentType.fileExtension)")

        let _ = try? attachment.data.write(to: tempURL)

        ShareLink(
            item: tempURL,
            preview: SharePreview(
                attachment.filename ?? "Attachment",
                image: Image(systemName: attachment.isImage ? "photo" : "doc.richtext")
            )
        )
    }
}
#endif
