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

import SwiftUI
import SwiftData
import LocumTrackerCore
import LocumTrackerUI

/// View displaying a list of receipts with filtering by category
///
/// Provides a searchable, filterable list of expense receipts grouped by category.
/// Includes a summary section showing total expenses and receipt count.
struct ReceiptListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    @State private var showingAddReceipt = false
    @State private var searchText = ""
    @State private var filterCategory: ExpenseCategory?

    /// Receipts filtered by search text and category
    private var filteredReceipts: [Receipt] {
        receipts.filter { receipt in
            let matchesSearch = searchText.isEmpty ||
                receipt.receiptDescription.localizedCaseInsensitiveContains(searchText)

            let matchesFilter = filterCategory == nil ||
                receipt.category == filterCategory

            return matchesSearch && matchesFilter
        }
    }

    /// Receipts grouped by category, maintaining category order
    private var groupedReceipts: [(category: ExpenseCategory, receipts: [Receipt])] {
        let grouped = Dictionary(grouping: filteredReceipts) { $0.category }
        return ExpenseCategory.allCases.compactMap { category in
            guard let categoryReceipts = grouped[category], !categoryReceipts.isEmpty else {
                return nil
            }
            return (category, categoryReceipts)
        }
    }

    /// Total amount of filtered receipts
    private var totalAmount: Double {
        filteredReceipts.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            if filteredReceipts.isEmpty {
                emptyStateView
            } else {
                summarySection
                ForEach(groupedReceipts, id: \.category) { group in
                    Section {
                        ForEach(group.receipts) { receipt in
                            NavigationLink(value: receipt) {
                                ReceiptRowView(receipt: receipt)
                            }
                        }
                        .onDelete { offsets in
                            deleteReceipts(at: offsets, from: group.receipts)
                        }
                    } header: {
                        categoryHeader(for: group.category, count: group.receipts.count)
                    }
                }
            }
        }
        .navigationTitle("Receipts")
        .navigationDestination(for: Receipt.self) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
        .searchable(text: $searchText, prompt: "Search receipts")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddReceipt = true
                } label: {
                    Label("Add Receipt", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                filterMenu
            }
        }
        .sheet(isPresented: $showingAddReceipt) {
            AddReceiptSheet(isPresented: $showingAddReceipt)
        }
    }

    // MARK: - View Components

    private var summarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: SummaryConstants.verticalSpacing) {
                    Text("Total Expenses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(totalAmount))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: SummaryConstants.verticalSpacing) {
                    Text("Receipts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(filteredReceipts.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }
            .padding(.vertical, SummaryConstants.sectionPadding)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Receipts", systemImage: "receipt")
        } description: {
            if !searchText.isEmpty || filterCategory != nil {
                Text("No receipts match your search criteria.")
            } else {
                Text("Add your first receipt to track expenses.")
            }
        } actions: {
            if searchText.isEmpty && filterCategory == nil {
                Button("Add Receipt") {
                    showingAddReceipt = true
                }
            } else {
                Button("Clear Filters") {
                    searchText = ""
                    filterCategory = nil
                }
            }
        }
    }

    /// Creates a header view for a category section
    /// - Parameters:
    ///   - category: The expense category
    ///   - count: Number of receipts in this category
    /// - Returns: A header view with category icon and count
    private func categoryHeader(for category: ExpenseCategory, count: Int) -> some View {
        HStack {
            Label(category.description, systemImage: category.iconName)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                filterCategory = nil
            } label: {
                Label("All Categories", systemImage: filterCategory == nil ? "checkmark" : "")
            }

            Divider()

            ForEach(ExpenseCategory.allCases, id: \.self) { category in
                Button {
                    filterCategory = category
                } label: {
                    Label(category.description, systemImage: filterCategory == category ? "checkmark" : "")
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: filterCategory != nil
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

    // MARK: - Actions

    /// Deletes receipts at the specified offsets from a group
    /// - Parameters:
    ///   - offsets: Index set of receipts to delete
    ///   - groupReceipts: The array of receipts in the current group
    private func deleteReceipts(at offsets: IndexSet, from groupReceipts: [Receipt]) {
        for index in offsets {
            modelContext.delete(groupReceipts[index])
        }
    }
}

// MARK: - Receipt Row View

/// Row view displaying a single receipt in the list
///
/// Shows category icon, description, date, attachment indicator, and amount.
struct ReceiptRowView: View {
    /// The receipt to display
    let receipt: Receipt

    var body: some View {
        HStack(spacing: RowConstants.horizontalSpacing) {
            categoryIconView

            VStack(alignment: .leading, spacing: RowConstants.verticalSpacing) {
                Text(receipt.receiptDescription)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(receipt.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if receipt.hasImage {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }

            Spacer()

            Text(CurrencyFormatter.format(receipt.amount))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, RowConstants.rowVerticalPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("receiptRow_\(receipt.id)")
    }

    private var categoryIconView: some View {
        Image(systemName: receipt.category.iconName)
            .font(.title3)
            .foregroundStyle(receipt.category.color)
            .frame(width: RowConstants.iconSize, height: RowConstants.iconSize)
            .background(receipt.category.color.opacity(RowConstants.iconBackgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: RowConstants.iconCornerRadius))
            .accessibilityHidden(true)
    }

    /// Combined accessibility description for the entire row
    private var accessibilityDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateString = formatter.string(from: receipt.date)
        let attachmentInfo = receipt.hasImage ? ", has attachment" : ""
        return "\(receipt.receiptDescription), \(receipt.category.description), \(CurrencyFormatter.format(receipt.amount)), \(dateString)\(attachmentInfo)"
    }
}

// MARK: - Category Badge

/// Badge displaying the expense category with color coding
///
/// Uses the category's color for both text and background (with opacity).
struct CategoryBadge: View {
    /// The expense category to display
    let category: ExpenseCategory

    var body: some View {
        Text(category.description)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, BadgeConstants.horizontalPadding)
            .padding(.vertical, BadgeConstants.verticalPadding)
            .background(category.color.opacity(BadgeConstants.backgroundOpacity))
            .foregroundStyle(category.color)
            .clipShape(Capsule())
            .accessibilityLabel("Category: \(category.description)")
            .accessibilityIdentifier("categoryBadge_\(category.rawValue)")
    }
}

// MARK: - Constants

private enum SummaryConstants {
    static let verticalSpacing: CGFloat = 4
    static let sectionPadding: CGFloat = 8
}

private enum RowConstants {
    static let verticalSpacing: CGFloat = 4
    static let horizontalSpacing: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 4
    static let iconSize: CGFloat = 36
    static let iconBackgroundOpacity: Double = 0.15
    static let iconCornerRadius: CGFloat = 8
}

private enum BadgeConstants {
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
    static let backgroundOpacity: Double = 0.15
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Receipt.self, configurations: config)

    let secondsPerDay: TimeInterval = 86400
    let receipts = [
        Receipt(
            amount: 45.50,
            category: .meals,
            date: Date(),
            receiptDescription: "Lunch at hospital cafeteria"
        ),
        Receipt(
            amount: 185.00,
            category: .accommodation,
            date: Date().addingTimeInterval(-secondsPerDay),
            receiptDescription: "Hotel Darwin"
        ),
        Receipt(
            amount: 78.20,
            category: .travel,
            date: Date().addingTimeInterval(-2 * secondsPerDay),
            receiptDescription: "Fuel for travel to Cooktown"
        ),
        Receipt(
            amount: 250.00,
            category: .professional,
            date: Date().addingTimeInterval(-3 * secondsPerDay),
            receiptDescription: "AHPRA registration fee"
        )
    ]
    receipts.forEach { container.mainContext.insert($0) }

    return NavigationStack {
        ReceiptListView()
    }
    .modelContainer(container)
}
