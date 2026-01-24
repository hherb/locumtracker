# Phase 4: Camera Integration

SwiftUI view for capturing receipt images on iOS.

## ReceiptCaptureView.swift

```swift
import SwiftUI
import AVFoundation

struct ReceiptCaptureView: View {
    @StateObject private var viewModel = ReceiptCaptureViewModel()
    @Environment(\.dismiss) private var dismiss

    var onCapture: (ReceiptData) -> Void

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Overlay
            VStack {
                Spacer()

                // Capture button
                Button(action: {
                    viewModel.capturePhoto()
                }) {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(.gray, lineWidth: 3)
                                .frame(width: 60, height: 60)
                        )
                }
                .disabled(viewModel.isProcessing)
                .padding(.bottom, 30)
            }

            // Processing indicator
            if viewModel.isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView("Processing receipt...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
        .task {
            await viewModel.setupCamera()
            await viewModel.initializeOCR()
        }
        .onChange(of: viewModel.extractedData) { _, newValue in
            if let data = newValue {
                onCapture(data)
                dismiss()
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

@MainActor
class ReceiptCaptureViewModel: NSObject, ObservableObject {
    @Published var isProcessing = false
    @Published var extractedData: ReceiptData?
    @Published var error: String?

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var ocrEngine: OCREngine?

    func setupCamera() async {
        guard await requestCameraPermission() else {
            error = "Camera permission required"
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Failed to access camera"
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        Task.detached { [captureSession] in
            captureSession.startRunning()
        }
    }

    func initializeOCR() async {
        ocrEngine = OCREngine()
        do {
            try await ocrEngine?.initialize()
        } catch {
            self.error = "Failed to initialize OCR: \(error.localizedDescription)"
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

extension ReceiptCaptureViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.error = error.localizedDescription
                return
            }

            guard let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData)?.cgImage else {
                self.error = "Failed to process photo"
                return
            }

            await processImage(image)
        }
    }

    @MainActor
    private func processImage(_ image: CGImage) async {
        isProcessing = true
        defer { isProcessing = false }

        guard let engine = ocrEngine else {
            error = "OCR not initialized"
            return
        }

        do {
            let results = try await engine.recognizeText(in: image)
            let receiptData = ReceiptDataExtractor.extract(from: results)
            extractedData = receiptData
        } catch {
            self.error = "OCR failed: \(error.localizedDescription)"
        }
    }
}

// Camera preview UIViewRepresentable
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

---

**Previous:** [03_core_implementation.md](03_core_implementation.md)
**Next:** [05_receipt_extraction.md](05_receipt_extraction.md) - Receipt data extraction with regex patterns
