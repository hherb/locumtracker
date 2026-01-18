import SwiftUI

/// Compact view displaying current CloudKit sync status
public struct CloudKitSyncStatusView: View {
    private var status: CloudKitSyncStatus

    /// Creates a sync status view
    /// - Parameter status: The status object to display (defaults to shared)
    public init(status: CloudKitSyncStatus = .shared) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.state.systemImage)
                .foregroundStyle(status.state.color)
                .symbolEffect(.pulse, isActive: status.isSyncing)

            Text(status.statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iCloud sync status: \(status.statusDescription)")
    }
}

/// Larger sync status view with more details
public struct CloudKitSyncStatusDetailView: View {
    private var status: CloudKitSyncStatus

    /// Creates a detailed sync status view
    /// - Parameter status: The status object to display (defaults to shared)
    public init(status: CloudKitSyncStatus = .shared) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(status.state.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: status.state.systemImage)
                    .font(.title2)
                    .foregroundStyle(status.state.color)
                    .symbolEffect(.pulse, isActive: status.isSyncing)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(status.state.rawValue)
                    .font(.headline)

                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !status.isCloudKitAvailable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iCloud sync: \(status.state.rawValue). \(statusDetailText)")
    }

    private var statusDetailText: String {
        if !status.isCloudKitAvailable {
            return status.errorMessage ?? "iCloud unavailable"
        }

        switch status.state {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Uploading changes..."
        case .synced:
            return status.lastSyncDescription
        case .pending:
            return "\(status.pendingChangesCount) change\(status.pendingChangesCount == 1 ? "" : "s") pending"
        case .error:
            return status.errorMessage ?? "Unknown error"
        }
    }
}

#Preview("Compact") {
    CloudKitSyncStatusView()
}

#Preview("Detail") {
    CloudKitSyncStatusDetailView()
        .padding()
}
