import SwiftUI

struct PortalCredentialsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var revealedCredentialIds: Set<Int> = []

    var body: some View {
        List {
            Section {
                Text("Values from VTOP. Default passwords are sensitive—change them if you still use defaults.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
            }

            if dataManager.portalCredentials.isEmpty && dataManager.rankEntries.isEmpty {
                Section {
                    Text("No credentials or rank data. Sync while logged in to refresh.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }

            if !dataManager.portalCredentials.isEmpty {
                Section(header: Text("Accounts").font(.headline)) {
                    ForEach(dataManager.portalCredentials) { cred in
                        credentialBlock(cred: cred)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowSeparator(.hidden, edges: .all)
                            .listRowBackground(Color.clear)
                    }
                }
            }

            if !dataManager.rankEntries.isEmpty {
                Section(header: Text("Rank").font(.headline)) {
                    ForEach(dataManager.rankEntries) { entry in
                        HStack {
                            Text(entry.name)
                                .font(.body)
                            Spacer()
                            Text(entry.rank)
                                .font(.body.weight(.semibold))
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
        VStack(alignment: .leading, spacing: 12) {
            Text(cred.account)
                .font(.title3.weight(.semibold))

            LabeledContent("User name") {
                Text(cred.userName)
                    .font(.body)
                    .textSelection(.enabled)
            }

            LabeledContent("Default password") {
                HStack(spacing: 10) {
                    if revealedCredentialIds.contains(cred.id) {
                        Text(cred.defaultPassword)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "•", count: min(12, max(4, cred.defaultPassword.count))))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Button(revealedCredentialIds.contains(cred.id) ? "Hide" : "Show") {
                        if revealedCredentialIds.contains(cred.id) {
                            revealedCredentialIds.remove(cred.id)
                        } else {
                            revealedCredentialIds.insert(cred.id)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                }
            }

            if let url = cred.urlString, !url.isEmpty {
                LabeledContent("URL") {
                    if url.lowercased().hasPrefix("http"), let u = URL(string: url) {
                        Link("Open link", destination: u)
                            .font(.body)
                    } else {
                        Text(url)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
            if let v = cred.venueDate, !v.isEmpty {
                LabeledContent("Venue & date", value: v)
                    .font(.body)
            }
            if let s = cred.seatLocation, !s.isEmpty {
                LabeledContent("Seat", value: s)
                    .font(.body)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
