import SwiftUI

/// Surfaces sync failures and, when enabled, when the UI is backed by persisted cache.
struct OfflineDataBanner: View {
    @EnvironmentObject var dataManager: DataManager
    @EnvironmentObject var syncState: DataManagerSyncState
    /// When `false`, hides the “Last sync / saved data” strip (e.g. on Home).
    var showSyncMetadata: Bool = true

    private var showsSyncLine: Bool {
        showSyncMetadata
            && syncState.lastDataFetchFailureReason == nil
            && (syncState.lastSuccessfulSyncAt != nil || syncState.cachePersistedAt != nil)
    }

    @ViewBuilder
    var body: some View {
        if let reason = syncState.lastDataFetchFailureReason,
           !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.medium)
                Text(reason)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.orange)
        } else if showsSyncLine {
            HStack(spacing: 8) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.caption.weight(.semibold))
                if let sync = syncState.lastSuccessfulSyncAt {
                    Text("Last sync: \(sync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                } else if let cached = syncState.cachePersistedAt {
                    Text("Using saved data from \(cached.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }
}
