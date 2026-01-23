import SwiftUI

#if canImport(UIKit)
import UIKit
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

// MARK: - Camera/Photo Picker

#if os(iOS)
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

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ReceiptImagePicker

        init(parent: ReceiptImagePicker) {
            self.parent = parent
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = imageToJPEGData(image)
            }
            picker.dismiss(animated: true) {
                self.parent.onDismiss()
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.parent.onDismiss()
            }
        }
    }
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
