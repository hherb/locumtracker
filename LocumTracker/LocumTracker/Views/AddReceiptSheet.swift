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
    @State private var activeSheet: ActiveSheet?

    /// Enum to track which sheet is active
    enum ActiveSheet: Identifiable {
        case camera
        case photoLibrary
        case fullImage

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
            #if os(iOS)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .camera:
                    ImagePicker(imageData: $imageData, sourceType: .camera)
                case .photoLibrary:
                    ImagePicker(imageData: $imageData, sourceType: .photoLibrary)
                case .fullImage:
                    if let imgData = imageData {
                        FullImageView(imageData: imgData)
                    }
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
                imagePreviewView(for: imgData)
            } else {
                imagePickerButtons
            }
        }
    }

    @ViewBuilder
    private func imagePreviewView(for data: Data) -> some View {
        VStack {
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                Button {
                    activeSheet = .fullImage
                } label: {
                    VStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: ImageConstants.maxPreviewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: ImageConstants.cornerRadius))

                        Text("Tap to view full size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            #else
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: ImageConstants.maxPreviewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: ImageConstants.cornerRadius))
            }
            #endif

            Button("Remove Image", role: .destructive) {
                imageData = nil
            }
            .font(.caption)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var imagePickerButtons: some View {
        #if os(iOS)
        HStack {
            Button {
                activeSheet = .camera
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            Spacer()

            Button {
                activeSheet = .photoLibrary
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
        let finalDescription = receiptDescription.isEmpty ? DefaultReceiptValues.description : receiptDescription
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

// MARK: - Image Picker

#if os(iOS)
/// UIKit image picker wrapper for SwiftUI
///
/// Wraps UIImagePickerController to provide camera and photo library access.
struct ImagePicker: UIViewControllerRepresentable {
    /// Binding to store the selected image data
    @Binding var imageData: Data?

    /// The source type for the picker (camera or photo library)
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator for handling image picker delegate callbacks
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: ImageConstants.compressionQuality)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

// MARK: - Constants

private enum ImageConstants {
    static let maxPreviewHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 8
    static let compressionQuality: CGFloat = 0.7
}

private enum DefaultReceiptValues {
    static let description = "Receipt image"
}

// MARK: - Preview

#Preview {
    AddReceiptSheet(isPresented: .constant(true))
        .modelContainer(for: [Receipt.self, Assignment.self], inMemory: true)
}
