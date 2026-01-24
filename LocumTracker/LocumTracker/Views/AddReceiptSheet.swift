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
struct PendingAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let type: AttachmentType
    let filename: String?
}

/// Sheet view for adding a new receipt
///
/// Provides a form for entering receipt details including amount, category,
/// description, date, optional assignment link, and image capture.
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
    @State private var pendingAttachments: [PendingAttachment] = []
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
        case viewAttachment(PendingAttachment)
        #if os(iOS)
        /// Crop with the image data embedded to avoid state timing issues
        case cropImage(Data)
        #endif

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .documentPicker: return "documentPicker"
            case .fullImage: return "fullImage"
            case .viewAttachment(let att): return "viewAttachment-\(att.id)"
            #if os(iOS)
            case .cropImage: return "cropImage"
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
    /// - Parameter date: The date to check
    /// - Returns: The assignment that contains this date, or nil if none found
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
                imageSection
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
        .onChange(of: pickedFileData) { oldValue, newValue in
            if let data = newValue, let type = pickedFileType {
                let attachment = PendingAttachment(data: data, type: type, filename: pickedFilename)
                pendingAttachments.append(attachment)
                pickedFileData = nil
                pickedFileType = nil
                pickedFilename = nil
            }
        }
        .fullScreenCover(item: $presentedSheet) { sheet in
            let _ = print("[AddReceiptSheet] fullScreenCover presenting sheet: \(sheet.id)")
            switch sheet {
            case .camera:
                let _ = print("[AddReceiptSheet] Creating ReceiptImagePicker with .camera")
                CameraPickerWrapper(
                    onImageCaptured: { data in
                        let attachment = PendingAttachment(data: data, type: .jpeg, filename: nil)
                        pendingAttachments.append(attachment)
                    },
                    onDismiss: { presentedSheet = nil }
                )
            case .photoLibrary:
                PhotoLibraryPickerWrapper(
                    onImageSelected: { data in
                        let attachment = PendingAttachment(data: data, type: .jpeg, filename: nil)
                        pendingAttachments.append(attachment)
                    },
                    onDismiss: { presentedSheet = nil }
                )
            case .documentPicker:
                DocumentPicker(
                    fileData: $pickedFileData,
                    fileType: $pickedFileType,
                    filename: $pickedFilename,
                    onDismiss: { presentedSheet = nil }
                )
            case .fullImage(let imgData):
                FullImageView(imageData: imgData)
            case .viewAttachment(let attachment):
                AttachmentFullScreenView(attachment: attachment)
            case .cropImage(let dataToEdit):
                ImageCropView(
                    originalImage: UIImage(data: dataToEdit) ?? UIImage(),
                    onCrop: { croppedImage in
                        if let jpegData = imageToJPEGData(croppedImage) {
                            let attachment = PendingAttachment(data: jpegData, type: .jpeg, filename: nil)
                            pendingAttachments.append(attachment)
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

            DatePicker(
                "Date",
                selection: $date,
                displayedComponents: .date
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

    private var imageSection: some View {
        Section("Attachments") {
            if !pendingAttachments.isEmpty {
                attachmentsGrid

                #if os(iOS)
                // OCR import for the first image attachment
                if let firstImage = pendingAttachments.first(where: { $0.type.isImage }) {
                    ocrImportButton(for: firstImage.data)
                }
                #endif
            }

            attachmentPickerButtons

            if !pendingAttachments.isEmpty {
                Text("\(pendingAttachments.count) attachment\(pendingAttachments.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var attachmentsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 8)], spacing: 8) {
            ForEach(pendingAttachments) { attachment in
                ZStack(alignment: .topTrailing) {
                    AttachmentPreview(
                        data: attachment.data,
                        attachmentType: attachment.type,
                        maxHeight: 80,
                        onTap: { presentedSheet = .viewAttachment(attachment) },
                        onDelete: nil
                    )

                    Button {
                        pendingAttachments.removeAll { $0.id == attachment.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .offset(x: 6, y: -6)
                }
            }
        }
        .padding(.vertical, 4)
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

            // Apply extracted data to form fields
            if let extractedAmount = receiptData.totalAmount {
                amount = NSDecimalNumber(decimal: extractedAmount).doubleValue
                amountText = String(format: "%.2f", amount)
            }

            if let merchant = receiptData.merchant {
                receiptDescription = merchant
                // Try to infer category from merchant name
                category = inferCategory(from: merchant)
            }

            if let extractedDate = receiptData.date {
                date = extractedDate
                // Update assignment selection based on new date
                selectedAssignmentId = findActiveAssignment(for: extractedDate)?.id
            }

            ocrImportState = .completed(receiptData)

            // Show success feedback briefly then reset
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

        // Fuel stations
        if ["BP", "SHELL", "CALTEX", "AMPOL", "7-ELEVEN", "UNITED", "LIBERTY", "PUMA"].contains(where: { upperMerchant.contains($0) }) {
            return .travel
        }

        // Accommodation
        if ["HOTEL", "MOTEL", "INN", "LODGE", "AIRBNB", "RESORT"].contains(where: { upperMerchant.contains($0) }) {
            return .accommodation
        }

        // Restaurants/fast food
        if ["MCDONALD", "KFC", "SUBWAY", "HUNGRY JACK", "DOMINO", "PIZZA", "CAFE", "RESTAURANT", "NANDO"].contains(where: { upperMerchant.contains($0) }) {
            return .meals
        }

        // Pharmacy/medical
        if ["CHEMIST", "PHARMACY", "PRICELINE", "AMCAL", "TERRY WHITE"].contains(where: { upperMerchant.contains($0) }) {
            return .supplies
        }

        // Office supplies
        if ["OFFICEWORKS", "STAPLES"].contains(where: { upperMerchant.contains($0) }) {
            return .supplies
        }

        return .other
    }
    #endif

    @ViewBuilder
    private var attachmentPickerButtons: some View {
        #if os(iOS)
        Menu {
            if CameraPermissionService.isCameraHardwareAvailable {
                Button {
                    handleTakePhotoTapped()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                .disabled(isRequestingCameraPermission)
            }

            Button {
                print("[AddReceiptSheet] Choose Photo button tapped, setting presentedSheet = .photoLibrary")
                presentedSheet = .photoLibrary
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                presentedSheet = .documentPicker
            } label: {
                Label("Browse Files", systemImage: "folder")
            }
        } label: {
            Label("Add Attachment", systemImage: "plus.circle")
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
        Text("Attachments available on iOS")
            .foregroundStyle(.secondary)
            .font(.caption)
        #endif
    }

    #if os(iOS)
    private func handleTakePhotoTapped() {
        print("[AddReceiptSheet] handleTakePhotoTapped called")

        let status = CameraPermissionService.authorizationStatus
        print("[AddReceiptSheet] Camera authorization status: \(status.rawValue)")

        switch status {
        case .authorized:
            print("[AddReceiptSheet] Already authorized, setting presentedSheet = .camera")
            presentedSheet = .camera
            print("[AddReceiptSheet] presentedSheet is now: \(String(describing: presentedSheet?.id))")

        case .notDetermined:
            print("[AddReceiptSheet] Permission not determined, requesting...")
            isRequestingCameraPermission = true
            Task { @MainActor in
                let granted = await CameraPermissionService.requestPermission()
                isRequestingCameraPermission = false
                print("[AddReceiptSheet] Permission request result: \(granted)")
                if granted {
                    print("[AddReceiptSheet] Permission granted, setting presentedSheet = .camera")
                    presentedSheet = .camera
                    print("[AddReceiptSheet] presentedSheet is now: \(String(describing: presentedSheet?.id))")
                } else {
                    showCameraPermissionAlert = true
                }
            }

        case .denied, .restricted:
            print("[AddReceiptSheet] Permission denied/restricted")
            showCameraPermissionAlert = true

        @unknown default:
            showCameraPermissionAlert = true
        }
    }
    #endif

    // MARK: - Helpers

    /// Formats an assignment's date range for display
    /// - Parameter assignment: The assignment to format
    /// - Returns: A formatted date range string
    private func formatAssignmentDateRange(_ assignment: Assignment) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
    }

    // MARK: - Actions

    /// Saves the receipt to the model context and dismisses the sheet
    ///
    /// When saving with only attachments (no manual entry), applies defaults:
    /// - Amount: 0.00
    /// - Category: .other (tax deductible)
    /// - Description: "Receipt"
    /// - Assignment: Inferred from current date if within an assignment's date range
    private func saveReceipt() {
        // Apply defaults for attachment-only saves
        let finalDescription = receiptDescription.isEmpty ? "Receipt" : receiptDescription
        let finalAssignmentId = selectedAssignmentId ?? findActiveAssignment(for: date)?.id

        let receipt = Receipt(
            amount: amount,
            category: category,
            date: date,
            receiptDescription: finalDescription,
            assignmentId: finalAssignmentId,
            imageData: nil
        )

        modelContext.insert(receipt)

        // Create and attach ReceiptAttachment objects
        for (index, pending) in pendingAttachments.enumerated() {
            let attachment = ReceiptAttachment(
                data: pending.data,
                attachmentType: pending.type,
                filename: pending.filename,
                order: index
            )
            receipt.addAttachment(attachment)
            modelContext.insert(attachment)
        }

        isPresented = false
    }
}

// MARK: - Helper Views

#if os(iOS)
/// Wrapper for camera picker that captures image data directly
private struct CameraPickerWrapper: UIViewControllerRepresentable {
    let onImageCaptured: (Data) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> ImagePickerHostController {
        let host = ImagePickerHostController()
        host.sourceType = .camera
        host.onImagePicked = { image in
            if let data = imageToJPEGData(image) {
                onImageCaptured(data)
            }
        }
        host.onCancel = onDismiss
        return host
    }

    func updateUIViewController(_ uiViewController: ImagePickerHostController, context: Context) {}
}

/// Wrapper for photo library picker that captures image data directly
private struct PhotoLibraryPickerWrapper: UIViewControllerRepresentable {
    let onImageSelected: (Data) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> ImagePickerHostController {
        let host = ImagePickerHostController()
        host.sourceType = .photoLibrary
        host.onImagePicked = { image in
            if let data = imageToJPEGData(image) {
                onImageSelected(data)
            }
        }
        host.onCancel = onDismiss
        return host
    }

    func updateUIViewController(_ uiViewController: ImagePickerHostController, context: Context) {}
}

/// Full screen view for a pending attachment
private struct AttachmentFullScreenView: View {
    let attachment: PendingAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if attachment.type.isImage {
                    imageViewer
                } else {
                    PDFViewer(data: attachment.data)
                }
            }
            .navigationTitle(attachment.filename ?? attachment.type.description)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
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
}
#endif

// MARK: - Preview

#Preview {
    AddReceiptSheet(isPresented: .constant(true))
        .modelContainer(for: [Receipt.self, Assignment.self], inMemory: true)
}
