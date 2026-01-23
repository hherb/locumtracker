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
    @State private var showingCamera = false
    @State private var presentedSheet: SheetType?
    #if os(iOS)
    /// Holds the raw captured image before cropping
    @State private var imageToCrop: UIImage?
    #endif

    /// Sheet types (excluding camera which uses fullScreenCover)
    enum SheetType: Identifiable {
        case photoLibrary
        #if os(iOS)
        case cropImage
        #endif

        var id: Self { self }
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
            .fullScreenCover(isPresented: $showingCamera) {
                EditImagePicker(imageToCrop: $imageToCrop, isPresented: $showingCamera, sourceType: .camera)
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .photoLibrary:
                    EditPhotoLibraryPicker(imageToCrop: $imageToCrop, presentedSheet: $presentedSheet)
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

// MARK: - Edit Image Pickers

#if os(iOS)
/// Camera picker for EditReceiptSheet (used with fullScreenCover)
///
/// Passes captured image to crop view before final storage.
struct EditImagePicker: UIViewControllerRepresentable {
    @Binding var imageToCrop: UIImage?
    @Binding var isPresented: Bool
    let sourceType: UIImagePickerController.SourceType

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
        let parent: EditImagePicker

        init(parent: EditImagePicker) {
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

/// Photo library picker for EditReceiptSheet with item-based dismissal
///
/// Passes selected image to crop view before final storage.
struct EditPhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var imageToCrop: UIImage?
    @Binding var presentedSheet: EditReceiptSheet.SheetType?

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
        let parent: EditPhotoLibraryPicker

        init(parent: EditPhotoLibraryPicker) {
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
