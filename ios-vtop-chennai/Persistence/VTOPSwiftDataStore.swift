import Foundation
import SwiftData

/// Durable, queryable academic snapshot. Arrays remain encoded so the first
/// migration does not duplicate every existing VTOP value type as a database model.
@Model
final class VTOPSemesterSnapshotRecord {
    @Attribute(.unique) var semesterID: String
    var semesterName: String
    var fetchedAt: Date
    var coursesData: Data
    var timetableData: Data
    var attendanceData: Data
    var marksData: Data
    var cumulativeMarksData: Data
    var examsData: Data
    var marksReportRowsData: Data

    init(
        semesterID: String,
        semesterName: String,
        fetchedAt: Date = Date(),
        coursesData: Data = Data(),
        timetableData: Data = Data(),
        attendanceData: Data = Data(),
        marksData: Data = Data(),
        cumulativeMarksData: Data = Data(),
        examsData: Data = Data(),
        marksReportRowsData: Data = Data()
    ) {
        self.semesterID = semesterID
        self.semesterName = semesterName
        self.fetchedAt = fetchedAt
        self.coursesData = coursesData
        self.timetableData = timetableData
        self.attendanceData = attendanceData
        self.marksData = marksData
        self.cumulativeMarksData = cumulativeMarksData
        self.examsData = examsData
        self.marksReportRowsData = marksReportRowsData
    }
}

/// SwiftData bridge for semester-scoped VTOP data.
///
/// The legacy JSON cache remains authoritative during the migration window.
/// This store is deliberately isolated so future search, reminders, and history
/// features can query records without coupling views to DataManager arrays.
final class VTOPSwiftDataStore {
    static let shared = VTOPSwiftDataStore()

    let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(inMemory: Bool = false) {
        do {
            let configuration = ModelConfiguration(
                "VITConnectAcademic",
                isStoredInMemoryOnly: inMemory
            )
            container = try ModelContainer(
                for: VTOPSemesterSnapshotRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to initialize SwiftData academic store: \(error)")
        }
    }

    func upsert(
        semester: Semester,
        courses: [Course],
        timetable: [TimetableSlot],
        attendance: [Attendance],
        marks: [Mark],
        cumulativeMarks: [CumulativeMark],
        exams: [Exam],
        marksReportRows: [MarkReportRow],
        fetchedAt: Date = Date()
    ) {
        let context = ModelContext(container)
        let record = (try? context.fetch(FetchDescriptor<VTOPSemesterSnapshotRecord>()))?
            .first { $0.semesterID == semester.id }
            ?? VTOPSemesterSnapshotRecord(semesterID: semester.id, semesterName: semester.name)

        record.semesterName = semester.name
        record.fetchedAt = fetchedAt
        record.coursesData = encode(courses)
        record.timetableData = encode(timetable)
        record.attendanceData = encode(attendance)
        record.marksData = encode(marks)
        record.cumulativeMarksData = encode(cumulativeMarks)
        record.examsData = encode(exams)
        record.marksReportRowsData = encode(marksReportRows)

        if record.modelContext == nil { context.insert(record) }
        try? context.save()
    }

    /// Imports existing semester maps once, without replacing newer SwiftData records.
    func importLegacySemesterCachesIfNeeded() {
        let context = ModelContext(container)
        let existing = (try? context.fetch(FetchDescriptor<VTOPSemesterSnapshotRecord>())) ?? []
        let existingIDs = Set(existing.map(\.semesterID))
        let coursesBySemester = VTOPDiskCache.load([String: [Course]].self, fileName: "coursesBySemester.json") ?? [:]
        let timetableBySemester = VTOPDiskCache.load([String: [TimetableSlot]].self, fileName: "timetableBySemester.json") ?? [:]
        let marksBySemester = VTOPDiskCache.load([String: [Mark]].self, fileName: "marksBySemester.json") ?? [:]
        let cumulativeBySemester = VTOPDiskCache.load([String: [CumulativeMark]].self, fileName: "cumulativeMarksBySemester.json") ?? [:]
        let ids = Set(coursesBySemester.keys)
            .union(timetableBySemester.keys)
            .union(marksBySemester.keys)
            .union(cumulativeBySemester.keys)

        for id in ids where !existingIDs.contains(id) {
            let record = VTOPSemesterSnapshotRecord(
                semesterID: id,
                semesterName: id,
                coursesData: encode(coursesBySemester[id] ?? []),
                timetableData: encode(timetableBySemester[id] ?? []),
                marksData: encode(marksBySemester[id] ?? []),
                cumulativeMarksData: encode(cumulativeBySemester[id] ?? [])
            )
            context.insert(record)
        }
        try? context.save()
    }

    func deleteAll() {
        let context = ModelContext(container)
        let records = (try? context.fetch(FetchDescriptor<VTOPSemesterSnapshotRecord>())) ?? []
        records.forEach(context.delete)
        try? context.save()
    }

    /// Returns only semester snapshots that were actually fetched and persisted.
    /// This is the read-side bridge used while the remaining legacy cache fields migrate.
    func semesterCaches() -> (
        courses: [String: [Course]],
        timetable: [String: [TimetableSlot]],
        marks: [String: [Mark]],
        cumulativeMarks: [String: [CumulativeMark]]
    ) {
        let context = ModelContext(container)
        let records = (try? context.fetch(FetchDescriptor<VTOPSemesterSnapshotRecord>())) ?? []
        var courses: [String: [Course]] = [:]
        var timetable: [String: [TimetableSlot]] = [:]
        var marks: [String: [Mark]] = [:]
        var cumulativeMarks: [String: [CumulativeMark]] = [:]
        for record in records {
            if let value = decode([Course].self, from: record.coursesData) { courses[record.semesterID] = value }
            if let value = decode([TimetableSlot].self, from: record.timetableData) { timetable[record.semesterID] = value }
            if let value = decode([Mark].self, from: record.marksData) { marks[record.semesterID] = value }
            if let value = decode([CumulativeMark].self, from: record.cumulativeMarksData) { cumulativeMarks[record.semesterID] = value }
        }
        return (courses, timetable, marks, cumulativeMarks)
    }

    private func encode<T: Encodable>(_ value: T) -> Data {
        (try? encoder.encode(value)) ?? Data()
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? decoder.decode(type, from: data)
    }
}
