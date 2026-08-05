import SwiftUI

/// Shared semester selector used by the academic, marks, and exam screens.
struct SemesterMenuView: View {
    let choices: [Semester]
    let selectedName: String
    let onSelect: (Semester) -> Void
    var tint: Color = .accentColor
    var bottomPadding: CGFloat = 8

    init(
        choices: [Semester],
        selectedName: String,
        tint: Color = .accentColor,
        bottomPadding: CGFloat = 8,
        onSelect: @escaping (Semester) -> Void
    ) {
        self.choices = choices
        self.selectedName = selectedName
        self.tint = tint
        self.bottomPadding = bottomPadding
        self.onSelect = onSelect
    }

    var body: some View {
        Menu {
            ForEach(choices) { semester in
                Button(semester.name) {
                    onSelect(semester)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("Semester — \(selectedName)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Semester")
        .accessibilityValue(selectedName)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, bottomPadding)
    }
}
