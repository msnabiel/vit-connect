import SwiftUI

private enum GPAGrade: String, CaseIterable, Identifiable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case f = "F"
    case n = "N"

    var id: String { rawValue }
    var points: Double {
        switch self {
        case .s: return 10
        case .a: return 9
        case .b: return 8
        case .c: return 7
        case .d: return 6
        case .e: return 5
        case .f, .n: return 0
        }
    }
}

private struct GPACourseInput: Identifiable {
    let id: UUID
    var name: String
    var creditsText: String
    var grade: GPAGrade

    init(id: UUID = UUID(), name: String, creditsText: String, grade: GPAGrade) {
        self.id = id
        self.name = name
        self.creditsText = creditsText
        self.grade = grade
    }
}

private enum GPAKeyboardFocus: Hashable {
    case courseName(UUID)
    case courseCredits(UUID)
    case remainingCredits
    case customTarget
}

struct GPACalculatorView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var courses: [GPACourseInput] = [
        GPACourseInput(name: "Course 1", creditsText: "3", grade: .a)
    ]
    @State private var remainingCreditsText = "60"
    @State private var customTargetText = "9.00"
    @FocusState private var keyboardFocus: GPAKeyboardFocus?

    private var semesterGPA: Double {
        let valid = courses.compactMap { course -> (Double, Double)? in
            guard let credits = Double(course.creditsText), credits > 0 else { return nil }
            return (credits, course.grade.points)
        }
        let totalCredits = valid.reduce(0) { $0 + $1.0 }
        guard totalCredits > 0 else { return 0 }
        let weighted = valid.reduce(0) { $0 + ($1.0 * $1.1) }
        return weighted / totalCredits
    }

    private var currentCGPA: Double { dataManager.studentProfile?.cgpa ?? 0 }
    private var completedCredits: Double { dataManager.studentProfile?.totalCredits ?? 0 }
    private var remainingCredits: Double { Double(remainingCreditsText) ?? 0 }
    private var suggestedCurrentSemesterCredits: Double? {
        if let reg = dataManager.studentProfile?.creditsRegistered, reg > 0 {
            return reg
        }
        let gpaCredits = courses.compactMap { Double($0.creditsText) }.reduce(0, +)
        if gpaCredits > 0 {
            return gpaCredits
        }
        return nil
    }

    var body: some View {
        List {
            Section {
                ForEach($courses) { $course in
                    GPACourseInputRow(course: $course, keyboardFocus: $keyboardFocus)
                }
                .onDelete { courses.remove(atOffsets: $0) }

                Button {
                    courses.append(GPACourseInput(name: "Course \(courses.count + 1)", creditsText: "3", grade: .a))
                } label: {
                    Label("Add course", systemImage: "plus.circle")
                }

                HStack {
                    Text("Calculated GPA")
                    Spacer()
                    Text(String(format: "%.2f", semesterGPA))
                        .fontWeight(.semibold)
                }
            } header: {
                Text("Semester GPA calculator")
            }

            Section {
                LabeledContent("Current CGPA", value: String(format: "%.2f", currentCGPA))
                LabeledContent("Completed credits", value: String(format: "%.0f", completedCredits))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining credits to graduate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Remaining credits to graduate", text: $remainingCreditsText)
                        .keyboardType(.decimalPad)
                        .focused($keyboardFocus, equals: .remainingCredits)
                }
                Button {
                    applySuggestedRemainingCredits()
                } label: {
                    Label("Use current semester registered credits", systemImage: "wand.and.stars")
                }
                .disabled(suggestedCurrentSemesterCredits == nil)

                TargetNeedRow(
                    title: "Need for 9.00 CGPA",
                    requiredGPA: requiredGPA(for: 9.0)
                )
                TargetNeedRow(
                    title: "Need for 8.50 CGPA",
                    requiredGPA: requiredGPA(for: 8.5)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom target CGPA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Custom target CGPA", text: $customTargetText)
                        .keyboardType(.decimalPad)
                        .focused($keyboardFocus, equals: .customTarget)
                }
                TargetNeedRow(
                    title: "Need for custom target",
                    requiredGPA: requiredGPA(for: Double(customTargetText) ?? 0)
                )
            } header: {
                Text("Quick targets")
            } footer: {
                Text("Uses VIT GPA logic: weighted by credits with S=10, A=9, ... E=5, F/N=0.")
            }
        }
        .navigationTitle("GPA Calculator")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    keyboardFocus = nil
                }
            }
        }
    }

    private func requiredGPA(for targetCGPA: Double) -> Double? {
        guard targetCGPA > 0, remainingCredits > 0 else { return nil }
        let needed = ((targetCGPA * (completedCredits + remainingCredits)) - (currentCGPA * completedCredits)) / remainingCredits
        return needed
    }

    private func applySuggestedRemainingCredits() {
        guard let suggested = suggestedCurrentSemesterCredits else { return }
        remainingCreditsText = String(format: "%.0f", suggested)
    }
}

private struct GPACourseInputRow: View {
    @Binding var course: GPACourseInput
    var keyboardFocus: FocusState<GPAKeyboardFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Course name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Course name", text: $course.name)
                    .focused(keyboardFocus, equals: .courseName(course.id))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Credits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Credits", text: $course.creditsText)
                    .keyboardType(.decimalPad)
                    .focused(keyboardFocus, equals: .courseCredits(course.id))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Grade")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Grade", selection: $course.grade) {
                    ForEach(GPAGrade.allCases) { grade in
                        Text("\(grade.rawValue) (\(Int(grade.points)))").tag(grade)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TargetNeedRow: View {
    let title: String
    let requiredGPA: Double?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let needed = requiredGPA {
                if needed > 10 {
                    Text("Not possible")
                        .foregroundStyle(.red)
                } else if needed < 0 {
                    Text("Already above target")
                        .foregroundStyle(.green)
                } else {
                    Text(String(format: "%.2f", needed))
                        .fontWeight(.semibold)
                }
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
