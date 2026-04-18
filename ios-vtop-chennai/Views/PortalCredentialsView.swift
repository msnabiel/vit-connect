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
                ForEach(dataManager.portalCredentials) { cred in
                    Section(cred.account) {
                        LabeledContent("User name") {
                            Text(cred.userName)
                                .font(.body)
                                .multilineTextAlignment(.trailing)
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
                        }
                        if let s = cred.seatLocation, !s.isEmpty {
                            LabeledContent("Seat", value: s)
                        }
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
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("Portal access")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PortalCredentialsView()
            .environmentObject(DataManager())
    }
}
