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
#endif

/// Detail view displaying full receipt information with edit capability
///
/// Shows receipt amount, category, description, date, linked assignment,
/// and attached image. Provides edit and delete functionality.
struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var receipt: Receipt

    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedAttachment: ReceiptAttachment?

    var body: some View {
        List {
            amountSection
            categorySection
            detailsSection
            assignmentSection
            imageSection
            actionsSection
        }
        .navigationTitle("Receipt Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditReceiptSheet(isPresented: $showingEditSheet, receipt: receipt)
        }
        .sheet(item: $selectedAttachment) { attachment in
            AttachmentViewer(attachment: attachment)
        }
        .confirmationDialog(
            "Delete Receipt",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this receipt? This action cannot be undone.")
        }
    }

    // MARK: - View Components

    private var amountSection: some View {
        Section("Amount") {
            HStack {
                Text(CurrencyFormatter.format(receipt.amount))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                CategoryBadge(category: receipt.category)
            }
            .padding(.vertical, 8)
        }
    }

    private var categorySection: some View {
        Section("Category") {
            LabeledContent("Type") {
                Text(receipt.category.description)
            }

            LabeledContent("Tax Status") {
                if receipt.category.isTaxDeductible {
                    Label("Deductible", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Not Deductible")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Description") {
                Text(receipt.receiptDescription)
            }

            LabeledContent("Date") {
                Text(receipt.date, style: .date)
            }

            LabeledContent("Added") {
                Text(receipt.createdAt, style: .date)
            }
        }
    }

    private var assignmentSection: some View {
        Section("Assignment") {
            if let assignmentId = receipt.assignmentId,
               let assignment = assignments.first(where: { $0.id == assignmentId }) {
                LabeledContent("Linked Assignment") {
                    Text(formatAssignmentDateRange(assignment, style: .medium))
                }
            } else {
                Text("Not linked to any assignment")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        let attachments = receipt.sortedAttachments

        if !attachments.isEmpty {
            Section("Attachments (\(attachments.count))") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)], spacing: 12) {
                    ForEach(attachments) { attachment in
                        AttachmentPreview(
                            data: attachment.data,
                            attachmentType: attachment.attachmentType,
                            maxHeight: 120,
                            onTap: { selectedAttachment = attachment },
                            onDelete: nil
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        } else if let imageData = receipt.imageData {
            // Legacy: show single image data for old receipts
            Section("Receipt Image") {
                ReceiptImagePreview(
                    imageData: imageData,
                    onTap: {
                        // Create temporary attachment for viewer
                        let tempAttachment = ReceiptAttachment(
                            data: imageData,
                            attachmentType: .jpeg,
                            filename: nil,
                            order: 0
                        )
                        selectedAttachment = tempAttachment
                    }
                )
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Delete Receipt", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    // MARK: - Actions

    /// Deletes the receipt and dismisses the view
    private func deleteReceipt() {
        modelContext.delete(receipt)
        dismiss()
    }
}

// MARK: - Edit Receipt Sheet

/// Sheet view for editing an existing receipt
///
/// Pre-populates form fields with current receipt values.
struct EditReceiptSheet: View {
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    /// Binding to control sheet presentation
    @Binding var isPresented: Bool

    /// The receipt being edited
    @Bindable var receipt: Receipt

    @Environment(\.modelContext) private var modelContext

    @State private var amount: Double
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var receiptDescription: String
    @State private var selectedAssignmentId: UUID?
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var attachmentsToDelete: Set<UUID> = []
    @State private var presentedSheet: SheetType?
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
        case viewAttachment(ReceiptAttachment)
        case viewPendingAttachment(PendingAttachment)
        #if os(iOS)
        case cropImage(Data)
        #endif

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .documentPicker: return "documentPicker"
            case .viewAttachment(let att): return "viewAttachment-\(att.id)"
            case .viewPendingAttachment(let att): return "viewPending-\(att.id)"
            #if os(iOS)
            case .cropImage: return "cropImage"
            #endif
            }
        }
    }

    /// Pending attachment for new files added during edit
    struct PendingAttachment: Identifiable {
        let id = UUID()
        let data: Data
        let type: AttachmentType
        let filename: String?
    }

    init(isPresented: Binding<Bool>, receipt: Receipt) {
        self._isPresented = isPresented
        self.receipt = receipt
        _amount = State(initialValue: receipt.amount)
        _amountText = State(initialValue: String(format: "%.2f", receipt.amount))
        _category = State(initialValue: receipt.category)
        _date = State(initialValue: receipt.date)
        _receiptDescription = State(initialValue: receipt.receiptDescription)
        _selectedAssignmentId = State(initialValue: receipt.assignmentId)
    }

    /// Existing attachments that haven't been marked for deletion
    private var existingAttachments: [ReceiptAttachment] {
        receipt.sortedAttachments.filter { !attachmentsToDelete.contains($0.id) }
    }

    /// Whether the form has valid input for saving
    private var isValidInput: Bool {
        let hasAttachments = !existingAttachments.isEmpty || !pendingAttachments.isEmpty || receipt.imageData != nil
        return hasAttachments || (amount > 0 && !receiptDescription.isEmpty)
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
            .navigationTitle("Edit Receipt")
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
                        saveChanges()
                    }
                    .disabled(!isValidInput)
                }
            }
            #if os(iOS)
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
                switch sheet {
                case .camera:
                    EditCameraPickerWrapper(
                        onImageCaptured: { data in
                            let attachment = PendingAttachment(data: data, type: .jpeg, filename: nil)
                            pendingAttachments.append(attachment)
                        },
                        onDismiss: { presentedSheet = nil }
                    )
                case .photoLibrary:
                    EditPhotoLibraryPickerWrapper(
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
                case .viewAttachment(let attachment):
                    AttachmentViewer(attachment: attachment)
                case .viewPendingAttachment(let pending):
                    EditPendingAttachmentViewer(attachment: pending)
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
                    Label(cat.description, systemImage: cat.iconName).tag(cat)
                }
            }
            #if os(iOS)
            .pickerStyle(.navigationLink)
            #endif
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
                    Text(formatAssignmentDateRange(assignment, style: .short))
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
            // Existing attachments (not marked for deletion)
            if !existingAttachments.isEmpty || !pendingAttachments.isEmpty {
                attachmentsGrid

                #if os(iOS)
                // OCR import for the first image attachment
                if let firstImage = existingAttachments.first(where: { $0.isImage }) {
                    ocrImportButton(for: firstImage.data)
                } else if let firstPending = pendingAttachments.first(where: { $0.type.isImage }) {
                    ocrImportButton(for: firstPending.data)
                }
                #endif
            }

            attachmentPickerButtons

            let totalCount = existingAttachments.count + pendingAttachments.count
            if totalCount > 0 {
                Text("\(totalCount) attachment\(totalCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var attachmentsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 8)], spacing: 8) {
            // Existing attachments
            ForEach(existingAttachments) { attachment in
                ZStack(alignment: .topTrailing) {
                    AttachmentPreview(
                        data: attachment.data,
                        attachmentType: attachment.attachmentType,
                        maxHeight: 80,
                        onTap: { presentedSheet = .viewAttachment(attachment) },
                        onDelete: nil
                    )

                    Button {
                        attachmentsToDelete.insert(attachment.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                    }
                    .offset(x: 6, y: -6)
                }
            }

            // Pending attachments (newly added)
            ForEach(pendingAttachments) { attachment in
                ZStack(alignment: .topTrailing) {
                    AttachmentPreview(
                        data: attachment.data,
                        attachmentType: attachment.type,
                        maxHeight: 80,
                        onTap: { presentedSheet = .viewPendingAttachment(attachment) },
                        onDelete: nil
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 2)
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

    private func findActiveAssignment(for date: Date) -> Assignment? {
        assignments.first { assignment in
            date >= assignment.startDate && date <= assignment.endDate
        }
    }
    #endif

    @ViewBuilder
    private var attachmentPickerButtons: some View {
        #if os(iOS)
        Menu {
            if CameraPermissionService.isCameraHardwareAvailable {
                Button {
                    presentedSheet = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }

            Button {
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
        #else
        Text("Attachments available on iOS")
            .foregroundStyle(.secondary)
            .font(.caption)
        #endif
    }

    // MARK: - Actions

    /// Saves changes to the receipt and dismisses the sheet
    private func saveChanges() {
        receipt.amount = amount
        receipt.category = category
        receipt.date = date
        receipt.receiptDescription = receiptDescription
        receipt.assignmentId = selectedAssignmentId
        receipt.updatedAt = Date()

        // Delete attachments marked for removal
        for attachmentId in attachmentsToDelete {
            if let attachment = receipt.attachments?.first(where: { $0.id == attachmentId }) {
                receipt.removeAttachment(attachment)
                modelContext.delete(attachment)
            }
        }

        // Add new pending attachments
        let currentMaxOrder = receipt.sortedAttachments.last?.order ?? -1
        for (index, pending) in pendingAttachments.enumerated() {
            let attachment = ReceiptAttachment(
                data: pending.data,
                attachmentType: pending.type,
                filename: pending.filename,
                order: currentMaxOrder + 1 + index
            )
            receipt.addAttachment(attachment)
            modelContext.insert(attachment)
        }

        // Clear legacy imageData if we have new attachments
        if !pendingAttachments.isEmpty || !existingAttachments.isEmpty {
            receipt.imageData = nil
        }

        isPresented = false
    }
}

// MARK: - Edit Sheet Helper Views

#if os(iOS)
/// Wrapper for camera picker in edit sheet
private struct EditCameraPickerWrapper: UIViewControllerRepresentable {
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

/// Wrapper for photo library picker in edit sheet
private struct EditPhotoLibraryPickerWrapper: UIViewControllerRepresentable {
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

/// Viewer for pending attachments in edit sheet
private struct EditPendingAttachmentViewer: View {
    let attachment: EditReceiptSheet.PendingAttachment
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

// MARK: - Full Image View

/// Full screen image viewer with pinch-to-zoom support
///
/// Displays the receipt image initially filling the screen with support
/// for pinch-to-zoom and pan gestures.
struct FullImageView: View {
    @Environment(\.dismiss) private var dismiss

    /// The image data to display
    let imageData: Data

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    zoomableImage(Image(uiImage: uiImage), in: geometry)
                }
                #else
                if let nsImage = NSImage(data: imageData) {
                    zoomableImage(Image(nsImage: nsImage), in: geometry)
                }
                #endif
            }
            .background(Color.black)
            .navigationTitle("Receipt Image")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func zoomableImage(_ image: Image, in geometry: GeometryProxy) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastScale * value.magnification
                        scale = min(max(newScale, minScale), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        // Reset offset if zoomed out to minimum
                        if scale <= minScale {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > minScale {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if scale > minScale {
                                // Reset to original size
                                scale = minScale
                                lastScale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                // Zoom in
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            )
    }
}

// MARK: - Helper Functions

/// Formats an assignment's date range for display
/// - Parameters:
///   - assignment: The assignment to format
///   - style: The date formatter style to use
/// - Returns: A formatted date range string
private func formatAssignmentDateRange(_ assignment: Assignment, style: DateFormatter.Style) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = style
    return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Receipt.self, configurations: config)

    let receipt = Receipt(
        amount: 185.00,
        category: .accommodation,
        date: Date(),
        receiptDescription: "Hotel Darwin - 2 nights accommodation"
    )
    container.mainContext.insert(receipt)

    return NavigationStack {
        ReceiptDetailView(receipt: receipt)
    }
    .modelContainer(container)
}
