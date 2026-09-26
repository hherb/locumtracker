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
import PDFKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Image from Data

public extension Image {
    /// Creates a SwiftUI image from encoded image data (JPEG, PNG, HEIC, ...)
    /// using the platform's native image type.
    /// - Parameter imageData: Encoded image bytes
    /// - Returns: The image, or nil if the data cannot be decoded
    init?(imageData: Data) {
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: imageData) else { return nil }
        self.init(uiImage: uiImage)
        #else
        guard let nsImage = NSImage(data: imageData) else { return nil }
        self.init(nsImage: nsImage)
        #endif
    }
}

// MARK: - PDF Document View

/// Displays a PDF document from raw data, scaled to fit, scrolling vertically.
/// Works on both iOS (UIKit) and macOS (AppKit).
public struct PDFDocumentView {
    let data: Data

    /// - Parameter data: Raw PDF bytes
    public init(data: Data) {
        self.data = data
    }

    private func makePDFView() -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }
}

#if canImport(UIKit)
extension PDFDocumentView: UIViewRepresentable {
    public func makeUIView(context: Context) -> PDFView { makePDFView() }
    public func updateUIView(_ uiView: PDFView, context: Context) {}
}
#else
extension PDFDocumentView: NSViewRepresentable {
    public func makeNSView(context: Context) -> PDFView { makePDFView() }
    public func updateNSView(_ nsView: PDFView, context: Context) {}
}
#endif
