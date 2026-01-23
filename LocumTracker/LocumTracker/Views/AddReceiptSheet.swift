import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

#if canImport(UIKit)
import UIKit
#endif

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
    @State private var imageData: Data?
    @State private var showingCamera = false
    @State private var presentedSheet: SheetType?

    /// Sheet types (excluding camera which uses fullScreenCover)
    enum SheetType: Identifiable {
        case photoLibrary
        case fullImage
        #if os(iOS)
        case cropImage
        #endif

        var id: Self { self }
    }

    /// Whether the form has valid input for saving
    /// Allows saving if either: manual entry (amount > 0 and description) OR image captured
    private var isValidInput: Bool {
        imageData != nil || (amount > 0 && !receiptDescription.isEmpty)
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
        .fullScreenCover(isPresented: $showingCamera) {
            ReceiptImagePicker(
                imageData: $imageData,
                sourceType: .camera,
                onDismiss: { showingCamera = false }
            )
        }
        .fullScreenCover(item: $presentedSheet) { sheet in
            switch sheet {
            case .photoLibrary:
                ReceiptImagePicker(
                    imageData: $imageData,
                    sourceType: .photoLibrary,
                    onDismiss: { presentedSheet = nil }
                )
            case .fullImage:
                FullImageView(imageData: imageData ?? Data())
            case .cropImage:
                ReceiptCropWrapper(
                    imageData: $imageData,
                    onDismiss: { presentedSheet = nil }
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
        Section("Receipt Image") {
            if let imgData = imageData {
                ReceiptImagePreview(
                    imageData: imgData,
                    onDelete: { imageData = nil },
                    onCrop: { presentedSheet = .cropImage },
                    onTap: { presentedSheet = .fullImage }
                )
            } else {
                imagePickerButtons
            }
        }
    }

    @ViewBuilder
    private var imagePickerButtons: some View {
        #if os(iOS)
        HStack {
            if ReceiptImagePicker.isCameraAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                Spacer()
            }

            Button {
                presentedSheet = .photoLibrary
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
    /// When saving with only an image (no manual entry), applies defaults:
    /// - Amount: 0.00
    /// - Category: .other (tax deductible)
    /// - Description: "Receipt image"
    /// - Assignment: Inferred from current date if within an assignment's date range
    private func saveReceipt() {
        // Apply defaults for image-only saves
        let finalDescription = receiptDescription.isEmpty ? "Receipt image" : receiptDescription
        let finalAssignmentId = selectedAssignmentId ?? findActiveAssignment(for: date)?.id

        let receipt = Receipt(
            amount: amount,
            category: category,
            date: date,
            receiptDescription: finalDescription,
            assignmentId: finalAssignmentId,
            imageData: imageData
        )

        modelContext.insert(receipt)
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    AddReceiptSheet(isPresented: .constant(true))
        .modelContainer(for: [Receipt.self, Assignment.self], inMemory: true)
}
