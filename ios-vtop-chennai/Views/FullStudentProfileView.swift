import SwiftUI

struct FullStudentProfileView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        List {
            if let profile = dataManager.studentProfile {
                Section {
                    if let reg = profile.registrationNumber, !reg.isEmpty {
                        LabeledContent {
                            Text(reg)
                                .foregroundColor(Color.accentColor)
                                .textSelection(.enabled)
                        } label: {
                            Text("Register No.")
                                .foregroundColor(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let mail = profile.vitEmail, !mail.isEmpty {
                        LabeledContent {
                            Text(mail)
                                .foregroundColor(Color(uiColor: .systemBlue))
                                .textSelection(.enabled)
                        } label: {
                            Text("VIT email")
                                .foregroundColor(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let pb = profile.programBranch, !pb.isEmpty {
                        LabeledContent {
                            Text(pb)
                                .font(.subheadline)
                                .foregroundColor(Color.purple.opacity(0.92))
                        } label: {
                            Text("Program & branch")
                                .foregroundColor(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let school = profile.schoolName, !school.isEmpty {
                        LabeledContent {
                            Text(school)
                                .font(.subheadline)
                                .foregroundColor(Color.teal.opacity(0.95))
                        } label: {
                            Text("School")
                                .foregroundColor(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let cr = profile.creditsRegistered, cr > 0 {
                        LabeledContent {
                            Text(String(format: "%.0f", cr))
                                .foregroundColor(Color.orange.opacity(0.95))
                        } label: {
                            Text("Credits registered")
                                .foregroundColor(FullProfileStyle.summaryLabelColor)
                        }
                    }
                } header: {
                    FullProfileSectionHeader(title: "Summary")
                }

                if let sections = profile.accordionSections, !sections.isEmpty {
                    ForEach(sections) { section in
                        ProfileAccordionSectionBlock(section: section)
                    }
                } else {
                    Section {
                        Text("Open Sync from Profile after login to load personal, education, and family details from VTOP.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Section {
                    Text("No profile loaded yet.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Full profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Styling

private enum FullProfileStyle {
    static let summaryLabelColor = Color.secondary.opacity(0.95)
    static let valueColor = Color.primary.opacity(0.92)

    static func accentForSectionTitle(_ title: String) -> Color {
        let t = title.lowercased()
        if t.contains("personal") { return Color.cyan.opacity(0.95) }
        if t.contains("education") || t.contains("academic") { return Color.purple.opacity(0.9) }
        if t.contains("family") || t.contains("parent") || t.contains("guardian") { return Color.orange.opacity(0.92) }
        if t.contains("contact") || t.contains("address") || t.contains("communication") { return Color.blue.opacity(0.9) }
        if t.contains("bank") || t.contains("fee") || t.contains("financial") { return Color.green.opacity(0.88) }
        if t.contains("application") || t.contains("admission") { return Color.indigo.opacity(0.9) }
        return Color.accentColor.opacity(0.92)
    }
}

private struct ProfileAccordionSectionBlock: View {
    let section: ProfileAccordionSectionData

    private var accent: Color {
        FullProfileStyle.accentForSectionTitle(section.title)
    }

    var body: some View {
        Section {
            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.key)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(accent)
                    Text(row.value.isEmpty ? "—" : row.value)
                        .font(.body)
                        .foregroundColor(FullProfileStyle.valueColor)
                        .textSelection(.enabled)
                }
                .padding(.vertical, 2)
            }
        } header: {
            FullProfileSectionHeader(title: section.title, tint: accent)
        }
    }
}

private struct FullProfileSectionHeader: View {
    let title: String
    var tint: Color?

    init(title: String, tint: Color? = nil) {
        self.title = title
        self.tint = tint
    }

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(tint ?? Color.accentColor)
            .textCase(nil)
    }
}

#Preview {
    NavigationStack {
        FullStudentProfileView()
            .environmentObject(DataManager())
    }
}
