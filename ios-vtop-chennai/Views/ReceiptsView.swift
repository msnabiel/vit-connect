import SwiftUI

struct ReceiptsView: View {
    @EnvironmentObject var dataManager: DataManager

    var totalAmount: Double {
        dataManager.receipts.reduce(0) { $0 + $1.amount }
    }

    var groupedReceipts: [String: [Receipt]] {
        Dictionary(grouping: dataManager.receipts) { receipt in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(receipt.date / 1000)))
        }
    }

    var body: some View {
        ScrollView {
            if dataManager.isLoading && dataManager.receipts.isEmpty {
                // Skeleton loading
                VStack(spacing: 20) {
                    SkeletonCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    LazyVStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonListRow()
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else if dataManager.receipts.isEmpty {
                EmptyStateView(
                    icon: "doc.text.fill",
                    message: "No payment receipts available"
                )
                .frame(maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                VStack(spacing: 20) {
                    // Summary card
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Total Paid")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            Text("₹\(formatAmount(totalAmount))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Receipts")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            Text("\(dataManager.receipts.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                    // Grouped receipts
                    LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                        ForEach(groupedReceipts.keys.sorted().reversed(), id: \.self) { month in
                            Section(header: MonthHeader(month: month)) {
                                VStack(spacing: 12) {
                                    ForEach(groupedReceipts[month] ?? []) { receipt in
                                        ReceiptRow(receipt: receipt)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
            }
        }
        .refreshable {
            dataManager.syncAll()
        }
        .navigationTitle("Payment receipts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}

struct MonthHeader: View {
    let month: String

    var body: some View {
        HStack {
            Text(month)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(Color(uiColor: .systemBackground))
    }
}

struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.15))
                )

            // Receipt details
            VStack(alignment: .leading, spacing: 4) {
                Text("Receipt #\(receipt.number)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(receipt.formattedDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(formatAmount(receipt.amount))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)

                Text("Paid")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
}

#Preview {
    NavigationStack {
        ReceiptsView()
            .environmentObject(DataManager())
    }
}
