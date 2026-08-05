import Foundation

enum VTOPCockpitMetrics {
    static func attendanceRiskLabel(for percentage: Int?) -> String? {
        guard let percentage else { return nil }
        if percentage >= 75 { return "On track" }
        if percentage >= 65 { return "At risk" }
        return "Critical"
    }

    static func nextExam(from exams: [Exam], now: Date = Date()) -> (exam: Exam, date: Date)? {
        exams
            .compactMap { exam -> (Exam, Date)? in
                guard let date = exam.startDate, date > now else { return nil }
                return (exam, date)
            }
            .min { $0.1 < $1.1 }
    }
}
