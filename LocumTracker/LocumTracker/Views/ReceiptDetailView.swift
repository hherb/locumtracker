import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

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
    @State private var showingFullImage = false

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
        .sheet(isPresented: $showingFullImage) {
            if let imageData = receipt.imageData {
                FullImageView(imageData: imageData)
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
            .padding(.vertical, DetailConstants.sectionPadding)
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
        if let imageData = receipt.imageData {
            Section("Receipt Image") {
                Button {
                    showingFullImage = true
                } label: {
                    VStack {
                        ReceiptImageView(imageData: imageData, maxHeight: ImageConstants.previewHeight)

                        Text("Tap to view full size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
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

    @State private var amount: Double
    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var date: Date
    @State private var receiptDescription: String
    @State private var selectedAssignmentId: UUID?
    @State private var imageData: Data?
    @State private var showingImagePicker = false
    @State private var showingCamera = false

    init(isPresented: Binding<Bool>, receipt: Receipt) {
        self._isPresented = isPresented
        self.receipt = receipt
        _amount = State(initialValue: receipt.amount)
        _amountText = State(initialValue: String(format: "%.2f", receipt.amount))
        _category = State(initialValue: receipt.category)
        _date = State(initialValue: receipt.date)
        _receiptDescription = State(initialValue: receipt.receiptDescription)
        _selectedAssignmentId = State(initialValue: receipt.assignmentId)
        _imageData = State(initialValue: receipt.imageData)
    }

    /// Whether the form has valid input for saving
    private var isValidInput: Bool {
        amount > 0 && !receiptDescription.isEmpty
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
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(imageData: $imageData, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(imageData: $imageData, sourceType: .camera)
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
        Section("Receipt Image") {
            if let imgData = imageData {
                VStack {
                    ReceiptImageView(imageData: imgData, maxHeight: ImageConstants.previewHeight)

                    Button("Remove Image", role: .destructive) {
                        imageData = nil
                    }
                    .font(.caption)
                }
            } else {
                imagePickerButtons
            }
        }
    }

    @ViewBuilder
    private var imagePickerButtons: some View {
        #if os(iOS)
        HStack {
            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            Spacer()

            Button {
                showingImagePicker = true
            } label: {
                Label("Choose Photo", systemImage: "photo")
            }
        }
        #else
        Text("Image capture available on iOS")
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
        receipt.imageData = imageData
        receipt.updatedAt = Date()

        isPresented = false
    }
}

// MARK: - Full Image View

/// Full screen image viewer with scroll support
///
/// Displays the receipt image in a scrollable container for zooming.
struct FullImageView: View {
    @Environment(\.dismiss) private var dismiss

    /// The image data to display
    let imageData: Data

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    #if os(iOS)
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    }
                    #else
                    if let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                    }
                    #endif
                }
            }
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
}

// MARK: - Receipt Image View

/// Reusable view for displaying receipt images across platforms
struct ReceiptImageView: View {
    /// The image data to display
    let imageData: Data

    /// Maximum height for the image
    let maxHeight: CGFloat

    var body: some View {
        #if os(iOS)
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: ImageConstants.cornerRadius))
        }
        #else
        if let nsImage = NSImage(data: imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: ImageConstants.cornerRadius))
        }
        #endif
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

// MARK: - Constants

private enum DetailConstants {
    static let sectionPadding: CGFloat = 8
}

private enum ImageConstants {
    static let previewHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 8
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
