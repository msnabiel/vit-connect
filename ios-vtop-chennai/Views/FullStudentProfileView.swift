import SwiftUI

struct FullStudentProfileView: View {
    @EnvironmentObject var dataManager: DataManager

    private let headerColors: [Color] = [
        Color(red: 0.18, green: 0.35, blue: 0.75),
        Color(red: 0.12, green: 0.55, blue: 0.82)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let profile = dataManager.studentProfile {
                    headerCard(profile: profile)

                    if let sections = profile.accordionSections, !sections.isEmpty {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { idx, section in
                            sectionCard(section: section, accentIndex: idx)
                        }
                    } else {
                        emptyHintCard
                    }
                } else {
                    Text("No profile loaded yet.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Full profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(profile: StudentProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    if let sem = profile.semester, !sem.isEmpty {
                        Text(sem)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
                Spacer()
                Image(systemName: "person.crop.rectangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.35))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let reg = profile.registrationNumber, !reg.isEmpty {
                    miniChip(title: "Register No.", value: reg, tone: .white)
                }
                if let mail = profile.vitEmail, !mail.isEmpty {
                    miniChip(title: "VIT email", value: mail, tone: .white)
                }
                if let pb = profile.programBranch, !pb.isEmpty {
                    miniChip(title: "Program", value: pb, tone: .white)
                }
                if let school = profile.schoolName, !school.isEmpty {
                    miniChip(title: "School", value: school, tone: .white)
                }
                if let cr = profile.creditsRegistered, cr > 0 {
                    miniChip(title: "Credits registered", value: String(format: "%.0f", cr), tone: .mint)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: headerColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: headerColors[0].opacity(0.35), radius: 12, x: 0, y: 6)
    }

    private func miniChip(title: String, value: String, tone: ChipTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(tone.titleColor)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(tone.valueColor)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tone.background)
        )
    }

    private enum ChipTone {
        case white
        case mint

        var titleColor: Color {
            switch self {
            case .white: return .white.opacity(0.75)
            case .mint: return .mint.opacity(0.85)
            }
        }

        var valueColor: Color {
            switch self {
            case .white: return .white
            case .mint: return .mint.opacity(0.95)
            }
        }

        var background: Color {
            switch self {
            case .white: return Color.white.opacity(0.14)
            case .mint: return Color.mint.opacity(0.22)
            }
        }
    }

    private func sectionCard(section: ProfileAccordionSectionData, accentIndex: Int) -> some View {
        let hues: [Color] = [.indigo, .teal, .orange, .purple, .pink]
        let accent = hues[accentIndex % hues.count]

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 4, height: 22)
                Text(section.title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(accent.opacity(0.12))

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.offset) { i, row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.key)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(accent.opacity(0.9))
                        Text(row.value.isEmpty ? "—" : row.value)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(i % 2 == 0 ? Color(uiColor: .secondarySystemGroupedBackground) : Color.clear)

                    if i < section.rows.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private var emptyHintCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nothing to show yet", systemImage: "icloud.and.arrow.down")
                .font(.headline)
            Text("Use Profile → Sync Data while signed in so VTOP can load personal, education, and family sections.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}

#Preview {
    NavigationStack {
        FullStudentProfileView()
            .environmentObject(DataManager())
    }
}
