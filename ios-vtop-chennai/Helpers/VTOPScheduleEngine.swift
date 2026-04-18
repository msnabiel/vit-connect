import Foundation

struct VTOPUpcomingSlot: Sendable {
    let slot: TimetableSlot
    let dayIndex: Int
    let course: Course
    let startDate: Date
    let endDate: Date
}

enum VTOPScheduleEngine {
    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }

    /// Next enrolled period starting after `now` within the next 7 days (wraps week).
    static func nextUpcomingSlot(
        now: Date = Date(),
        timetable: [TimetableSlot],
        courses: [Course]
    ) -> VTOPUpcomingSlot? {
        let cal = calendar
        let todayIdx = cal.component(.weekday, from: now) - 1
        var candidates: [VTOPUpcomingSlot] = []

        for dayOffset in 0..<7 {
            let idx = (todayIdx + dayOffset) % 7
            guard let dayDate = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)) else { continue }

            for slot in timetable {
                guard let course = slot.matchingCourse(on: idx, courses: courses) else { continue }
                guard let start = combine(day: dayDate, timeHHmm: slot.startTime, cal: cal),
                      let end = combine(day: dayDate, timeHHmm: slot.endTime, cal: cal),
                      end > now else { continue }
                if start > now {
                    candidates.append(VTOPUpcomingSlot(slot: slot, dayIndex: idx, course: course, startDate: start, endDate: end))
                }
            }
        }

        return candidates.min(by: { $0.startDate < $1.startDate })
    }

    /// Today’s enrolled classes (chronological), for widget lines.
    static func todaySlotSummaries(
        now: Date = Date(),
        timetable: [TimetableSlot],
        courses: [Course],
        max: Int = 6
    ) -> [String] {
        let cal = calendar
        let todayIdx = cal.component(.weekday, from: now) - 1
        let dayStart = cal.startOfDay(for: now)

        let slots = timetable
            .filter { $0.matchingCourse(on: todayIdx, courses: courses) != nil }
            .sorted { $0.startTime < $1.startTime }

        var lines: [String] = []
        for slot in slots.prefix(max) {
            guard let course = slot.matchingCourse(on: todayIdx, courses: courses) else { continue }
            lines.append("\(slot.startTime) · \(course.title) · \(course.venue)")
        }
        return lines
    }

    private static func combine(day: Date, timeHHmm: String, cal: Calendar) -> Date? {
        let parts = timeHHmm.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        var comp = cal.dateComponents([.year, .month, .day], from: day)
        comp.hour = h
        comp.minute = m
        comp.second = 0
        return cal.date(from: comp)
    }
}
