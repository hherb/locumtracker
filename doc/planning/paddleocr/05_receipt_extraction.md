# Phase 5: Receipt Data Extraction

Processes OCR results to extract structured receipt data using regex patterns optimized for Australian receipts.

## ReceiptData Model

```swift
import Foundation

/// Extracted receipt data
public struct ReceiptData {
    public var merchant: String?
    public var totalAmount: Decimal?
    public var subtotal: Decimal?
    public var gstAmount: Decimal?
    public var date: Date?
    public var rawText: String
    public var confidence: Float

    public init(rawText: String, confidence: Float) {
        self.rawText = rawText
        self.confidence = confidence
    }
}
```

## ReceiptDataExtractor.swift

```swift
import Foundation

/// Processes OCR results to extract structured receipt data
public final class ReceiptDataExtractor {

    // MARK: - Regex Patterns (Australian receipts)

    private static let totalPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:TOTAL|Total|AMOUNT DUE|Balance Due|TO PAY)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:EFTPOS|CARD|VISA|MASTERCARD|PAID)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"\$\s*([\d,]+\.\d{2})\s*(?:TOTAL|AUD)?"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let gstPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:GST|G\.S\.T\.|TAX)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:Includes GST of|GST Included)[:\s]*\$?\s*([\d,]+\.\d{2})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let datePatterns: [NSRegularExpression] = {
        let patterns = [
            #"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})"#,  // DD/MM/YYYY or DD-MM-YY
            #"(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{2,4})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let abnPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"ABN[:\s]*(\d{2}\s*\d{3}\s*\d{3}\s*\d{3})"#, options: .caseInsensitive)
    }()

    // Common Australian merchants
    private static let knownMerchants = [
        "WOOLWORTHS", "COLES", "ALDI", "IGA", "COSTCO",
        "BUNNINGS", "OFFICEWORKS", "JB HI-FI", "KMART", "TARGET", "BIG W",
        "BP", "SHELL", "CALTEX", "7-ELEVEN", "AMPOL",
        "CHEMIST WAREHOUSE", "PRICELINE", "TERRY WHITE",
        "MCDONALD'S", "SUBWAY", "KFC", "HUNGRY JACK'S"
    ]

    // MARK: - Public API

    /// Extract structured data from OCR results
    public static func extract(from ocrResults: [OCRResult]) -> ReceiptData {
        let fullText = ocrResults.map { $0.text }.joined(separator: "\n")
        let avgConfidence = ocrResults.isEmpty ? 0 : ocrResults.reduce(0) { $0 + $1.confidence } / Float(ocrResults.count)

        var receiptData = ReceiptData(rawText: fullText, confidence: avgConfidence)

        // Extract merchant (usually first few lines)
        receiptData.merchant = extractMerchant(from: ocrResults)

        // Extract amounts
        receiptData.totalAmount = extractTotal(from: fullText)
        receiptData.gstAmount = extractGST(from: fullText)

        // Extract date
        receiptData.date = extractDate(from: fullText)

        return receiptData
    }

    // MARK: - Extraction Methods

    private static func extractMerchant(from results: [OCRResult]) -> String? {
        // Take first 5 lines as candidates
        let topLines = results.prefix(5).map { $0.text.uppercased().trimmingCharacters(in: .whitespaces) }

        // Check for known merchants
        for line in topLines {
            for merchant in knownMerchants {
                if line.contains(merchant) {
                    return merchant.capitalized
                }
            }
        }

        // Return first non-empty, non-numeric line
        for line in topLines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty && !cleaned.allSatisfy({ $0.isNumber || $0 == " " }) {
                return cleaned.capitalized
            }
        }

        return nil
    }

    private static func extractTotal(from text: String) -> Decimal? {
        for pattern in totalPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
                    return Decimal(string: amountString)
                }
            }
        }
        return nil
    }

    private static func extractGST(from text: String) -> Decimal? {
        for pattern in gstPatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let amountRange = Range(match.range(at: 1), in: text) {
                    let amountString = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
                    return Decimal(string: amountString)
                }
            }
        }
        return nil
    }

    private static func extractDate(from text: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_AU")

        for pattern in datePatterns {
            let range = NSRange(text.startIndex..., in: text)
            if let match = pattern.firstMatch(in: text, options: [], range: range) {
                if let fullRange = Range(match.range, in: text) {
                    let dateString = String(text[fullRange])

                    // Try various formats
                    for format in ["dd/MM/yyyy", "dd-MM-yyyy", "dd.MM.yyyy", "dd/MM/yy", "dd MMM yyyy"] {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                }
            }
        }
        return nil
    }
}
```

---

**Previous:** [04_camera_integration.md](04_camera_integration.md)
**Next:** [06_optimization_testing.md](06_optimization_testing.md) - Performance optimization, testing, and fallback strategy
