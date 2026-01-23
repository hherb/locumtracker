import SwiftUI

#if os(iOS)
import UIKit
import Vision

/// View for cropping images with adjustable rectangle and auto-detection support
///
/// Displays the captured image with a draggable/resizable crop rectangle.
/// Uses Vision framework to auto-detect document/receipt edges on appearance.
struct ImageCropView: View {
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

    /// Size of the displayed image area
    @State private var imageDisplaySize: CGSize = .zero

    /// Minimum crop size as a fraction of the image
    private let minCropFraction: CGFloat = 0.1

    /// Handle size for corner dragging
    private let handleSize: CGFloat = 44

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack {
                        Spacer()

                        ZStack {
                            // Original image
                            Image(uiImage: originalImage)
                                .resizable()
                                .scaledToFit()
                                .background(
                                    GeometryReader { imageGeometry in
                                        Color.clear
                                            .onAppear {
                                                imageDisplaySize = imageGeometry.size
                                            }
                                            .onChange(of: imageGeometry.size) { _, newSize in
                                                imageDisplaySize = newSize
                                            }
                                    }
                                )

                            // Dimmed overlay outside crop area
                            if imageDisplaySize != .zero {
                                cropOverlay
                            }
                        }

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

    // MARK: - Crop Overlay

    @ViewBuilder
    private var cropOverlay: some View {
        let pixelRect = CGRect(
            x: cropRect.minX * imageDisplaySize.width,
            y: cropRect.minY * imageDisplaySize.height,
            width: cropRect.width * imageDisplaySize.width,
            height: cropRect.height * imageDisplaySize.height
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

            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: pixelRect.width, height: pixelRect.height)
                .position(x: pixelRect.midX, y: pixelRect.midY)

            // Corner handles
            cornerHandles(for: pixelRect)
        }
        .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
    }

    @ViewBuilder
    private func cornerHandles(for rect: CGRect) -> some View {
        // Top-left
        cornerHandle(at: CGPoint(x: rect.minX, y: rect.minY), corner: .topLeft)
        // Top-right
        cornerHandle(at: CGPoint(x: rect.maxX, y: rect.minY), corner: .topRight)
        // Bottom-left
        cornerHandle(at: CGPoint(x: rect.minX, y: rect.maxY), corner: .bottomLeft)
        // Bottom-right
        cornerHandle(at: CGPoint(x: rect.maxX, y: rect.maxY), corner: .bottomRight)
    }

    @ViewBuilder
    private func cornerHandle(at position: CGPoint, corner: Corner) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize / 2, height: handleSize / 2)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        updateCropRect(for: corner, with: value.location)
                    }
            )
            .contentShape(Rectangle().size(CGSize(width: handleSize, height: handleSize)))
    }

    private enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func updateCropRect(for corner: Corner, with location: CGPoint) {
        guard imageDisplaySize.width > 0, imageDisplaySize.height > 0 else { return }

        let normalizedX = max(0, min(1, location.x / imageDisplaySize.width))
        let normalizedY = max(0, min(1, location.y / imageDisplaySize.height))

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
        defer { isDetecting = false }

        guard let cgImage = originalImage.cgImage else { return }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.2
        request.maximumObservations = 1

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            if let observation = request.results?.first {
                // Vision coordinates are normalized with origin at bottom-left
                // Convert to SwiftUI coordinates (origin at top-left)
                await MainActor.run {
                    let boundingBox = observation.boundingBox
                    cropRect = CGRect(
                        x: boundingBox.minX,
                        y: 1 - boundingBox.maxY,
                        width: boundingBox.width,
                        height: boundingBox.height
                    )
                }
            }
        } catch {
            // Detection failed, keep default crop rect
        }
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
