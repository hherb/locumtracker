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
import PDFKit
#endif

/// Detail view displaying full receipt information with edit capability
///
/// Shows receipt amount, category, description, date, linked assignment,
/// and attached files. Provides edit and delete functionality.
struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var receipt: Receipt

    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    /// Query attachments for this receipt
    private var attachments: [Attachment] {
        let receiptId = receipt.id
        let descriptor = FetchDescriptor<Attachment>(
            predicate: #Predicate { $0.receiptId == receiptId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFullImage = false
    @State private var selectedAttachment: Attachment?
    @State private var showingAttachmentViewer = false

    var body: some View {
        List {
            amountSection
            categorySection
            detailsSection
            assignmentSection
            attachmentsSection
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
        .sheet(isPresented: $showingAttachmentViewer) {
            if let attachment = selectedAttachment {
                StoredAttachmentViewerSheet(attachment: attachment)
            }
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
    private var attachmentsSection: some View {
        let allAttachments = attachments

        if !allAttachments.isEmpty {
            Section("Attachments (\(allAttachments.count))") {
                ForEach(allAttachments) { attachment in
                    StoredAttachmentRow(attachment: attachment) {
                        selectedAttachment = attachment
                        showingAttachmentViewer = true
                    }
                }
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

    private func deleteReceipt() {
        // Delete associated attachments
        for attachment in attachments {
            modelContext.delete(attachment)
        }
        modelContext.delete(receipt)
        dismiss()
    }
}

// MARK: - Stored Attachment Row

struct StoredAttachmentRow: View {
    let attachment: Attachment
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                attachmentThumbnail
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(attachment.fileSizeFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var attachmentThumbnail: some View {
        if attachment.fileType.isImage, let data = attachment.fileData {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
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
        Image(systemName: attachment.fileType.systemImage)
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.1))
    }
}

// MARK: - Stored Attachment Viewer Sheet

struct StoredAttachmentViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: Attachment

    var body: some View {
        NavigationStack {
            Group {
                if attachment.fileType.isImage, let data = attachment.fileData {
                    #if os(iOS)
                    if let uiImage = UIImage(data: data) {
                        ZoomableImageView(image: Image(uiImage: uiImage))
                    } else {
                        noPreviewView
                    }
                    #else
                    noPreviewView
                    #endif
                } else if attachment.fileType == .pdf, let data = attachment.fileData {
                    #if os(iOS)
                    StoredPDFViewer(data: data)
                    #else
                    noPreviewView
                    #endif
                } else {
                    noPreviewView
                }
            }
            .navigationTitle(attachment.filename)
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

    private var noPreviewView: some View {
        VStack(spacing: 16) {
            Image(systemName: attachment.fileType.systemImage)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(attachment.filename)
                .font(.headline)
            Text("Preview not available")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let image: Image

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        GeometryReader { geometry in
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
                                    scale = minScale
                                    lastScale = minScale
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                )
        }
        .background(Color.black)
    }
}

// MARK: - Stored PDF Viewer

#if os(iOS)
struct StoredPDFViewer: UIViewRepresentable {
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
#endif

// MARK: - Edit Receipt Sheet

/// Sheet view for editing an existing receipt
struct EditReceiptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Assignment.startDate, order: .reverse) private var assignments: [Assignment]

    @Binding var isPresented: Bool
    @Bindable var receipt: Receipt

    /// Query existing attachments for this receipt
    private var existingAttachments: [Attachment] {
        let receiptId = receipt.id
        let descriptor = FetchDescriptor<Attachment>(
            predicate: #Predicate { $0.receiptId == receiptId },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @State private var amount: Double
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var receiptDescription: String
    @State private var selectedAssignmentId: UUID?
    @State private var pendingAttachments: [ReceiptPendingAttachment] = []
    @State private var attachmentsToDelete: Set<UUID> = []
    @State private var presentedSheet: EditSheetType?
    @State private var ocrImportState: OCRImportState = .idle
    @State private var showOCRError = false
    @State private var ocrErrorMessage = ""
    @State private var pickedFileData: Data?
    @State private var pickedFileType: AttachmentType?
    @State private var pickedFilename: String?

    enum EditSheetType: Identifiable {
        case camera
        case photoLibrary
        case documentPicker
        #if os(iOS)
        case cropImage(Data, UUID)
        #endif

        var id: String {
            switch self {
            case .camera: return "camera"
            case .photoLibrary: return "photoLibrary"
            case .documentPicker: return "documentPicker"
            #if os(iOS)
            case .cropImage(_, let id): return "cropImage-\(id)"
            #endif
            }
        }
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

    private var isValidInput: Bool {
        let hasExistingAttachments = existingAttachments.contains { !attachmentsToDelete.contains($0.id) }
        let hasReceiptPendingAttachments = !pendingAttachments.isEmpty
        return hasExistingAttachments || hasReceiptPendingAttachments || (amount > 0 && !receiptDescription.isEmpty)
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
            .fullScreenCover(item: $presentedSheet) { sheet in
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
                    Text(formatAssignmentDateRange(assignment, style: .short))
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
            // Show existing attachments (not marked for deletion)
            ForEach(existingAttachments.filter { !attachmentsToDelete.contains($0.id) }) { attachment in
                ExistingAttachmentRow(
                    attachment: attachment,
                    onDelete: {
                        attachmentsToDelete.insert(attachment.id)
                    }
                )
            }

            // Show pending new attachments
            ForEach(pendingAttachments) { attachment in
                AttachmentRowView(
                    attachment: attachment,
                    onTap: {},
                    onCrop: attachment.type.isImage ? {
                        presentedSheet = .cropImage(attachment.data, attachment.id)
                    } : nil,
                    onDelete: {
                        removeAttachment(id: attachment.id)
                    }
                )
            }

            #if os(iOS)
            // OCR button if there's an image attachment
            if let firstImage = pendingAttachments.first(where: { $0.type.isImage }) {
                ocrImportButton(for: firstImage.data)
            } else if let existingImage = existingAttachments.first(where: { $0.fileType.isImage && !attachmentsToDelete.contains($0.id) }),
                      let data = existingImage.fileData {
                ocrImportButton(for: data)
            }
            #endif

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

    private func findActiveAssignment(for date: Date) -> Assignment? {
        assignments.first { assignment in
            date >= assignment.startDate && date <= assignment.endDate
        }
    }
    #endif

    @ViewBuilder
    private var attachmentPickerButtons: some View {
        #if os(iOS)
        HStack(spacing: 20) {
            if CameraPermissionService.isCameraHardwareAvailable {
                Button {
                    presentedSheet = .camera
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .buttonStyle(.bordered)
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
        #else
        Text("Attachment capture available on iOS")
            .foregroundStyle(.secondary)
            .font(.caption)
        #endif
    }

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

    // MARK: - Actions

    private func saveChanges() {
        receipt.amount = amount
        receipt.category = category
        receipt.date = date
        receipt.receiptDescription = receiptDescription
        receipt.assignmentId = selectedAssignmentId
        receipt.updatedAt = Date()

        // Delete marked attachments
        for attachmentId in attachmentsToDelete {
            if let attachment = existingAttachments.first(where: { $0.id == attachmentId }) {
                modelContext.delete(attachment)
            }
        }

        // Create new attachments
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

// MARK: - Existing Attachment Row

struct ExistingAttachmentRow: View {
    let attachment: Attachment
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            attachmentThumbnail
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(attachment.fileSizeFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var attachmentThumbnail: some View {
        if attachment.fileType.isImage, let data = attachment.fileData {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
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
        Image(systemName: attachment.fileType.systemImage)
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.secondary.opacity(0.1))
    }
}

// MARK: - Full Image View

/// Full screen image viewer with pinch-to-zoom support
struct FullImageView: View {
    @Environment(\.dismiss) private var dismiss
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
                                scale = minScale
                                lastScale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            )
    }
}

// MARK: - Helper Functions

private func formatAssignmentDateRange(_ assignment: Assignment, style: DateFormatter.Style) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = style
    return "\(formatter.string(from: assignment.startDate)) - \(formatter.string(from: assignment.endDate))"
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Receipt.self, Attachment.self, configurations: config)

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
