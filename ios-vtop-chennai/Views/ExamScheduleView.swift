import SwiftUI

struct ExamScheduleView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedExamIndex: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if dataManager.exams.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        message: "No exam schedule available"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Exam selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(dataManager.exams.enumerated()), id: \.offset) { index, exam in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedExamIndex = index
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Text("Exam \(index + 1)")
                                            .font(.system(size: 13, weight: .semibold))

                                        Text(exam.title)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(selectedExamIndex == index ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                                    )
                                    .foregroundColor(selectedExamIndex == index ? .white : .primary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color(uiColor: .systemBackground))

                    // Exam details
                    TabView(selection: $selectedExamIndex) {
                        ForEach(Array(dataManager.exams.enumerated()), id: \.offset) { index, exam in
                            ExamDetailCard(exam: exam, course: dataManager.courses.first(where: { $0.id == exam.courseId }))
                                .padding(20)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Exam Schedule")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ExamDetailCard: View {
    let exam: Exam
    let course: Course?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Course info
                VStack(spacing: 12) {
                    // Exam type badge
                    HStack {
                        Spacer()

                        Text(exam.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )

                        Spacer()
                    }

                    if let course = course {
                        VStack(spacing: 8) {
                            Text(course.title)
                                .font(.system(size: 24, weight: .bold))
                                .multilineTextAlignment(.center)

                            Text(course.code)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)

                // Exam details
                VStack(spacing: 16) {
                    // Date & Time (placeholder - we'll show venue for now since we don't have date parsing)
                    if let venue = exam.venue {
                        InfoRow(
                            icon: "mappin.circle.fill",
                            title: "Venue",
                            value: venue,
                            color: .blue
                        )
                    }

                    // Seat location
                    if let seatLocation = exam.seatLocation {
                        InfoRow(
                            icon: "person.crop.square.fill",
                            title: "Seat Location",
                            value: seatLocation,
                            color: .purple
                        )
                    }

                    // Seat number
                    if let seatNumber = exam.seatNumber {
                        InfoRow(
                            icon: "number.circle.fill",
                            title: "Seat Number",
                            value: "\(seatNumber)",
                            color: .orange
                        )
                    }

                    // Course type
                    if let course = course {
                        InfoRow(
                            icon: "book.fill",
                            title: "Course Type",
                            value: course.type.rawValue.capitalized,
                            color: course.type == .lab ? .green : (course.type == .project ? .purple : .blue)
                        )

                        InfoRow(
                            icon: "person.fill",
                            title: "Faculty",
                            value: course.faculty,
                            color: .indigo
                        )
                    }
                }
                .padding(.horizontal, 4)

                // Important note
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Important")
                                .font(.system(size: 15, weight: .bold))

                            Text("Please verify exam details on VTOP before the exam")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange.opacity(0.1))
                    )
                }

                Spacer()
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(size: 16, weight: .semibold))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview {
    ExamScheduleView()
        .environmentObject(DataManager())
}
