import SwiftUI

struct SemesterSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)

                    Text("Select Semester")
                        .font(.system(size: 24, weight: .bold))

                    Text("Choose a semester to view your academic data")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Semester List
                ScrollView {
                    VStack(spacing: 12) {
                        if dataManager.semesters.isEmpty {
                            ProgressView("Loading semesters...")
                                .padding()
                        } else {
                            ForEach(dataManager.semesters) { semester in
                                Button(action: {
                                    dataManager.selectSemester(semester)
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(semester.name)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }

                                        Spacer()

                                        if dataManager.selectedSemester?.id == semester.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.accentColor)
                                        } else {
                                            Image(systemName: "circle")
                                                .font(.system(size: 24))
                                                .foregroundColor(.secondary.opacity(0.3))
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                dataManager.selectedSemester?.id == semester.id
                                                    ? Color.accentColor.opacity(0.1)
                                                    : Color(uiColor: .secondarySystemBackground)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                dataManager.selectedSemester?.id == semester.id
                                                    ? Color.accentColor
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

#Preview {
    SemesterSelectionView()
        .environmentObject(DataManager())
}
