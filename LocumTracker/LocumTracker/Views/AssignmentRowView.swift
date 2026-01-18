import SwiftUI
import LocumTrackerCore
import LocumTrackerUI

/// Row view displaying assignment summary information in a list
///
/// Shows location name, status badge, MMM classification, rate information,
/// and date range for an assignment.
struct AssignmentRowView: View {
    /// The assignment to display
    let assignment: Assignment
    /// Available locations for looking up the assignment's location
    let locations: [Location]

    /// The location associated with this assignment
    private var location: Location? {
        locations.first { $0.id == assignment.locationId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ViewConstants.verticalSpacing) {
            headerRow
            detailRow
            dateRow
        }
        .padding(.vertical, ViewConstants.rowVerticalPadding)
    }

    // MARK: - View Components

    private var headerRow: some View {
        HStack {
            Text(location?.name ?? "Unknown Location")
                .font(.headline)

            Spacer()

            StatusBadge(status: assignment.status)
        }
    }

    private var detailRow: some View {
        HStack {
            if let location = location {
                MMMBadge(classification: location.mmmClassification)
            }

            Text(assignment.rateStructure.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            rateText
        }
    }

    @ViewBuilder
    private var rateText: some View {
        if assignment.rateStructure == .dailyRate, let dailyRate = assignment.dailyRate {
            Text(CurrencyFormatter.format(dailyRate) + "/day")
                .font(.subheadline)
                .fontWeight(.medium)
        } else if assignment.rateStructure == .hourlyRate, let hourlyRate = assignment.hourlyRate {
            Text(CurrencyFormatter.format(hourlyRate) + "/hr")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var dateRow: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formattedDateRange)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Formats the assignment date range as a human-readable string
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let start = formatter.string(from: assignment.startDate)
        let end = formatter.string(from: assignment.endDate)

        return "\(start) - \(end)"
    }
}

// MARK: - Constants

private enum ViewConstants {
    /// Vertical spacing between row elements
    static let verticalSpacing: CGFloat = 6
    /// Vertical padding for the entire row
    static let rowVerticalPadding: CGFloat = 4
}

// MARK: - Status Badge

/// Badge displaying the assignment status with color coding
struct StatusBadge: View {
    /// The status to display
    let status: AssignmentStatus

    var body: some View {
        Text(status.description)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, BadgeConstants.horizontalPadding)
            .padding(.vertical, BadgeConstants.verticalPadding)
            .background(statusColor.opacity(BadgeConstants.backgroundOpacity))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    /// Color associated with the assignment status
    private var statusColor: Color {
        switch status {
        case .planned: return .blue
        case .active: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
}

// MARK: - MMM Badge

/// Badge displaying the Modified Monash Model classification
struct MMMBadge: View {
    /// The MMM classification (1-7)
    let classification: Int

    var body: some View {
        Text("MMM\(classification)")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, BadgeConstants.horizontalPadding)
            .padding(.vertical, BadgeConstants.verticalPadding)
            .background(mmmColor.opacity(BadgeConstants.backgroundOpacity))
            .foregroundStyle(mmmColor)
            .clipShape(Capsule())
    }

    /// Color associated with the MMM classification level
    private var mmmColor: Color {
        switch classification {
        case 1, 2: return .gray      // Metropolitan/Regional - not eligible
        case 3: return .blue         // Large rural town
        case 4: return .cyan         // Medium rural town
        case 5: return .teal         // Small rural town
        case 6: return .orange       // Remote community
        case 7: return .red          // Very remote community
        default: return .gray
        }
    }
}

// MARK: - Badge Constants

private enum BadgeConstants {
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
    static let backgroundOpacity: Double = 0.15
}

// MARK: - Preview

#Preview {
    let location = Location(
        name: "Cooktown Hospital",
        address: "123 Main St",
        mmmClassification: 6
    )
    let secondsPerDay: TimeInterval = 86400
    let assignment = Assignment(
        locationId: location.id,
        rateStructure: .dailyRate,
        dailyRate: 450.0,
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * secondsPerDay)
    )

    return List {
        AssignmentRowView(assignment: assignment, locations: [location])
    }
}
