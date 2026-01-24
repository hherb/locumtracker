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

#if canImport(UIKit)
import UIKit
import AVFoundation
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
