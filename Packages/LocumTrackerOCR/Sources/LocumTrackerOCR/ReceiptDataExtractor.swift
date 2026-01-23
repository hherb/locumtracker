import Foundation

/// Processes OCR results to extract structured receipt data.
///
/// Uses regex patterns optimized for Australian receipts to extract:
/// - Merchant name
/// - Total amount
/// - GST amount
/// - Date
///
/// ## Usage
/// ```swift
/// let ocrResults = try await engine.recognizeText(in: image)
/// let receiptData = ReceiptDataExtractor.extract(from: ocrResults)
/// print("Total: $\(receiptData.totalAmount ?? 0)")
/// ```
public final class ReceiptDataExtractor: Sendable {

    // MARK: - Regex Patterns (Australian receipts)

    private static let totalPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:TOTAL|Total|AMOUNT DUE|Balance Due|TO PAY|AMOUNT)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:EFTPOS|CARD|VISA|MASTERCARD|PAID|DEBIT|CREDIT)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"\$\s*([\d,]+\.\d{2})\s*(?:TOTAL|AUD)?"#,
            #"(?:SALE TOTAL|SUB\s*TOTAL|SUBTOTAL)[:\s]*\$?\s*([\d,]+\.\d{2})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let gstPatterns: [NSRegularExpression] = {
        let patterns = [
            #"(?:GST|G\.S\.T\.|TAX)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:Includes GST of|GST Included|Inc GST)[:\s]*\$?\s*([\d,]+\.\d{2})"#,
            #"(?:TOTAL GST|GST TOTAL)[:\s]*\$?\s*([\d,]+\.\d{2})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private static let datePatterns: [NSRegularExpression] = {
        let patterns = [
            #"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})"#,
            #"(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{2,4})"#,
            #"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{1,2}),?\s+(\d{2,4})"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    // Common Australian merchants (uppercase for matching)
    private static let knownMerchants = [
        // Supermarkets
        "WOOLWORTHS", "COLES", "ALDI", "IGA", "COSTCO", "FOODLAND", "FOODWORKS",
        // Retail
        "BUNNINGS", "OFFICEWORKS", "JB HI-FI", "KMART", "TARGET", "BIG W", "MYER", "DAVID JONES",
        // Fuel
        "BP", "SHELL", "CALTEX", "7-ELEVEN", "AMPOL", "UNITED", "PUMA ENERGY", "LIBERTY",
        // Pharmacy
        "CHEMIST WAREHOUSE", "PRICELINE", "TERRY WHITE", "AMCAL", "BLOOMS",
        // Fast food
        "MCDONALD'S", "MCDONALDS", "SUBWAY", "KFC", "HUNGRY JACK'S", "HUNGRY JACKS",
        "DOMINO'S", "DOMINOS", "PIZZA HUT", "RED ROOSTER", "NANDO'S", "NANDOS",
        // Coffee
        "STARBUCKS", "GLORIA JEANS", "MUFFIN BREAK", "COFFEE CLUB",
        // Travel
        "QANTAS", "VIRGIN", "JETSTAR", "REX", "HERTZ", "AVIS", "BUDGET", "THRIFTY"
    ]

    // MARK: - Public API

    /// Extracts structured data from OCR results.
    ///
    /// - Parameter ocrResults: Array of OCR results from the engine.
    /// - Returns: Extracted receipt data with merchant, amounts, and date.
    public static func extract(from ocrResults: [OCRResult]) -> ReceiptData {
        let fullText = ocrResults.map { $0.text }.joined(separator: "\n")
        let avgConfidence = ocrResults.isEmpty
            ? 0
            : ocrResults.reduce(0) { $0 + $1.confidence } / Float(ocrResults.count)

        var receiptData = ReceiptData(rawText: fullText, confidence: avgConfidence)

        // Extract merchant (usually first few lines)
        receiptData.merchant = extractMerchant(from: ocrResults)

        // Extract amounts
        receiptData.totalAmount = extractTotal(from: fullText)
        receiptData.gstAmount = extractGST(from: fullText)

        // Calculate subtotal if we have total and GST
        if let total = receiptData.totalAmount, let gst = receiptData.gstAmount {
            receiptData.subtotal = total - gst
        }

        // Extract date
        receiptData.date = extractDate(from: fullText)

        return receiptData
    }

    /// Extracts structured data from raw text.
    ///
    /// Use this when you already have the OCR text and don't need
    /// individual bounding boxes.
    ///
    /// - Parameters:
    ///   - text: The raw OCR text.
    ///   - confidence: Optional confidence score (defaults to 1.0).
    /// - Returns: Extracted receipt data.
    public static func extract(from text: String, confidence: Float = 1.0) -> ReceiptData {
        let lines = text.components(separatedBy: .newlines)
        let mockResults = lines.map { line in
            OCRResult(text: line, boundingBox: .zero, confidence: confidence)
        }
        return extract(from: mockResults)
    }

    // MARK: - Extraction Methods

    private static func extractMerchant(from results: [OCRResult]) -> String? {
        // Take first 5 lines as candidates
        let topLines = results.prefix(5).map {
            $0.text.uppercased().trimmingCharacters(in: .whitespaces)
        }

        // Check for known merchants first
        for line in topLines {
            for merchant in knownMerchants {
                if line.contains(merchant) {
                    return formatMerchantName(merchant)
                }
            }
        }

        // Return first non-empty, non-numeric line that looks like a name
        for line in topLines {
            let cleaned = line.trimmingCharacters(in: .whitespaces)
            if isLikelyMerchantName(cleaned) {
                return formatMerchantName(cleaned)
            }
        }

        return nil
    }

    private static func isLikelyMerchantName(_ text: String) -> Bool {
        // Skip empty or very short strings
        guard text.count >= 3 else { return false }

        // Skip if mostly numbers
        let digits = text.filter { $0.isNumber }
        if Double(digits.count) / Double(text.count) > 0.5 {
            return false
        }

        // Skip common non-merchant patterns
        let skipPatterns = ["ABN", "TAX INVOICE", "RECEIPT", "DATE", "TIME", "TERMINAL"]
        for pattern in skipPatterns {
            if text.contains(pattern) {
                return false
            }
        }

        return true
    }

    private static func formatMerchantName(_ name: String) -> String {
        // Convert to title case
        name.lowercased().split(separator: " ").map { word in
            word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ")
    }

    private static func extractTotal(from text: String) -> Decimal? {
        var amounts: [(Decimal, Int)] = []

        for pattern in totalPatterns {
            let range = NSRange(text.startIndex..., in: text)
            pattern.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match = match,
                      let amountRange = Range(match.range(at: 1), in: text) else {
                    return
                }
                let amountString = String(text[amountRange]).replacingOccurrences(of: ",", with: "")
                if let amount = Decimal(string: amountString) {
                    amounts.append((amount, match.range.location))
                }
            }
        }

        // Return the largest amount (usually the total)
        // If amounts are similar, prefer the one appearing later (more likely to be final total)
        return amounts.max { a, b in
            if abs(NSDecimalNumber(decimal: a.0 - b.0).doubleValue) < 0.01 {
                return a.1 < b.1
            }
            return a.0 < b.0
        }?.0
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

                    // Try various Australian date formats
                    let formats = [
                        "dd/MM/yyyy",
                        "dd-MM-yyyy",
                        "dd.MM.yyyy",
                        "dd/MM/yy",
                        "dd-MM-yy",
                        "dd MMM yyyy",
                        "dd MMM yy",
                        "MMM dd, yyyy",
                        "MMM dd yyyy"
                    ]

                    for format in formats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: dateString) {
                            // Validate year is reasonable (not in the future, not too old)
                            let year = Calendar.current.component(.year, from: date)
                            let currentYear = Calendar.current.component(.year, from: Date())
                            if year >= currentYear - 5 && year <= currentYear + 1 {
                                return date
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
