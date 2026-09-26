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

/// A self-contained JSON document describing locations, assignments, worked days,
/// sessions, receipts and attachments to be imported into the store.
///
/// Conventions:
/// - Dates are `yyyy-MM-dd`; session times are `yyyy-MM-dd'T'HH:mm`. Both are
///   "wall clock" values interpreted in the importing device's time zone, exactly
///   as if the user had typed them into the app.
/// - Enum fields use the models' raw values (e.g. `daily_rate`, `on_call`, `travel`).
/// - Attachment file contents are embedded as base64 so the bundle is a single
///   file (sandboxed apps are only granted access to the file the user picks).
/// - Optional `id`s make imports idempotent: records whose id already exists are skipped.
public struct ImportBundle: Codable, Sendable {
    /// Format version of the bundle
    public var formatVersion: Int
    /// Locations referenced by assignments and sessions
    public var locations: [ImportLocation]
    /// Assignments with their days, receipts and documents
    public var assignments: [ImportAssignment]

    /// The only bundle format version this importer understands
    public static let supportedFormatVersion = 1

    public init(formatVersion: Int = ImportBundle.supportedFormatVersion,
                locations: [ImportLocation],
                assignments: [ImportAssignment]) {
        self.formatVersion = formatVersion
        self.locations = locations
        self.assignments = assignments
    }
}

/// A location (hospital, clinic, community) in an import bundle
public struct ImportLocation: Codable, Sendable {
    /// Key used by assignments and sessions to reference this location
    public var key: String
    public var id: UUID?
    public var name: String
    public var address: String
    /// MMM classification 1-7
    public var mmm: Int
    public var latitude: Double?
    public var longitude: Double?
    public var phoneNumber: String?
    public var notes: String?

    public init(key: String, id: UUID? = nil, name: String, address: String, mmm: Int,
                latitude: Double? = nil, longitude: Double? = nil,
                phoneNumber: String? = nil, notes: String? = nil) {
        self.key = key
        self.id = id
        self.name = name
        self.address = address
        self.mmm = mmm
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.notes = notes
    }
}

/// An assignment (locum placement) in an import bundle
public struct ImportAssignment: Codable, Sendable {
    public var id: UUID?
    public var name: String?
    /// Key of the primary location
    public var locationKey: String
    /// Keys of additional locations covered by this assignment
    public var additionalLocationKeys: [String]?
    /// `RateStructure` raw value
    public var rateStructure: String
    public var dailyRate: Double?
    public var hourlyRate: Double?
    public var onCallRate: Double?
    public var callOutRate: Double?
    public var startDate: String
    public var endDate: String
    /// `AssignmentStatus` raw value
    public var status: String
    public var days: [ImportDay]?
    public var receipts: [ImportReceipt]?
    /// Documents attached to the assignment itself (invoices, timesheets, contracts)
    public var attachments: [ImportAttachment]?

    public init(id: UUID? = nil, name: String? = nil, locationKey: String,
                additionalLocationKeys: [String]? = nil, rateStructure: String,
                dailyRate: Double? = nil, hourlyRate: Double? = nil,
                onCallRate: Double? = nil, callOutRate: Double? = nil,
                startDate: String, endDate: String, status: String,
                days: [ImportDay]? = nil, receipts: [ImportReceipt]? = nil,
                attachments: [ImportAttachment]? = nil) {
        self.id = id
        self.name = name
        self.locationKey = locationKey
        self.additionalLocationKeys = additionalLocationKeys
        self.rateStructure = rateStructure
        self.dailyRate = dailyRate
        self.hourlyRate = hourlyRate
        self.onCallRate = onCallRate
        self.callOutRate = callOutRate
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.days = days
        self.receipts = receipts
        self.attachments = attachments
    }
}

/// A worked day in an import bundle
public struct ImportDay: Codable, Sendable {
    public var id: UUID?
    public var date: String
    public var notes: String?
    public var wasOnCall: Bool?
    public var sessions: [ImportSession]

    public init(id: UUID? = nil, date: String, notes: String? = nil,
                wasOnCall: Bool? = nil, sessions: [ImportSession]) {
        self.id = id
        self.date = date
        self.notes = notes
        self.wasOnCall = wasOnCall
        self.sessions = sessions
    }
}

/// A session within a worked day
public struct ImportSession: Codable, Sendable {
    public var id: UUID?
    public var start: String
    public var end: String
    /// `SessionType` raw value
    public var type: String
    /// Location key for multi-location assignments; defaults to the assignment's primary location
    public var locationKey: String?
    public var notes: String?

    public init(id: UUID? = nil, start: String, end: String, type: String,
                locationKey: String? = nil, notes: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.type = type
        self.locationKey = locationKey
        self.notes = notes
    }
}

/// An expense receipt in an import bundle
public struct ImportReceipt: Codable, Sendable {
    public var id: UUID?
    public var date: String
    /// Amount paid, GST inclusive
    public var amount: Double
    /// `ExpenseCategory` raw value
    public var category: String
    public var description: String
    public var attachments: [ImportAttachment]?

    public init(id: UUID? = nil, date: String, amount: Double, category: String,
                description: String, attachments: [ImportAttachment]? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.category = category
        self.description = description
        self.attachments = attachments
    }
}

/// A file attachment with embedded content
public struct ImportAttachment: Codable, Sendable {
    public var id: UUID?
    public var filename: String
    /// Base64-encoded file contents
    public var dataBase64: String
    public var notes: String?

    public init(id: UUID? = nil, filename: String, dataBase64: String, notes: String? = nil) {
        self.id = id
        self.filename = filename
        self.dataBase64 = dataBase64
        self.notes = notes
    }
}
