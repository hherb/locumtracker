# Flexible Invoice Template Systems for Swift Apps

## Overview

This document provides a comprehensive guide to implementing flexible invoice template systems in Swift applications, with a focus on multi-country tax compliance, PDF generation, and accounting software integration.

## Table of Contents

1. [Invoice Template Architecture](#invoice-template-architecture)
2. [Data Models](#data-models)
3. [PDF Generation Libraries](#pdf-generation-libraries)
4. [Tax Calculation Engines](#tax-calculation-engines)
5. [JSON Export Schemas](#json-export-schemas)
6. [Template Customization](#template-customization)
7. [Australian Business Requirements](#australian-business-requirements)
8. [International Tax Support](#international-tax-support)
9. [Implementation Examples](#implementation-examples)

---

## Invoice Template Architecture

### Core Components

```swift
// MARK: - Invoice Template System Architecture

protocol InvoiceTemplate {
    var id: UUID { get }
    var name: String { get }
    var country: CountryCode { get }
    var taxSystem: TaxSystem { get }
    var layout: TemplateLayout { get }
    var fields: [TemplateField] { get }
}

protocol TemplateField {
    var id: String { get }
    var type: FieldType { get }
    var position: CGRect { get }
    var styling: FieldStyling { get }
    var validation: FieldValidation? { get }
    var isRequired: Bool { get }
}

enum FieldType {
    case text
    case number
    case currency
    case date
    case image
    case table
    case barcode
    case signature
}

enum TaxSystem {
    case gst(AustraliaGSTConfig)
    case vat(EUVATConfig)
    case salesTax(USStateTaxConfig)
    case none
}
```

### Template Manager

```swift
class InvoiceTemplateManager {
    private var templates: [InvoiceTemplate] = []
    private let taxEngine: TaxCalculationEngine
    private let pdfGenerator: PDFGenerator
    
    init(taxEngine: TaxCalculationEngine, pdfGenerator: PDFGenerator) {
        self.taxEngine = taxEngine
        self.pdfGenerator = pdfGenerator
        loadDefaultTemplates()
    }
    
    func createTemplate(from config: TemplateConfiguration) -> InvoiceTemplate {
        return FlexibleInvoiceTemplate(
            id: UUID(),
            name: config.name,
            country: config.country,
            taxSystem: config.taxSystem,
            layout: config.layout,
            fields: config.fields
        )
    }
    
    func generateInvoice(
        using template: InvoiceTemplate,
        data: InvoiceData
    ) async throws -> InvoiceDocument {
        let calculatedData = try await taxEngine.calculate(
            for: data,
            taxSystem: template.taxSystem
        )
        
        return try await pdfGenerator.generate(
            template: template,
            data: calculatedData
        )
    }
}
```

---

## Data Models

### Core Invoice Data Structure

```swift
// MARK: - Core Invoice Data Models

struct InvoiceData: Codable {
    let id: UUID
    let number: String
    let date: Date
    let dueDate: Date
    let status: InvoiceStatus
    let currency: Currency
    let customer: Customer
    let supplier: Supplier
    let lineItems: [LineItem]
    let totals: InvoiceTotals
    let tax: TaxInformation
    let payment: PaymentInformation?
    let metadata: [String: Any]
}

struct Customer: Codable {
    let id: UUID
    let name: String
    let taxNumber: String? // ABN, VAT, etc.
    let address: Address
    let contact: ContactInfo
    let billingAddress: Address?
    let shippingAddress: Address?
}

struct Supplier: Codable {
    let id: UUID
    let name: String
    let taxNumber: String
    let address: Address
    let contact: ContactInfo
    let logo: Data?
    let businessNumber: String? // ABN for Australia
}

struct LineItem: Codable {
    let id: UUID
    let description: String
    let quantity: Decimal
    let unitPrice: Decimal
    let discount: Decimal?
    let taxCode: String
    let total: Decimal
    let metadata: [String: Any]
}

struct InvoiceTotals: Codable {
    let subtotal: Decimal
    let discountTotal: Decimal
    let taxTotal: Decimal
    let total: Decimal
    let paid: Decimal
    let balance: Decimal
}

struct TaxInformation: Codable {
    let system: TaxSystem
    let rate: Decimal
    let amount: Decimal
    let breakdown: [TaxBreakdown]
    let compliance: TaxCompliance
}

struct TaxBreakdown: Codable {
    let type: String
    let rate: Decimal
    let amount: Decimal
    let description: String
}
```

### Australian-Specific Models

```swift
// MARK: - Australian Business Models

struct AustraliaGSTConfig: Codable {
    let rate: Decimal = 0.10
    let abn: String
    let isGSTRegistered: Bool
    let gstMethod: GSTMethod
    let basFrequency: BASFrequency
    
    enum GSTMethod {
        case accrual
        case cash
        case hybrid
    }
    
    enum BASFrequency {
        case monthly
        case quarterly
        case annually
    }
}

struct BASInformation: Codable {
    let period: BASPeriod
    let totalSales: Decimal
    let gstCollected: Decimal
    let gstPaid: Decimal
    let netGST: Decimal
    let otherTaxes: [OtherTax]
    
    struct BASPeriod {
        let startDate: Date
        let endDate: Date
        let frequency: AustraliaGSTConfig.BASFrequency
    }
}

struct OtherTax: Codable {
    let type: String
    let amount: Decimal
    let description: String
}
```

---

## PDF Generation Libraries

### 1. PDFKit (Native iOS)

```swift
// MARK: - PDFKit Implementation

import PDFKit

class PDFKitGenerator: PDFGenerator {
    func generate(
        template: InvoiceTemplate,
        data: InvoiceData
    ) async throws -> InvoiceDocument {
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let pdfData = NSMutableData()
        
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        UIGraphicsBeginPDFPage()
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Draw template elements
        try await drawTemplate(template: template, data: data, in: context)
        
        UIGraphicsEndPDFContext()
        
        return InvoiceDocument(
            data: pdfData as Data,
            format: .pdf,
            template: template
        )
    }
    
    private func drawTemplate(
        template: InvoiceTemplate,
        data: InvoiceData,
        in context: CGContext
    ) async throws {
        
        // Draw header
        try await drawHeader(template: template, data: data, in: context)
        
        // Draw customer/supplier info
        try await drawParties(template: template, data: data, in: context)
        
        // Draw line items table
        try await drawLineItems(template: template, data: data, in: context)
        
        // Draw totals
        try await drawTotals(template: template, data: data, in: context)
        
        // Draw footer
        try await drawFooter(template: template, data: data, in: context)
    }
}
```

### 2. TPPDF (Third-party Library)

```swift
// MARK: - TPPDF Implementation

import TPPDF

class TPPDFGenerator: PDFGenerator {
    func generate(
        template: InvoiceTemplate,
        data: InvoiceData
    ) async throws -> InvoiceDocument {
        
        let document = PDFDocument(format: .a4)
        document.add(.header, text: "Tax Invoice")
        
        // Add supplier information
        try await addSupplierInfo(to: document, data: data)
        
        // Add customer information
        try await addCustomerInfo(to: document, data: data)
        
        // Add line items table
        try await addLineItemsTable(to: document, data: data)
        
        // Add totals section
        try await addTotalsSection(to: document, data: data)
        
        // Add footer
        try await addFooter(to: document, template: template, data: data)
        
        let pdfData = try document.generatePDFData()
        
        return InvoiceDocument(
            data: pdfData,
            format: .pdf,
            template: template
        )
    }
    
    private func addLineItemsTable(to document: PDFDocument, data: InvoiceData) async throws {
        let tableData = data.lineItems.map { item in
            return [
                item.description,
                "\(item.quantity)",
                formatCurrency(item.unitPrice, currency: data.currency),
                formatCurrency(item.total, currency: data.currency)
            ]
        }
        
        let table = PDFTable(
            data: tableData,
            headers: ["Description", "Qty", "Unit Price", "Total"],
            alignments: [.left, .center, .right, .right],
            widths: [0.5, 0.1, 0.2, 0.2]
        )
        
        document.add(table)
    }
}
```

### 3. PDFBlocks (SwiftUI-like Syntax)

```swift
// MARK: - PDFBlocks Implementation

import PDFBlocks

class PDFBlocksGenerator: PDFGenerator {
    func generate(
        template: InvoiceTemplate,
        data: InvoiceData
    ) async throws -> InvoiceDocument {
        
        let document = PDFDocument {
            VStack(spacing: 20) {
                // Header
                HeaderView(data: data, template: template)
                
                // Parties
                HStack {
                    SupplierView(data: data.supplier)
                    Spacer()
                    CustomerView(data: data.customer)
                }
                
                // Line Items
                LineItemsTableView(items: data.lineItems, currency: data.currency)
                
                // Totals
                TotalsView(totals: data.totals, tax: data.tax)
                
                // Footer
                FooterView(template: template, data: data)
            }
            .padding(20)
        }
        
        let pdfData = try document.render()
        
        return InvoiceDocument(
            data: pdfData,
            format: .pdf,
            template: template
        )
    }
}
```

---

## Tax Calculation Engines

### Core Tax Engine Protocol

```swift
// MARK: - Tax Calculation Engine

protocol TaxCalculationEngine {
    func calculate(
        for invoice: InvoiceData,
        taxSystem: TaxSystem
    ) async throws -> InvoiceData
    
    func validate(
        invoice: InvoiceData,
        taxSystem: TaxSystem
    ) async throws -> ValidationResult
}

class FlexibleTaxEngine: TaxCalculationEngine {
    private let calculators: [TaxSystem: TaxCalculator]
    
    init() {
        self.calculators = [
            .gst(AustraliaGSTConfig(rate: 0.10, abn: "", isGSTRegistered: true, gstMethod: .accrual, basFrequency: .quarterly)): AustraliaGSTCalculator(),
            .vat(EUVATConfig(country: .germany, rate: 0.19, isVATRegistered: true)): EUVATCalculator(),
            .salesTax(USStateTaxConfig(state: .california, rate: 0.0875)): USSalesTaxCalculator()
        ]
    }
    
    func calculate(
        for invoice: InvoiceData,
        taxSystem: TaxSystem
    ) async throws -> InvoiceData {
        
        guard let calculator = calculators[taxSystem] else {
            throw TaxError.unsupportedTaxSystem
        }
        
        return try await calculator.calculate(invoice: invoice)
    }
    
    func validate(
        invoice: InvoiceData,
        taxSystem: TaxSystem
    ) async throws -> ValidationResult {
        
        guard let calculator = calculators[taxSystem] else {
            throw TaxError.unsupportedTaxSystem
        }
        
        return try await calculator.validate(invoice: invoice)
    }
}
```

### Australian GST Calculator

```swift
// MARK: - Australian GST Calculator

class AustraliaGSTCalculator: TaxCalculator {
    func calculate(invoice: InvoiceData) async throws -> InvoiceData {
        guard case .gst(let config) = invoice.tax.system else {
            throw TaxError.invalidTaxSystem
        }
        
        var updatedLineItems = [LineItem]()
        var totalGST = Decimal.zero
        
        for item in invoice.lineItems {
            let itemGST = try calculateGST(for: item, config: config)
            let updatedItem = LineItem(
                id: item.id,
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: item.discount,
                taxCode: item.taxCode,
                total: item.total + itemGST,
                metadata: item.metadata
            )
            updatedLineItems.append(updatedItem)
            totalGST += itemGST
        }
        
        let updatedTotals = InvoiceTotals(
            subtotal: invoice.totals.subtotal,
            discountTotal: invoice.totals.discountTotal,
            taxTotal: totalGST,
            total: invoice.totals.subtotal + totalGST,
            paid: invoice.totals.paid,
            balance: invoice.totals.subtotal + totalGST - invoice.totals.paid
        )
        
        let taxInfo = TaxInformation(
            system: invoice.tax.system,
            rate: config.rate,
            amount: totalGST,
            breakdown: [
                TaxBreakdown(
                    type: "GST",
                    rate: config.rate,
                    amount: totalGST,
                    description: "Goods and Services Tax"
                )
            ],
            compliance: TaxCompliance(
                taxNumber: config.abn,
                registrationNumber: config.abn,
                isRegistered: config.isGSTRegistered,
                country: "AU"
            )
        )
        
        return InvoiceData(
            id: invoice.id,
            number: invoice.number,
            date: invoice.date,
            dueDate: invoice.dueDate,
            status: invoice.status,
            currency: invoice.currency,
            customer: invoice.customer,
            supplier: invoice.supplier,
            lineItems: updatedLineItems,
            totals: updatedTotals,
            tax: taxInfo,
            payment: invoice.payment,
            metadata: invoice.metadata
        )
    }
    
    private func calculateGST(for item: LineItem, config: AustraliaGSTConfig) throws -> Decimal {
        // Check if item is GST-free or input taxed
        if item.taxCode == "GST_FREE" || item.taxCode == "INPUT_TAXED" {
            return Decimal.zero
        }
        
        // Calculate GST on item total
        return item.total * config.rate
    }
    
    func validate(invoice: InvoiceData) async throws -> ValidationResult {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        
        // Validate ABN format
        if let abn = invoice.supplier.businessNumber, !isValidABN(abn) {
            errors.append(ValidationError(
                field: "supplier.abn",
                message: "Invalid ABN format"
            ))
        }
        
        // Validate GST registration
        guard case .gst(let config) = invoice.tax.system else {
            errors.append(ValidationError(
                field: "tax.system",
                message: "GST configuration required for Australian invoices"
            ))
            return ValidationResult(errors: errors, warnings: warnings)
        }
        
        if !config.isGSTRegistered && invoice.totals.total > 82.50 {
            warnings.append(ValidationWarning(
                field: "tax.registration",
                message: "GST registration recommended for invoices over $82.50"
            ))
        }
        
        // Validate tax codes
        for item in invoice.lineItems {
            if !isValidAustralianTaxCode(item.taxCode) {
                errors.append(ValidationError(
                    field: "lineItem.\(item.id).taxCode",
                    message: "Invalid Australian tax code: \(item.taxCode)"
                ))
            }
        }
        
        return ValidationResult(errors: errors, warnings: warnings)
    }
    
    private func isValidABN(_ abn: String) -> Bool {
        // ABN validation algorithm
        let cleanABN = abn.replacingOccurrences(of: " ", with: "")
        guard cleanABN.count == 11, cleanABN.allSatisfy(\.isNumber) else { return false }
        
        let digits = cleanABN.compactMap { $0.wholeNumberValue }
        var weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
        
        // Apply ABN algorithm
        var sum = 0
        for (index, digit) in digits.enumerated() {
            if index == 0 {
                sum += (digit - 1) * weights[index]
            } else {
                sum += digit * weights[index]
            }
        }
        
        return sum % 89 == 0
    }
    
    private func isValidAustralianTaxCode(_ code: String) -> Bool {
        let validCodes = ["GST", "GST_FREE", "INPUT_TAXED", "EXEMPT"]
        return validCodes.contains(code)
    }
}
```

---

## JSON Export Schemas

### Standard Invoice JSON Schema

```swift
// MARK: - JSON Export Schemas

struct InvoiceExportSchema: Codable {
    let version: String
    let format: String
    let invoice: InvoiceData
    let template: TemplateInfo
    let export: ExportMetadata
}

struct TemplateInfo: Codable {
    let id: UUID
    let name: String
    let version: String
    let country: String
    let taxSystem: String
}

struct ExportMetadata: Codable {
    let exportedAt: Date
    let exportedBy: String
    let format: String
    let purpose: ExportPurpose
    let target: ExportTarget
    
    enum ExportPurpose {
        case accounting
        case reporting
        case archival
        case compliance
    }
    
    enum ExportTarget {
        case xero
        case quickBooks
        case myob
        case sage
        case custom(String)
    }
}
```

### Xero Integration Schema

```swift
// MARK: - Xero Export Schema

struct XeroInvoiceExport: Codable {
    let Type: String = "ACCREC"
    let Contact: XeroContact
    let Date: String // YYYY-MM-DD
    let DueDate: String
    let LineItems: [XeroLineItem]
    let Status: String
    let CurrencyCode: String
    let InvoiceNumber: String
    let Reference: String?
    let Terms: Int?
    let TotalTax: String
    let Total: String
    let SubTotal: String
}

struct XeroContact: Codable {
    let Name: String
    let ContactNumber: String?
    let TaxNumber: String? // ABN
    let Addresses: [XeroAddress]
    let Phones: [XeroPhone]
}

struct XeroLineItem: Codable {
    let Description: String
    let Quantity: String
    let UnitAmount: String
    let TaxType: String
    let AccountCode: String?
    let DiscountRate: String?
}

struct XeroAddress: Codable {
    let AddressType: String // POBOX, STREET
    let AddressLine1: String
    let AddressLine2: String?
    let City: String
    let Region: String?
    let PostalCode: String
    let Country: String
}

extension InvoiceData {
    func toXeroExport() -> XeroInvoiceExport {
        return XeroInvoiceExport(
            Contact: XeroContact(
                Name: customer.name,
                ContactNumber: customer.contact.phone,
                TaxNumber: customer.taxNumber,
                Addresses: [
                    XeroAddress(
                        AddressType: "STREET",
                        AddressLine1: customer.address.line1,
                        AddressLine2: customer.address.line2,
                        City: customer.address.city,
                        Region: customer.address.state,
                        PostalCode: customer.address.postalCode,
                        Country: customer.address.country
                    )
                ],
                Phones: [
                    XeroPhone(
                        PhoneType: "MOBILE",
                        PhoneNumber: customer.contact.phone,
                        AreaCode: nil
                    )
                ]
            ),
            Date: formatDate(date),
            DueDate: formatDate(dueDate),
            LineItems: lineItems.map { $0.toXeroLineItem() },
            Status: status.xeroStatus,
            CurrencyCode: currency.code,
            InvoiceNumber: number,
            Reference: metadata["reference"] as? String,
            Terms: nil,
            TotalTax: formatCurrency(tax.amount),
            Total: formatCurrency(totals.total),
            SubTotal: formatCurrency(totals.subtotal)
        )
    }
}
```

### QuickBooks Integration Schema

```swift
// MARK: - QuickBooks Export Schema

struct QuickBooksInvoiceExport: Codable {
    let DocNumber: String
    let TxnDate: String
    let DueDate: String
    let CustomerRef: QuickBooksRef
    let Line: [QuickBooksLineItem]
    let TotalAmt: String
    let ApplyTaxAfterDiscount: Bool
    let PrintStatus: String
    let EmailStatus: String
    let Balance: String
    let CurrencyRef: QuickBooksRef
}

struct QuickBooksRef: Codable {
    let value: String
    let name: String?
}

struct QuickBooksLineItem: Codable {
    let Id: String?
    let LineNum: Int?
    let Description: String
    let Amount: String
    let DetailType: String
    let SalesItemLineDetail: QuickBooksSalesItemDetail
}

struct QuickBooksSalesItemDetail: Codable {
    let ItemRef: QuickBooksRef
    let UnitPrice: String
    let Qty: String
    let TaxCodeRef: QuickBooksRef?
}

extension InvoiceData {
    func toQuickBooksExport() -> QuickBooksInvoiceExport {
        return QuickBooksInvoiceExport(
            DocNumber: number,
            TxnDate: formatDate(date),
            DueDate: formatDate(dueDate),
            CustomerRef: QuickBooksRef(
                value: customer.id.uuidString,
                name: customer.name
            ),
            Line: lineItems.enumerated().map { index, item in
                item.toQuickBooksLineItem(lineNumber: index + 1)
            },
            TotalAmt: formatCurrency(totals.total),
            ApplyTaxAfterDiscount: true,
            PrintStatus: "NeedToPrint",
            EmailStatus: "NotSet",
            Balance: formatCurrency(totals.balance),
            CurrencyRef: QuickBooksRef(
                value: currency.code,
                name: currency.name
            )
        )
    }
}
```

---

## Template Customization

### Template Builder

```swift
// MARK: - Template Builder

class InvoiceTemplateBuilder {
    private var template: FlexibleInvoiceTemplate
    
    init(name: String, country: CountryCode) {
        self.template = FlexibleInvoiceTemplate(
            id: UUID(),
            name: name,
            country: country,
            taxSystem: .none,
            layout: DefaultTemplateLayout(),
            fields: []
        )
    }
    
    func withTaxSystem(_ system: TaxSystem) -> InvoiceTemplateBuilder {
        template.taxSystem = system
        return self
    }
    
    func withLayout(_ layout: TemplateLayout) -> InvoiceTemplateBuilder {
        template.layout = layout
        return self
    }
    
    func addField(_ field: TemplateField) -> InvoiceTemplateBuilder {
        template.fields.append(field)
        return self
    }
    
    func withLogo(position: CGRect) -> InvoiceTemplateBuilder {
        let logoField = ImageField(
            id: "logo",
            position: position,
            styling: ImageStyling(
                aspectRatio: .fit,
                alignment: .topLeft
            ),
            isRequired: false
        )
        template.fields.append(logoField)
        return self
    }
    
    func withHeader(position: CGRect) -> InvoiceTemplateBuilder {
        let headerField = TextField(
            id: "header",
            position: position,
            styling: TextStyling(
                font: .boldSystemFont(ofSize: 24),
                color: .black,
                alignment: .center
            ),
            validation: nil,
            isRequired: true
        )
        template.fields.append(headerField)
        return self
    }
    
    func withTable(position: CGRect, columns: [TableColumn]) -> InvoiceTemplateBuilder {
        let tableField = TableField(
            id: "lineItems",
            position: position,
            columns: columns,
            styling: TableStyling(
                headerFont: .boldSystemFont(ofSize: 12),
                rowFont: .systemFont(ofSize: 11),
                borderColor: .gray,
                borderWidth: 1.0
            ),
            isRequired: true
        )
        template.fields.append(tableField)
        return self
    }
    
    func build() -> InvoiceTemplate {
        return template
    }
}

// Usage Example:
let australianTemplate = InvoiceTemplateBuilder(name: "Australian GST Invoice", country: .AU)
    .withTaxSystem(.gst(AustraliaGSTConfig(
        rate: 0.10,
        abn: "12345678901",
        isGSTRegistered: true,
        gstMethod: .accrual,
        basFrequency: .quarterly
    )))
    .withLogo(position: CGRect(x: 20, y: 20, width: 100, height: 50))
    .withHeader(position: CGRect(x: 0, y: 80, width: 595, height: 40))
    .withTable(position: CGRect(x: 20, y: 200, width: 555, height: 300), columns: [
        TableColumn(id: "description", title: "Description", width: 0.4),
        TableColumn(id: "quantity", title: "Qty", width: 0.1),
        TableColumn(id: "unitPrice", title: "Unit Price", width: 0.2),
        TableColumn(id: "total", title: "Total", width: 0.2),
        TableColumn(id: "tax", title: "GST", width: 0.1)
    ])
    .build()
```

### Localization Support

```swift
// MARK: - Template Localization

class TemplateLocalization {
    private let locale: Locale
    private let translations: [String: String]
    
    init(locale: Locale) {
        self.locale = locale
        self.translations = loadTranslations(for: locale)
    }
    
    func translate(_ key: String) -> String {
        return translations[key] ?? key
    }
    
    func formatCurrency(_ amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency.code
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func loadTranslations(for locale: Locale) -> [String: String] {
        // Load translations from bundle or database
        switch locale.identifier {
        case "en_AU":
            return [
                "tax_invoice": "Tax Invoice",
                "abn": "ABN",
                "gst": "GST",
                "subtotal": "Subtotal",
                "total": "Total",
                "due_date": "Due Date"
            ]
        case "en_US":
            return [
                "tax_invoice": "Invoice",
                "abn": "Tax ID",
                "gst": "Sales Tax",
                "subtotal": "Subtotal",
                "total": "Total",
                "due_date": "Due Date"
            ]
        default:
            return [:]
        }
    }
}
```

---

## Australian Business Requirements

### ATO Compliance

```swift
// MARK: - Australian Tax Office Compliance

struct ATOComplianceValidator {
    func validateTaxInvoice(_ invoice: InvoiceData) -> ValidationResult {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        
        // Check if "Tax Invoice" is prominently displayed
        if !invoice.metadata.keys.contains("taxInvoiceHeader") {
            errors.append(ValidationError(
                field: "header",
                message: "Must include 'Tax Invoice' prominently displayed"
            ))
        }
        
        // Validate ABN format and presence
        guard let abn = invoice.supplier.businessNumber else {
            errors.append(ValidationError(
                field: "supplier.abn",
                message: "ABN is required for tax invoices"
            ))
            return ValidationResult(errors: errors, warnings: warnings)
        }
        
        if !isValidABN(abn) {
            errors.append(ValidationError(
                field: "supplier.abn",
                message: "Invalid ABN format"
            ))
        }
        
        // Check invoice date
        let today = Date()
        if invoice.date > today {
            warnings.append(ValidationWarning(
                field: "date",
                message: "Invoice date is in the future"
            ))
        }
        
        // Validate GST for invoices over $82.50
        if invoice.totals.total > 82.50 {
            guard case .gst(let config) = invoice.tax.system else {
                errors.append(ValidationError(
                    field: "tax",
                    message: "GST information required for invoices over $82.50"
                ))
                return ValidationResult(errors: errors, warnings: warnings)
            }
            
            if !config.isGSTRegistered {
                errors.append(ValidationError(
                    field: "tax.registration",
                    message: "Supplier must be GST registered for invoices over $82.50"
                ))
            }
        }
        
        // Validate customer ABN for B2B invoices over $1,000
        if invoice.totals.total >= 1000 && invoice.customer.taxNumber == nil {
            warnings.append(ValidationWarning(
                field: "customer.abn",
                message: "Customer ABN recommended for B2B invoices over $1,000"
            ))
        }
        
        // Validate line items
        for item in invoice.lineItems {
            if item.description.isEmpty {
                errors.append(ValidationError(
                    field: "lineItem.\(item.id).description",
                    message: "Line item description is required"
                ))
            }
            
            if item.quantity <= 0 {
                errors.append(ValidationError(
                    field: "lineItem.\(item.id).quantity",
                    message: "Line item quantity must be greater than 0"
                ))
            }
        }
        
        return ValidationResult(errors: errors, warnings: warnings)
    }
    
    private func isValidABN(_ abn: String) -> Bool {
        // Implementation from earlier
        let cleanABN = abn.replacingOccurrences(of: " ", with: "")
        guard cleanABN.count == 11, cleanABN.allSatisfy(\.isNumber) else { return false }
        
        let digits = cleanABN.compactMap { $0.wholeNumberValue }
        var weights = [10, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19]
        
        var sum = 0
        for (index, digit) in digits.enumerated() {
            if index == 0 {
                sum += (digit - 1) * weights[index]
            } else {
                sum += digit * weights[index]
            }
        }
        
        return sum % 89 == 0
    }
}
```

### BAS Reporting

```swift
// MARK: - Business Activity Statement Reporting

class BASReportGenerator {
    func generateBASReport(
        from invoices: [InvoiceData],
        period: BASInformation.BASPeriod
    ) -> BASReport {
        
        let filteredInvoices = filterInvoicesForPeriod(
            invoices: invoices,
            period: period
        )
        
        let totalSales = calculateTotalSales(invoices: filteredInvoices)
        let gstCollected = calculateGSTCollected(invoices: filteredInvoices)
        let gstPaid = calculateGSTPaid(invoices: filteredInvoices)
        
        return BASReport(
            period: period,
            totalSales: totalSales,
            gstCollected: gstCollected,
            gstPaid: gstPaid,
            netGST: gstCollected - gstPaid,
            otherTaxes: calculateOtherTaxes(invoices: filteredInvoices),
            invoices: filteredInvoices
        )
    }
    
    private func filterInvoicesForPeriod(
        invoices: [InvoiceData],
        period: BASInformation.BASPeriod
    ) -> [InvoiceData] {
        return invoices.filter { invoice in
            invoice.date >= period.startDate && invoice.date <= period.endDate
        }
    }
    
    private func calculateTotalSales(invoices: [InvoiceData]) -> Decimal {
        return invoices.reduce(Decimal.zero) { total, invoice in
            total + invoice.totals.subtotal
        }
    }
    
    private func calculateGSTCollected(invoices: [InvoiceData]) -> Decimal {
        return invoices.reduce(Decimal.zero) { total, invoice in
            total + invoice.tax.amount
        }
    }
    
    private func calculateGSTPaid(invoices: [InvoiceData]) -> Decimal {
        // This would typically come from expense data
        // For now, return a placeholder
        return Decimal.zero
    }
    
    private func calculateOtherTaxes(invoices: [InvoiceData]) -> [OtherTax] {
        // Calculate other taxes like PAYG withholding, FBT, etc.
        return []
    }
}

struct BASReport {
    let period: BASInformation.BASPeriod
    let totalSales: Decimal
    let gstCollected: Decimal
    let gstPaid: Decimal
    let netGST: Decimal
    let otherTaxes: [OtherTax]
    let invoices: [InvoiceData]
    
    func exportToJSON() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try! encoder.encode(self)
    }
    
    func exportToCSV() -> String {
        var csv = "BAS Report - \(period.startDate) to \(period.endDate)\n\n"
        csv += "Total Sales,GST Collected,GST Paid,Net GST\n"
        csv += "\(totalSales),\(gstCollected),\(gstPaid),\(netGST)\n\n"
        csv += "Invoice Details:\n"
        csv += "Invoice Number,Date,Total,GST\n"
        
        for invoice in invoices {
            csv += "\(invoice.number),\(invoice.date),\(invoice.totals.total),\(invoice.tax.amount)\n"
        }
        
        return csv
    }
}
```

---

## International Tax Support

### Multi-Country Tax Engine

```swift
// MARK: - International Tax Support

class InternationalTaxEngine: TaxCalculationEngine {
    private let countryCalculators: [CountryCode: TaxCalculator]
    
    init() {
        self.countryCalculators = [
            .AU: AustraliaGSTCalculator(),
            .US: USSalesTaxCalculator(),
            .GB: UKVATCalculator(),
            .DE: GermanyVATCalculator(),
            .FR: FranceVATCalculator(),
            .CA: CanadaGSTCalculator(),
            .NZ: NewZealandGSTCalculator()
        ]
    }
    
    func calculate(
        for invoice: InvoiceData,
        taxSystem: TaxSystem
    ) async throws -> InvoiceData {
        
        let countryCode = invoice.supplier.address.countryCode
        
        guard let calculator = countryCalculators[countryCode] else {
            throw TaxError.unsupportedCountry(countryCode)
        }
        
        return try await calculator.calculate(invoice: invoice)
    }
    
    func validate(
        invoice: InvoiceData,
        taxSystem: TaxSystem
    ) async throws -> ValidationResult {
        
        let countryCode = invoice.supplier.address.countryCode
        
        guard let calculator = countryCalculators[countryCode] else {
            throw TaxError.unsupportedCountry(countryCode)
        }
        
        return try await calculator.validate(invoice: invoice)
    }
}

// EU VAT Calculator
class EUVATCalculator: TaxCalculator {
    func calculate(invoice: InvoiceData) async throws -> InvoiceData {
        guard case .vat(let config) = invoice.tax.system else {
            throw TaxError.invalidTaxSystem
        }
        
        // Check if intra-EU supply (VAT reverse charge applies)
        let isReverseCharge = shouldApplyReverseCharge(
            supplier: invoice.supplier,
            customer: invoice.customer,
            config: config
        )
        
        var updatedLineItems = [LineItem]()
        var totalVAT = Decimal.zero
        
        for item in invoice.lineItems {
            let itemVAT: Decimal
            if isReverseCharge {
                itemVAT = Decimal.zero // Reverse charge
            } else {
                itemVAT = try calculateVAT(for: item, config: config)
            }
            
            let updatedItem = LineItem(
                id: item.id,
                description: item.description,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: item.discount,
                taxCode: item.taxCode,
                total: item.total + itemVAT,
                metadata: item.metadata
            )
            updatedLineItems.append(updatedItem)
            totalVAT += itemVAT
        }
        
        let updatedTotals = InvoiceTotals(
            subtotal: invoice.totals.subtotal,
            discountTotal: invoice.totals.discountTotal,
            taxTotal: totalVAT,
            total: invoice.totals.subtotal + totalVAT,
            paid: invoice.totals.paid,
            balance: invoice.totals.subtotal + totalVAT - invoice.totals.paid
        )
        
        let taxInfo = TaxInformation(
            system: invoice.tax.system,
            rate: config.rate,
            amount: totalVAT,
            breakdown: [
                TaxBreakdown(
                    type: "VAT",
                    rate: config.rate,
                    amount: totalVAT,
                    description: isReverseCharge ? "VAT Reverse Charge" : "Value Added Tax"
                )
            ],
            compliance: TaxCompliance(
                taxNumber: invoice.supplier.taxNumber ?? "",
                registrationNumber: invoice.supplier.taxNumber ?? "",
                isRegistered: true,
                country: config.country.rawValue
            )
        )
        
        return InvoiceData(
            id: invoice.id,
            number: invoice.number,
            date: invoice.date,
            dueDate: invoice.dueDate,
            status: invoice.status,
            currency: invoice.currency,
            customer: invoice.customer,
            supplier: invoice.supplier,
            lineItems: updatedLineItems,
            totals: updatedTotals,
            tax: taxInfo,
            payment: invoice.payment,
            metadata: invoice.metadata
        )
    }
    
    private func shouldApplyReverseCharge(
        supplier: Supplier,
        customer: Customer,
        config: EUVATConfig
    ) -> Bool {
        
        // Check if both supplier and customer are in EU
        guard EUCountryCode(rawValue: supplier.address.countryCode) != nil,
              EUCountryCode(rawValue: customer.address.countryCode) != nil else {
            return false
        }
        
        // Check if customer has valid VAT number
        guard customer.taxNumber != nil else { return false }
        
        // Check if countries are different
        return supplier.address.countryCode != customer.address.countryCode
    }
    
    private func calculateVAT(for item: LineItem, config: EUVATConfig) throws -> Decimal {
        // Check if item is exempt or zero-rated
        if item.taxCode == "EXEMPT" || item.taxCode == "ZERO_RATED" {
            return Decimal.zero
        }
        
        return item.total * config.rate
    }
    
    func validate(invoice: InvoiceData) async throws -> ValidationResult {
        var errors = [ValidationError]()
        var warnings = [ValidationWarning]()
        
        // Validate VAT number format
        if let vatNumber = invoice.supplier.taxNumber {
            if !isValidVATNumber(vatNumber, country: invoice.supplier.address.countryCode) {
                errors.append(ValidationError(
                    field: "supplier.vatNumber",
                    message: "Invalid VAT number format"
                ))
            }
        }
        
        // Validate EU compliance
        if case .vat(let config) = invoice.tax.system {
            if !config.isVATRegistered {
                errors.append(ValidationError(
                    field: "tax.registration",
                    message: "VAT registration required for EU invoices"
                ))
            }
        }
        
        return ValidationResult(errors: errors, warnings: warnings)
    }
    
    private func isValidVATNumber(_ vatNumber: String, country: String) -> Bool {
        // VAT number validation algorithm varies by country
        // This is a simplified version
        let cleanVAT = vatNumber.replacingOccurrences(of: " ", with: "")
        let cleanCountry = country.uppercased()
        
        switch cleanCountry {
        case "GB":
            return cleanVAT.hasPrefix("GB") && cleanVAT.count >= 9
        case "DE":
            return cleanVAT.hasPrefix("DE") && cleanVAT.count == 11
        case "FR":
            return cleanVAT.hasPrefix("FR") && cleanVAT.count == 13
        default:
            return cleanVAT.count >= 8
        }
    }
}
```

---

## Implementation Examples

### Complete Invoice Generation Example

```swift
// MARK: - Complete Implementation Example

class InvoiceService {
    private let templateManager: InvoiceTemplateManager
    private let taxEngine: InternationalTaxEngine
    private let pdfGenerator: TPPDFGenerator
    private let complianceValidator: ATOComplianceValidator
    
    init() {
        self.taxEngine = InternationalTaxEngine()
        self.pdfGenerator = TPPDFGenerator()
        self.complianceValidator = ATOComplianceValidator()
        self.templateManager = InvoiceTemplateManager(
            taxEngine: taxEngine,
            pdfGenerator: pdfGenerator
        )
    }
    
    func generateAustralianGSTInvoice(
        from data: InvoiceData
    ) async throws -> InvoiceDocument {
        
        // Create Australian GST template
        let template = InvoiceTemplateBuilder(
            name: "Australian GST Invoice",
            country: .AU
        )
        .withTaxSystem(.gst(AustraliaGSTConfig(
            rate: 0.10,
            abn: data.supplier.businessNumber ?? "",
            isGSTRegistered: true,
            gstMethod: .accrual,
            basFrequency: .quarterly
        )))
        .withLogo(position: CGRect(x: 20, y: 20, width: 100, height: 50))
        .withHeader(position: CGRect(x: 0, y: 80, width: 595, height: 40))
        .withTable(position: CGRect(x: 20, y: 200, width: 555, height: 300), columns: [
            TableColumn(id: "description", title: "Description", width: 0.4),
            TableColumn(id: "quantity", title: "Qty", width: 0.1),
            TableColumn(id: "unitPrice", title: "Unit Price", width: 0.2),
            TableColumn(id: "total", title: "Total", width: 0.2),
            TableColumn(id: "gst", title: "GST", width: 0.1)
        ])
        .build()
        
        // Validate ATO compliance
        let validationResult = complianceValidator.validateTaxInvoice(data)
        if !validationResult.errors.isEmpty {
            throw ValidationError.complianceFailed(validationResult.errors)
        }
        
        // Calculate taxes
        let calculatedData = try await taxEngine.calculate(
            for: data,
            taxSystem: template.taxSystem
        )
        
        // Generate PDF
        let document = try await pdfGenerator.generate(
            template: template,
            data: calculatedData
        )
        
        return document
    }
    
    func exportToAccountingSystem(
        invoice: InvoiceData,
        target: ExportTarget
    ) async throws -> Data {
        
        switch target {
        case .xero:
            let xeroExport = invoice.toXeroExport()
            return try JSONEncoder().encode(xeroExport)
            
        case .quickBooks:
            let qbExport = invoice.toQuickBooksExport()
            return try JSONEncoder().encode(qbExport)
            
        case .custom(let format):
            return try exportToCustomFormat(invoice: invoice, format: format)
        }
    }
    
    func generateBASReport(
        from invoices: [InvoiceData],
        period: DateInterval
    ) async throws -> BASReport {
        
        let basPeriod = BASInformation.BASPeriod(
            startDate: period.start,
            endDate: period.end,
            frequency: .quarterly
        )
        
        let generator = BASReportGenerator()
        return generator.generateBASReport(
            from: invoices,
            period: basPeriod
        )
    }
}

// Usage Example:
class InvoiceViewController: UIViewController {
    private let invoiceService = InvoiceService()
    
    func createInvoice() async {
        do {
            let invoiceData = createSampleInvoiceData()
            let document = try await invoiceService.generateAustralianGSTInvoice(
                from: invoiceData
            )
            
            // Save or share the PDF
            let pdfData = document.data
            savePDFToFiles(pdfData)
            
            // Export to accounting system
            let xeroData = try await invoiceService.exportToAccountingSystem(
                invoice: invoiceData,
                target: .xero
            )
            
            // Send to Xero API
            try await sendToXero(xeroData)
            
        } catch {
            showError(error)
        }
    }
    
    private func createSampleInvoiceData() -> InvoiceData {
        return InvoiceData(
            id: UUID(),
            number: "INV-2025-001",
            date: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            status: .draft,
            currency: .aud,
            customer: Customer(
                id: UUID(),
                name: "Acme Corporation",
                taxNumber: "12345678901",
                address: Address(
                    line1: "123 Business Street",
                    line2: nil,
                    city: "Sydney",
                    state: "NSW",
                    postalCode: "2000",
                    country: "Australia",
                    countryCode: "AU"
                ),
                contact: ContactInfo(
                    name: "John Doe",
                    email: "john@acme.com",
                    phone: "+61 2 1234 5678"
                )
            ),
            supplier: Supplier(
                id: UUID(),
                name: "My Business Pty Ltd",
                taxNumber: "98765432109",
                address: Address(
                    line1: "456 Supplier Road",
                    line2: nil,
                    city: "Melbourne",
                    state: "VIC",
                    postalCode: "3000",
                    country: "Australia",
                    countryCode: "AU"
                ),
                contact: ContactInfo(
                    name: "Jane Smith",
                    email: "jane@mybusiness.com",
                    phone: "+61 3 9876 5432"
                ),
                logo: nil,
                businessNumber: "98765432109"
            ),
            lineItems: [
                LineItem(
                    id: UUID(),
                    description: "Professional Services - Consulting",
                    quantity: 10,
                    unitPrice: 150.00,
                    discount: nil,
                    taxCode: "GST",
                    total: 1500.00,
                    metadata: [:]
                ),
                LineItem(
                    id: UUID(),
                    description: "Software License",
                    quantity: 1,
                    unitPrice: 500.00,
                    discount: nil,
                    taxCode: "GST",
                    total: 500.00,
                    metadata: [:]
                )
            ],
            totals: InvoiceTotals(
                subtotal: 2000.00,
                discountTotal: 0.00,
                taxTotal: 200.00,
                total: 2200.00,
                paid: 0.00,
                balance: 2200.00
            ),
            tax: TaxInformation(
                system: .gst(AustraliaGSTConfig(
                    rate: 0.10,
                    abn: "98765432109",
                    isGSTRegistered: true,
                    gstMethod: .accrual,
                    basFrequency: .quarterly
                )),
                rate: 0.10,
                amount: 200.00,
                breakdown: [
                    TaxBreakdown(
                        type: "GST",
                        rate: 0.10,
                        amount: 200.00,
                        description: "Goods and Services Tax"
                    )
                ],
                compliance: TaxCompliance(
                    taxNumber: "98765432109",
                    registrationNumber: "98765432109",
                    isRegistered: true,
                    country: "AU"
                )
            ),
            payment: nil,
            metadata: [
                "taxInvoiceHeader": "Tax Invoice",
                "reference": "Project ABC"
            ]
        )
    }
}
```

### Error Handling and Validation

```swift
// MARK: - Error Handling

enum InvoiceError: Error, LocalizedError {
    case invalidTemplate(String)
    case taxCalculationFailed(String)
    case pdfGenerationFailed(String)
    case complianceFailed([ValidationError])
    case exportFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidTemplate(let message):
            return "Invalid template: \(message)"
        case .taxCalculationFailed(let message):
            return "Tax calculation failed: \(message)"
        case .pdfGenerationFailed(let message):
            return "PDF generation failed: \(message)"
        case .complianceFailed(let errors):
            return "Compliance validation failed: \(errors.map(\.message).joined(separator: ", "))"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}

struct ValidationError {
    let field: String
    let message: String
}

struct ValidationWarning {
    let field: String
    let message: String
}

struct ValidationResult {
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    
    var isValid: Bool {
        return errors.isEmpty
    }
}

enum TaxError: Error, LocalizedError {
    case unsupportedTaxSystem
    case invalidTaxSystem
    case unsupportedCountry(String)
    case calculationError(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedTaxSystem:
            return "Unsupported tax system"
        case .invalidTaxSystem:
            return "Invalid tax system configuration"
        case .unsupportedCountry(let country):
            return "Unsupported country: \(country)"
        case .calculationError(let message):
            return "Tax calculation error: \(message)"
        }
    }
}
```

---

## Conclusion

This comprehensive guide provides a robust foundation for implementing flexible invoice template systems in Swift applications. The architecture supports:

1. **Multi-country tax compliance** with specialized calculators for different tax systems
2. **Flexible PDF generation** using multiple libraries (PDFKit, TPPDF, PDFBlocks)
3. **Accounting software integration** with standardized JSON export schemas
4. **Template customization** with a builder pattern for easy configuration
5. **Australian business requirements** including ATO compliance and BAS reporting
6. **International tax support** with extensible tax calculation engines

The system is designed to be modular, extensible, and maintainable, allowing businesses to easily adapt to changing tax regulations and requirements across different jurisdictions.

### Key Benefits

- **Compliance**: Built-in validation for ATO, EU VAT, and other tax authorities
- **Flexibility**: Template builder pattern allows for easy customization
- **Integration**: Standardized export formats for major accounting software
- **Scalability**: Modular architecture supports adding new countries and tax systems
- **Maintainability**: Clear separation of concerns and well-defined interfaces

### Next Steps

1. Implement additional tax calculators for more countries
2. Add support for electronic invoicing standards (UBL, PEPPOL)
3. Integrate with real-time tax rate APIs
4. Add template versioning and migration support
5. Implement advanced reporting and analytics features