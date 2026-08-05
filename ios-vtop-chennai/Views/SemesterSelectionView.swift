import SwiftUI

struct SemesterSelectionView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .vtopFont(size: 50)
.foregroundStyle(Color.accentColor)

                    Text("Select Semester")
                        .vtopFont(size: 24, weight: .bold)
                    Text("Choose a semester to view your academic data")
                        .vtopFont(size: 15)
.foregroundStyle(.secondary)
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
                                                .vtopFont(size: 17, weight: .semibold)
.foregroundStyle(.primary)
                                        }

                                        Spacer()

                                        if dataManager.selectedSemester?.id == semester.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .vtopFont(size: 24)
.foregroundStyle(Color.accentColor)
                                        } else {
                                            Image(systemName: "circle")
                                                .vtopFont(size: 24)
.foregroundStyle(.secondary.opacity(0.3))
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
            .navigationTitle("Semester")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

#Preview {
    SemesterSelectionView()
        .environmentObject(DataManager())
            .environmentObject(DataManagerSyncState())
}
