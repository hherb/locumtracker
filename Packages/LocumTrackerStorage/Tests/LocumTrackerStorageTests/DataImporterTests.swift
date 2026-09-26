// LocumTrackerStorageTests
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

import XCTest
import SwiftData
import LocumTrackerCore
@testable import LocumTrackerStorage

@MainActor
final class DataImporterTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var calendar: Calendar!

    private let dailyRate = 2000.0

    override func setUp() async throws {
        let schema = Schema(LocumTrackerSchema.models)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
    }

    // MARK: - Fixtures

    private func sampleBundle(assignmentId: UUID = UUID()) -> ImportBundle {
        let pdf = Data("%PDF-1.4 fake".utf8).base64EncodedString()
        return ImportBundle(
            locations: [
                ImportLocation(key: "town", name: "Sample Town Hospital", address: "1 Main St", mmm: 6),
                ImportLocation(key: "outpost", name: "Outpost Clinic", address: "Outpost", mmm: 7),
            ],
            assignments: [
                ImportAssignment(
                    id: assignmentId,
                    name: "Sample locum",
                    locationKey: "town",
                    additionalLocationKeys: ["outpost"],
                    rateStructure: "daily_rate",
                    dailyRate: dailyRate,
                    startDate: "2026-03-02",
                    endDate: "2026-03-04",
                    status: "completed",
                    days: [
                        ImportDay(date: "2026-03-02", sessions: [
                            ImportSession(start: "2026-03-02T08:00", end: "2026-03-02T12:00", type: "regular"),
                            ImportSession(start: "2026-03-02T12:30", end: "2026-03-02T18:00", type: "regular"),
                        ]),
                        ImportDay(date: "2026-03-03", wasOnCall: true, sessions: [
                            ImportSession(start: "2026-03-03T18:00", end: "2026-03-04T08:00",
                                          type: "on_call", locationKey: "outpost", notes: "2nd on call"),
                        ]),
                    ],
                    receipts: [
                        ImportReceipt(date: "2026-03-01", amount: 550.0, category: "travel",
                                      description: "Flight",
                                      attachments: [ImportAttachment(filename: "ticket.pdf", dataBase64: pdf)]),
                    ],
                    attachments: [ImportAttachment(filename: "invoice.pdf", dataBase64: pdf, notes: "Invoice")]
                ),
            ]
        )
    }

    // MARK: - Tests

    func testImportCreatesAllRecords() throws {
        let summary = try DataImporter.importBundle(sampleBundle(), into: context, calendar: calendar)

        XCTAssertEqual(summary.locations, 2)
        XCTAssertEqual(summary.assignments, 1)
        XCTAssertEqual(summary.dailyRecords, 2)
        XCTAssertEqual(summary.sessions, 3)
        XCTAssertEqual(summary.receipts, 1)
        XCTAssertEqual(summary.attachments, 2)
        XCTAssertEqual(summary.skipped, 0)

        let assignment = try XCTUnwrap(context.fetch(FetchDescriptor<Assignment>()).first)
        XCTAssertEqual(assignment.additionalLocationIds.count, 1)
        XCTAssertEqual(assignment.status, .completed)
    }

    func testDailyEarningsAreCalculated() throws {
        try DataImporter.importBundle(sampleBundle(), into: context, calendar: calendar)

        let records = try context.fetch(FetchDescriptor<DailyRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.allSatisfy { $0.totalEarnings == dailyRate })
    }

    func testSessionLocationAndMMMResolved() throws {
        try DataImporter.importBundle(sampleBundle(), into: context, calendar: calendar)

        let outpost = try XCTUnwrap(context.fetch(FetchDescriptor<Location>()).first { $0.name == "Outpost Clinic" })
        let onCall = try XCTUnwrap(context.fetch(FetchDescriptor<Session>()).first { $0.sessionType == .onCall })
        XCTAssertEqual(onCall.locationId, outpost.id)
        XCTAssertEqual(onCall.mmmClassification, 7)
        XCTAssertEqual(onCall.durationHours, 14, accuracy: 0.001)
        XCTAssertEqual(onCall.notes, "2nd on call")

        let regular = try XCTUnwrap(context.fetch(FetchDescriptor<Session>()).first { $0.sessionType == .regular })
        XCTAssertNil(regular.locationId)
        XCTAssertEqual(regular.mmmClassification, 6)
    }

    func testWallClockTimesUseCalendarTimeZone() throws {
        try DataImporter.importBundle(sampleBundle(), into: context, calendar: calendar)

        let sessions = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startTime)]))
        let first = try XCTUnwrap(sessions.first)
        XCTAssertEqual(calendar.component(.hour, from: first.startTime), 8)
        XCTAssertEqual(calendar.component(.day, from: first.startTime), 2)
    }

    func testAttachmentsLinkedToReceiptAndAssignment() throws {
        try DataImporter.importBundle(sampleBundle(), into: context, calendar: calendar)

        let receipt = try XCTUnwrap(context.fetch(FetchDescriptor<Receipt>()).first)
        let attachments = try context.fetch(FetchDescriptor<Attachment>())
        let ticket = try XCTUnwrap(attachments.first { $0.filename == "ticket.pdf" })
        XCTAssertEqual(ticket.receiptId, receipt.id)
        XCTAssertNil(ticket.assignmentId)
        XCTAssertEqual(ticket.fileType, .pdf)
        XCTAssertEqual(ticket.fileData, Data("%PDF-1.4 fake".utf8))

        let invoice = try XCTUnwrap(attachments.first { $0.filename == "invoice.pdf" })
        XCTAssertEqual(invoice.assignmentId, receipt.assignmentId)
    }

    func testReimportWithSameIdsIsSkipped() throws {
        var bundle = sampleBundle()
        bundle.locations = bundle.locations.map { location in
            var copy = location
            copy.id = UUID()
            return copy
        }

        try DataImporter.importBundle(bundle, into: context, calendar: calendar)
        let second = try DataImporter.importBundle(bundle, into: context, calendar: calendar)

        XCTAssertEqual(second.assignments, 0)
        XCTAssertEqual(second.locations, 0)
        XCTAssertEqual(second.skipped, 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Session>()), 3)
    }

    func testInvalidBundleInsertsNothing() throws {
        var bundle = sampleBundle()
        bundle.assignments[0].days?[1].sessions[0].type = "nonsense"

        XCTAssertThrowsError(try DataImporter.importBundle(bundle, into: context, calendar: calendar)) { error in
            XCTAssertEqual(error as? DataImportError, .invalidValue(field: "session type", value: "nonsense"))
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Location>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Assignment>()), 0)
    }

    func testUnknownLocationKeyRejected() {
        var bundle = sampleBundle()
        bundle.assignments[0].locationKey = "missing"

        XCTAssertThrowsError(try DataImporter.importBundle(bundle, into: context, calendar: calendar)) { error in
            XCTAssertEqual(error as? DataImportError, .unknownLocationKey("missing"))
        }
    }

    func testSessionEndingBeforeStartRejected() {
        var bundle = sampleBundle()
        bundle.assignments[0].days?[0].sessions[0].end = "2026-03-02T07:00"

        XCTAssertThrowsError(try DataImporter.importBundle(bundle, into: context, calendar: calendar)) { error in
            XCTAssertEqual(error as? DataImportError, .endBeforeStart("session 2026-03-02T08:00"))
        }
    }

    func testUnsupportedFormatVersionRejected() {
        var bundle = sampleBundle()
        bundle.formatVersion = 99

        XCTAssertThrowsError(try DataImporter.importBundle(bundle, into: context, calendar: calendar)) { error in
            XCTAssertEqual(error as? DataImportError, .unsupportedFormatVersion(99))
        }
    }

    func testDecodeRoundTrip() throws {
        let data = try JSONEncoder().encode(sampleBundle())
        let decoded = try DataImporter.decode(data)
        XCTAssertEqual(decoded.assignments.first?.days?.count, 2)
        XCTAssertEqual(decoded.locations.map(\.key), ["town", "outpost"])
    }
}
