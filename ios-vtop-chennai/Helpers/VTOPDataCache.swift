import Foundation

/// Persists VTOP snapshots to **disk** (Application Support) with optional migration from legacy `UserDefaults` blobs.
enum VTOPDataCache {
    private static let persistenceQueue = DispatchQueue(label: "com.vitconnect.cache-persistence", qos: .utility)
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private enum LegacyKey {
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
                studentProfile, gradeHistoryRows, courses, timetable,
                attendance, marks, cumulativeMarks, exams, staff,
                semesters, selectedSemester, attendanceSemesterOptions,
                marksReportSemesterOptions, marksReportRows, marksReportSemesterId,
                examScheduleSemesterOptions, examScheduleSemesterId,
                spotlights, receipts, scheduledEventRows, portalCredentials,
                rankEntries, deanPortraitData, hodPortraitData
            ]
        }
    }

    private enum FileName {
        static let studentProfile = "studentProfile.json"
        static let gradeHistoryRows = "gradeHistoryRows.json"
        static let courses = "courses.json"
        static let timetable = "timetable.json"
        static let attendance = "attendance.json"
        static let marks = "marks.json"
        static let cumulativeMarks = "cumulativeMarks.json"
        static let exams = "exams.json"
        static let staff = "staff.json"
        static let semesters = "semesters.json"
        static let selectedSemester = "selectedSemester.json"
        static let attendanceSemesterOptions = "attendanceSemesterOptions.json"
        static let marksReportSemesterOptions = "marksReportSemesterOptions.json"
        static let marksReportRows = "marksReportRows.json"
        static let examScheduleSemesterOptions = "examScheduleSemesterOptions.json"
        static let spotlights = "spotlights.json"
        static let receipts = "receipts.json"
        static let scheduledEventRows = "scheduledEventRows.json"
        static let portalCredentials = "portalCredentials.json"
        static let rankEntries = "rankEntries.json"
        static let deanPortrait = "deanPortrait.bin"
        static let hodPortrait = "hodPortrait.bin"
        static let coursesBySemester = "coursesBySemester.json"
        static let timetableBySemester = "timetableBySemester.json"
        static let marksBySemester = "marksBySemester.json"
        static let cumulativeMarksBySemester = "cumulativeMarksBySemester.json"
    }

    /// Removes persisted snapshots (disk + legacy UserDefaults).
    static func clearAll() {
        VTOPDiskCache.clearAllFiles()
        for key in LegacyKey.allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        for legacy in ["name", "cgpa", "totalCredits", "semester", "semesterId"] {
            UserDefaults.standard.removeObject(forKey: legacy)
        }
    }

    private static func loadFromDiskOrMigrate<T: Codable>(_ type: T.Type, file: String, legacyKey: String) -> T? {
        if let v: T = VTOPDiskCache.load(type, fileName: file) { return v }
        guard let data = UserDefaults.standard.data(forKey: legacyKey),
              let v = try? decoder.decode(T.self, from: data) else { return nil }
        VTOPDiskCache.save(v, fileName: file)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return v
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
        hodPortraitData: Data?,
        coursesBySemesterId: [String: [Course]],
        timetableBySemesterId: [String: [TimetableSlot]],
        marksBySemesterId: [String: [Mark]],
        cumulativeMarksBySemesterId: [String: [CumulativeMark]],
        synchronously: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        if !synchronously {
            persistenceQueue.async {
                persistSnapshot(
                    studentProfile: studentProfile,
                    gradeHistoryRows: gradeHistoryRows,
                    courses: courses,
                    timetable: timetable,
                    attendance: attendance,
                    marks: marks,
                    cumulativeMarks: cumulativeMarks,
                    exams: exams,
                    staff: staff,
                    semesters: semesters,
                    selectedSemester: selectedSemester,
                    attendanceSemesterOptions: attendanceSemesterOptions,
                    marksReportSemesterOptions: marksReportSemesterOptions,
                    marksReportRows: marksReportRows,
                    marksReportSemesterId: marksReportSemesterId,
                    examScheduleSemesterOptions: examScheduleSemesterOptions,
                    examScheduleSemesterId: examScheduleSemesterId,
                    spotlights: spotlights,
                    receipts: receipts,
                    scheduledEventRows: scheduledEventRows,
                    portalCredentials: portalCredentials,
                    rankEntries: rankEntries,
                    deanPortraitData: deanPortraitData,
                    hodPortraitData: hodPortraitData,
                    coursesBySemesterId: coursesBySemesterId,
                    timetableBySemesterId: timetableBySemesterId,
                    marksBySemesterId: marksBySemesterId,
                    cumulativeMarksBySemesterId: cumulativeMarksBySemesterId,
                    synchronously: true,
                    completion: completion
                )
            }
            return
        }

        defer {
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }

        func bucketOn(_ b: AppCacheSettings.VTOPBucket) -> Bool {
            AppCacheSettings.VTOPBucket.isEnabled(b)
        }

        if bucketOn(.profileSummary), let studentProfile {
            VTOPDiskCache.save(studentProfile, fileName: FileName.studentProfile)
        }
        if bucketOn(.marksAndGrades) {
            VTOPDiskCache.save(gradeHistoryRows, fileName: FileName.gradeHistoryRows)
        }
        if bucketOn(.academic) {
            VTOPDiskCache.save(courses, fileName: FileName.courses)
            VTOPDiskCache.save(timetable, fileName: FileName.timetable)
            VTOPDiskCache.save(attendance, fileName: FileName.attendance)
            VTOPDiskCache.save(semesters, fileName: FileName.semesters)
            if let selectedSemester { VTOPDiskCache.save(selectedSemester, fileName: FileName.selectedSemester) }
            VTOPDiskCache.save(attendanceSemesterOptions, fileName: FileName.attendanceSemesterOptions)
            VTOPDiskCache.save(coursesBySemesterId, fileName: FileName.coursesBySemester)
            VTOPDiskCache.save(timetableBySemesterId, fileName: FileName.timetableBySemester)
        }
        if bucketOn(.marksAndGrades) {
            VTOPDiskCache.save(marks, fileName: FileName.marks)
            VTOPDiskCache.save(cumulativeMarks, fileName: FileName.cumulativeMarks)
            VTOPDiskCache.save(marksReportSemesterOptions, fileName: FileName.marksReportSemesterOptions)
            VTOPDiskCache.save(marksReportRows, fileName: FileName.marksReportRows)
            VTOPDiskCache.save(marksBySemesterId, fileName: FileName.marksBySemester)
            VTOPDiskCache.save(cumulativeMarksBySemesterId, fileName: FileName.cumulativeMarksBySemester)
            if let marksReportSemesterId {
                UserDefaults.standard.set(marksReportSemesterId, forKey: LegacyKey.marksReportSemesterId)
            }
        }
        if bucketOn(.exams) {
            VTOPDiskCache.save(exams, fileName: FileName.exams)
            VTOPDiskCache.save(examScheduleSemesterOptions, fileName: FileName.examScheduleSemesterOptions)
            if let examScheduleSemesterId {
                UserDefaults.standard.set(examScheduleSemesterId, forKey: LegacyKey.examScheduleSemesterId)
            }
        }
        if bucketOn(.campusExtras) {
            VTOPDiskCache.save(staff, fileName: FileName.staff)
            VTOPDiskCache.save(spotlights, fileName: FileName.spotlights)
            VTOPDiskCache.save(scheduledEventRows, fileName: FileName.scheduledEventRows)
            VTOPDiskCache.save(portalCredentials, fileName: FileName.portalCredentials)
            VTOPDiskCache.save(rankEntries, fileName: FileName.rankEntries)
            VTOPDiskCache.saveData(deanPortraitData, fileName: FileName.deanPortrait)
            VTOPDiskCache.saveData(hodPortraitData, fileName: FileName.hodPortrait)
        }
        if bucketOn(.receipts) {
            VTOPDiskCache.save(receipts, fileName: FileName.receipts)
        }

        for k in LegacyKey.allKeys {
            UserDefaults.standard.removeObject(forKey: k)
        }

        // `LegacyKey.allKeys` includes these string IDs; the loop above would erase them right after we set them.
        // Restore so Exam Schedule / marks-by-semester remember which term the cached rows belong to.
        if bucketOn(.marksAndGrades), let id = marksReportSemesterId, !id.isEmpty {
            UserDefaults.standard.set(id, forKey: LegacyKey.marksReportSemesterId)
        }
        if bucketOn(.exams), let id = examScheduleSemesterId, !id.isEmpty {
            UserDefaults.standard.set(id, forKey: LegacyKey.examScheduleSemesterId)
        }

        if bucketOn(.profileSummary), let p = studentProfile {
            UserDefaults.standard.set(p.name, forKey: "name")
            UserDefaults.standard.set(p.cgpa, forKey: "cgpa")
            UserDefaults.standard.set(p.totalCredits, forKey: "totalCredits")
            if let s = p.semester { UserDefaults.standard.set(s, forKey: "semester") }
        }
        if bucketOn(.academic), let sel = selectedSemester {
            UserDefaults.standard.set(sel.id, forKey: "semesterId")
            UserDefaults.standard.set(sel.name, forKey: "semester")
        }

        VTOPDiskCache.writeMeta(lastPersistedAt: Date())
    }

    /// Removes on-disk VTOP files + related `UserDefaults` keys for one bucket (e.g. when the user turns caching off).
    static func clearVTOPBucket(_ bucket: AppCacheSettings.VTOPBucket) {
        switch bucket {
        case .profileSummary:
            VTOPDiskCache.removeFile(fileName: FileName.studentProfile)
            UserDefaults.standard.removeObject(forKey: LegacyKey.studentProfile)
            for k in ["name", "cgpa", "totalCredits"] as [String] { UserDefaults.standard.removeObject(forKey: k) }
        case .academic:
            for f in [
                FileName.courses, FileName.timetable, FileName.attendance, FileName.semesters,
                FileName.selectedSemester, FileName.attendanceSemesterOptions,
                FileName.coursesBySemester, FileName.timetableBySemester
            ] { VTOPDiskCache.removeFile(fileName: f) }
            for k in [
                LegacyKey.courses, LegacyKey.timetable, LegacyKey.attendance, LegacyKey.semesters,
                LegacyKey.selectedSemester, LegacyKey.attendanceSemesterOptions
            ] { UserDefaults.standard.removeObject(forKey: k) }
            UserDefaults.standard.removeObject(forKey: "semesterId")
            UserDefaults.standard.removeObject(forKey: "semester")
        case .marksAndGrades:
            for f in [
                FileName.gradeHistoryRows, FileName.marks, FileName.cumulativeMarks,
                FileName.marksReportSemesterOptions, FileName.marksReportRows,
                FileName.marksBySemester, FileName.cumulativeMarksBySemester
            ] { VTOPDiskCache.removeFile(fileName: f) }
            for k in [
                LegacyKey.gradeHistoryRows, LegacyKey.marks, LegacyKey.cumulativeMarks,
                LegacyKey.marksReportSemesterOptions, LegacyKey.marksReportRows,
                LegacyKey.marksReportSemesterId
            ] { UserDefaults.standard.removeObject(forKey: k) }
        case .exams:
            for f in [FileName.exams, FileName.examScheduleSemesterOptions] { VTOPDiskCache.removeFile(fileName: f) }
            for k in [LegacyKey.exams, LegacyKey.examScheduleSemesterOptions, LegacyKey.examScheduleSemesterId] {
                UserDefaults.standard.removeObject(forKey: k)
            }
        case .receipts:
            VTOPDiskCache.removeFile(fileName: FileName.receipts)
            UserDefaults.standard.removeObject(forKey: LegacyKey.receipts)
        case .campusExtras:
            for f in [
                FileName.staff, FileName.spotlights, FileName.scheduledEventRows,
                FileName.portalCredentials, FileName.rankEntries, FileName.deanPortrait, FileName.hodPortrait
            ] { VTOPDiskCache.removeFile(fileName: f) }
            for k in [
                LegacyKey.staff, LegacyKey.spotlights, LegacyKey.scheduledEventRows,
                LegacyKey.portalCredentials, LegacyKey.rankEntries, LegacyKey.deanPortraitData, LegacyKey.hodPortraitData
            ] { UserDefaults.standard.removeObject(forKey: k) }
        }
    }

    /// Loads cache off the main thread, then applies on `MainActor`.
    static func restoreInto(_ dm: DataManager, shouldApply: @escaping @MainActor () -> Bool = { true }) {
        Task.detached(priority: .userInitiated) {
            func bucketOn(_ b: AppCacheSettings.VTOPBucket) -> Bool {
                AppCacheSettings.VTOPBucket.isEnabled(b)
            }

            let profile: StudentProfile? = bucketOn(.profileSummary)
                ? (loadFromDiskOrMigrate(
                    StudentProfile.self,
                    file: FileName.studentProfile,
                    legacyKey: LegacyKey.studentProfile
                ) ?? {
                    if let name = UserDefaults.standard.string(forKey: "name") {
                        let cgpa = UserDefaults.standard.double(forKey: "cgpa")
                        let totalCredits = UserDefaults.standard.double(forKey: "totalCredits")
                        let semester = UserDefaults.standard.string(forKey: "semester")
                        return StudentProfile(name: name, cgpa: cgpa, totalCredits: totalCredits, semester: semester)
                    }
                    return nil
                }())
                : nil

            let gradeHistoryRows: [GradeHistoryCourseRow] = bucketOn(.marksAndGrades)
                ? (loadFromDiskOrMigrate(
                    [GradeHistoryCourseRow].self,
                    file: FileName.gradeHistoryRows,
                    legacyKey: LegacyKey.gradeHistoryRows
                ) ?? [])
                : []
            let courses: [Course] = bucketOn(.academic)
                ? (loadFromDiskOrMigrate([Course].self, file: FileName.courses, legacyKey: LegacyKey.courses) ?? [])
                : []
            let timetable: [TimetableSlot] = bucketOn(.academic)
                ? (loadFromDiskOrMigrate([TimetableSlot].self, file: FileName.timetable, legacyKey: LegacyKey.timetable) ?? [])
                : []
            let attendance: [Attendance] = bucketOn(.academic)
                ? (loadFromDiskOrMigrate([Attendance].self, file: FileName.attendance, legacyKey: LegacyKey.attendance) ?? [])
                : []
            let marks: [Mark] = bucketOn(.marksAndGrades)
                ? (loadFromDiskOrMigrate([Mark].self, file: FileName.marks, legacyKey: LegacyKey.marks) ?? [])
                : []
            let cumulativeMarks: [CumulativeMark] = bucketOn(.marksAndGrades)
                ? (loadFromDiskOrMigrate([CumulativeMark].self, file: FileName.cumulativeMarks, legacyKey: LegacyKey.cumulativeMarks) ?? [])
                : []
            let exams: [Exam] = bucketOn(.exams)
                ? (loadFromDiskOrMigrate([Exam].self, file: FileName.exams, legacyKey: LegacyKey.exams) ?? [])
                : []
            let staff: [Staff] = bucketOn(.campusExtras)
                ? (loadFromDiskOrMigrate([Staff].self, file: FileName.staff, legacyKey: LegacyKey.staff) ?? [])
                : []
            let semesters: [Semester] = bucketOn(.academic)
                ? (loadFromDiskOrMigrate([Semester].self, file: FileName.semesters, legacyKey: LegacyKey.semesters) ?? [])
                : []
            let selectedSemester: Semester? = bucketOn(.academic)
                ? loadFromDiskOrMigrate(Semester.self, file: FileName.selectedSemester, legacyKey: LegacyKey.selectedSemester)
                : nil
            let attendanceSemesterOptions: [Semester] = bucketOn(.academic)
                ? (loadFromDiskOrMigrate([Semester].self, file: FileName.attendanceSemesterOptions, legacyKey: LegacyKey.attendanceSemesterOptions) ?? [])
                : []
            let marksReportSemesterOptions: [Semester] = bucketOn(.marksAndGrades)
                ? (loadFromDiskOrMigrate([Semester].self, file: FileName.marksReportSemesterOptions, legacyKey: LegacyKey.marksReportSemesterOptions) ?? [])
                : []
            let marksReportRows: [MarkReportRow] = bucketOn(.marksAndGrades)
                ? (loadFromDiskOrMigrate([MarkReportRow].self, file: FileName.marksReportRows, legacyKey: LegacyKey.marksReportRows) ?? [])
                : []
            let examScheduleSemesterOptions: [Semester] = bucketOn(.exams)
                ? (loadFromDiskOrMigrate([Semester].self, file: FileName.examScheduleSemesterOptions, legacyKey: LegacyKey.examScheduleSemesterOptions) ?? [])
                : []
            let spotlights: [Spotlight] = bucketOn(.campusExtras)
                ? (loadFromDiskOrMigrate([Spotlight].self, file: FileName.spotlights, legacyKey: LegacyKey.spotlights) ?? [])
                : []
            let receipts: [Receipt] = bucketOn(.receipts)
                ? (loadFromDiskOrMigrate([Receipt].self, file: FileName.receipts, legacyKey: LegacyKey.receipts) ?? [])
                : []
            let scheduledEventRows: [VTOPScheduledEventRow] = bucketOn(.campusExtras)
                ? (loadFromDiskOrMigrate([VTOPScheduledEventRow].self, file: FileName.scheduledEventRows, legacyKey: LegacyKey.scheduledEventRows) ?? [])
                : []
            let portalCredentials: [VTOPPortalCredential] = bucketOn(.campusExtras)
                ? (loadFromDiskOrMigrate([VTOPPortalCredential].self, file: FileName.portalCredentials, legacyKey: LegacyKey.portalCredentials) ?? [])
                : []
            let rankEntries: [VTOPRankEntry] = bucketOn(.campusExtras)
                ? (loadFromDiskOrMigrate([VTOPRankEntry].self, file: FileName.rankEntries, legacyKey: LegacyKey.rankEntries) ?? [])
                : []
            let coursesBySemesterId: [String: [Course]] = bucketOn(.academic)
                ? (VTOPDiskCache.load([String: [Course]].self, fileName: FileName.coursesBySemester) ?? [:])
                : [:]
            let timetableBySemesterId: [String: [TimetableSlot]] = bucketOn(.academic)
                ? (VTOPDiskCache.load([String: [TimetableSlot]].self, fileName: FileName.timetableBySemester) ?? [:])
                : [:]
            let marksBySemesterId: [String: [Mark]] = bucketOn(.marksAndGrades)
                ? (VTOPDiskCache.load([String: [Mark]].self, fileName: FileName.marksBySemester) ?? [:])
                : [:]
            let cumulativeMarksBySemesterId: [String: [CumulativeMark]] = bucketOn(.marksAndGrades)
                ? (VTOPDiskCache.load([String: [CumulativeMark]].self, fileName: FileName.cumulativeMarksBySemester) ?? [:])
                : [:]

            let marksReportSemesterId = bucketOn(.marksAndGrades)
                ? UserDefaults.standard.string(forKey: LegacyKey.marksReportSemesterId)
                : nil
            let examScheduleSemesterId = bucketOn(.exams)
                ? UserDefaults.standard.string(forKey: LegacyKey.examScheduleSemesterId)
                : nil
            let deanPortraitData = bucketOn(.campusExtras)
                ? (VTOPDiskCache.loadData(fileName: FileName.deanPortrait)
                    ?? UserDefaults.standard.data(forKey: LegacyKey.deanPortraitData))
                : nil
            let hodPortraitData = bucketOn(.campusExtras)
                ? (VTOPDiskCache.loadData(fileName: FileName.hodPortrait)
                    ?? UserDefaults.standard.data(forKey: LegacyKey.hodPortraitData))
                : nil

            let meta = VTOPDiskCache.readMeta()
            let marksBucketOn = bucketOn(.marksAndGrades)
            let examsBucketOn = bucketOn(.exams)
            await MainActor.run {
                guard shouldApply() else { return }
                dm.studentProfile = profile
                dm.gradeHistoryRows = gradeHistoryRows
                dm.courses = courses
                dm.timetable = timetable
                dm.attendance = attendance
                dm.marks = marks
                dm.cumulativeMarks = cumulativeMarks
                dm.exams = exams
                dm.staff = staff
                dm.semesters = semesters
                dm.selectedSemester = selectedSemester
                dm.attendanceSemesterOptions = attendanceSemesterOptions
                dm.marksReportSemesterOptions = marksReportSemesterOptions
                dm.marksReportRows = marksReportRows
                if marksBucketOn, let sid = marksReportSemesterId, !sid.isEmpty { dm.marksReportSemesterId = sid }
                if !marksBucketOn { dm.marksReportSemesterId = nil }
                dm.examScheduleSemesterOptions = examScheduleSemesterOptions
                if examsBucketOn, let sid = examScheduleSemesterId, !sid.isEmpty { dm.examScheduleSemesterId = sid }
                if !examsBucketOn { dm.examScheduleSemesterId = nil }
                dm.spotlights = spotlights
                dm.receipts = receipts
                dm.scheduledEventRows = scheduledEventRows
                dm.portalCredentials = portalCredentials
                dm.rankEntries = rankEntries
                dm.deanPortraitData = deanPortraitData
                dm.hodPortraitData = hodPortraitData
                dm.restoreSemesterScopedCache(coursesBySemesterId: coursesBySemesterId, timetableBySemesterId: timetableBySemesterId, marksBySemesterId: marksBySemesterId, cumulativeMarksBySemesterId: cumulativeMarksBySemesterId)
                dm.syncState.cachePersistedAt = meta.lastPersistedAt
            }
        }
    }
}
