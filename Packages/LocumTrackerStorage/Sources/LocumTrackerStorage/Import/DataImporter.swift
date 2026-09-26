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

import Foundation
import SwiftData
import LocumTrackerCore

/// Errors raised while validating an import bundle. Validation happens before
/// anything is inserted, so a failed import leaves the store untouched.
public enum DataImportError: LocalizedError, Equatable {
    case unsupportedFormatVersion(Int)
    case invalidDate(String)
    case invalidDateTime(String)
    case invalidValue(field: String, value: String)
    case duplicateLocationKey(String)
    case unknownLocationKey(String)
    case invalidMMM(Int)
    case endBeforeStart(String)
    case invalidAttachmentData(filename: String)
    case attachmentTooLarge(filename: String, size: Int)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let version):
            return "Unsupported import format version \(version)"
        case .invalidDate(let value):
            return "Invalid date '\(value)' (expected yyyy-MM-dd)"
        case .invalidDateTime(let value):
            return "Invalid date/time '\(value)' (expected yyyy-MM-ddTHH:mm)"
        case .invalidValue(let field, let value):
            return "Invalid value '\(value)' for \(field)"
        case .duplicateLocationKey(let key):
            return "Location key '\(key)' is used more than once"
        case .unknownLocationKey(let key):
            return "Unknown location key '\(key)'"
        case .invalidMMM(let value):
            return "Invalid MMM classification \(value) (expected 1-7)"
        case .endBeforeStart(let context):
            return "End is before start: \(context)"
        case .invalidAttachmentData(let filename):
            return "Attachment '\(filename)' is not valid base64"
        case .attachmentTooLarge(let filename, let size):
            return "Attachment '\(filename)' is \(size) bytes (limit \(maxAttachmentSize))"
        }
    }
}

/// Counts of records created (and skipped because they already existed) by an import
public struct DataImportSummary: Equatable, Sendable {
    public var locations = 0
    public var assignments = 0
    public var dailyRecords = 0
    public var sessions = 0
    public var receipts = 0
    public var attachments = 0
    /// Records skipped because a record with the same id already exists
    public var skipped = 0

    public init() {}

    /// Human-readable one-line summary
    public var description: String {
        var text = "Imported \(locations) locations, \(assignments) assignments, "
            + "\(dailyRecords) days, \(sessions) sessions, \(receipts) receipts, "
            + "\(attachments) attachments"
        if skipped > 0 {
            text += " (\(skipped) already present, skipped)"
        }
        return text
    }
}

/// Imports an `ImportBundle` into a SwiftData model context.
public enum DataImporter {

    /// Decodes an import bundle from JSON data.
    ///
    /// - Parameter data: JSON-encoded `ImportBundle`
    /// - Returns: The decoded bundle
    /// - Throws: `DecodingError` if the JSON does not match the bundle format
    public static func decode(_ data: Data) throws -> ImportBundle {
        try JSONDecoder().decode(ImportBundle.self, from: data)
    }

    /// Validates the bundle and inserts its contents into the context, then saves.
    ///
    /// Records carrying an `id` that already exists in the store are skipped
    /// (together with their children), so importing the same bundle twice is harmless.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to import
    ///   - context: The model context to insert into
    ///   - calendar: Calendar (and time zone) used to interpret wall-clock dates
    /// - Returns: Counts of created and skipped records
    /// - Throws: `DataImportError` if validation fails (nothing is inserted), or a save error
    @discardableResult
    public static func importBundle(
        _ bundle: ImportBundle,
        into context: ModelContext,
        calendar: Calendar = .current
    ) throws -> DataImportSummary {
        let plan = try ImportPlan(bundle: bundle, calendar: calendar)
        var summary = DataImportSummary()

        for location in plan.locations {
            if locationExists(id: location.id, in: context) {
                summary.skipped += 1
                continue
            }
            context.insert(location.makeModel())
            summary.locations += 1
        }

        for assignment in plan.assignments {
            insert(assignment, into: context, summary: &summary)
        }

        try context.save()
        return summary
    }

    // MARK: - Insertion

    private static func insert(
        _ planned: PlannedAssignment,
        into context: ModelContext,
        summary: inout DataImportSummary
    ) {
        if assignmentExists(id: planned.id, in: context) {
            summary.skipped += 1
            return
        }

        let assignment = Assignment(
            id: planned.id,
            locationId: planned.locationId,
            rateStructure: planned.rateStructure,
            dailyRate: planned.dailyRate,
            hourlyRate: planned.hourlyRate,
            onCallRate: planned.onCallRate,
            callOutRate: planned.callOutRate,
            startDate: planned.startDate,
            endDate: planned.endDate,
            status: planned.status,
            name: planned.name,
            additionalLocationIds: planned.additionalLocationIds
        )
        context.insert(assignment)
        summary.assignments += 1

        for day in planned.days {
            let record = DailyRecord(
                id: day.id,
                assignmentId: assignment.id,
                date: day.date,
                notes: day.notes,
                wasOnCall: day.wasOnCall
            )
            context.insert(record)
            summary.dailyRecords += 1

            for session in day.sessions {
                let model = Session(
                    id: session.id,
                    dailyRecordId: record.id,
                    startTime: session.start,
                    endTime: session.end,
                    sessionType: session.type,
                    mmmClassification: session.mmm,
                    locationId: session.locationId
                )
                model.notes = session.notes
                context.insert(model)
                summary.sessions += 1
            }

            record.totalEarnings = EarningsService.calculateDailyEarnings(
                rateStructure: assignment.rateStructure,
                dailyRate: assignment.dailyRate,
                hourlyRate: assignment.hourlyRate,
                onCallRate: assignment.onCallRate,
                callOutRate: assignment.callOutRate,
                sessions: day.sessions.map { session in
                    (type: session.type,
                     durationHours: session.end.timeIntervalSince(session.start) / TimeInterval.secondsPerHour)
                }
            )
        }

        for receipt in planned.receipts {
            context.insert(Receipt(
                id: receipt.id,
                amount: receipt.amount,
                category: receipt.category,
                date: receipt.date,
                receiptDescription: receipt.description,
                assignmentId: assignment.id
            ))
            summary.receipts += 1
            for file in receipt.attachments {
                context.insert(file.makeModel(assignmentId: nil, receiptId: receipt.id))
                summary.attachments += 1
            }
        }

        for file in planned.attachments {
            context.insert(file.makeModel(assignmentId: assignment.id, receiptId: nil))
            summary.attachments += 1
        }
    }

    private static func locationExists(id: UUID, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Location>(predicate: #Predicate { $0.id == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private static func assignmentExists(id: UUID, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Assignment>(predicate: #Predicate { $0.id == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }
}

private extension TimeInterval {
    static let secondsPerHour: TimeInterval = 3600
}

// MARK: - Validated plan

/// Fully validated, typed representation of a bundle. Building it performs all
/// parsing, so insertion afterwards cannot fail half-way.
private struct ImportPlan {
    var locations: [PlannedLocation] = []
    var assignments: [PlannedAssignment] = []

    init(bundle: ImportBundle, calendar: Calendar) throws {
        guard bundle.formatVersion == ImportBundle.supportedFormatVersion else {
            throw DataImportError.unsupportedFormatVersion(bundle.formatVersion)
        }
        let parser = WallClockParser(calendar: calendar)

        var locationsByKey: [String: PlannedLocation] = [:]
        for source in bundle.locations {
            guard locationsByKey[source.key] == nil else {
                throw DataImportError.duplicateLocationKey(source.key)
            }
            guard MMMClassification(rawValue: source.mmm) != nil else {
                throw DataImportError.invalidMMM(source.mmm)
            }
            let planned = PlannedLocation(id: source.id ?? UUID(), source: source)
            locationsByKey[source.key] = planned
            locations.append(planned)
        }

        func location(_ key: String) throws -> PlannedLocation {
            guard let found = locationsByKey[key] else { throw DataImportError.unknownLocationKey(key) }
            return found
        }

        for source in bundle.assignments {
            let primary = try location(source.locationKey)
            let additional = try (source.additionalLocationKeys ?? []).map { try location($0).id }

            guard let rateStructure = RateStructure(rawValue: source.rateStructure) else {
                throw DataImportError.invalidValue(field: "rateStructure", value: source.rateStructure)
            }
            guard let status = AssignmentStatus(rawValue: source.status) else {
                throw DataImportError.invalidValue(field: "status", value: source.status)
            }
            let startDate = try parser.date(source.startDate)
            let endDate = try parser.date(source.endDate)
            guard endDate >= startDate else {
                throw DataImportError.endBeforeStart("assignment \(source.name ?? source.startDate)")
            }

            let days = try (source.days ?? []).map { day -> PlannedDay in
                let sessions = try day.sessions.map { session -> PlannedSession in
                    guard let type = SessionType(rawValue: session.type) else {
                        throw DataImportError.invalidValue(field: "session type", value: session.type)
                    }
                    let start = try parser.dateTime(session.start)
                    let end = try parser.dateTime(session.end)
                    guard end > start else {
                        throw DataImportError.endBeforeStart("session \(session.start)")
                    }
                    let sessionLocation = try session.locationKey.map(location)
                    return PlannedSession(
                        id: session.id ?? UUID(),
                        start: start,
                        end: end,
                        type: type,
                        mmm: (sessionLocation ?? primary).source.mmm,
                        locationId: sessionLocation?.id,
                        notes: session.notes
                    )
                }
                return PlannedDay(
                    id: day.id ?? UUID(),
                    date: try parser.date(day.date),
                    notes: day.notes,
                    wasOnCall: day.wasOnCall ?? false,
                    sessions: sessions
                )
            }

            let receipts = try (source.receipts ?? []).map { receipt -> PlannedReceipt in
                guard let category = ExpenseCategory(rawValue: receipt.category) else {
                    throw DataImportError.invalidValue(field: "receipt category", value: receipt.category)
                }
                return PlannedReceipt(
                    id: receipt.id ?? UUID(),
                    date: try parser.date(receipt.date),
                    amount: receipt.amount,
                    category: category,
                    description: receipt.description,
                    attachments: try (receipt.attachments ?? []).map(PlannedAttachment.init)
                )
            }

            assignments.append(PlannedAssignment(
                id: source.id ?? UUID(),
                name: source.name,
                locationId: primary.id,
                additionalLocationIds: additional,
                rateStructure: rateStructure,
                dailyRate: source.dailyRate,
                hourlyRate: source.hourlyRate,
                onCallRate: source.onCallRate,
                callOutRate: source.callOutRate,
                startDate: startDate,
                endDate: endDate,
                status: status,
                days: days,
                receipts: receipts,
                attachments: try (source.attachments ?? []).map(PlannedAttachment.init)
            ))
        }
    }
}

private struct PlannedLocation {
    let id: UUID
    let source: ImportLocation

    func makeModel() -> Location {
        Location(
            id: id,
            name: source.name,
            address: source.address,
            mmmClassification: source.mmm,
            latitude: source.latitude,
            longitude: source.longitude,
            phoneNumber: source.phoneNumber,
            notes: source.notes
        )
    }
}

private struct PlannedAssignment {
    let id: UUID
    let name: String?
    let locationId: UUID
    let additionalLocationIds: [UUID]
    let rateStructure: RateStructure
    let dailyRate: Double?
    let hourlyRate: Double?
    let onCallRate: Double?
    let callOutRate: Double?
    let startDate: Date
    let endDate: Date
    let status: AssignmentStatus
    let days: [PlannedDay]
    let receipts: [PlannedReceipt]
    let attachments: [PlannedAttachment]
}

private struct PlannedDay {
    let id: UUID
    let date: Date
    let notes: String?
    let wasOnCall: Bool
    let sessions: [PlannedSession]
}

private struct PlannedSession {
    let id: UUID
    let start: Date
    let end: Date
    let type: SessionType
    let mmm: Int
    let locationId: UUID?
    let notes: String?
}

private struct PlannedReceipt {
    let id: UUID
    let date: Date
    let amount: Double
    let category: ExpenseCategory
    let description: String
    let attachments: [PlannedAttachment]
}

private struct PlannedAttachment {
    let id: UUID
    let filename: String
    let data: Data
    let notes: String?

    init(_ source: ImportAttachment) throws {
        guard let data = Data(base64Encoded: source.dataBase64) else {
            throw DataImportError.invalidAttachmentData(filename: source.filename)
        }
        guard data.count <= maxAttachmentSize else {
            throw DataImportError.attachmentTooLarge(filename: source.filename, size: data.count)
        }
        self.id = source.id ?? UUID()
        self.filename = source.filename
        self.data = data
        self.notes = source.notes
    }

    func makeModel(assignmentId: UUID?, receiptId: UUID?) -> Attachment {
        Attachment(
            id: id,
            assignmentId: assignmentId,
            receiptId: receiptId,
            filename: filename,
            fileType: AttachmentType(fromExtension: (filename as NSString).pathExtension),
            fileSize: Int64(data.count),
            fileData: data,
            notes: notes
        )
    }
}

/// Parses wall-clock date strings in a given calendar's time zone
private struct WallClockParser {
    private let dateFormatter: DateFormatter
    private let dateTimeFormatter: DateFormatter

    init(calendar: Calendar) {
        dateFormatter = Self.formatter("yyyy-MM-dd", calendar: calendar)
        dateTimeFormatter = Self.formatter("yyyy-MM-dd'T'HH:mm", calendar: calendar)
    }

    func date(_ string: String) throws -> Date {
        guard let date = dateFormatter.date(from: string) else { throw DataImportError.invalidDate(string) }
        return date
    }

    func dateTime(_ string: String) throws -> Date {
        guard let date = dateTimeFormatter.date(from: string) else { throw DataImportError.invalidDateTime(string) }
        return date
    }

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}
