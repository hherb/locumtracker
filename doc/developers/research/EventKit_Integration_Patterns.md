# EventKit Integration Patterns for Swift Apps

## Overview

This guide covers comprehensive EventKit integration patterns for Swift applications, specifically tailored for a locum tracking app that needs to manage calendar events, detect conflicts, and provide seamless user experience across iOS and macOS platforms.

## Table of Contents

1. [EventKit Permission Workflows](#eventkit-permission-workflows)
2. [Calendar Event Reading and Conflict Detection](#calendar-event-reading-and-conflict-detection)
3. [Creating Calendar Events from App Data](#creating-calendar-events-from-app-data)
4. [Cross-Platform EventKit Differences](#cross-platform-eventkit-differences)
5. [Best Practices for Calendar Integration](#best-practices-for-calendar-integration)
6. [Privacy and User Experience Considerations](#privacy-and-user-experience-considerations)
7. [Complete Locum Tracking App Example](#complete-locum-tracking-app-example)

---

## EventKit Permission Workflows

### iOS 17+ Permission Model

Starting with iOS 17, EventKit introduced granular permission levels:

```swift
import EventKit

class CalendarPermissionManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    // Request full access for reading and writing events
    func requestFullAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                authorizationStatus = eventStore.authorizationStatus(for: .event)
                return granted
            } else {
                // Fallback for older versions
                let granted = try await eventStore.requestAccess(to: .event)
                authorizationStatus = eventStore.authorizationStatus(for: .event)
                return granted
            }
        } catch {
            print("Error requesting calendar access: \(error)")
            authorizationStatus = .denied
            return false
        }
    }
    
    // Request write-only access (iOS 17+)
    func requestWriteOnlyAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestWriteOnlyAccessToEvents()
                authorizationStatus = .writeOnly
                return granted
            } else {
                // Write-only not available pre-iOS 17, fallback to full access
                return await requestFullAccess()
            }
        } catch {
            print("Error requesting write-only access: \(error)")
            return false
        }
    }
    
    func checkCurrentStatus() -> EKAuthorizationStatus {
        return eventStore.authorizationStatus(for: .event)
    }
}
```

### Permission Status Handling

```swift
extension CalendarPermissionManager {
    enum PermissionState {
        case notDetermined
        case fullAccess
        case writeOnly
        case denied
        case restricted
    }
    
    var currentPermissionState: PermissionState {
        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }
    
    func getPermissionMessage() -> String {
        switch currentPermissionState {
        case .notDetermined:
            return "Calendar access is needed to check for scheduling conflicts and add work assignments."
        case .fullAccess:
            return "Full calendar access granted. You can read events and create new assignments."
        case .writeOnly:
            return "Write-only access granted. You can create new assignments but cannot read existing events."
        case .denied:
            return "Calendar access denied. Please enable access in Settings to use calendar features."
        case .restricted:
            return "Calendar access is restricted by parental controls or device management."
        }
    }
}
```

---

## Calendar Event Reading and Conflict Detection

### Conflict Detection Service

```swift
import EventKit
import Foundation

struct WorkAssignment {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
}

struct CalendarConflict {
    let existingEvent: EKEvent
    let newAssignment: WorkAssignment
    let conflictType: ConflictType
    
    enum ConflictType {
        case fullOverlap      // Events completely overlap
        case partialOverlap   // Events partially overlap
        case adjacent         // Events are back-to-back
    }
}

class ConflictDetectionService {
    private let eventStore: EKEventStore
    
    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    // Check for conflicts with existing calendar events
    func detectConflicts(for assignment: WorkAssignment, in calendars: [EKCalendar]? = nil) async -> [CalendarConflict] {
        let predicate = eventStore.predicateForEvents(
            withStart: assignment.startDate,
            end: assignment.endDate,
            calendars: calendars
        )
        
        let existingEvents = eventStore.events(matching: predicate)
        var conflicts: [CalendarConflict] = []
        
        for event in existingEvents {
            if let conflictType = analyzeConflict(between: assignment, and: event) {
                let conflict = CalendarConflict(
                    existingEvent: event,
                    newAssignment: assignment,
                    conflictType: conflictType
                )
                conflicts.append(conflict)
            }
        }
        
        return conflicts.sorted { $0.existingEvent.startDate < $1.existingEvent.startDate }
    }
    
    // Analyze the type of conflict between assignment and event
    private func analyzeConflict(between assignment: WorkAssignment, and event: EKEvent) -> CalendarConflict.ConflictType? {
        let assignmentStart = assignment.startDate
        let assignmentEnd = assignment.endDate
        let eventStart = event.startDate
        let eventEnd = event.endDate
        
        // Check for full overlap
        if assignmentStart <= eventStart && assignmentEnd >= eventEnd {
            return .fullOverlap
        }
        
        // Check for partial overlap
        if (assignmentStart < eventEnd && assignmentEnd > eventStart) {
            return .partialOverlap
        }
        
        // Check for adjacent events (within 15 minutes)
        let adjacencyThreshold: TimeInterval = 15 * 60 // 15 minutes
        if abs(assignmentEnd.timeIntervalSince(eventStart)) <= adjacencyThreshold ||
           abs(assignmentStart.timeIntervalSince(eventEnd)) <= adjacencyThreshold {
            return .adjacent
        }
        
        return nil
    }
    
    // Get all events in a date range for comprehensive analysis
    func getEventsInRange(from startDate: Date, to endDate: Date, in calendars: [EKCalendar]? = nil) async -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        return eventStore.events(matching: predicate)
    }
    
    // Check availability for a specific time window
    func isTimeSlotAvailable(from startDate: Date, to endDate: Date, excludingEventId: String? = nil) async -> Bool {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        // Filter out the event we're excluding (for updates)
        let relevantEvents = events.filter { event in
            if let excludeId = excludingEventId {
                return event.eventIdentifier != excludeId
            }
            return true
        }
        
        return relevantEvents.isEmpty
    }
}
```

### Advanced Conflict Analysis

```swift
extension ConflictDetectionService {
    // Analyze multiple assignments for batch conflicts
    func detectBatchConflicts(for assignments: [WorkAssignment]) async -> [BatchConflictResult] {
        var results: [BatchConflictResult] = []
        
        for assignment in assignments {
            let conflicts = await detectConflicts(for: assignment)
            let result = BatchConflictResult(
                assignment: assignment,
                conflicts: conflicts,
                hasConflicts: !conflicts.isEmpty
            )
            results.append(result)
        }
        
        return results
    }
    
    struct BatchConflictResult {
        let assignment: WorkAssignment
        let conflicts: [CalendarConflict]
        let hasConflicts: Bool
    }
    
    // Find optimal time slots for assignments
    func findAvailableTimeSlots(
        duration: TimeInterval,
        in dateRange: ClosedRange<Date>,
        workingHours: ClosedRange<Date> = DailyWorkingHours.default
    ) async -> [TimeSlot] {
        var availableSlots: [TimeSlot] = []
        var currentDate = dateRange.lowerBound
        
        while currentDate < dateRange.upperBound {
            let dayStart = Calendar.current.startOfDay(for: currentDate)
            let dayWorkingStart = Calendar.current.date(byAdding: .second, value: Int(workingHours.lowerBound.timeIntervalSince(dayStart)), to: dayStart)!
            let dayWorkingEnd = Calendar.current.date(byAdding: .second, value: Int(workingHours.upperBound.timeIntervalSince(dayStart)), to: dayStart)!
            
            var slotStart = max(currentDate, dayWorkingStart)
            
            while slotStart + duration <= dayWorkingEnd {
                let slotEnd = slotStart + duration
                
                if await isTimeSlotAvailable(from: slotStart, to: slotEnd) {
                    availableSlots.append(TimeSlot(start: slotStart, end: slotEnd))
                    slotStart = slotEnd
                } else {
                    slotStart = slotStart + 3600 // Move forward 1 hour
                }
            }
            
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return availableSlots
    }
    
    struct TimeSlot {
        let start: Date
        let end: Date
    }
    
    struct DailyWorkingHours {
        static let `default` = ClosedRange(uncheckedBounds: (
            lower: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!,
            upper: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
        ))
    }
}
```

---

## Creating Calendar Events from App Data

### Event Creation Service

```swift
import EventKit
import UserNotifications

class CalendarEventService {
    private let eventStore: EKEventStore
    private let notificationCenter = UNUserNotificationCenter.current()
    
    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    // Create a calendar event from work assignment
    func createEvent(from assignment: WorkAssignment, in calendar: EKCalendar? = nil) async throws -> EKEvent {
        let targetCalendar = calendar ?? eventStore.defaultCalendarForNewEvents
        
        let event = EKEvent(eventStore: eventStore)
        event.title = assignment.title
        event.startDate = assignment.startDate
        event.endDate = assignment.endDate
        event.calendar = targetCalendar
        
        // Set location if available
        if let location = assignment.location {
            event.location = location
        }
        
        // Set notes with assignment details
        var notes = "Work Assignment created by LocumTracker\n"
        notes += "Assignment ID: \(assignment.id.uuidString)\n"
        
        if let assignmentNotes = assignment.notes {
            notes += "\n\(assignmentNotes)"
        }
        
        event.notes = notes
        
        // Add alarms for the assignment
        addAlarms(to: event, for: assignment)
        
        // Save the event
        try eventStore.save(event, span: .thisEvent)
        
        // Schedule notification for the event
        await scheduleNotification(for: event, assignment: assignment)
        
        return event
    }
    
    // Add appropriate alarms to the event
    private func addAlarms(to event: EKEvent, for assignment: WorkAssignment) {
        // 1 hour before reminder
        let oneHourBefore = EKAlarm(relativeOffset: -3600)
        event.addAlarm(oneHourBefore)
        
        // 24 hours before reminder
        let oneDayBefore = EKAlarm(relativeOffset: -86400)
        event.addAlarm(oneDayBefore)
        
        // At the start time
        let atStart = EKAlarm(relativeOffset: 0)
        event.addAlarm(atStart)
    }
    
    // Update an existing event
    func updateEvent(_ event: EKEvent, with assignment: WorkAssignment) async throws {
        event.title = assignment.title
        event.startDate = assignment.startDate
        event.endDate = assignment.endDate
        
        if let location = assignment.location {
            event.location = location
        }
        
        var notes = event.notes ?? ""
        if !notes.contains("Assignment ID: \(assignment.id.uuidString)") {
            notes += "\nWork Assignment created by LocumTracker\n"
            notes += "Assignment ID: \(assignment.id.uuidString)\n"
        }
        
        if let assignmentNotes = assignment.notes {
            notes += "\n\(assignmentNotes)"
        }
        
        event.notes = notes
        
        try eventStore.save(event, span: .thisEvent)
        await scheduleNotification(for: event, assignment: assignment)
    }
    
    // Delete an event
    func deleteEvent(_ event: EKEvent) async throws {
        try eventStore.remove(event, span: .thisEvent)
        
        // Cancel associated notification
        await notificationCenter.removePendingNotificationRequests(withIdentifiers: [event.eventIdentifier])
    }
    
    // Schedule local notification for the event
    private func scheduleNotification(for event: EKEvent, assignment: WorkAssignment) async {
        let content = UNMutableNotificationContent()
        content.title = "Work Assignment: \(assignment.title)"
        content.body = "Starting at \(event.startDate.formatted(date: .abbreviated, time: .shortened))"
        content.sound = .default
        content.userInfo = ["assignmentId": assignment.id.uuidString]
        
        // Schedule notification 1 hour before the event
        let fireDate = event.startDate.addingTimeInterval(-3600)
        let calendar = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar, repeats: false)
        let request = UNNotificationRequest(identifier: event.eventIdentifier, content: content, trigger: trigger)
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
}
```

### Batch Event Operations

```swift
extension CalendarEventService {
    // Create multiple events in a batch
    func createBatchEvents(from assignments: [WorkAssignment]) async -> [BatchEventResult] {
        var results: [BatchEventResult] = []
        
        for assignment in assignments {
            do {
                let event = try await createEvent(from: assignment)
                let result = BatchEventResult(
                    assignment: assignment,
                    event: event,
                    success: true,
                    error: nil
                )
                results.append(result)
            } catch {
                let result = BatchEventResult(
                    assignment: assignment,
                    event: nil,
                    success: false,
                    error: error
                )
                results.append(result)
            }
        }
        
        return results
    }
    
    struct BatchEventResult {
        let assignment: WorkAssignment
        let event: EKEvent?
        let success: Bool
        let error: Error?
    }
    
    // Sync assignments with calendar events
    func syncAssignments(_ assignments: [WorkAssignment]) async -> SyncResult {
        var created = 0
        var updated = 0
        var deleted = 0
        var errors: [Error] = []
        
        // Get all existing events with our app's identifier
        let existingEvents = await getEventsForAssignments(assignments)
        
        for assignment in assignments {
            do {
                if let existingEvent = existingEvents[assignment.id] {
                    // Update existing event
                    try await updateEvent(existingEvent, with: assignment)
                    updated += 1
                } else {
                    // Create new event
                    _ = try await createEvent(from: assignment)
                    created += 1
                }
            } catch {
                errors.append(error)
            }
        }
        
        return SyncResult(created: created, updated: updated, deleted: deleted, errors: errors)
    }
    
    private func getEventsForAssignments(_ assignments: [WorkAssignment]) async -> [UUID: EKEvent] {
        var eventsByAssignmentId: [UUID: EKEvent] = [:]
        
        // Get events in a reasonable date range
        let dateRange = assignments.reduce(into: DateRange()) { range, assignment in
            range.update(with: assignment.startDate)
            range.update(with: assignment.endDate)
        }
        
        let events = await ConflictDetectionService(eventStore: eventStore)
            .getEventsInRange(from: dateRange.startDate, to: dateRange.endDate)
        
        for event in events {
            if let notes = event.notes,
               let assignmentId = extractAssignmentId(from: notes) {
                eventsByAssignmentId[assignmentId] = event
            }
        }
        
        return eventsByAssignmentId
    }
    
    private func extractAssignmentId(from notes: String) -> UUID? {
        let pattern = "Assignment ID: ([0-9a-fA-F-]{36})"
        if let range = notes.range(of: pattern, options: .regularExpression) {
            let idString = String(notes[range].dropFirst("Assignment ID: ".count))
            return UUID(uuidString: idString)
        }
        return nil
    }
    
    struct SyncResult {
        let created: Int
        let updated: Int
        let deleted: Int
        let errors: [Error]
        
        var hasErrors: Bool { !errors.isEmpty }
    }
    
    private struct DateRange {
        var startDate: Date = Date.distantFuture
        var endDate: Date = Date.distantPast
        
        mutating func update(with date: Date) {
            startDate = min(startDate, date)
            endDate = max(endDate, date)
        }
    }
}
```

---

## Cross-Platform EventKit Differences

### Platform-Specific Implementation

```swift
import Foundation
import EventKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class PlatformCalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var platform: Platform = .current
    
    enum Platform {
        case iOS
        case macOS
        case watchOS
        
        static var current: Platform {
            #if os(iOS)
            return .iOS
            #elseif os(macOS)
            return .macOS
            #elseif os(watchOS)
            return .watchOS
            #else
            return .iOS
            #endif
        }
    }
    
    // Platform-specific permission request
    func requestCalendarAccess() async -> Bool {
        switch platform {
        case .iOS:
            return await requestIOSAccess()
        case .macOS:
            return await requestMacOSAccess()
        case .watchOS:
            return await requestWatchOSAccess()
        }
    }
    
    @MainActor
    private func requestIOSAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("iOS calendar access error: \(error)")
            return false
        }
    }
    
    @MainActor
    private func requestMacOSAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("macOS calendar access error: \(error)")
            return false
        }
    }
    
    @MainActor
    private func requestWatchOSAccess() async -> Bool {
        // watchOS has limited EventKit support
        // Typically relies on iPhone for calendar operations
        return false
    }
    
    // Platform-specific calendar selection
    func getAvailableCalendars() -> [EKCalendar] {
        switch platform {
        case .iOS:
            return eventStore.calendars(for: .event)
        case .macOS:
            return eventStore.calendars(for: .event)
        case .watchOS:
            return []
        }
    }
    
    // Platform-specific UI presentation
    func presentEventEditViewController(for event: EKEvent) {
        switch platform {
        case .iOS:
            presentIOSEventEdit(event)
        case .macOS:
            presentMacOSEventEdit(event)
        case .watchOS:
            break
        }
    }
    
    private func presentIOSEventEdit(_ event: EKEvent) {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let editController = EKEventEditViewController()
        editController.event = event
        editController.eventStore = eventStore
        editController.editViewDelegate = rootViewController as? EKEventEditViewDelegate
        
        rootViewController.present(editController, animated: true)
        #endif
    }
    
    private func presentMacOSEventEdit(_ event: EKEvent) {
        #if os(macOS)
        let editController = EKEventEditViewController()
        editController.event = event
        editController.eventStore = eventStore
        
        if let window = NSApp.keyWindow,
           let viewController = window.contentViewController {
            viewController.presentAsSheet(editController)
        }
        #endif
    }
}
```

### Platform Differences Summary

| Feature | iOS | macOS | watchOS |
|---------|-----|-------|---------|
| **Permission Model** | Full/Write-only access (iOS 17+) | Full/Write-only access (macOS 14+) | Limited |
| **UI Components** | EKEventEditViewController | EKEventEditViewController | Not available |
| **Calendar Sources** | iCloud, Local, Exchange | iCloud, Local, Exchange, CalDAV | Limited |
| **Notification Integration** | Full support | Full support | Limited |
| **Background Sync** | Supported | Supported | Limited |
| **Siri Integration** | Full support | Limited | Limited |

---

## Best Practices for Calendar Integration

### 1. Permission Management

```swift
class BestPracticesCalendarService {
    private let eventStore = EKEventStore()
    
    // Check permissions before operations
    func ensureCalendarAccess() async throws -> Bool {
        let status = eventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized, .fullAccess:
            return true
        case .writeOnly:
            // Determine if write-only is sufficient
            return canProceedWithWriteOnly()
        case .notDetermined:
            return await requestPermission()
        case .denied, .restricted:
            throw CalendarError.accessDenied
        @unknown default:
            throw CalendarError.unknownStatus
        }
    }
    
    private func canProceedWithWriteOnly() -> Bool {
        // Implement logic to determine if write-only access is sufficient
        // For conflict detection, we need read access
        return false
    }
    
    private func requestPermission() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("Permission request failed: \(error)")
            return false
        }
    }
    
    enum CalendarError: Error {
        case accessDenied
        case unknownStatus
        case eventCreationFailed
        case conflictDetected
    }
}
```

### 2. Error Handling and Recovery

```swift
extension BestPracticesCalendarService {
    // Robust error handling for calendar operations
    func createEventWithErrorHandling(from assignment: WorkAssignment) async -> Result<EKEvent, CalendarError> {
        do {
            // Ensure we have access
            guard await ensureCalendarAccess() else {
                return .failure(.accessDenied)
            }
            
            // Check for conflicts
            let conflictService = ConflictDetectionService(eventStore: eventStore)
            let conflicts = await conflictService.detectConflicts(for: assignment)
            
            if !conflicts.isEmpty {
                return .failure(.conflictDetected)
            }
            
            // Create the event
            let eventService = CalendarEventService(eventStore: eventStore)
            let event = try await eventService.createEvent(from: assignment)
            
            return .success(event)
            
        } catch {
            print("Calendar operation failed: \(error)")
            return .failure(.eventCreationFailed)
        }
    }
    
    // Retry mechanism for failed operations
    func createEventWithRetry(from assignment: WorkAssignment, maxRetries: Int = 3) async -> Result<EKEvent, CalendarError> {
        var lastError: CalendarError?
        
        for attempt in 1...maxRetries {
            let result = await createEventWithErrorHandling(from: assignment)
            
            switch result {
            case .success(let event):
                return .success(event)
            case .failure(let error):
                lastError = error
                
                // Don't retry certain errors
                if error == .accessDenied || error == .conflictDetected {
                    return .failure(error)
                }
                
                // Exponential backoff
                let delay = pow(2.0, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        return .failure(lastError ?? .eventCreationFailed)
    }
}
```

### 3. Performance Optimization

```swift
class OptimizedCalendarService {
    private let eventStore = EKEventStore()
    private var eventCache: [String: EKEvent] = [:]
    private var lastCacheUpdate: Date = .distantPast
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Efficient event fetching with caching
    func getEventsWithCaching(from startDate: Date, to endDate: Date) async -> [EKEvent] {
        let cacheKey = "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
        
        // Check cache validity
        if Date().timeIntervalSince(lastCacheUpdate) < cacheTimeout,
           let cachedEvents = eventCache[cacheKey] {
            return [cachedEvents]
        }
        
        // Fetch fresh data
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        // Update cache
        eventCache[cacheKey] = events.first ?? EKEvent(eventStore: eventStore)
        lastCacheUpdate = Date()
        
        return events
    }
    
    // Batch operations for better performance
    func performBatchOperation(_ operations: [CalendarOperation]) async -> [CalendarOperationResult] {
        var results: [CalendarOperationResult] = []
        
        // Group operations by type for efficiency
        let createOperations = operations.filter { $0.type == .create }
        let updateOperations = operations.filter { $0.type == .update }
        let deleteOperations = operations.filter { $0.type == .delete }
        
        // Process each batch
        results.append(contentsOf: await processBatch(createOperations, type: .create))
        results.append(contentsOf: await processBatch(updateOperations, type: .update))
        results.append(contentsOf: await processBatch(deleteOperations, type: .delete))
        
        return results
    }
    
    private func processBatch(_ operations: [CalendarOperation], type: CalendarOperationType) async -> [CalendarOperationResult] {
        // Implement batch processing logic
        return operations.map { operation in
            CalendarOperationResult(
                operation: operation,
                success: true,
                error: nil
            )
        }
    }
    
    enum CalendarOperationType {
        case create
        case update
        case delete
    }
    
    struct CalendarOperation {
        let id: UUID
        let type: CalendarOperationType
        let data: WorkAssignment
    }
    
    struct CalendarOperationResult {
        let operation: CalendarOperation
        let success: Bool
        let error: Error?
    }
}
```

---

## Privacy and User Experience Considerations

### 1. Privacy-First Design

```swift
class PrivacyAwareCalendarService {
    private let eventStore = EKEventStore()
    
    // Minimal data collection
    func createPrivacyFocusedEvent(from assignment: WorkAssignment) async throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        
        // Only collect necessary information
        event.title = assignment.title
        event.startDate = assignment.startDate
        event.endDate = assignment.endDate
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Sanitize location data
        if let location = assignment.location {
            event.location = sanitizeLocation(location)
        }
        
        // Minimal notes without sensitive information
        event.notes = "Created by LocumTracker"
        
        return event
    }
    
    private func sanitizeLocation(_ location: String) -> String {
        // Remove potentially sensitive information
        let sensitivePatterns = [
            #"\\b\d{3}-\d{3}-\d{4}\b"#, // Phone numbers
            #"\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, // Email addresses
            #"\\b\d{1,5}\s+\w+\s+(Street|St|Avenue|Ave|Road|Rd)\b"# // Street addresses
        ]
        
        var sanitized = location
        for pattern in sensitivePatterns {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "[REDACTED]", options: .regularExpression)
        }
        
        return sanitized
    }
    
    // Data minimization for conflict detection
    func detectConflictsWithPrivacy(from assignment: WorkAssignment) async -> [ConflictSummary] {
        let predicate = eventStore.predicateForEvents(
            withStart: assignment.startDate,
            end: assignment.endDate,
            calendars: nil
        )
        
        let events = eventStore.events(matching: predicate)
        
        return events.map { event in
            ConflictSummary(
                title: event.title,
                startTime: event.startDate,
                endTime: event.endDate,
                isAllDay: event.isAllDay
                // Deliberately exclude sensitive details like location, notes
            )
        }
    }
    
    struct ConflictSummary {
        let title: String
        let startTime: Date
        let endTime: Date
        let isAllDay: Bool
    }
}
```

### 2. User Experience Optimization

```swift
class UserExperienceCalendarService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Progressive permission requests
    func requestProgressiveAccess() async {
        // Start with write-only access
        if #available(iOS 17.0, *) {
            do {
                let writeOnlyGranted = try await eventStore.requestWriteOnlyAccessToEvents()
                
                if writeOnlyGranted {
                    successMessage = "Calendar access granted for creating events."
                    
                    // Later, request full access if needed for conflict detection
                    await requestFullAccessIfNeeded()
                } else {
                    errorMessage = "Calendar access is needed to create work assignments."
                }
            } catch {
                errorMessage = "Failed to request calendar access."
            }
        }
    }
    
    private func requestFullAccessIfNeeded() async {
        // Check if user tries to use conflict detection
        // Then request full access with clear explanation
        if #available(iOS 17.0, *) {
            do {
                let fullAccessGranted = try await eventStore.requestFullAccessToEvents()
                if fullAccessGranted {
                    successMessage = "Full calendar access granted. Conflict detection is now available."
                }
            } catch {
                errorMessage = "Full access is needed for conflict detection."
            }
        }
    }
    
    // Clear error messages after delay
    func clearMessages(after delay: TimeInterval = 5.0) {
        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            await MainActor.run {
                errorMessage = nil
                successMessage = nil
            }
        }
    }
    
    // Provide context for permission requests
    func getPermissionContextMessage(for feature: CalendarFeature) -> String {
        switch feature {
        case .createAssignment:
            return "LocumTracker needs calendar access to add your work assignments to your calendar."
        case .conflictDetection:
            return "To check for scheduling conflicts, LocumTracker needs to read your existing calendar events."
        case .syncWithCalendar:
            return "Full calendar access allows LocumTracker to sync assignments and detect conflicts automatically."
        }
    }
    
    enum CalendarFeature {
        case createAssignment
        case conflictDetection
        case syncWithCalendar
    }
}
```

---

## Complete Locum Tracking App Example

### Main Calendar Manager

```swift
import EventKit
import Foundation
import Combine
import UserNotifications

@MainActor
class LocumCalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    private let conflictService: ConflictDetectionService
    private let eventService: CalendarEventService
    private let permissionManager: CalendarPermissionManager
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var currentConflicts: [CalendarConflict] = []
    
    init() {
        self.conflictService = ConflictDetectionService(eventStore: eventStore)
        self.eventService = CalendarEventService(eventStore: eventStore)
        self.permissionManager = CalendarPermissionManager()
        
        setupNotifications()
    }
    
    // MARK: - Permission Management
    
    func requestCalendarAccess() async {
        isLoading = true
        errorMessage = nil
        
        let granted = await permissionManager.requestFullAccess()
        authorizationStatus = permissionManager.checkCurrentStatus()
        
        if granted {
            successMessage = "Calendar access granted. You can now create work assignments and detect conflicts."
        } else {
            errorMessage = "Calendar access is required for full functionality."
        }
        
        isLoading = false
        clearMessagesAfterDelay()
    }
    
    // MARK: - Assignment Management
    
    func createWorkAssignment(_ assignment: WorkAssignment) async -> Result<EKEvent, CalendarError> {
        isLoading = true
        errorMessage = nil
        currentConflicts = []
        
        // Check permissions
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else {
            errorMessage = "Calendar access is required to create assignments."
            isLoading = false
            return .failure(.accessDenied)
        }
        
        // Check for conflicts
        let conflicts = await conflictService.detectConflicts(for: assignment)
        
        if !conflicts.isEmpty {
            currentConflicts = conflicts
            errorMessage = "Scheduling conflicts detected. Please review before proceeding."
            isLoading = false
            return .failure(.conflictDetected)
        }
        
        // Create the event
        do {
            let event = try await eventService.createEvent(from: assignment)
            successMessage = "Work assignment added to calendar successfully."
            isLoading = false
            clearMessagesAfterDelay()
            return .success(event)
        } catch {
            errorMessage = "Failed to create calendar event: \(error.localizedDescription)"
            isLoading = false
            return .failure(.eventCreationFailed)
        }
    }
    
    func createAssignmentIgnoringConflicts(_ assignment: WorkAssignment) async -> Result<EKEvent, CalendarError> {
        isLoading = true
        errorMessage = nil
        
        do {
            let event = try await eventService.createEvent(from: assignment)
            successMessage = "Work assignment added to calendar (conflicts ignored)."
            currentConflicts = []
            isLoading = false
            clearMessagesAfterDelay()
            return .success(event)
        } catch {
            errorMessage = "Failed to create calendar event: \(error.localizedDescription)"
            isLoading = false
            return .failure(.eventCreationFailed)
        }
    }
    
    // MARK: - Conflict Detection
    
    func checkConflicts(for assignment: WorkAssignment) async {
        isLoading = true
        currentConflicts = await conflictService.detectConflicts(for: assignment)
        isLoading = false
        
        if currentConflicts.isEmpty {
            successMessage = "No scheduling conflicts detected."
        } else {
            errorMessage = "\(currentConflicts.count) scheduling conflict(s) detected."
        }
        
        clearMessagesAfterDelay()
    }
    
    func findAvailableSlots(for duration: TimeInterval, in dateRange: ClosedRange<Date>) async -> [ConflictDetectionService.TimeSlot] {
        isLoading = true
        let slots = await conflictService.findAvailableTimeSlots(duration: duration, in: dateRange)
        isLoading = false
        
        if slots.isEmpty {
            errorMessage = "No available time slots found in the selected range."
        } else {
            successMessage = "\(slots.count) available time slot(s) found."
        }
        
        clearMessagesAfterDelay()
        return slots
    }
    
    // MARK: - Event Management
    
    func updateAssignment(_ assignment: WorkAssignment, in event: EKEvent) async -> Result<EKEvent, CalendarError> {
        isLoading = true
        errorMessage = nil
        
        do {
            try await eventService.updateEvent(event, with: assignment)
            successMessage = "Work assignment updated successfully."
            isLoading = false
            clearMessagesAfterDelay()
            return .success(event)
        } catch {
            errorMessage = "Failed to update assignment: \(error.localizedDescription)"
            isLoading = false
            return .failure(.eventCreationFailed)
        }
    }
    
    func deleteAssignment(_ event: EKEvent) async -> Result<Void, CalendarError> {
        isLoading = true
        errorMessage = nil
        
        do {
            try await eventService.deleteEvent(event)
            successMessage = "Work assignment deleted successfully."
            isLoading = false
            clearMessagesAfterDelay()
            return .success(())
        } catch {
            errorMessage = "Failed to delete assignment: \(error.localizedDescription)"
            isLoading = false
            return .failure(.eventCreationFailed)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupNotifications() {
        Task {
            do {
                try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("Failed to request notification authorization: \(error)")
            }
        }
    }
    
    private func clearMessagesAfterDelay() {
        Task {
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await MainActor.run {
                errorMessage = nil
                successMessage = nil
            }
        }
    }
    
    enum CalendarError: Error {
        case accessDenied
        case eventCreationFailed
        case conflictDetected
    }
}
```

### SwiftUI View Integration

```swift
import SwiftUI
import EventKit

struct LocumCalendarView: View {
    @StateObject private var calendarManager = LocumCalendarManager()
    @State private var showingAssignmentForm = false
    @State private var showingConflictDetails = false
    @State private var selectedAssignment: WorkAssignment?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Permission Status
                permissionStatusView
                
                // Quick Actions
                quickActionsView
                
                // Conflicts Section
                if !calendarManager.currentConflicts.isEmpty {
                    conflictsView
                }
                
                // Recent Assignments
                recentAssignmentsView
                
                Spacer()
            }
            .padding()
            .navigationTitle("Locum Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Assignment") {
                        selectedAssignment = nil
                        showingAssignmentForm = true
                    }
                    .disabled(calendarManager.authorizationStatus != .fullAccess && 
                             calendarManager.authorizationStatus != .authorized)
                }
            }
            .sheet(isPresented: $showingAssignmentForm) {
                AssignmentFormView(
                    assignment: selectedAssignment,
                    calendarManager: calendarManager
                )
            }
            .alert("Error", isPresented: .constant(calendarManager.errorMessage != nil)) {
                Button("OK") {
                    calendarManager.errorMessage = nil
                }
            } message: {
                if let errorMessage = calendarManager.errorMessage {
                    Text(errorMessage)
                }
            }
            .overlay {
                if calendarManager.isLoading {
                    ProgressView("Processing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }
    
    private var permissionStatusView: some View {
        VStack(spacing: 10) {
            Image(systemName: permissionIcon)
                .font(.largeTitle)
                .foregroundColor(permissionColor)
            
            Text(permissionText)
                .font(.headline)
            
            if calendarManager.authorizationStatus == .notDetermined {
                Button("Request Calendar Access") {
                    Task {
                        await calendarManager.requestCalendarAccess()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var quickActionsView: some View {
        VStack(spacing: 15) {
            Button("Check for Conflicts") {
                // Implement conflict checking for a sample assignment
            }
            .buttonStyle(.bordered)
            
            Button("Find Available Slots") {
                // Implement slot finding
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var conflictsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scheduling Conflicts")
                .font(.headline)
                .foregroundColor(.red)
            
            ForEach(calendarManager.currentConflicts, id: \.existingEvent.eventIdentifier) { conflict in
                ConflictRowView(conflict: conflict)
            }
            
            Button("Ignore Conflicts & Create") {
                if let assignment = selectedAssignment {
                    Task {
                        _ = await calendarManager.createAssignmentIgnoringConflicts(assignment)
                    }
                }
            }
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var recentAssignmentsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Assignments")
                .font(.headline)
            
            // Placeholder for recent assignments
            Text("No recent assignments")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var permissionIcon: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .writeOnly:
            return "pencil.circle.fill"
        case .notDetermined:
            return "questionmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var permissionColor: Color {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return .green
        case .denied, .restricted:
            return .red
        case .writeOnly:
            return .orange
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    private var permissionText: String {
        switch calendarManager.authorizationStatus {
        case .authorized, .fullAccess:
            return "Full Calendar Access"
        case .denied:
            return "Calendar Access Denied"
        case .restricted:
            return "Calendar Access Restricted"
        case .writeOnly:
            return "Write-Only Access"
        case .notDetermined:
            return "Calendar Access Required"
        @unknown default:
            return "Unknown Status"
        }
    }
}

struct ConflictRowView: View {
    let conflict: CalendarConflict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(conflict.existingEvent.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("\(conflict.existingEvent.startDate.formatted(date: .omitted, time: .shortened)) - \(conflict.existingEvent.endDate.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(conflictTypeText)
                .font(.caption)
                .foregroundColor(conflictTypeColor)
        }
        .padding(.vertical, 5)
    }
    
    private var conflictTypeText: String {
        switch conflict.conflictType {
        case .fullOverlap:
            return "Full overlap"
        case .partialOverlap:
            return "Partial overlap"
        case .adjacent:
            return "Back-to-back"
        }
    }
    
    private var conflictTypeColor: Color {
        switch conflict.conflictType {
        case .fullOverlap:
            return .red
        case .partialOverlap:
            return .orange
        case .adjacent:
            return .yellow
        }
    }
}

struct AssignmentFormView: View {
    let assignment: WorkAssignment?
    let calendarManager: LocumCalendarManager
    
    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var location: String = ""
    @State private var notes: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Assignment Details") {
                    TextField("Title", text: $title)
                    
                    DatePicker("Start Date", selection: $startDate)
                    DatePicker("End Date", selection: $endDate)
                    
                    TextField("Location", text: $location)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section("Actions") {
                    Button("Check for Conflicts") {
                        checkForConflicts()
                    }
                    
                    Button("Create Assignment") {
                        createAssignment()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle(assignment == nil ? "New Assignment" : "Edit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func checkForConflicts() {
        let assignment = WorkAssignment(
            id: UUID(),
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            await calendarManager.checkConflicts(for: assignment)
        }
    }
    
    private func createAssignment() {
        let assignment = WorkAssignment(
            id: UUID(),
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            let result = await calendarManager.createWorkAssignment(assignment)
            
            switch result {
            case .success:
                dismiss()
            case .failure:
                // Error is already handled by the calendar manager
                break
            }
        }
    }
}
```

### Info.plist Configuration

```xml
<!-- Required for calendar access -->
<key>NSCalendarsFullAccessUsageDescription</key>
<string>LocumTracker needs full calendar access to check for scheduling conflicts and add work assignments to your calendar.</string>

<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
<string>LocumTracker needs calendar access to add your work assignments to your calendar.</string>

<!-- Required for notifications -->
<key>NSUserNotificationsUsageDescription</key>
<string>LocumTracker sends notifications to remind you of upcoming work assignments.</string>
```

This comprehensive guide provides all the necessary patterns and code examples for integrating EventKit into a Swift locum tracking app, with proper permission handling, conflict detection, cross-platform support, and privacy considerations.