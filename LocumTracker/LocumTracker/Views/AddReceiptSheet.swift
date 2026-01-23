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
    #if os(iOS)
    /// Holds the raw captured image before cropping
    @State private var imageToCrop: UIImage?
    #endif

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
            ImagePicker(imageToCrop: $imageToCrop, isPresented: $showingCamera, sourceType: .camera)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .photoLibrary:
                PhotoLibraryPicker(imageToCrop: $imageToCrop, presentedSheet: $presentedSheet)
            case .fullImage:
                if let imgData = imageData {
                    FullImageView(imageData: imgData)
                }
            case .cropImage:
                if let image = imageToCrop {
                    ImageCropView(
                        originalImage: image,
                        onCrop: { croppedImage in
                            let resizedImage = resizeImage(croppedImage, maxDimension: ImageConstants.maxStoredImageDimension)
                            imageData = resizedImage.jpegData(compressionQuality: ImageConstants.compressionQuality)
                            imageToCrop = nil
                            presentedSheet = nil
                        },
                        onCancel: {
                            imageToCrop = nil
                            presentedSheet = nil
                        }
                    )
                }
            }
        }
        .onChange(of: imageToCrop) { _, newImage in
            if newImage != nil {
                presentedSheet = .cropImage
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
                    presentedSheet = .fullImage
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
            if ImagePicker.isCameraAvailable {
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
/// UIKit camera picker wrapper for SwiftUI (used with fullScreenCover)
///
/// Wraps UIImagePickerController for camera access with boolean binding dismissal.
/// Passes captured image to crop view before final storage.
struct ImagePicker: UIViewControllerRepresentable {
    /// Binding to store the captured image for cropping
    @Binding var imageToCrop: UIImage?

    /// Binding to control presentation (for explicit dismissal)
    @Binding var isPresented: Bool

    /// The source type for the picker
    let sourceType: UIImagePickerController.SourceType

    /// Check if camera is available on this device
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageToCrop = image
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

/// Photo library picker for use with sheet(item:) presentation
///
/// Uses optional binding for dismissal to work with item-based sheet presentation.
/// Passes selected image to crop view before final storage.
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var imageToCrop: UIImage?
    @Binding var presentedSheet: AddReceiptSheet.SheetType?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker

        init(parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageToCrop = image
            }
            parent.presentedSheet = nil
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentedSheet = nil
        }
    }
}
#endif

// MARK: - Constants

private enum ImageConstants {
    static let maxPreviewHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 8
    static let compressionQuality: CGFloat = 0.7
    /// Maximum dimension (width or height) for stored images to prevent memory issues
    static let maxStoredImageDimension: CGFloat = 1920
}

#if os(iOS)
/// Resizes a UIImage to fit within the specified maximum dimension while preserving aspect ratio
/// - Parameters:
///   - image: The original image to resize
///   - maxDimension: The maximum width or height for the resized image
/// - Returns: The resized image, or the original if it's already within bounds
private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size

    // Check if resize is needed
    guard size.width > maxDimension || size.height > maxDimension else {
        return image
    }

    // Calculate new size maintaining aspect ratio
    let aspectRatio = size.width / size.height
    let newSize: CGSize
    if size.width > size.height {
        newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
    } else {
        newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
    }

    // Render resized image
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}
#endif

private enum DefaultReceiptValues {
    static let description = "Receipt image"
}

// MARK: - Preview

#Preview {
    AddReceiptSheet(isPresented: .constant(true))
        .modelContainer(for: [Receipt.self, Assignment.self], inMemory: true)
}
