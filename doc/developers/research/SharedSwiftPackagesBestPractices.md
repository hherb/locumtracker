# Shared Swift Packages for iOS and macOS: Best Practices Guide

## Overview

This guide covers best practices for creating shared Swift packages between iOS and macOS apps, with concrete examples for a locum tracking application. The focus is on clean architecture, pure functions, and maintainable cross-platform code.

## 1. Swift Package Manager Structure for Multi-Platform Support

### Package.swift Configuration

```swift
// Package.swift
import PackageDescription

let package = Package(
    name: "LocumTrackerCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LocumTrackerCore",
            targets: ["LocumTrackerCore"]
        ),
        .library(
            name: "LocumTrackerUI",
            targets: ["LocumTrackerUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-sharing.git", from: "2.0.0"),
        .package(url: "https://github.com/tuist/filesystem.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "LocumTrackerCore",
            dependencies: [
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "FileSystem", package: "filesystem")
            ]
        ),
        .target(
            name: "LocumTrackerUI",
            dependencies: ["LocumTrackerCore"]
        ),
        .testTarget(
            name: "LocumTrackerCoreTests",
            dependencies: ["LocumTrackerCore"]
        ),
        .testTarget(
            name: "LocumTrackerUITests",
            dependencies: ["LocumTrackerUI"]
        )
    ]
)
```

### Directory Structure

```
LocumTrackerCore/
├── Package.swift
├── Sources/
│   ├── LocumTrackerCore/
│   │   ├── Domain/
│   │   │   ├── Models/
│   │   │   │   ├── Locum.swift
│   │   │   │   ├── Shift.swift
│   │   │   │   ├── Location.swift
│   │   │   │   └── Payment.swift
│   │   │   ├── Services/
│   │   │   │   ├── LocumService.swift
│   │   │   │   ├── ShiftService.swift
│   │   │   │   └── PaymentService.swift
│   │   │   └── Repositories/
│   │   │       ├── LocumRepository.swift
│   │   │       └── ShiftRepository.swift
│   │   ├── Data/
│   │   │   ├── DataSource/
│   │   │   │   ├── FileStorage.swift
│   │   │   │   └── UserDefaultsStorage.swift
│   │   │   └── DTOs/
│   │   │       ├── LocumDTO.swift
│   │   │       └── ShiftDTO.swift
│   │   └── Infrastructure/
│   │       ├── FileSystem/
│   │       │   └── FileSystemAdapter.swift
│   │       └── Storage/
│   │           └── StorageManager.swift
│   └── LocumTrackerUI/
│       ├── Components/
│       │   ├── ShiftCard.swift
│       │   ├── LocumProfile.swift
│       │   └── PaymentSummary.swift
│       └── Platform/
│           ├── iOS/
│           │   └── iOSComponents.swift
│           └── macOS/
│               └── macOSComponents.swift
├── Tests/
│   ├── LocumTrackerCoreTests/
│   └── LocumTrackerUITests/
└── Examples/
    ├── iOS-Example/
    └── macOS-Example/
```

## 2. Pure Function Design Patterns

### Core Business Logic as Pure Functions

```swift
// Domain/Services/ShiftService.swift
public struct ShiftService {
    
    // Pure function: calculates total hours without side effects
    public static func calculateTotalHours(for shifts: [Shift]) -> TimeInterval {
        shifts.reduce(0) { total, shift in
            total + shift.duration
        }
    }
    
    // Pure function: validates shift data
    public static func validateShift(_ shift: Shift) -> ValidationResult {
        var errors: [String] = []
        
        if shift.startTime >= shift.endTime {
            errors.append("Start time must be before end time")
        }
        
        if shift.duration <= 0 {
            errors.append("Shift duration must be positive")
        }
        
        if shift.hourlyRate <= 0 {
            errors.append("Hourly rate must be positive")
        }
        
        return errors.isEmpty ? .valid : .invalid(errors)
    }
    
    // Pure function: calculates payment
    public static func calculatePayment(for shift: Shift) -> Payment {
        let baseAmount = shift.duration * shift.hourlyRate
        let bonus = shift.isOvertime ? baseAmount * 0.5 : 0
        let total = baseAmount + bonus
        
        return Payment(
            id: UUID(),
            shiftId: shift.id,
            baseAmount: baseAmount,
            bonus: bonus,
            total: total,
            date: shift.startTime,
            status: .pending
        )
    }
    
    // Pure function: filters available shifts
    public static func filterAvailableShifts(
        _ shifts: [Shift],
        for locum: Locum,
        in dateRange: ClosedRange<Date>
    ) -> [Shift] {
        shifts.filter { shift in
            dateRange.contains(shift.startTime) &&
            shift.requiredSkills.isSubset(of: locum.skills) &&
            shift.status == .available
        }
    }
}

// Domain/Models/Common.swift
public enum ValidationResult {
    case valid
    case invalid([String])
}
```

### Functional Composition Examples

```swift
// Domain/Services/LocumService.swift
public struct LocumService {
    
    // Pure function: composes multiple operations
    public static func createLocumProfile(
        from data: LocumRegistrationData
    ) -> Result<Locum, ValidationError> {
        // Functional composition pipeline
        return validateRegistrationData(data)
            .flatMap(normalizeData)
            .flatMap(createLocum)
    }
    
    private static func validateRegistrationData(
        _ data: LocumRegistrationData
    ) -> Result<LocumRegistrationData, ValidationError> {
        // Validation logic without side effects
        guard !data.firstName.isEmpty else {
            return .failure(.invalidFirstName)
        }
        
        guard !data.lastName.isEmpty else {
            return .failure(.invalidLastName)
        }
        
        guard data.email.contains("@") else {
            return .failure(.invalidEmail)
        }
        
        return .success(data)
    }
    
    private static func normalizeData(
        _ data: LocumRegistrationData
    ) -> Result<LocumRegistrationData, ValidationError> {
        // Data normalization without side effects
        let normalizedData = LocumRegistrationData(
            firstName: data.firstName.trimmingCharacters(in: .whitespaces),
            lastName: data.lastName.trimmingCharacters(in: .whitespaces),
            email: data.email.lowercased(),
            skills: data.skills.sorted(),
            hourlyRate: data.hourlyRate
        )
        
        return .success(normalizedData)
    }
    
    private static func createLocum(
        from data: LocumRegistrationData
    ) -> Result<Locum, ValidationError> {
        let locum = Locum(
            id: UUID(),
            firstName: data.firstName,
            lastName: data.lastName,
            email: data.email,
            skills: data.skills,
            hourlyRate: data.hourlyRate,
            status: .active
        )
        
        return .success(locum)
    }
}
```

## 3. Shared Business Logic Separation Strategies

### Clean Architecture Layers

```swift
// Domain/Models/Locum.swift
public struct Locum: Identifiable, Codable, Equatable {
    public let id: UUID
    public let firstName: String
    public let lastName: String
    public let email: String
    public let skills: Set<Skill>
    public let hourlyRate: Decimal
    public let status: LocumStatus
    public let createdAt: Date
    
    public init(
        id: UUID,
        firstName: String,
        lastName: String,
        email: String,
        skills: Set<Skill>,
        hourlyRate: Decimal,
        status: LocumStatus,
        createdAt: Date
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.skills = skills
        self.hourlyRate = hourlyRate
        self.status = status
        self.createdAt = createdAt
    }
}

// Domain/Repositories/LocumRepository.swift
public protocol LocumRepository {
    func save(_ locum: Locum) async throws
    func findById(_ id: UUID) async throws -> Locum?
    func findAll() async throws -> [Locum]
    func findByStatus(_ status: LocumStatus) async throws -> [Locum]
    func delete(_ id: UUID) async throws
}

// Data/DataSource/FileStorage.swift
public class FileLocumRepository: LocumRepository {
    private let fileSystem: FileSystem
    private let storageURL: URL
    
    public init(fileSystem: FileSystem, storageURL: URL) {
        self.fileSystem = fileSystem
        self.storageURL = storageURL
    }
    
    public func save(_ locum: Locum) async throws {
        let data = try JSONEncoder().encode(locum)
        let fileURL = storageURL.appendingPathComponent("\(locum.id.uuidString).json")
        try await fileSystem.write(data, to: fileURL)
    }
    
    public func findById(_ id: UUID) async throws -> Locum? {
        let fileURL = storageURL.appendingPathComponent("\(id.uuidString).json")
        
        guard await fileSystem.exists(fileURL) else {
            return nil
        }
        
        let data = try await fileSystem.read(fileURL)
        return try JSONDecoder().decode(Locum.self, from: data)
    }
    
    // Implement other methods...
}
```

### Dependency Injection for Shared Code

```swift
// Infrastructure/DependencyContainer.swift
public final class DependencyContainer {
    private var services: [String: Any] = [:]
    
    public init() {}
    
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        services[key] = factory
    }
    
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        guard let factory = services[key] as? () -> T else {
            return nil
        }
        return factory()
    }
    
    // Singleton registration
    public func registerSingleton<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
    }
}

// Infrastructure/AppComposition.swift
public struct AppComposition {
    public static func configure(container: DependencyContainer) {
        // Register repositories
        container.register(LocumRepository.self) {
            FileLocumRepository(
                fileSystem: DefaultFileSystem(),
                storageURL: documentsDirectory.appendingPathComponent("locums")
            )
        }
        
        // Register services
        container.register(LocumService.self) {
            LocumService(repository: container.resolve(LocumRepository.self)!)
        }
        
        // Register storage managers
        container.registerSingleton(StorageManager.self) {
            DefaultStorageManager()
        }
    }
}
```

## 4. Platform-Specific UI vs Shared Core Functionality

### Shared UI Components

```swift
// LocumTrackerUI/Components/ShiftCard.swift
import SwiftUI

public struct ShiftCard: View {
    private let shift: Shift
    private let onTap: () -> Void
    
    public init(shift: Shift, onTap: @escaping () -> Void) {
        self.shift = shift
        self.onTap = onTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(shift.location.name)
                        .font(.headline)
                    Text(shift.specialty.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(formatCurrency(shift.hourlyRate))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(formatDate(shift.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label(formatDuration(shift.duration), systemImage: "clock")
                Spacer()
                Label(shift.status.rawValue, systemImage: statusIcon)
                    .foregroundColor(statusColor)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture(perform: onTap)
    }
    
    // Pure helper functions
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private var statusIcon: String {
        switch shift.status {
        case .available: return "checkmark.circle"
        case .taken: return "person.fill"
        case .completed: return "checkmark.shield"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch shift.status {
        case .available: return .green
        case .taken: return .blue
        case .completed: return .purple
        case .cancelled: return .red
        }
    }
}
```

### Platform-Specific Adaptations

```swift
// LocumTrackerUI/Platform/iOS/iOSComponents.swift
import SwiftUI

public struct iOSNavigationContainer<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        NavigationView {
            content
        }
        .navigationViewStyle(.stack)
    }
}

public struct iOSShiftList: View {
    private let shifts: [Shift]
    private let onShiftTap: (Shift) -> Void
    
    public init(shifts: [Shift], onShiftTap: @escaping (Shift) -> Void) {
        self.shifts = shifts
        self.onShiftTap = onShiftTap
    }
    
    public var body: some View {
        List(shifts) { shift in
            ShiftCard(shift: shift) {
                onShiftTap(shift)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

// LocumTrackerUI/Platform/macOS/macOSComponents.swift
import SwiftUI

public struct macOSNavigationContainer<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView()
        } detail: {
            content
        }
    }
}

public struct macOSShiftList: View {
    private let shifts: [Shift]
    private let onShiftTap: (Shift) -> Void
    
    public init(shifts: [Shift], onShiftTap: @escaping (Shift) -> Void) {
        self.shifts = shifts
        self.onShiftTap = onShiftTap
    }
    
    public var body: some View {
        Table(shifts) { shift in
            TableColumn("Location") {
                Text(shift.location.name)
            }
            TableColumn("Specialty") {
                Text(shift.specialty.rawValue)
            }
            TableColumn("Date") {
                Text(formatDate(shift.startTime))
            }
            TableColumn("Rate") {
                Text(formatCurrency(shift.hourlyRate))
            }
            TableColumn("Status") {
                Label(shift.status.rawValue, systemImage: statusIcon)
                    .foregroundColor(statusColor)
            }
        }
        .tableStyle(.bordered)
    }
}
```

## 5. Testing Shared Packages

### Unit Testing Pure Functions

```swift
// Tests/LocumTrackerCoreTests/ShiftServiceTests.swift
import XCTest
@testable import LocumTrackerCore

final class ShiftServiceTests: XCTestCase {
    
    func testCalculateTotalHours() {
        // Given
        let shifts = [
            Shift.test(duration: 3600), // 1 hour
            Shift.test(duration: 7200), // 2 hours
            Shift.test(duration: 1800)  // 30 minutes
        ]
        
        // When
        let totalHours = ShiftService.calculateTotalHours(for: shifts)
        
        // Then
        XCTAssertEqual(totalHours, 12600) // 3.5 hours in seconds
    }
    
    func testValidateShift_ValidShift() {
        // Given
        let validShift = Shift.test(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            hourlyRate: 50.0
        )
        
        // When
        let result = ShiftService.validateShift(validShift)
        
        // Then
        if case .valid = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected valid shift")
        }
    }
    
    func testValidateShift_InvalidTimes() {
        // Given
        let invalidShift = Shift.test(
            startTime: Date(),
            endTime: Date().addingTimeInterval(-3600), // End before start
            hourlyRate: 50.0
        )
        
        // When
        let result = ShiftService.validateShift(invalidShift)
        
        // Then
        if case .invalid(let errors) = result {
            XCTAssertTrue(errors.contains("Start time must be before end time"))
        } else {
            XCTFail("Expected invalid shift")
        }
    }
    
    func testCalculatePayment_WithOvertime() {
        // Given
        let overtimeShift = Shift.test(
            duration: 3600,
            hourlyRate: 50.0,
            isOvertime: true
        )
        
        // When
        let payment = ShiftService.calculatePayment(for: overtimeShift)
        
        // Then
        XCTAssertEqual(payment.baseAmount, 50.0)
        XCTAssertEqual(payment.bonus, 25.0) // 50% of base
        XCTAssertEqual(payment.total, 75.0)
    }
}

// Test helpers extension
extension Shift {
    static func test(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date = Date().addingTimeInterval(3600),
        location: Location = .test,
        specialty: Specialty = .general,
        duration: TimeInterval = 3600,
        hourlyRate: Decimal = 50.0,
        isOvertime: Bool = false,
        status: ShiftStatus = .available
    ) -> Shift {
        return Shift(
            id: id,
            startTime: startTime,
            endTime: endTime,
            location: location,
            specialty: specialty,
            duration: duration,
            hourlyRate: hourlyRate,
            isOvertime: isOvertime,
            status: status
        )
    }
}
```

### Integration Testing with Mock Dependencies

```swift
// Tests/LocumTrackerCoreTests/LocumServiceTests.swift
import XCTest
@testable import LocumTrackerCore

final class LocumServiceTests: XCTestCase {
    private var mockRepository: MockLocumRepository!
    private var locumService: LocumService!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockLocumRepository()
        locumService = LocumService(repository: mockRepository)
    }
    
    func testCreateLocumProfile_Success() {
        // Given
        let registrationData = LocumRegistrationData(
            firstName: "John",
            lastName: "Doe",
            email: "john.doe@example.com",
            skills: [.general, .pediatrics],
            hourlyRate: 75.0
        )
        
        // When
        let result = locumService.createProfile(from: registrationData)
        
        // Then
        switch result {
        case .success(let locum):
            XCTAssertEqual(locum.firstName, "John")
            XCTAssertEqual(locum.lastName, "Doe")
            XCTAssertEqual(locum.email, "john.doe@example.com")
            XCTAssertEqual(locum.skills, [.general, .pediatrics])
            XCTAssertEqual(locum.hourlyRate, 75.0)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testCreateLocumProfile_InvalidEmail() {
        // Given
        let invalidData = LocumRegistrationData(
            firstName: "John",
            lastName: "Doe",
            email: "invalid-email",
            skills: [.general],
            hourlyRate: 75.0
        )
        
        // When
        let result = locumService.createProfile(from: invalidData)
        
        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error, .invalidEmail)
        }
    }
}

// Mock repository for testing
class MockLocumRepository: LocumRepository {
    private var locums: [Locum] = []
    
    func save(_ locum: Locum) async throws {
        locums.append(locum)
    }
    
    func findById(_ id: UUID) async throws -> Locum? {
        return locums.first { $0.id == id }
    }
    
    func findAll() async throws -> [Locum] {
        return locums
    }
    
    func findByStatus(_ status: LocumStatus) async throws -> [Locum] {
        return locums.filter { $0.status == status }
    }
    
    func delete(_ id: UUID) async throws {
        locums.removeAll { $0.id == id }
    }
}
```

## 6. Data Models and Domain Entities

### Domain Models (Business Logic)

```swift
// Domain/Models/Locum.swift
public struct Locum: Identifiable, Codable, Equatable {
    public let id: UUID
    public let firstName: String
    public let lastName: String
    public let email: String
    public let skills: Set<Skill>
    public let hourlyRate: Decimal
    public let status: LocumStatus
    public let createdAt: Date
    
    public init(
        id: UUID,
        firstName: String,
        lastName: String,
        email: String,
        skills: Set<Skill>,
        hourlyRate: Decimal,
        status: LocumStatus,
        createdAt: Date
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.skills = skills
        self.hourlyRate = hourlyRate
        self.status = status
        self.createdAt = createdAt
    }
    
    // Computed properties for business logic
    public var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    public var isActive: Bool {
        return status == .active
    }
    
    public var canAcceptShifts: Bool {
        return isActive && !skills.isEmpty
    }
}

// Domain/Models/Shift.swift
public struct Shift: Identifiable, Codable, Equatable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let location: Location
    public let specialty: Specialty
    public let duration: TimeInterval
    public let hourlyRate: Decimal
    public let isOvertime: Bool
    public let status: ShiftStatus
    public let assignedLocumId: UUID?
    
    public init(
        id: UUID,
        startTime: Date,
        endTime: Date,
        location: Location,
        specialty: Specialty,
        duration: TimeInterval,
        hourlyRate: Decimal,
        isOvertime: Bool,
        status: ShiftStatus,
        assignedLocumId: UUID? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.specialty = specialty
        self.duration = duration
        self.hourlyRate = hourlyRate
        self.isOvertime = isOvertime
        self.status = status
        self.assignedLocumId = assignedLocumId
    }
    
    // Business logic
    public var isAvailable: Bool {
        return status == .available
    }
    
    public var isCompleted: Bool {
        return status == .completed
    }
    
    public var totalPayment: Decimal {
        let base = Decimal(duration) * hourlyRate / 3600
        let bonus = isOvertime ? base * 0.5 : 0
        return base + bonus
    }
}
```

### Data Transfer Objects (Storage Layer)

```swift
// Data/DTOs/LocumDTO.swift
internal struct LocumDTO: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let skills: [String]
    let hourlyRate: Double
    let status: String
    let createdAt: Double // Unix timestamp
    
    // Mapping to Domain model
    func toDomain() throws -> Locum {
        guard let uuid = UUID(uuidString: id) else {
            throw MappingError.invalidUUID
        }
        
        guard let locumStatus = LocumStatus(rawValue: status) else {
            throw MappingError.invalidStatus
        }
        
        let skillSet = Set(skills.compactMap { Skill(rawValue: $0) })
        
        return Locum(
            id: uuid,
            firstName: firstName,
            lastName: lastName,
            email: email,
            skills: skillSet,
            hourlyRate: Decimal(hourlyRate),
            status: locumStatus,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
    
    // Mapping from Domain model
    static func from(_ locum: Locum) -> LocumDTO {
        return LocumDTO(
            id: locum.id.uuidString,
            firstName: locum.firstName,
            lastName: locum.lastName,
            email: locum.email,
            skills: locum.skills.map { $0.rawValue },
            hourlyRate: locum.hourlyRate.doubleValue,
            status: locum.status.rawValue,
            createdAt: locum.createdAt.timeIntervalSince1970
        )
    }
}

// Mapping errors
enum MappingError: Error {
    case invalidUUID
    case invalidStatus
    case invalidSkill
}
```

## 7. File System and Storage Abstractions

### Storage Abstraction Layer

```swift
// Infrastructure/Storage/StorageManager.swift
public protocol StorageManager {
    func save<T: Codable>(_ object: T, to key: String) async throws
    func load<T: Codable>(_ type: T.Type, from key: String) async throws -> T?
    func delete(from key: String) async throws
    func exists(at key: String) async throws -> Bool
}

// Infrastructure/Storage/DefaultStorageManager.swift
public class DefaultStorageManager: StorageManager {
    private let fileSystem: FileSystem
    private let storageURL: URL
    
    public init(fileSystem: FileSystem = DefaultFileSystem()) {
        self.fileSystem = fileSystem
        self.storageURL = documentsDirectory
    }
    
    public func save<T: Codable>(_ object: T, to key: String) async throws {
        let data = try JSONEncoder().encode(object)
        let fileURL = storageURL.appendingPathComponent("\(key).json")
        try await fileSystem.write(data, to: fileURL)
    }
    
    public func load<T: Codable>(_ type: T.Type, from key: String) async throws -> T? {
        let fileURL = storageURL.appendingPathComponent("\(key).json")
        
        guard await fileSystem.exists(fileURL) else {
            return nil
        }
        
        let data = try await fileSystem.read(fileURL)
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func delete(from key: String) async throws {
        let fileURL = storageURL.appendingPathComponent("\(key).json")
        try await fileSystem.remove(fileURL)
    }
    
    public func exists(at key: String) async throws -> Bool {
        let fileURL = storageURL.appendingPathComponent("\(key).json")
        return await fileSystem.exists(fileURL)
    }
}
```

### Platform-Specific Storage Implementations

```swift
// Infrastructure/Storage/UserDefaultsStorage.swift
public class UserDefaultsStorage: StorageManager {
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func save<T: Codable>(_ object: T, to key: String) async throws {
        let data = try JSONEncoder().encode(object)
        userDefaults.set(data, forKey: key)
    }
    
    public func load<T: Codable>(_ type: T.Type, from key: String) async throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func delete(from key: String) async throws {
        userDefaults.removeObject(forKey: key)
    }
    
    public func exists(at key: String) async throws -> Bool {
        return userDefaults.object(forKey: key) != nil
    }
}

// Infrastructure/Storage/iCloudStorage.swift
public class iCloudStorage: StorageManager {
    private let ubiquityContainer: URL?
    
    public init() {
        self.ubiquityContainer = FileManager.default.url(forUbiquityContainerIdentifier: nil)
    }
    
    public func save<T: Codable>(_ object: T, to key: String) async throws {
        guard let container = ubiquityContainer else {
            throw StorageError.iCloudUnavailable
        }
        
        let data = try JSONEncoder().encode(object)
        let fileURL = container.appendingPathComponent("\(key).json")
        try data.write(to: fileURL)
    }
    
    // Implement other methods...
}

enum StorageError: Error {
    case iCloudUnavailable
    case fileNotFound
    case permissionDenied
}
```

## 8. Complete Project Structure for Locum Tracking App

### Root Project Structure

```
LocumTracker/
├── LocumTracker.xcodeproj
├── LocumTrackerCore/                 # Shared Swift Package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── LocumTrackerCore/         # Domain + Data
│   │   └── LocumTrackerUI/           # Shared UI
│   └── Tests/
├── LocumTrackeriOS/                  # iOS App Target
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   └── ContentView.swift
│   ├── Features/
│   │   ├── Shifts/
│   │   ├── Profile/
│   │   └── Settings/
│   └── Platform/
│       └── iOS/
├── LocumTrackermacOS/                # macOS App Target
│   ├── App/
│   │   ├── AppDelegate.swift
│   │   └── ContentView.swift
│   ├── Features/
│   │   ├── Shifts/
│   │   ├── Profile/
│   │   └── Settings/
│   └── Platform/
│       └── macOS/
└── Shared/
    ├── Resources/
    │   ├── Localizable.strings
    │   └── Assets.xcassets
    └── Configuration/
        ├── AppConfig.swift
        └── BuildSettings.swift
```

### App Composition Examples

```swift
// iOS App/AppDelegate.swift
import UIKit
import LocumTrackerCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    private var dependencyContainer: DependencyContainer!
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Configure dependencies
        dependencyContainer = DependencyContainer()
        AppComposition.configure(container: dependencyContainer)
        
        // Setup window
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootViewController = ShiftListViewController(
            dependencyContainer: dependencyContainer
        )
        let navigationController = UINavigationController(rootViewController: rootViewController)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        return true
    }
}

// macOS App/AppDelegate.swift
import AppKit
import LocumTrackerCore

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    private var dependencyContainer: DependencyContainer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure dependencies
        dependencyContainer = DependencyContainer()
        AppComposition.configure(container: dependencyContainer)
        
        // Setup window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: ShiftListView(
            dependencyContainer: dependencyContainer
        ))
        window.makeKeyAndOrderFront(nil)
    }
}
```

## 9. Best Practices Summary

### Architecture Principles

1. **Separation of Concerns**: Keep business logic, data access, and UI in separate layers
2. **Dependency Inversion**: Depend on abstractions, not concrete implementations
3. **Single Responsibility**: Each class/module should have one reason to change
4. **Pure Functions**: Keep business logic pure and side-effect free

### Code Organization

1. **Feature-Based Structure**: Organize by features, not by platforms
2. **Shared Domain**: Keep domain models completely platform-agnostic
3. **Platform-Specific UI**: Isolate platform differences in dedicated modules
4. **Clear Boundaries**: Use protocols to define clear boundaries between layers

### Testing Strategy

1. **Test Pure Functions**: Unit test business logic extensively
2. **Mock Dependencies**: Use mocks for integration testing
3. **Platform Tests**: Test platform-specific code separately
4. **End-to-End Tests**: Test complete workflows on each platform

### Performance Considerations

1. **Lazy Loading**: Load data only when needed
2. **Efficient Serialization**: Use efficient formats for data persistence
3. **Memory Management**: Be mindful of memory usage in shared code
4. **Background Processing**: Use async/await for long-running operations

### Maintenance Tips

1. **Version Compatibility**: Use platform availability attributes carefully
2. **Documentation**: Document shared APIs thoroughly
3. **Continuous Integration**: Test on all platforms in CI/CD
4. **Regular Refactoring**: Keep the codebase clean and maintainable

This comprehensive guide provides a solid foundation for creating maintainable, testable, and scalable shared Swift packages for iOS and macOS applications, with concrete examples tailored for a locum tracking app.