import SwiftUI

struct GradeTargetView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage(VTOPGradeTargetPreferences.targetKey) private var targetCGPA = 8.5
    @AppStorage(VTOPGradeTargetPreferences.remainingCreditsKey) private var remainingCredits = 0.0

    private var currentCGPA: Double { dataManager.studentProfile?.cgpa ?? 0 }
    private var completedCredits: Double { dataManager.studentProfile?.totalCredits ?? 0 }
    private var requiredGPA: Double? {
        guard remainingCredits > 0, completedCredits > 0 else { return nil }
        return ((targetCGPA * (completedCredits + remainingCredits)) - (currentCGPA * completedCredits)) / remainingCredits
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current CGPA")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f", currentCGPA))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Image(systemName: "target")
                        .font(.title)
                        .foregroundStyle(.purple)
                }
                .padding(.vertical, 8)
            }

            Section("Your target") {
                Stepper(value: $targetCGPA, in: 5...10, step: 0.1) {
                    LabeledContent("Target CGPA", value: String(format: "%.2f", targetCGPA))
                }
                HStack {
                    Text("Remaining credits")
                    Spacer()
                    TextField("Credits", value: $remainingCredits, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                Text("Set the number of credits you expect to complete. The calculation is saved on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("What you need") {
                if let requiredGPA {
                    if requiredGPA > 10 {
                        Label("This target is not reachable with the remaining credits.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } else if requiredGPA <= 0 {
                        Label("You are already above this target.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        LabeledContent("Required average GPA", value: String(format: "%.2f", requiredGPA))
                        Text("Based on your current CGPA and completed credits.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Enter remaining credits to calculate the required average GPA.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Grade target")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if remainingCredits == 0, let registered = dataManager.studentProfile?.creditsRegistered, registered > 0 {
                remainingCredits = registered
            }
        }
    }
}

struct GradeTargetCard: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage(VTOPGradeTargetPreferences.targetKey) private var targetCGPA = 8.5
    @AppStorage(VTOPGradeTargetPreferences.remainingCreditsKey) private var remainingCredits = 0.0

    private var requiredGPA: Double? {
        guard let profile = dataManager.studentProfile, remainingCredits > 0, profile.totalCredits > 0 else { return nil }
        return ((targetCGPA * (profile.totalCredits + remainingCredits)) - (profile.cgpa * profile.totalCredits)) / remainingCredits
    }

    var body: some View {
        NavigationLink(destination: GradeTargetView().environmentObject(dataManager)) {
            VTOPCockpitCard(title: "Grade target", systemImage: "target", tint: .purple) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target CGPA \(targetCGPA, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(requiredGPA.map { "Need \($0, specifier: "%.2f") average GPA" } ?? "Set remaining credits to calculate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
