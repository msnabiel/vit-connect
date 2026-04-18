import Foundation

/// JSON snapshots in `UserDefaults` for offline / faster startup after sync.
enum VTOPDataCache {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
    private static let decoder = JSONDecoder()

    private enum Key {
        static let studentProfile = "vtop_cache_studentProfile_v1"
        static let gradeHistoryRows = "vtop_cache_gradeHistoryRows_v1"
        static let courses = "vtop_cache_courses_v1"
        static let timetable = "vtop_cache_timetable_v1"
        static let attendance = "vtop_cache_attendance_v1"
        static let marks = "vtop_cache_marks_v1"
        static let cumulativeMarks = "vtop_cache_cumulativeMarks_v1"
        static let exams = "vtop_cache_exams_v1"
        static let staff = "vtop_cache_staff_v1"
        static let semesters = "vtop_cache_semesters_v1"
        static let selectedSemester = "vtop_cache_selectedSemester_v1"
        static let attendanceSemesterOptions = "vtop_cache_attendanceSemesterOptions_v1"
        static let marksReportSemesterOptions = "vtop_cache_marksReportSemesterOptions_v1"
        static let marksReportRows = "vtop_cache_marksReportRows_v1"
        static let marksReportSemesterId = "vtop_cache_marksReportSemesterId_v1"
        static let examScheduleSemesterOptions = "vtop_cache_examScheduleSemesterOptions_v1"
        static let examScheduleSemesterId = "vtop_cache_examScheduleSemesterId_v1"
        static let spotlights = "vtop_cache_spotlights_v1"
        static let receipts = "vtop_cache_receipts_v1"
        static let scheduledEventRows = "vtop_cache_scheduledEventRows_v1"
        static let portalCredentials = "vtop_cache_portalCredentials_v1"
        static let rankEntries = "vtop_cache_rankEntries_v1"
        static let deanPortraitData = "vtop_cache_deanPortraitData_v1"
        static let hodPortraitData = "vtop_cache_hodPortraitData_v1"

        static var allKeys: [String] {
            [
                Key.studentProfile, Key.gradeHistoryRows, Key.courses, Key.timetable,
                Key.attendance, Key.marks, Key.cumulativeMarks, Key.exams, Key.staff,
                Key.semesters, Key.selectedSemester, Key.attendanceSemesterOptions,
                Key.marksReportSemesterOptions, Key.marksReportRows, Key.marksReportSemesterId,
                Key.examScheduleSemesterOptions, Key.examScheduleSemesterId,
                Key.spotlights, Key.receipts, Key.scheduledEventRows, Key.portalCredentials,
                Key.rankEntries, Key.deanPortraitData, Key.hodPortraitData
            ]
        }
    }

    /// Removes all persisted VTOP snapshot keys (login session is unchanged).
    static func clearAll() {
        for key in Key.allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        for legacy in ["name", "cgpa", "totalCredits", "semester", "semesterId"] {
            UserDefaults.standard.removeObject(forKey: legacy)
        }
    }

    static func save<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? encoder.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    static func saveData(_ data: Data?, key: String) {
        if let data {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func loadData(key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }

    static func persistSnapshot(
        studentProfile: StudentProfile?,
        gradeHistoryRows: [GradeHistoryCourseRow],
        courses: [Course],
        timetable: [TimetableSlot],
        attendance: [Attendance],
        marks: [Mark],
        cumulativeMarks: [CumulativeMark],
        exams: [Exam],
        staff: [Staff],
        semesters: [Semester],
        selectedSemester: Semester?,
        attendanceSemesterOptions: [Semester],
        marksReportSemesterOptions: [Semester],
        marksReportRows: [MarkReportRow],
        marksReportSemesterId: String?,
        examScheduleSemesterOptions: [Semester],
        examScheduleSemesterId: String?,
        spotlights: [Spotlight],
        receipts: [Receipt],
        scheduledEventRows: [VTOPScheduledEventRow],
        portalCredentials: [VTOPPortalCredential],
        rankEntries: [VTOPRankEntry],
        deanPortraitData: Data?,
        hodPortraitData: Data?
    ) {
        if let studentProfile { save(studentProfile, for: Key.studentProfile) }
        save(gradeHistoryRows, for: Key.gradeHistoryRows)
        save(courses, for: Key.courses)
        save(timetable, for: Key.timetable)
        save(attendance, for: Key.attendance)
        save(marks, for: Key.marks)
        save(cumulativeMarks, for: Key.cumulativeMarks)
        save(exams, for: Key.exams)
        save(staff, for: Key.staff)
        save(semesters, for: Key.semesters)
        if let selectedSemester { save(selectedSemester, for: Key.selectedSemester) }
        save(attendanceSemesterOptions, for: Key.attendanceSemesterOptions)
        save(marksReportSemesterOptions, for: Key.marksReportSemesterOptions)
        save(marksReportRows, for: Key.marksReportRows)
        if let marksReportSemesterId {
            UserDefaults.standard.set(marksReportSemesterId, forKey: Key.marksReportSemesterId)
        }
        save(examScheduleSemesterOptions, for: Key.examScheduleSemesterOptions)
        if let examScheduleSemesterId {
            UserDefaults.standard.set(examScheduleSemesterId, forKey: Key.examScheduleSemesterId)
        }
        save(spotlights, for: Key.spotlights)
        save(receipts, for: Key.receipts)
        save(scheduledEventRows, for: Key.scheduledEventRows)
        save(portalCredentials, for: Key.portalCredentials)
        save(rankEntries, for: Key.rankEntries)
        saveData(deanPortraitData, key: Key.deanPortraitData)
        saveData(hodPortraitData, key: Key.hodPortraitData)

        // Legacy keys used elsewhere
        if let p = studentProfile {
            UserDefaults.standard.set(p.name, forKey: "name")
            UserDefaults.standard.set(p.cgpa, forKey: "cgpa")
            UserDefaults.standard.set(p.totalCredits, forKey: "totalCredits")
            if let s = p.semester { UserDefaults.standard.set(s, forKey: "semester") }
        }
        if let sel = selectedSemester {
            UserDefaults.standard.set(sel.id, forKey: "semesterId")
            UserDefaults.standard.set(sel.name, forKey: "semester")
        }
    }

    static func restoreInto(_ dm: DataManager) {
        DispatchQueue.main.async {
            if let p: StudentProfile = load(StudentProfile.self, key: Key.studentProfile) {
                dm.studentProfile = p
            } else if let name = UserDefaults.standard.string(forKey: "name") {
                let cgpa = UserDefaults.standard.double(forKey: "cgpa")
                let totalCredits = UserDefaults.standard.double(forKey: "totalCredits")
                let semester = UserDefaults.standard.string(forKey: "semester")
                dm.studentProfile = StudentProfile(
                    name: name,
                    cgpa: cgpa,
                    totalCredits: totalCredits,
                    semester: semester
                )
            }

            if let v = load([GradeHistoryCourseRow].self, key: Key.gradeHistoryRows) { dm.gradeHistoryRows = v }
            if let v = load([Course].self, key: Key.courses) { dm.courses = v }
            if let v = load([TimetableSlot].self, key: Key.timetable) { dm.timetable = v }
            if let v = load([Attendance].self, key: Key.attendance) { dm.attendance = v }
            if let v = load([Mark].self, key: Key.marks) { dm.marks = v }
            if let v = load([CumulativeMark].self, key: Key.cumulativeMarks) { dm.cumulativeMarks = v }
            if let v = load([Exam].self, key: Key.exams) { dm.exams = v }
            if let v = load([Staff].self, key: Key.staff) { dm.staff = v }
            if let v = load([Semester].self, key: Key.semesters) { dm.semesters = v }
            if let v = load(Semester.self, key: Key.selectedSemester) { dm.selectedSemester = v }
            if let v = load([Semester].self, key: Key.attendanceSemesterOptions) { dm.attendanceSemesterOptions = v }
            if let v = load([Semester].self, key: Key.marksReportSemesterOptions) { dm.marksReportSemesterOptions = v }
            if let v = load([MarkReportRow].self, key: Key.marksReportRows) { dm.marksReportRows = v }
            if let sid = UserDefaults.standard.string(forKey: Key.marksReportSemesterId), !sid.isEmpty {
                dm.marksReportSemesterId = sid
            }
            if let v = load([Semester].self, key: Key.examScheduleSemesterOptions) { dm.examScheduleSemesterOptions = v }
            if let sid = UserDefaults.standard.string(forKey: Key.examScheduleSemesterId), !sid.isEmpty {
                dm.examScheduleSemesterId = sid
            }
            if let v = load([Spotlight].self, key: Key.spotlights) { dm.spotlights = v }
            if let v = load([Receipt].self, key: Key.receipts) { dm.receipts = v }
            if let v = load([VTOPScheduledEventRow].self, key: Key.scheduledEventRows) { dm.scheduledEventRows = v }
            if let v = load([VTOPPortalCredential].self, key: Key.portalCredentials) { dm.portalCredentials = v }
            if let v = load([VTOPRankEntry].self, key: Key.rankEntries) { dm.rankEntries = v }
            dm.deanPortraitData = loadData(key: Key.deanPortraitData)
            dm.hodPortraitData = loadData(key: Key.hodPortraitData)
        }
    }
}
