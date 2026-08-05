import SwiftUI
import UIKit

struct FullStudentProfileView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        List {
            if let profile = dataManager.studentProfile {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.gradient)
                            Text(profile.name.prefix(1).uppercased())
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 54, height: 54)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.title3.weight(.semibold))
                            Text([profile.programBranch, profile.semester].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    if let reg = profile.registrationNumber, !reg.isEmpty {
                        LabeledContent {
                            Text(reg)
                                .foregroundStyle(Color.accentColor)
                                .textSelection(.enabled)
                            CopyValueButton(value: reg, label: "Register number")
                        } label: {
                            Text("Register No.")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let mail = profile.vitEmail, !mail.isEmpty {
                        LabeledContent {
                            Text(mail)
                                .foregroundStyle(Color(uiColor: .systemBlue))
                                .textSelection(.enabled)
                            CopyValueButton(value: mail, label: "VIT email")
                        } label: {
                            Text("VIT email")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let pb = profile.programBranch, !pb.isEmpty {
                        LabeledContent {
                            Text(pb)
                                .font(.subheadline)
                                .foregroundStyle(Color.purple.opacity(0.92))
                        } label: {
                            Text("Program & branch")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let school = profile.schoolName, !school.isEmpty {
                        LabeledContent {
                            Text(school)
                                .font(.subheadline)
                                .foregroundStyle(Color.teal.opacity(0.95))
                        } label: {
                            Text("School")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let cr = profile.creditsRegistered, cr > 0 {
                        LabeledContent {
                            Text(String(format: "%.0f", cr))
                                .foregroundStyle(Color.orange.opacity(0.95))
                        } label: {
                            Text("Credits registered")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let required = profile.totalCreditsRequired, required > 0 {
                        LabeledContent {
                            Text(String(format: "%.0f", required))
                                .foregroundStyle(Color.blue.opacity(0.92))
                        } label: {
                            Text("Total credits required")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
                        }
                    }
                    if let nonGraded = profile.nonGradedCoreRequirement, nonGraded >= 0 {
                        LabeledContent {
                            Text(String(format: "%.1f", nonGraded))
                                .foregroundStyle(Color.red.opacity(0.88))
                        } label: {
                            Text("Non-graded core requirement")
                                .foregroundStyle(FullProfileStyle.summaryLabelColor)
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
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Text("No profile loaded yet.")
                        .foregroundStyle(.secondary)
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
            ForEach(section.rows) { row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.key)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(minWidth: 108, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.value.isEmpty ? "—" : row.value)
                        .font(.body)
                        .foregroundStyle(FullProfileStyle.valueColor)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
            .foregroundStyle(tint ?? Color.accentColor)
            .textCase(nil)
    }
}

private struct CopyValueButton: View {
    let value: String
    let label: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copied ? "Copied (label)" : "Copy (label)")
        .sensoryFeedback(.success, trigger: copied)
    }
}

#Preview {
    NavigationStack {
        FullStudentProfileView()
            .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
    }
}
