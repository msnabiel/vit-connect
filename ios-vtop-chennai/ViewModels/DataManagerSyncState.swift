import Foundation
import Combine

/// UI-facing sync state kept separate from academic data so progress changes do not
/// invalidate every view observing `DataManager`.
final class DataManagerSyncState: ObservableObject {
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    @Published var cachePersistedAt: Date?
    @Published var lastSuccessfulSyncAt: Date?
    @Published var fullSyncQuotaBlockedMessage: String?
    @Published var fullSyncConfirmSlotsRemaining: Int?
    @Published var lastDataFetchFailureReason: String?
}
