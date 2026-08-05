import EventKit
import Foundation

enum VTOPCalendarExportError: LocalizedError {
    case accessDenied
    case noDates

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Calendar access was not granted."
        case .noDates: "No exam dates could be converted to calendar events."
        }
    }
}

enum VTOPCalendarExportService {
    private static let store = EKEventStore()

    @MainActor
    static func export(exams: [Exam]) async throws -> Int {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await store.requestAccess(to: .event)
        }
        guard granted else { throw VTOPCalendarExportError.accessDenied }

        let calendar = store.defaultCalendarForNewEvents
        var count = 0
        for exam in exams {
            guard let start = date(from: exam.examDateText) else { continue }
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = [exam.courseCode, exam.courseTitle, exam.examCategory]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            event.startDate = start
            event.endDate = start.addingTimeInterval(2 * 60 * 60)
            event.location = exam.venue
            event.notes = [exam.slotText, exam.seatLocation, exam.seatNumber.map(String.init)]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            try store.save(event, span: .thisEvent)
            count += 1
        }
        guard count > 0 else { throw VTOPCalendarExportError.noDates }
        return count
    }

    private static func date(from text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd", "dd MMM yyyy", "dd MMMM yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}
