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
import LocumTrackerCore
import LocumTrackerUI
import LocumTrackerOCR
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
import AVFoundation
#endif

/// Represents a pending attachment before the receipt is saved
struct ReceiptPendingAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let type: AttachmentType
    let filename: String?

    /// File size in bytes
    var fileSize: Int64 {
        Int64(data.count)
    }

    /// Human-readable file size
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

/// Sheet view for adding a new receipt
///
/// Provides a form for entering receipt details including amount, category,
/// description, date, optional assignment link, and multiple attachments.
struct AddReceiptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    /// Binding to control sheet presentation
    @Binding var isPresented: Bool

    @State private var amount: Double = 0
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var date: Date = Date()
    @State private var receiptDescription: String = ""
    @State private var selectedAssignmentId: UUID?
    @State private var pendingAttachments: [ReceiptPendingAttachment] = []
    @State private var presentedSheet: SheetType?
    @State private var showCameraPermissionAlert = false
    @State private var isRequestingCameraPermission = false
    @State private var ocrImportState: OCRImportState = .idle
    @State private var showOCRError = false
    @State private var ocrErrorMessage = ""
    @State private var pickedFileData: Data?
    @State private var pickedFileType: AttachmentType?
    @State private var pickedFilename: String?

    /// Sheet types for fullScreenCover presentations
    enum SheetType: Identifiable {
        case camera
        case photoLibrary
        case documentPicker
        case fullImage(Data)
        case viewAttachment(ReceiptPendingAttachment)
        #if os(iOS)
        case cropImage(Data, UUID)
        #endif

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .documentPicker: return "documentPicker"
            case .fullImage: return "fullImage"
            case .viewAttachment(let att): return "viewAttachment-\(att.id)"
            #if os(iOS)
            case .cropImage(_, let id): return "cropImage-\(id)"
            #endif
            }
        }
    }

    /// Whether the form has valid input for saving
    /// Allows saving if either: manual entry (amount > 0 and description) OR attachments added
    private var isValidInput: Bool {
        !pendingAttachments.isEmpty || (amount > 0 && !receiptDescription.isEmpty)
    }

    /// Finds the active assignment for a given date based on assignment date ranges
    private func findActiveAssignment(for date: Date) -> Assignment? {
        assignments.first { assignment in
            date >= assignment.startDate && date <= assignment.endDate
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                categorySection
                detailsSection
                assignmentSection
                attachmentsSection
            }
            .navigationTitle("Add Receipt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReceipt()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
        #if os(iOS)
        .onChange(of: presentedSheet?.id) { oldValue, newValue in
            print("[AddReceiptSheet] presentedSheet CHANGED from '\(oldValue ?? "nil")' to '\(newValue ?? "nil")'")
        }
        .fullScreenCover(item: $presentedSheet) { sheet in
            let _ = print("[AddReceiptSheet] fullScreenCover presenting sheet: \(sheet.id)")
            switch sheet {
            case .camera:
                ReceiptImagePicker(
                    imageData: .init(
                        get: { nil },
                        set: { data in
                            if let data = data {
                                addAttachment(data: data, type: .jpeg, filename: nil)
                            }
                        }
                    ),
                    sourceType: .camera,
                    onDismiss: { presentedSheet = nil }
                )
            case .photoLibrary:
                ReceiptImagePicker(
                    imageData: .init(
                        get: { nil },
                        set: { data in
                            if let data = data {
                                addAttachment(data: data, type: .jpeg, filename: nil)
                            }
                        }
                    ),
                    sourceType: .photoLibrary,
                    onDismiss: { presentedSheet = nil }
                )
            case .documentPicker:
                DocumentPickerView(
                    onDocumentPicked: { url in
                        handlePickedDocument(url)
                        presentedSheet = nil
                    },
                    onCancel: { presentedSheet = nil }
                )
            case .fullImage(let imgData):
                FullImageView(imageData: imgData)
            case .viewAttachment(let attachment):
                AttachmentViewerSheet(attachment: attachment, onDismiss: { presentedSheet = nil })
            case .cropImage(let dataToEdit, let attachmentId):
                ImageCropView(
                    originalImage: UIImage(data: dataToEdit) ?? UIImage(),
                    onCrop: { croppedImage in
                        if let newData = imageToJPEGData(croppedImage) {
                            updateAttachment(id: attachmentId, with: newData)
                        }
                        presentedSheet = nil
                    },
                    onCancel: { presentedSheet = nil }
                )
            }
        }
        #endif
    }

    // MARK: - View Components

    private var amountSection: some View {
        Section("Amount") {
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .onChange(of: amountText) { _, newValue in
                        amount = Double(newValue) ?? 0
                    }
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $category) {
                ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                    Label(cat.description, systemImage: cat.iconName)
                        .tag(cat)
                }
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif

            if category.isTaxDeductible {
                Label("Tax Deductible", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Description", text: $receiptDescription)

            AutoDismissDatePicker(
                label: "Date",
                selection: $date
            )
        }
    }

    private var assignmentSection: some View {
        Section("Link to Assignment (Optional)") {
            Picker("Assignment", selection: $selectedAssignmentId) {
                Text("None").tag(nil as UUID?)
                ForEach(assignments) { assignment in
                    Text(formatAssignmentDateRange(assignment))
                        .tag(assignment.id as UUID?)
                }
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif
        }
    }

    private var attachmentsSection: some View {
        Section("Attachments") {
            if !pendingAttachments.isEmpty {
                ForEach(pendingAttachments) { attachment in
                    AttachmentRowView(
                        attachment: attachment,
                        onTap: {
                            if attachment.type.isImage {
                                presentedSheet = .fullImage(attachment.data)
                            } else {
                                presentedSheet = .viewAttachment(attachment)
                            }
                        },
                        onCrop: attachment.type.isImage ? {
                            presentedSheet = .cropImage(attachment.data, attachment.id)
                        } : nil,
                        onDelete: {
                            removeAttachment(id: attachment.id)
                        }
                    )
                }

                #if os(iOS)
                if let firstImageAttachment = pendingAttachments.first(where: { $0.type.isImage }) {
                    ocrImportButton(for: firstImageAttachment.data)
                }
                #endif
            }

            attachmentPickerButtons
        }
    }

    #if os(iOS)
    @ViewBuilder
    private func ocrImportButton(for imgData: Data) -> some View {
        HStack {
            Button {
                Task {
                    await importFromImage(imgData)
                }
            } label: {
                if ocrImportState.isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(ocrImportState.statusMessage)
                    }
                } else {
                    Label("Import from Image", systemImage: "text.viewfinder")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(ocrImportState.isLoading)
        }
        .padding(.top, 8)
        .alert("OCR Import Failed", isPresented: $showOCRError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ocrErrorMessage)
        }
    }

    private func importFromImage(_ imgData: Data) async {
        ocrImportState = .initializing

        do {
            let service = ReceiptOCRService.shared
            ocrImportState = .processing

            guard let receiptData = try await service.extractReceiptData(from: imgData) else {
                ocrImportState = .failed("Could not process image")
                ocrErrorMessage = "The image could not be processed. Please try a clearer photo."
                showOCRError = true
                return
            }

            if let extractedAmount = receiptData.totalAmount {
                amount = NSDecimalNumber(decimal: extractedAmount).doubleValue
                amountText = String(format: "%.2f", amount)
            }

            if let merchant = receiptData.merchant {
                receiptDescription = merchant
                category = inferCategory(from: merchant)
            }

            if let extractedDate = receiptData.date {
                date = extractedDate
                selectedAssignmentId = findActiveAssignment(for: extractedDate)?.id
            }

            ocrImportState = .completed(receiptData)

            try? await Task.sleep(for: .seconds(2))
            ocrImportState = .idle

        } catch {
            ocrImportState = .failed(error.localizedDescription)
            ocrErrorMessage = "OCR failed: \(error.localizedDescription)"
            showOCRError = true
        }
    }

    private func inferCategory(from merchant: String) -> ExpenseCategory {
        let upperMerchant = merchant.uppercased()

        if ["BP", "SHELL", "CALTEX", "AMPOL", "7-ELEVEN", "UNITED", "LIBERTY", "PUMA"].contains(where: { upperMerchant.contains($0) }) {
            return .travel
        }
        if ["HOTEL", "MOTEL", "INN", "LODGE", "AIRBNB", "RESORT"].contains(where: { upperMerchant.contains($0) }) {
            return .accommodation
        }
        if ["MCDONALD", "KFC", "SUBWAY", "HUNGRY JACK", "DOMINO", "PIZZA", "CAFE", "RESTAURANT", "NANDO"].contains(where: { upperMerchant.contains($0) }) {
            return .meals
        }
        if ["CHEMIST", "PHARMACY", "PRICELINE", "AMCAL", "TERRY WHITE"].contains(where: { upperMerchant.contains($0) }) {
            return .supplies
        }
        if ["OFFICEWORKS", "STAPLES"].contains(where: { upperMerchant.contains($0) }) {
            return .supplies
        }
        return .other
    }
    #endif

    @ViewBuilder
    private var attachmentPickerButtons: some View {
        #if os(iOS)
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                if CameraPermissionService.isCameraHardwareAvailable {
                    Button {
                        handleTakePhotoTapped()
                    } label: {
                        if isRequestingCameraPermission {
                            ProgressView()
                        } else {
                            Label("Camera", systemImage: "camera")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRequestingCameraPermission)
                }

                Button {
                    presentedSheet = .photoLibrary
                } label: {
                    Label("Photos", systemImage: "photo")
                }
                .buttonStyle(.bordered)

                Button {
                    presentedSheet = .documentPicker
                } label: {
                    Label("Files", systemImage: "doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .alert("Camera Access Required", isPresented: $showCameraPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera access in Settings to take receipt photos.")
        }
        #else
        Text("Attachment capture available on iOS")
            .foregroundStyle(.secondary)
            .font(.caption)
        #endif
    }

    #if os(iOS)
    private func handleTakePhotoTapped() {
        let status = CameraPermissionService.authorizationStatus

        switch status {
        case .authorized:
            presentedSheet = .camera

        case .notDetermined:
            isRequestingCameraPermission = true
            Task { @MainActor in
                let granted = await CameraPermissionService.requestPermission()
                isRequestingCameraPermission = false
                if granted {
                    presentedSheet = .camera
                } else {
                    showCameraPermissionAlert = true
                }
            }

        case .denied, .restricted:
            showCameraPermissionAlert = true

        @unknown default:
            showCameraPermissionAlert = true
        }
    }
    #endif

    // MARK: - Attachment Management

    private func addAttachment(data: Data, type: AttachmentType, filename: String?) {
        let attachment = ReceiptPendingAttachment(data: data, type: type, filename: filename)
        pendingAttachments.append(attachment)
    }

    private func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    private func updateAttachment(id: UUID, with newData: Data) {
        if let index = pendingAttachments.firstIndex(where: { $0.id == id }) {
            let old = pendingAttachments[index]
            pendingAttachments[index] = ReceiptPendingAttachment(data: newData, type: old.type, filename: old.filename)
        }
    }

    #if os(iOS)
    private func handlePickedDocument(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let filename = url.lastPathComponent
            let ext = url.pathExtension
            let type = AttachmentType(fromExtension: ext)
            addAttachment(data: data, type: type, filename: filename)
        } catch {
            print("Failed to read document: \(error)")
        }
    }
    #endif

    // MARK: - Helpers

    private func formatAssignmentDateRange(_ assignment: Assignment) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
    }

    // MARK: - Actions

    private func saveReceipt() {
        let finalDescription = receiptDescription.isEmpty ? "Receipt" : receiptDescription
        let finalAssignmentId = selectedAssignmentId ?? findActiveAssignment(for: date)?.id

        // For backwards compatibility, store first image in imageData field
        let firstImageData = pendingAttachments.first(where: { $0.type.isImage })?.data

        let receipt = Receipt(
            amount: amount,
            category: category,
            date: date,
            receiptDescription: finalDescription,
            assignmentId: finalAssignmentId,
            imageData: firstImageData
        )

        modelContext.insert(receipt)

        // Create Attachment objects for all attachments
        for pending in pendingAttachments {
            let attachment = Attachment(
                receiptId: receipt.id,
                filename: pending.filename ?? "attachment.\(pending.type.rawValue)",
                fileType: pending.type,
                fileSize: pending.fileSize,
                fileData: pending.data
            )
            modelContext.insert(attachment)
        }

        isPresented = false
    }
}

// MARK: - Attachment Row View

struct AttachmentRowView: View {
    let attachment: ReceiptPendingAttachment
    let onTap: () -> Void
    let onCrop: (() -> Void)?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or icon
            attachmentThumbnail
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename ?? attachment.type.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(attachment.fileSizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let onCrop = onCrop {
                    Button {
                        onCrop()
                    } label: {
                        Image(systemName: "crop")
                    }
                    .buttonStyle(.borderless)
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private var attachmentThumbnail: some View {
        if attachment.type.isImage {
            #if os(iOS)
            if let uiImage = UIImage(data: attachment.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderIcon
            }
            #else
            placeholderIcon
            #endif
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: attachment.type.systemImage)
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.1))
    }
}

// MARK: - Document Picker

#if os(iOS)
struct DocumentPickerView: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.pdf, .image, .jpeg, .png, .heic]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void
        let onCancel: () -> Void

        init(onDocumentPicked: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onDocumentPicked = onDocumentPicked
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onDocumentPicked(url)
            } else {
                onCancel()
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
#endif

// MARK: - Attachment Viewer Sheet

struct AttachmentViewerSheet: View {
    let attachment: ReceiptPendingAttachment
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if attachment.type.isImage {
                    #if os(iOS)
                    if let uiImage = UIImage(data: attachment.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                    }
                    #endif
                } else if attachment.type == .pdf {
                    PDFViewerView(data: attachment.data)
                } else {
                    VStack {
                        Image(systemName: attachment.type.systemImage)
                            .font(.largeTitle)
                        Text(attachment.filename ?? "Document")
                        Text("Preview not available")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(attachment.filename ?? "Attachment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PDF Viewer

#if os(iOS)
import PDFKit

struct PDFViewerView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#else
struct PDFViewerView: View {
    let data: Data

    var body: some View {
        Text("PDF viewing not available on this platform")
            .foregroundStyle(.secondary)
    }
}
#endif

// MARK: - Preview

#Preview {
    AddReceiptSheet(isPresented: .constant(true))
        .modelContainer(for: [Receipt.self, Assignment.self, Attachment.self], inMemory: true)
}
