import SwiftUI

struct PortalCredentialsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var revealedCredentialIds: Set<Int> = []

    var body: some View {
        List {
            Section {
                Text("Values from VTOP. Default passwords are sensitive—change them if you still use defaults.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 4, trailing: 16))
            }

            if dataManager.portalCredentials.isEmpty && dataManager.rankEntries.isEmpty {
                Section {
                    Text("No credentials or rank data. Sync while logged in to refresh.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if !dataManager.portalCredentials.isEmpty {
                Section(header: Text("Accounts")) {
                    ForEach(dataManager.portalCredentials) { cred in
                        credentialBlock(cred: cred)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden, edges: .all)
                            .listRowBackground(Color.clear)
                    }
                }
            }

            if !dataManager.rankEntries.isEmpty {
                Section(header: Text("Rank")) {
                    ForEach(dataManager.rankEntries) { entry in
                        HStack {
                            Text(entry.name)
                            Spacer()
                            Text(entry.rank)
                                .fontWeight(.semibold)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("Portal access")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func credentialBlock(cred: VTOPPortalCredential) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cred.account)
                .font(.subheadline.weight(.semibold))

            LabeledContent("User name") {
                Text(cred.userName)
                    .textSelection(.enabled)
            }
            .font(.caption)

            LabeledContent("Password") {
                HStack(spacing: 8) {
                    if revealedCredentialIds.contains(cred.id) {
                        Text(cred.defaultPassword)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "•", count: min(10, max(4, cred.defaultPassword.count))))
                            .foregroundColor(.secondary)
                    }
                    Button(revealedCredentialIds.contains(cred.id) ? "Hide" : "Show") {
                        if revealedCredentialIds.contains(cred.id) {
                            revealedCredentialIds.remove(cred.id)
                        } else {
                            revealedCredentialIds.insert(cred.id)
                        }
                    }
                    .font(.caption2)
                }
            }
            .font(.caption)

            if let url = cred.urlString, !url.isEmpty {
                LabeledContent("URL") {
                    if url.lowercased().hasPrefix("http"), let u = URL(string: url) {
                        Link(destination: u) {
                            Text("Open link")
                                .font(.caption)
                        }
                    } else {
                        Text(url)
                            .font(.caption2)
                            .textSelection(.enabled)
                    }
                }
                .font(.caption2)
            }
            if let v = cred.venueDate, !v.isEmpty {
                LabeledContent("Venue & date", value: v)
                    .font(.caption2)
            }
            if let s = cred.seatLocation, !s.isEmpty {
                LabeledContent("Seat", value: s)
                    .font(.caption2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationStack {
        PortalCredentialsView()
            .environmentObject(DataManager())
    }
}
