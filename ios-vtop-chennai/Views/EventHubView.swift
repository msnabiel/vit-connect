import SwiftUI

/// Toolbar control: opens Event hub from tab roots (Attendance / Marks / Timetable, etc.).
struct EventHubToolbarLink: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationLink(destination: EventHubView().environmentObject(dataManager)) {
            Image(systemName: "calendar.badge.clock")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("Event hub")
    }
}

/// Toolbar control: opens the full week timetable (Home tab trailing).
struct TimetableToolbarLink: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationLink(
            destination: TimetableView()
                .environmentObject(authViewModel)
                .environmentObject(dataManager)
        ) {
            Image(systemName: "calendar")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("Timetable")
    }
}

struct EventHubView: View {
    @EnvironmentObject var dataManager: DataManager

    private var grouped: [(key: String, rows: [VTOPScheduledEventRow])] {
        let dict = Dictionary(grouping: dataManager.scheduledEventRows, by: \.groupKey)
        return dict.keys.sorted().compactMap { k in
            guard let rows = dict[k] else { return nil }
            let eventsOnly = rows.filter { !$0.isPlaceholder }
            guard !eventsOnly.isEmpty else { return nil }
            return (k, eventsOnly)
        }
    }

    var body: some View {
        Group {
            if dataManager.scheduledEventRows.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: "No events loaded",
                    message: "Pull to refresh after signing in, or run a full sync."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if grouped.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.checkmark",
                    title: "No upcoming events",
                    message: "There are no scheduled events in the current list."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.key) { group in
                        Section(header: sectionHeader(for: group.rows.first)) {
                            ForEach(group.rows) { row in
                                eventRow(row)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Event hub")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                dataManager.refreshScheduledEvents { cont.resume() }
            }
        }
        .onAppear {
            if dataManager.scheduledEventRows.isEmpty {
                dataManager.refreshScheduledEvents(completion: nil)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(for row: VTOPScheduledEventRow?) -> some View {
        if let row {
            HStack(spacing: 8) {
                Text(row.day)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                Text(row.monthYear)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                if !row.sectionBanner.isEmpty {
                    Spacer(minLength: 8)
                    Text(row.sectionBanner)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                        .lineLimit(2)
                }
            }
        } else {
            Text("Events")
        }
    }

    @ViewBuilder
    private func eventRow(_ row: VTOPScheduledEventRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = row.title, !title.isEmpty {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            if !row.detailLine.isEmpty {
                Text(row.detailLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.blue.opacity(0.92))
            }
            if !row.venue.isEmpty {
                Text(row.venue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange.opacity(0.95))
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        EventHubView()
            .environmentObject(DataManager())
    }
}
