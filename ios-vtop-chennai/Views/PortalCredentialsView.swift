import SwiftUI
import UIKit

struct PortalCredentialsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var revealedCredentialIds: Set<Int> = []
    @State private var copiedValue = ""

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keep your portal access private")
                            .font(.headline)
                        Text("Values come from VTOP. Default passwords are sensitive—change them if you still use defaults.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }

            if dataManager.portalCredentials.isEmpty && dataManager.rankEntries.isEmpty {
                Section {
                    Text("No credentials or rank data. Sync while logged in to refresh.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }

            if !dataManager.portalCredentials.isEmpty {
                ForEach(dataManager.portalCredentials) { cred in
                    Section {
                        PortalCredentialCard(
                            credential: cred,
                            isRevealed: revealedCredentialIds.contains(cred.id),
                            copiedValue: copiedValue,
                            onToggleReveal: {
                                if revealedCredentialIds.contains(cred.id) {
                                    revealedCredentialIds.remove(cred.id)
                                } else {
                                    revealedCredentialIds.insert(cred.id)
                                }
                            },
                            onCopy: { value in
                                UIPasteboard.general.string = value
                                copiedValue = value
                            }
                        )
                    } header: {
                        Label(cred.account, systemImage: "person.crop.circle.badge.key")
                    }
                }
            }

            if !dataManager.rankEntries.isEmpty {
                Section {
                    ForEach(dataManager.rankEntries) { entry in
                        HStack {
                            Text(entry.name)
                                .font(.body)
                            Spacer()
                            Text(entry.rank)
                                .font(.body.weight(.semibold))
                        }
                    }
                } header: {
                    Text("Rank")
                        .font(.headline)
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("Portal access")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PortalCredentialCard: View {
    let credential: VTOPPortalCredential
    let isRevealed: Bool
    let copiedValue: String
    let onToggleReveal: () -> Void
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CredentialValueRow(
                label: "Username",
                value: credential.userName,
                icon: "person.fill",
                isSensitive: false,
                copiedValue: copiedValue,
                onCopy: onCopy
            )
            CredentialValueRow(
                label: "Default password",
                value: credential.defaultPassword,
                icon: "key.fill",
                isSensitive: true,
                isRevealed: isRevealed,
                copiedValue: copiedValue,
                onToggleReveal: onToggleReveal,
                onCopy: onCopy
            )

            if let url = credential.urlString, !url.isEmpty {
                if url.lowercased().hasPrefix("http"), let destination = URL(string: url) {
                    Link(destination: destination) {
                        Label("Open portal", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                } else {
                    CredentialValueRow(label: "Portal URL", value: url, icon: "link", isSensitive: false, copiedValue: copiedValue, onCopy: onCopy)
                }
            }

            if let venue = credential.venueDate, !venue.isEmpty {
                Label(venue, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let seat = credential.seatLocation, !seat.isEmpty {
                Label("Seat (seat)", systemImage: "chair.lounge.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CredentialValueRow: View {
    let label: String
    let value: String
    let icon: String
    var isSensitive = false
    var isRevealed = false
    let copiedValue: String
    var onToggleReveal: (() -> Void)?
    let onCopy: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(isSensitive && !isRevealed ? String(repeating: "•", count: min(12, max(4, value.count))) : value)
                    .font(.body.weight(.medium))
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if isSensitive, let onToggleReveal {
                Button(isRevealed ? "Hide" : "Show", action: onToggleReveal)
                    .font(.caption.weight(.semibold))
            }
            Button {
                onCopy(value)
            } label: {
                Image(systemName: copiedValue == value ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copiedValue == value ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy (label)")
        }
    }
}

#Preview {
    NavigationStack {
        PortalCredentialsView()
            .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
    }
}
