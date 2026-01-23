import SwiftUI

#if os(iOS)
import UIKit
import Vision

/// View for cropping images with adjustable rectangle and auto-detection support
///
/// Displays the captured image with a draggable/resizable crop rectangle.
/// Uses Vision framework to auto-detect document/receipt edges on appearance.
public struct ImageCropView: View {
    @Environment(\.dismiss) private var dismiss

    /// The original image to crop
    let originalImage: UIImage

    /// Callback when cropping is complete
    let onCrop: (UIImage) -> Void

    /// Callback when user cancels
    let onCancel: () -> Void

    /// The normalized crop rectangle (0-1 range for both axes)
    @State private var cropRect: CGRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

    /// Whether auto-detection is in progress
    @State private var isDetecting = true

    /// Minimum crop size as a fraction of the image
    private let minCropFraction: CGFloat = 0.1

    /// Handle size for corner dragging
    private let handleSize: CGFloat = 44

    public init(
        originalImage: UIImage,
        onCrop: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalImage = originalImage
        self.onCrop = onCrop
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let imageSize = calculateImageDisplaySize(in: geometry.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    // Image with crop overlay
                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize.width, height: imageSize.height)
                        .overlay {
                            cropOverlay(imageSize: imageSize)
                        }

                    // Instructions at bottom
                    VStack {
                        Spacer()
                        if isDetecting {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Detecting receipt...")
                                    .foregroundStyle(.white)
                            }
                            .padding()
                        } else {
                            Text("Drag corners to adjust crop area")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("Crop Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropAndFinish()
                    }
                    .disabled(isDetecting)
                    .foregroundStyle(.white)
                }
            }
        }
        .task {
            await detectReceiptEdges()
        }
    }

    // MARK: - Size Calculation

    /// Calculate the actual displayed size of the image within the available space
    private func calculateImageDisplaySize(in availableSize: CGSize) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0 else { return .zero }

        // Get the actual pixel dimensions accounting for orientation
        let imageWidth = originalImage.size.width
        let imageHeight = originalImage.size.height

        guard imageWidth > 0, imageHeight > 0 else { return .zero }

        let imageAspect = imageWidth / imageHeight
        let availableAspect = availableSize.width / availableSize.height

        if imageAspect > availableAspect {
            // Image is wider than available space - width is limiting
            let width = availableSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller than available space - height is limiting
            let height = availableSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    // MARK: - Crop Overlay

    @ViewBuilder
    private func cropOverlay(imageSize: CGSize) -> some View {
        let pixelRect = CGRect(
            x: cropRect.minX * imageSize.width,
            y: cropRect.minY * imageSize.height,
            width: cropRect.width * imageSize.width,
            height: cropRect.height * imageSize.height
        )

        ZStack {
            // Semi-transparent overlay with hole for crop area
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .reverseMask {
                    Rectangle()
                        .frame(width: pixelRect.width, height: pixelRect.height)
                        .position(x: pixelRect.midX, y: pixelRect.midY)
                }
                .allowsHitTesting(false)

            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: pixelRect.width, height: pixelRect.height)
                .position(x: pixelRect.midX, y: pixelRect.midY)
                .allowsHitTesting(false)

            // Corner handles
            cornerHandles(for: pixelRect, imageSize: imageSize)
        }
        .frame(width: imageSize.width, height: imageSize.height)
        .coordinateSpace(name: "cropArea")
    }

    @ViewBuilder
    private func cornerHandles(for rect: CGRect, imageSize: CGSize) -> some View {
        // Top-left
        cornerHandle(at: CGPoint(x: rect.minX, y: rect.minY), corner: .topLeft, imageSize: imageSize)
        // Top-right
        cornerHandle(at: CGPoint(x: rect.maxX, y: rect.minY), corner: .topRight, imageSize: imageSize)
        // Bottom-left
        cornerHandle(at: CGPoint(x: rect.minX, y: rect.maxY), corner: .bottomLeft, imageSize: imageSize)
        // Bottom-right
        cornerHandle(at: CGPoint(x: rect.maxX, y: rect.maxY), corner: .bottomRight, imageSize: imageSize)
    }

    @ViewBuilder
    private func cornerHandle(at position: CGPoint, corner: Corner, imageSize: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize / 2, height: handleSize / 2)
            .frame(width: handleSize, height: handleSize)
            .contentShape(Rectangle())
            .position(position)
            .gesture(
                DragGesture(coordinateSpace: .named("cropArea"))
                    .onChanged { value in
                        updateCropRect(for: corner, with: value.location, imageSize: imageSize)
                    }
            )
    }

    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func updateCropRect(for corner: Corner, with location: CGPoint, imageSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let normalizedX = max(0, min(1, location.x / imageSize.width))
        let normalizedY = max(0, min(1, location.y / imageSize.height))

        var newRect = cropRect

        switch corner {
        case .topLeft:
            let newWidth = cropRect.maxX - normalizedX
            let newHeight = cropRect.maxY - normalizedY
            if newWidth >= minCropFraction && newHeight >= minCropFraction {
                newRect.origin.x = normalizedX
                newRect.origin.y = normalizedY
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
        case .topRight:
            let newWidth = normalizedX - cropRect.minX
            let newHeight = cropRect.maxY - normalizedY
            if newWidth >= minCropFraction && newHeight >= minCropFraction {
                newRect.origin.y = normalizedY
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
        case .bottomLeft:
            let newWidth = cropRect.maxX - normalizedX
            let newHeight = normalizedY - cropRect.minY
            if newWidth >= minCropFraction && newHeight >= minCropFraction {
                newRect.origin.x = normalizedX
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
        case .bottomRight:
            let newWidth = normalizedX - cropRect.minX
            let newHeight = normalizedY - cropRect.minY
            if newWidth >= minCropFraction && newHeight >= minCropFraction {
                newRect.size.width = newWidth
                newRect.size.height = newHeight
            }
        }

        cropRect = newRect
    }

    // MARK: - Vision Edge Detection

    private func detectReceiptEdges() async {
        // Skip detection - just use the default 80% crop rect
        // Vision rectangle detection often produces poor results for receipts
        isDetecting = false
    }

    // MARK: - Cropping

    private func cropAndFinish() {
        guard let cgImage = originalImage.cgImage else {
            onCrop(originalImage)
            return
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        let cropX = cropRect.minX * imageWidth
        let cropY = cropRect.minY * imageHeight
        let cropWidth = cropRect.width * imageWidth
        let cropHeight = cropRect.height * imageHeight

        let pixelCropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)

        guard let croppedCGImage = cgImage.cropping(to: pixelCropRect) else {
            onCrop(originalImage)
            return
        }

        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: originalImage.scale,
            orientation: originalImage.imageOrientation
        )

        onCrop(croppedImage)
    }
}

// MARK: - Reverse Mask Modifier

extension View {
    @ViewBuilder
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}

// MARK: - Preview

#Preview {
    ImageCropView(
        originalImage: UIImage(systemName: "doc.text")!,
        onCrop: { _ in },
        onCancel: {}
    )
}
#endif
