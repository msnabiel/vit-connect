import SwiftUI

struct FullStudentProfileView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        List {
            if let profile = dataManager.studentProfile {
                Section(header: Text("Summary")) {
                    if let reg = profile.registrationNumber, !reg.isEmpty {
                        LabeledContent("Register No.", value: reg)
                    }
                    if let mail = profile.vitEmail, !mail.isEmpty {
                        LabeledContent("VIT email") {
                            Text(mail)
                                .textSelection(.enabled)
                        }
                    }
                    if let pb = profile.programBranch, !pb.isEmpty {
                        LabeledContent("Program & branch") {
                            Text(pb)
                                .font(.subheadline)
                        }
                    }
                    if let school = profile.schoolName, !school.isEmpty {
                        LabeledContent("School") {
                            Text(school)
                                .font(.subheadline)
                        }
                    }
                    if let cr = profile.creditsRegistered, cr > 0 {
                        LabeledContent("Credits registered") {
                            Text(String(format: "%.0f", cr))
                        }
                    }
                }

                if let sections = profile.accordionSections, !sections.isEmpty {
                    ForEach(sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(row.value.isEmpty ? "—" : row.value)
                                        .font(.body)
                                        .textSelection(.enabled)
                                }
                                .padding(.vertical, 2)
                            }
                        }
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

#Preview {
    NavigationStack {
        FullStudentProfileView()
            .environmentObject(DataManager())
    }
}
