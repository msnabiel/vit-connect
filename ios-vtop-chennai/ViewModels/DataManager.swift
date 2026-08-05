import Foundation
import WebKit
import Combine

class DataManager: ObservableObject {
    let syncState = DataManagerSyncState()

    // MARK: - Published Properties
    @Published var studentProfile: StudentProfile?
    @Published var courses: [Course] = []
    @Published var timetable: [TimetableSlot] = []
    @Published var attendance: [Attendance] = []
    @Published var marks: [Mark] = []
    @Published var cumulativeMarks: [CumulativeMark] = []
    @Published var exams: [Exam] = []
    @Published var staff: [Staff] = []
    @Published var spotlights: [Spotlight] = []
    @Published var receipts: [Receipt] = []
    /// Campus calendar from `/vtop/get/scheduled/events`.
    @Published var scheduledEventRows: [VTOPScheduledEventRow] = []
    @Published var semesters: [Semester] = []
    @Published var selectedSemester: Semester?

    /// Semester options from `academics/common/StudentAttendance` (attendance dropdown; may include more terms than timetable).
    @Published var attendanceSemesterOptions: [Semester] = []

    /// Semester options from `examinations/StudentMarkView` (marks report; independent of `marks` from sync chain).
    @Published var marksReportSemesterOptions: [Semester] = []
    @Published var marksReportRows: [MarkReportRow] = []
    /// Last `semesterSubId` used for marks-by-semester (persisted for restore).
    @Published var marksReportSemesterId: String?

    /// Semester options from `examinations/StudExamSchedule` (exam schedule dropdown).
    @Published var examScheduleSemesterOptions: [Semester] = []
    /// Last `semesterSubId` chosen on the exam schedule screen (persisted).
    @Published var examScheduleSemesterId: String?

    /// All-semester grade rows from `StudentGradeHistory` (distinct from semester `cumulativeMarks`).
    @Published var gradeHistoryRows: [GradeHistoryCourseRow] = []
    @Published var portalCredentials: [VTOPPortalCredential] = []
    @Published var rankEntries: [VTOPRankEntry] = []

    /// Base64-decoded JPEG/PNG from HoD/Dean `viewHodDeanDetails` table images (optional).
    @Published var deanPortraitData: Data?
    @Published var hodPortraitData: Data?

    /// Called when the WebView session cannot be extracted (expired session, blank page, etc.).
    /// The `AuthenticationViewModel` can attach a handler to attempt auto re-login.
    var onSessionExpired: (() -> Void)?

    // MARK: - Private Properties
    private weak var webView: WKWebView?
    private let logger = VTOPLogger.shared
    private var authorizedID: String?
    private var csrfToken: String?
    private var syncDebounceItem: DispatchWorkItem?
    private var cachePersistenceWorkItem: DispatchWorkItem?
    private var cachePersistenceGeneration = UUID()
    /// Fires if a manual full sync stays in the loading state too long (hung WebView JS, network, etc.).
    private var fullSyncStallWatchdogItem: DispatchWorkItem?
    private var refreshIntentObserver: NSObjectProtocol?
    private var coursesBySemesterId: [String: [Course]] = [:]
    private var timetableBySemesterId: [String: [TimetableSlot]] = [:]
    private var marksBySemesterId: [String: [Mark]] = [:]
    private var cumulativeMarksBySemesterId: [String: [CumulativeMark]] = [:]
    private var cacheRestoreGeneration = UUID()
    /// Set for the lifetime of one `extractSessionData` → … → `finishDataFetching` chain. Only `performSyncAll` starts a chain with this true so post-login fetches never touch UserDefaults quota.
    private var countsCurrentSessionTowardManualFullSyncQuota = false

    /// Rolling window for manual full-sync completions recorded in `finishDataFetching` when `countsCurrentSessionTowardManualFullSyncQuota` is true.
    private static let fullSyncQuotaWindow: TimeInterval = 3600
    private static let fullSyncQuotaMaxPerWindow = 3
    /// Manual full sync / session extraction should not spin indefinitely in the UI.
    private static let fullSyncStallTimeout: TimeInterval = 60
    static let signInOrSyncStallUserMessage = "Could not sign in or finish syncing in time. Please sign out and sign in again, or try Full Sync again."
    private static let fullSyncCompletionTimesKey = "vtop_fullSyncCompletionTimes"
    /// Legacy single-date key (migrated into `fullSyncCompletionTimesKey`).
    private static let legacyLastFullSyncCompletedAtKey = "vtop_lastFullSyncCompletedAt"

    private static func migrateLegacyFullSyncStorageIfNeeded() {
        guard let legacy = UserDefaults.standard.object(forKey: legacyLastFullSyncCompletedAtKey) as? Date else { return }
        var intervals = (UserDefaults.standard.array(forKey: fullSyncCompletionTimesKey) as? [TimeInterval]) ?? []
        intervals.append(legacy.timeIntervalSince1970)
        UserDefaults.standard.set(intervals.sorted(), forKey: fullSyncCompletionTimesKey)
        UserDefaults.standard.removeObject(forKey: legacyLastFullSyncCompletedAtKey)
    }

    private static func storedFullSyncCompletionIntervals() -> [TimeInterval] {
        migrateLegacyFullSyncStorageIfNeeded()
        return (UserDefaults.standard.array(forKey: fullSyncCompletionTimesKey) as? [TimeInterval]) ?? []
    }

    private static func saveFullSyncCompletionIntervals(_ intervals: [TimeInterval]) {
        UserDefaults.standard.set(intervals, forKey: fullSyncCompletionTimesKey)
    }

    /// Successful full syncs completed within the last hour (sorted oldest → newest).
    private static func prunedFullSyncCompletionDates(reference: Date = Date()) -> [Date] {
        let cutoff = reference.addingTimeInterval(-fullSyncQuotaWindow)
        return storedFullSyncCompletionIntervals()
            .map { Date(timeIntervalSince1970: $0) }
            .filter { $0 >= cutoff }
            .sorted()
    }

    private static func recordFullSyncCompleted(at date: Date = Date()) {
        let cutoff = date.addingTimeInterval(-fullSyncQuotaWindow)
        var dates = storedFullSyncCompletionIntervals()
            .map { Date(timeIntervalSince1970: $0) }
            .filter { $0 >= cutoff }
        dates.append(date)
        saveFullSyncCompletionIntervals(dates.map { $0.timeIntervalSince1970 }.sorted())
    }

    private static func clearFullSyncQuotaStorage() {
        UserDefaults.standard.removeObject(forKey: fullSyncCompletionTimesKey)
        UserDefaults.standard.removeObject(forKey: legacyLastFullSyncCompletedAtKey)
    }

    private static func formattedCooldownRemaining(_ timeRemaining: TimeInterval) -> String {
        let total = max(0, Int(ceil(timeRemaining)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h) hour\(h == 1 ? "" : "s") \(m) minute\(m == 1 ? "" : "s")"
        }
        if m > 0 {
            return "\(m) minute\(m == 1 ? "" : "s") \(s) second\(s == 1 ? "" : "s")"
        }
        return "\(s) second\(s == 1 ? "" : "s")"
    }

    private func cacheCurrentSemesterScheduleIfNeeded() {
        guard let semesterId = selectedSemester?.id, !semesterId.isEmpty else { return }
        coursesBySemesterId[semesterId] = courses
        timetableBySemesterId[semesterId] = timetable
        if !marks.isEmpty { marksBySemesterId[semesterId] = marks }
        if !cumulativeMarks.isEmpty { cumulativeMarksBySemesterId[semesterId] = cumulativeMarks }
    }

    func restoreSemesterScopedCache(
        coursesBySemesterId: [String: [Course]],
        timetableBySemesterId: [String: [TimetableSlot]],
        marksBySemesterId: [String: [Mark]] = [:],
        cumulativeMarksBySemesterId: [String: [CumulativeMark]] = [:]
    ) {
        self.coursesBySemesterId = coursesBySemesterId
        self.timetableBySemesterId = timetableBySemesterId
        self.marksBySemesterId = marksBySemesterId
        self.cumulativeMarksBySemesterId = cumulativeMarksBySemesterId

        guard let semesterId = selectedSemester?.id, !semesterId.isEmpty else { return }
        if let semCourses = coursesBySemesterId[semesterId] {
            courses = semCourses
        }
        if let semTimetable = timetableBySemesterId[semesterId] {
            timetable = semTimetable
        }
        if let semMarks = marksBySemesterId[semesterId] {
            marks = semMarks
        }
        if let semCumulativeMarks = cumulativeMarksBySemesterId[semesterId] {
            cumulativeMarks = semCumulativeMarks
        }
    }

    // MARK: - Shared Timetable Import
    func importSharedTimetable(_ payload: TimetableSharePayload) {
        DispatchQueue.main.async {
            self.timetable = payload.timetable
            self.courses = payload.courses

            let baseName = payload.semesterName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = (baseName?.isEmpty == false ? baseName! : "Shared timetable") + " (Shared)"
            let sharedSemester = Semester(id: "shared-\(UUID().uuidString)", name: displayName)
            self.selectedSemester = sharedSemester

            if !self.semesters.contains(where: { $0.id == sharedSemester.id }) {
                self.semesters.insert(sharedSemester, at: 0)
            }
        }
    }

    /// Prints the complete VTOP HTML/response body to the Xcode console (no truncation).
    private func debugPrintFullVTOPResponse(_ label: String, _ body: String?) {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "vtop_verbose_response_logging") else { return }
        guard let body = body, !body.isEmpty else { return }
        print("🔍 FULL \(label) (length=\(body.count)):")
        print(body)
        #endif
    }

    /// Removes multi‑MB HTML blobs from bridged dictionaries in release builds.
    private static func strippingDebugPayloads(_ dict: [String: Any]) -> [String: Any] {
        #if DEBUG
        return dict
        #else
        var d = dict
        for k in ["rawProfileAllView", "rawResponse", "rawStudentTimeTableChn", "rawDoStudentMarkView",
                  "rawDoStudentGradeView", "rawProcessViewTimeTable", "rawProcessViewStudentAttendance",
                  "rawDoSearchExamScheduleForStudent", "rawViewProctorDetails", "rawViewHodDeanDetails",
                  "rawViewStudentCredentials", "rawHome", "rawReceipts", "rawGetReceiptsApplno", "rawScheduledEvents",
                  "rawStudentGradeHistory"] {
            d.removeValue(forKey: k)
        }
        return d
        #endif
    }

    // MARK: - Initialization
    init() {
        logger.info("📦 DataManager initialized", context: "DataManager")
        Self.migrateLegacyFullSyncStorageIfNeeded()
        let pruned = Self.prunedFullSyncCompletionDates()
        syncState.lastSuccessfulSyncAt = pruned.last
        refreshIntentObserver = NotificationCenter.default.addObserver(
            forName: .vtopRefreshRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAll()
        }
    }

    deinit {
        if let refreshIntentObserver {
            NotificationCenter.default.removeObserver(refreshIntentObserver)
        }
    }

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        logger.debug("WebView reference set in DataManager", context: "DataManager")
    }

    private func cancelFullSyncStallWatchdog() {
        fullSyncStallWatchdogItem?.cancel()
        fullSyncStallWatchdogItem = nil
    }

    private func scheduleFullSyncStallWatchdogIfNeeded() {
        cancelFullSyncStallWatchdog()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard self.syncState.isLoading else { return }
            self.logger.warning("Full sync stalled — timeout", context: "DataManager")
            self.countsCurrentSessionTowardManualFullSyncQuota = false
            self.syncState.lastDataFetchFailureReason = Self.signInOrSyncStallUserMessage
            self.syncState.isLoading = false
            self.syncState.loadingMessage = ""
        }
        fullSyncStallWatchdogItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fullSyncStallTimeout, execute: work)
    }

    /// Stops sync UI (toolbar spin, overlay) without implying a session error.
    private func clearSyncProgress() {
        DispatchQueue.main.async {
            self.cancelFullSyncStallWatchdog()
            self.countsCurrentSessionTowardManualFullSyncQuota = false
            self.syncState.isLoading = false
            self.syncState.loadingMessage = ""
        }
    }

    /// Called when CSRF / authorized ID cannot be read from the WebView after retries (expired session, blank page, etc.).
    private func reportSessionExtractionFailed() {
        DispatchQueue.main.async {
            self.cancelFullSyncStallWatchdog()
            self.countsCurrentSessionTowardManualFullSyncQuota = false
            self.syncState.lastDataFetchFailureReason = "VTOP session expired. Trying to sign you back in…"
            self.syncState.isLoading = false
            self.syncState.loadingMessage = ""
        }

        // Kick off a recovery attempt (auto re-login) if the auth layer is listening.
        DispatchQueue.main.async { [weak self] in
            self?.onSessionExpired?()
        }
    }

    // MARK: - Extract Session Data
    /// - Parameter incrementManualFullSyncQuotaOnCompletion: Pass `true` only from `performSyncAll` so a successful `finishDataFetching` appends to the hourly manual full-sync quota. Post-login / background calls use the default `false` (quota counters in UserDefaults are unchanged).
    func extractSessionData(attempt: Int = 1, incrementManualFullSyncQuotaOnCompletion: Bool = false) {
        if attempt == 1 {
            countsCurrentSessionTowardManualFullSyncQuota = incrementManualFullSyncQuotaOnCompletion
        }
        logger.info("🔑 Extracting session data (attempt \(attempt)/5)...", context: "DataManager")

        let script = """
        (function() {
            var authorizedID = document.getElementById('authorizedIDX');
            var csrfToken = document.querySelector('input[name="_csrf"]');
            var currentURL = window.location.href;
            return {
                authorizedID: authorizedID ? authorizedID.value : null,
                csrfToken: csrfToken ? csrfToken.value : null,
                currentURL: currentURL
            };
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to extract session data: \(error.localizedDescription)", context: "DataManager")

                if attempt < 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.extractSessionData(attempt: attempt + 1)
                    }
                } else {
                    self.reportSessionExtractionFailed()
                }
                return
            }

            guard let dict = result as? [String: Any] else {
                self.logger.error("Invalid result format from JavaScript", context: "DataManager")
                self.logger.debug("Raw result: \(String(describing: result))", context: "DataManager")
                if attempt < 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.extractSessionData(attempt: attempt + 1)
                    }
                } else {
                    self.reportSessionExtractionFailed()
                }
                return
            }

            let currentURL = dict["currentURL"] as? String ?? "unknown"
            self.logger.debug("Current URL: \(currentURL)", context: "DataManager")

            let authorizedIDRaw = dict["authorizedID"]
            let csrfTokenRaw = dict["csrfToken"]

            self.logger.debug("Raw authorizedID: \(String(describing: authorizedIDRaw)) (type: \(type(of: authorizedIDRaw)))", context: "DataManager")
            self.logger.debug("Raw csrfToken: \(String(describing: csrfTokenRaw)) (type: \(type(of: csrfTokenRaw)))", context: "DataManager")

            guard let authorizedID = dict["authorizedID"] as? String,
                  let csrfToken = dict["csrfToken"] as? String,
                  !authorizedID.isEmpty,
                  !csrfToken.isEmpty else {
                self.logger.warning("Session data not ready yet (authorizedID or CSRF missing)", context: "DataManager")
                self.logger.debug("authorizedID isEmpty: \((dict["authorizedID"] as? String)?.isEmpty ?? true)", context: "DataManager")
                self.logger.debug("csrfToken isEmpty: \((dict["csrfToken"] as? String)?.isEmpty ?? true)", context: "DataManager")

                // Retry after delay if not at max attempts
                if attempt < 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.extractSessionData(attempt: attempt + 1)
                    }
                } else {
                    self.logger.error("Failed to extract session data after \(attempt) attempts", context: "DataManager")
                    self.reportSessionExtractionFailed()
                }
                return
            }

            self.authorizedID = authorizedID
            self.csrfToken = csrfToken

            self.logger.success("✅ Session data extracted - AuthorizedID: \(authorizedID.prefix(10))...", context: "DataManager")

            // Start data fetching sequence
            self.fetchSemesters()
        }
    }

    // MARK: - Fetch Semesters
    /// - Parameters:
    ///   - chainIntoSelectSemester: When true (default), picks the first semester and starts `fetchAllData()`. When false, only updates `semesters` (e.g. pull-to-refresh on timetable before a selection exists).
    ///   - completion: Called on main when `chainIntoSelectSemester` is false and the request finishes.
    private func fetchSemesters(chainIntoSelectSemester: Bool = true, completion: (() -> Void)? = nil) {
        logger.info("📅 Fetching available semesters...", context: "DataManager")

        guard let authorizedID = authorizedID, let csrfToken = csrfToken else {
            logger.error("Missing session data", context: "DataManager")
            if chainIntoSelectSemester {
                clearSyncProgress()
            } else {
                DispatchQueue.main.async {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
            return
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { semesters: [], rawStudentTimeTableChn: '' };
            $.ajax({
                type: 'POST',
                url: '/vtop/academics/common/StudentTimeTableChn',
                data: {
                    verifyMenu: 'true',
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)'
                },
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawStudentTimeTableChn = res; }
                    var semesterSelect = $(res).find('#semesterSubId');
                    if (semesterSelect.length > 0) {
                        semesterSelect.find('option').each(function() {
                            var value = $(this).val();
                            var text = $(this).text().trim();
                            if (value && value !== '') {
                                result.semesters.push({
                                    id: value,
                                    name: text
                                });
                            }
                        });
                    }
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch semesters: \(error.localizedDescription)", context: "DataManager")
                if chainIntoSelectSemester {
                    self.clearSyncProgress()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            guard let raw = result as? [String: Any],
                  let semestersData = raw["semesters"] as? [[String: String]] else {
                self.logger.error("Invalid semesters response", context: "DataManager")
                if chainIntoSelectSemester {
                    self.clearSyncProgress()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            self.debugPrintFullVTOPResponse("StudentTimeTableChn", raw["rawStudentTimeTableChn"] as? String)
            _ = Self.strippingDebugPayloads(raw)

            let semesters = semestersData.compactMap { data -> Semester? in
                guard let id = data["id"], let name = data["name"] else { return nil }
                return Semester(id: id, name: name)
            }

            DispatchQueue.main.async {
                self.semesters = semesters
                self.logger.success("✅ Found \(semesters.count) semesters", context: "DataManager")

                if chainIntoSelectSemester {
                    if let firstSemester = semesters.first {
                        self.selectSemester(firstSemester)
                    } else {
                        self.logger.warning("No semesters returned from VTOP", context: "DataManager")
                        self.clearSyncProgress()
                        self.syncState.lastDataFetchFailureReason = "Could not load semesters. Sign out and sign in again, then sync."
                    }
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
                self.scheduleCachePersistence()
            }
        }
    }

    // MARK: - Select Semester
    func selectSemester(_ semester: Semester) {
        logger.info("📌 Semester selected: \(semester.name)", context: "DataManager")
        selectedSemester = semester

        // Save to UserDefaults
        UserDefaults.standard.set(semester.id, forKey: "semesterId")
        UserDefaults.standard.set(semester.name, forKey: "semester")

        // Immediately show cached data for this semester if available
        if let cachedCourses = coursesBySemesterId[semester.id] {
            courses = cachedCourses
        }
        if let cachedTimetable = timetableBySemesterId[semester.id] {
            timetable = cachedTimetable
        }
        if let cachedMarks = marksBySemesterId[semester.id] {
            marks = cachedMarks
        }
        if let cachedCumulativeMarks = cumulativeMarksBySemesterId[semester.id] {
            cumulativeMarks = cachedCumulativeMarks
        }

        // Start fetching all data for this semester
        fetchAllData()
    }

    // MARK: - Fetch All Data
    private func fetchAllData() {
        logger.info("🚀 Starting sequential data fetch...", context: "DataManager")

        DispatchQueue.main.async {
            self.syncState.isLoading = true
            if self.countsCurrentSessionTowardManualFullSyncQuota {
                self.scheduleFullSyncStallWatchdogIfNeeded()
            }
        }

        // Fetch in sequence
        fetchStudentProfile()
    }

    // MARK: - Fetch Student Profile
    /// - Parameter stopAfterTimetable: When true, loads profile then courses+timetable only (no attendance/marks/… chain).
    private func fetchStudentProfile(stopAfterTimetable: Bool = false, completion: (() -> Void)? = nil) {
        logger.info("👤 Fetching student profile...", context: "DataManager")

        guard let authorizedID = authorizedID, let csrfToken = csrfToken else {
            logger.error("Missing session data", context: "DataManager")
            clearSyncProgress()
            completion?()
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading profile..."
        }

        // `tryParseGradeTable` matches StudentGradeHistory markup in `Views/grades/grade.txt` (customTable, dual tableHeader rows, tableContent, detailsView rows skipped).
        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var profile = {
                name: null, cgpa: 0, totalCredits: 0, creditsRegistered: null,
                registrationNumber: null, vitEmail: null, programBranch: null, schoolName: null,
                gender: null,
                profileSections: [], gradeHistorySections: [],
                debug: '', rawResponse: '', rawProfileAllView: ''
            };

            function parseProfileAllView(res) {
                if (__VTOP_DEBUG__) { profile.rawProfileAllView = res; }
                var $r = $(res);
                if (res.toLowerCase().indexOf('personal information') < 0) return;
                var cardName = $r.find('.card p').filter(function() {
                    var st = $(this).attr('style') || '';
                    return st.indexOf('font-weight: bold') >= 0 || st.indexOf('font-weight:bold') >= 0;
                }).first().text().trim();
                if (cardName) profile.name = profile.name || cardName;
                $r.find('label.col-form-label').each(function() {
                    var lbl = $(this).text().trim();
                    var next = $(this).next('label.col-form-label');
                    if (!next.length) return;
                    var val = next.text().trim();
                    var low = lbl.toLowerCase();
                    if (low.indexOf('register') >= 0 && low.indexOf('number') >= 0) profile.registrationNumber = val;
                    else if (low.indexOf('vit') >= 0 && low.indexOf('email') >= 0) profile.vitEmail = val;
                    else if (low.indexOf('program') >= 0 || low.indexOf('branch') >= 0) profile.programBranch = val;
                    else if (low.indexOf('school name') >= 0) profile.schoolName = val;
                    else if (low === 'gender' || (low.indexOf('gender') >= 0 && low.indexOf('identity') < 0 && low.indexOf('prefer') < 0)) profile.gender = val;
                });
                var cells = $r.find('td');
                for (var i = 0; i < cells.length; i++) {
                    var key = (cells[i].innerText || '').toLowerCase();
                    if (key.indexOf('student') >= 0 && key.indexOf('name') >= 0 && i + 1 < cells.length) {
                        var raw = cells[i + 1].innerText || cells[i + 1].textContent || '';
                        var nm = raw.trim();
                        if (nm && nm.length > 2) profile.name = profile.name || nm;
                        break;
                    }
                }
                $r.find('.accordion-item').each(function() {
                    var title = $(this).find('.accordion-button strong').first().text().trim();
                    if (!title) return;
                    var rows = [];
                    $(this).find('.accordion-body table tr').each(function() {
                        var tds = $(this).find('td');
                        if (tds.length >= 2) {
                            var k = tds.eq(0).text().replace(/\\s+/g, ' ').trim();
                            var v = tds.eq(1).text().replace(/\\s+/g, ' ').trim();
                            if (k && k.length < 200) {
                                var kl = k.toLowerCase();
                                if (kl === 'gender' || (kl.indexOf('gender') === 0 && kl.length <= 16)) profile.gender = v;
                                rows.push({ k: k, v: v });
                            }
                        }
                    });
                    if (title && rows.length) profile.profileSections.push({ title: title, rows: rows });
                });
            }

            function tryParseGradeTable($table) {
                var blob = ($table.text() || '').toLowerCase();
                if (blob.indexOf('attendance') >= 0 && blob.indexOf('attended classes') >= 0) return null;
                var $directRows = $table.children('tbody').length ? $table.children('tbody').children('tr') : $table.children('tr');
                function parseCustomGradeTable() {
                    var bestHr = null, bestN = 0;
                    $directRows.filter('.tableHeader').each(function() {
                        var $r = $(this);
                        var cells = $r.children('td, th');
                        if (cells.length < 5) return;
                        var tx = ($r.text() || '').toLowerCase();
                        if (tx.indexOf('grade') < 0) return;
                        if (tx.indexOf('course') < 0 || tx.indexOf('code') < 0) return;
                        if (cells.length > bestN) { bestN = cells.length; bestHr = $r; }
                    });
                    if (!bestHr || !bestHr.length) return null;
                    var heads = [];
                    bestHr.children('td, th').each(function() {
                        heads.push(($(this).text() || '').toLowerCase().replace(/\\s+/g, ' ').trim());
                    });
                    var codeIdx = -1, titleIdx = -1, gradeIdx = -1, credIdx = -1, examIdx = -1;
                    for (var hi = 0; hi < heads.length; hi++) {
                        var h = heads[hi];
                        if (h.indexOf('course') >= 0 && h.indexOf('code') >= 0) codeIdx = hi;
                        else if (h.indexOf('course title') >= 0 || (h.indexOf('course') >= 0 && h.indexOf('title') >= 0)) titleIdx = hi;
                        else if (h === 'grade' || (h.indexOf('grade') >= 0 && h.indexOf('point') < 0 && h.indexOf('cgpa') < 0 && h.indexOf('gpa') < 0 && h.indexOf('history') < 0)) {
                            if (gradeIdx < 0) gradeIdx = hi;
                        } else if (h.indexOf('credit') >= 0 && h.indexOf('registered') < 0) credIdx = hi;
                        else if (h.indexOf('exam month') >= 0 || (h.indexOf('exam') >= 0 && h.indexOf('month') >= 0)) examIdx = hi;
                    }
                    if (codeIdx < 0 || gradeIdx < 0) return null;
                    var out = [];
                    $directRows.each(function() {
                        var $tr = $(this);
                        if (!$tr.is('.tableContent') || $tr.hasClass('tableContent-level1')) return;
                        var idAttr = $tr.attr('id') || '';
                        if (idAttr.indexOf('detailsView') === 0) return;
                        var st = (($tr.attr('style') || '').replace(/\\s/g, '')).toLowerCase();
                        if (st.indexOf('display:none') >= 0) return;
                        var $tds = $tr.children('td');
                        if ($tds.length < 3) return;
                        if ($tds.first().attr('colspan')) return;
                        var code = $tds.eq(codeIdx).text().trim();
                        var grade = $tds.eq(gradeIdx).text().trim();
                        if (!code || code.toLowerCase().indexOf('course') >= 0) return;
                        if (!/^[A-Z]{2,}\\d/i.test(code.replace(/\\s/g, ''))) return;
                        if (grade === '' || grade === '-') return;
                        var title = titleIdx >= 0 ? $tds.eq(titleIdx).text().trim() : null;
                        var cr = credIdx >= 0 ? parseFloat($tds.eq(credIdx).text().replace(/[^0-9.]/g, '')) : NaN;
                        var exm = examIdx >= 0 ? $tds.eq(examIdx).text().trim() : null;
                        out.push({
                            courseCode: code,
                            courseTitle: title || null,
                            credits: isNaN(cr) ? null : cr,
                            grade: grade,
                            examMonth: exm || null
                        });
                    });
                    return out.length ? out : null;
                }
                var custom = parseCustomGradeTable();
                if (custom) return custom;
                var $headerCells = $table.find('thead tr').last().find('th, td');
                if (!$headerCells.length) {
                    $table.find('tr').each(function() {
                        var $cells = $(this).children('th, td');
                        if ($cells.length < 8) return;
                        var j = ($(this).text() || '').toLowerCase();
                        if (j.indexOf('grade') < 0) return;
                        if (j.indexOf('course') < 0 && j.indexOf('code') < 0) return;
                        $headerCells = $cells;
                        return false;
                    });
                }
                if (!$headerCells || !$headerCells.length) return null;
                var heads = [];
                $headerCells.each(function() {
                    heads.push($(this).text().toLowerCase().replace(/\\s+/g, ' ').trim());
                });
                var joined = heads.join(' ');
                if (joined.indexOf('grade') < 0) return null;
                if (joined.indexOf('course') < 0 && joined.indexOf('code') < 0) return null;
                if (joined.indexOf('attendance') >= 0 && joined.indexOf('attended classes') >= 0) return null;
                var codeIdx = -1, titleIdx = -1, gradeIdx = -1, credIdx = -1, examIdx = -1;
                for (var hi = 0; hi < heads.length; hi++) {
                    var h = heads[hi];
                    if (h.indexOf('course') >= 0 && h.indexOf('code') >= 0) codeIdx = hi;
                    else if (h.indexOf('course title') >= 0 || (h.indexOf('course') >= 0 && h.indexOf('title') >= 0)) titleIdx = hi;
                    else if (h === 'grade' || (h.indexOf('grade') >= 0 && h.indexOf('point') < 0 && h.indexOf('cgpa') < 0 && h.indexOf('gpa') < 0)) {
                        if (gradeIdx < 0) gradeIdx = hi;
                    } else if (h.indexOf('credit') >= 0 && h.indexOf('registered') < 0) credIdx = hi;
                    else if (h.indexOf('exam month') >= 0 || (h.indexOf('exam') >= 0 && h.indexOf('month') >= 0)) examIdx = hi;
                }
                if (codeIdx < 0) return null;
                if (gradeIdx < 0) {
                    for (var hj = 0; hj < heads.length; hj++) {
                        if (heads[hj].indexOf('grade') >= 0) { gradeIdx = hj; break; }
                    }
                }
                if (gradeIdx < 0) return null;
                var out = [];
                $table.find('tr').each(function() {
                    if ($(this).closest('thead').length) return;
                    var $tds = $(this).find('td');
                    if ($tds.length < 3) return;
                    if ($tds.first().attr('colspan')) return;
                    var code = $tds.eq(codeIdx).text().trim();
                    var grade = $tds.eq(gradeIdx).text().trim();
                    if (!code || code.toLowerCase().indexOf('course') >= 0) return;
                    if (!/^[A-Z]{2,}\\d/i.test(code.replace(/\\s/g, ''))) return;
                    if (grade === '' || grade === '-') return;
                    var title = titleIdx >= 0 ? $tds.eq(titleIdx).text().trim() : null;
                    var cr = credIdx >= 0 ? parseFloat($tds.eq(credIdx).text().replace(/[^0-9.]/g, '')) : NaN;
                    var exm = examIdx >= 0 ? $tds.eq(examIdx).text().trim() : null;
                    out.push({
                        courseCode: code,
                        courseTitle: title || null,
                        credits: isNaN(cr) ? null : cr,
                        grade: grade,
                        examMonth: exm || null
                    });
                });
                return out.length ? out : null;
            }

            $.ajax({
                type: 'POST',
                url: '/vtop/studentsRecord/StudentProfileAllView',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(resProfile) {
                    parseProfileAllView(resProfile);
                    $.ajax({
                type: 'POST',
                url: '/vtop/examinations/examGradeView/StudentGradeHistory',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { profile.rawResponse = res; }
                    profile.debug = 'StudentGradeHistory length: ' + res.length;
                    var doc = new DOMParser().parseFromString(res, 'text/html');
                    var $doc = $(doc);
                    var nameFromHistory = null;
                    $doc.find('tr').each(function() {
                        var $row = $(this);
                        var $cells = $row.children('td, th');
                        var nameIdx = -1;
                        $cells.each(function() {
                            if ($(this).text().trim().toLowerCase() === 'name') { nameIdx = $(this).index(); return false; }
                        });
                        if (nameIdx >= 0) {
                            var $next = $row.next('tr');
                            var nm = $next.find('td').eq(nameIdx).text().trim();
                            if (nm && nm.length > 2) { nameFromHistory = nm; return false; }
                        }
                    });
                    profile.nameFromHistory = nameFromHistory;

                    function parseDashboardCgpaCredits(resCgpaCredits) {
                        var $cg = $(new DOMParser().parseFromString(resCgpaCredits, 'text/html'));
                        $cg.find('li').each(function() {
                            var txt = ($(this).text() || '').replace(/\\s+/g, ' ').trim();
                            if (!txt) return;
                            var low = txt.toLowerCase();
                            var num = parseFloat(txt.replace(/[^0-9.]/g, ''));
                            if (isNaN(num)) return;
                            if (low.indexOf('total credits required') >= 0) {
                                profile.totalCreditsRequired = num;
                            } else if (low.indexOf('earned credits') >= 0) {
                                profile.totalCredits = num;
                            } else if (low.indexOf('current cgpa') >= 0) {
                                profile.cgpa = num;
                            } else if (low.indexOf('non-graded core requirement') >= 0) {
                                profile.nonGradedCoreRequirement = num;
                            }
                        });
                    }

                    $.ajax({
                        type: 'POST',
                        url: '/vtop/get/dashboard/current/cgpa/credits',
                        data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                        contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                        async: false,
                        success: function(resCgpaCredits) {
                            parseDashboardCgpaCredits(resCgpaCredits);
                        },
                        error: function(xhr2, st2, err2) { }
                    });

                    var parsed = false;
                    $doc.find('h3.box-title, h3').each(function() {
                        var titleText = $(this).text();
                        if (titleText.indexOf('CGPA') >= 0 && titleText.indexOf('Details') >= 0) {
                            var $table = $(this).closest('.box').find('table').first();
                            if (!$table.length) $table = $(this).closest('.box-header').nextAll('table').first();
                            var $dataRow = $table.find('tbody tr').first();
                            if (!$dataRow.length) $dataRow = $table.find('tr').eq(1);
                            var tds = $dataRow.find('td');
                            if (tds.length >= 3) {
                                profile.creditsRegistered = parseFloat(tds.eq(0).text()) || 0;
                                profile.totalCredits = parseFloat(tds.eq(1).text()) || 0;
                                profile.cgpa = parseFloat(tds.eq(2).text()) || 0;
                                profile.debug += ', path=CGPA_Details_table';
                                parsed = true;
                                return false;
                            }
                        }
                    });

                    if (!parsed) {
                        var tables = doc.getElementsByTagName('table');
                        profile.debug += ', tables=' + tables.length;
                        for (var i = tables.length - 1; i >= 0; i--) {
                            var rows = tables[i].getElementsByTagName('tr');
                            if (rows.length === 0) continue;
                            var headings = rows[0].getElementsByTagName('td');
                            if (headings.length === 0) { headings = rows[0].getElementsByTagName('th'); }
                            if (headings.length > 0 && headings[0].innerText.toLowerCase().includes('credits')) {
                                var creditsIndex, cgpaIndex;
                                for (var j = 0; j < headings.length; j++) {
                                    var heading = headings[j].innerText.toLowerCase();
                                    if (heading.includes('earned')) { creditsIndex = j + headings.length; }
                                    else if (heading.includes('cgpa')) { cgpaIndex = j + headings.length; }
                                }
                                var cells = tables[i].getElementsByTagName('td');
                                if (cgpaIndex != null && cells[cgpaIndex]) {
                                    profile.cgpa = parseFloat(cells[cgpaIndex].innerText) || 0;
                                }
                                if (creditsIndex != null && cells[creditsIndex]) {
                                    profile.totalCredits = parseFloat(cells[creditsIndex].innerText) || 0;
                                }
                                profile.debug += ', path=android_fallback_table';
                                break;
                            }
                        }
                    }

                    var currentTitle = 'Grade record';
                    var scope = doc.getElementById('main-section') || doc.querySelector('section.content') || doc.body;
                    var seenTables = new WeakSet();
                    if (scope) {
                        var flow = scope.querySelectorAll('h2, h3, h4, table');
                        for (var fi = 0; fi < flow.length; fi++) {
                            var el = flow[fi];
                            var tag = el.tagName.toLowerCase();
                            if (tag !== 'table') {
                                var tt = (el.textContent || '').trim();
                                if (tt.length > 2 && tt.length < 140) currentTitle = tt;
                            } else {
                                if (seenTables.has(el)) continue;
                                var parsedRows = tryParseGradeTable($(el));
                                if (parsedRows && parsedRows.length) {
                                    seenTables.add(el);
                                    profile.gradeHistorySections.push({ title: currentTitle, rows: parsedRows });
                                }
                            }
                        }
                    }
                },
                error: function(xhr, status, error) {
                    profile.debug = 'StudentGradeHistory AJAX Error: ' + error;
                }
                    });
                },
                error: function(xhr, status, error) {
                    profile.debug = (profile.debug || '') + ' StudentProfileAllView Error: ' + error;
                }
            });
            return profile;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch student profile: \(error.localizedDescription)", context: "DataManager")
                if stopAfterTimetable {
                    self.fetchCoursesAndTimetable(chainToAttendance: false, completion: completion)
                } else {
                    self.fetchCoursesAndTimetable()
                }
                return
            }

            guard let raw = result as? [String: Any] else {
                self.logger.error("Invalid profile response", context: "DataManager")
                if stopAfterTimetable {
                    self.fetchCoursesAndTimetable(chainToAttendance: false, completion: completion)
                } else {
                    self.fetchCoursesAndTimetable()
                }
                return
            }

            let debug = raw["debug"] as? String ?? "No debug info"
            self.logger.debug("📊 Profile fetch debug: \(debug)", context: "DataManager")
            self.debugPrintFullVTOPResponse("StudentProfileAllView", raw["rawProfileAllView"] as? String)
            self.debugPrintFullVTOPResponse("StudentGradeHistory", raw["rawResponse"] as? String)

            let dict = Self.strippingDebugPayloads(raw)
            let semesterName = self.selectedSemester?.name
            let semesterId = self.selectedSemester?.id

            Task.detached(priority: .userInitiated) {
                let parsed = Self.parseStudentProfilePayload(dict, semesterName: semesterName, semesterId: semesterId)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.studentProfile = parsed.profile
                    self.gradeHistoryRows = parsed.dedupedGrades
                    UserDefaults.standard.set(parsed.name, forKey: "name")
                    UserDefaults.standard.set(parsed.cgpa, forKey: "cgpa")
                    UserDefaults.standard.set(parsed.totalCredits, forKey: "totalCredits")
                    self.logger.success("✅ Profile loaded - Name: \(parsed.name), CGPA: \(parsed.cgpa), Credits: \(parsed.totalCredits), grade history rows: \(parsed.dedupedGrades.count) (raw \(parsed.rawGradeRowCount))", context: "DataManager")
                    self.scheduleCachePersistence()
                    if stopAfterTimetable {
                        self.fetchCoursesAndTimetable(chainToAttendance: false, completion: completion)
                    } else {
                        self.fetchCoursesAndTimetable()
                    }
                }
            }
        }
    }

    private struct ParsedStudentProfileWork {
        let profile: StudentProfile
        let dedupedGrades: [GradeHistoryCourseRow]
        let rawGradeRowCount: Int
        let name: String
        let cgpa: Double
        let totalCredits: Double
    }

    /// Heavy dictionary → model work; safe to call off the main actor.
    private static func parseStudentProfilePayload(
        _ dict: [String: Any],
        semesterName: String?,
        semesterId: String?
    ) -> ParsedStudentProfileWork {
        var name = dict["name"] as? String ?? "Student"
        if let fromHistory = dict["nameFromHistory"] as? String,
           !fromHistory.isEmpty,
           name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
           || name == "Student" {
            name = fromHistory
        }
        let cgpa = dict["cgpa"] as? Double ?? 0.0
        let totalCredits = dict["totalCredits"] as? Double ?? 0.0
        let creditsRegistered = Self.doubleIfPresent(dict["creditsRegistered"])
        let totalCreditsRequired = Self.doubleIfPresent(dict["totalCreditsRequired"])
        let nonGradedCoreRequirement = Self.doubleIfPresent(dict["nonGradedCoreRequirement"])
        let registrationNumber = dict["registrationNumber"] as? String
        let vitEmail = dict["vitEmail"] as? String
        let programBranch = dict["programBranch"] as? String
        let schoolName = dict["schoolName"] as? String
        let gender = dict["gender"] as? String

        var accordionSections: [ProfileAccordionSectionData]?
        if let rawSections = dict["profileSections"] as? [[String: Any]] {
            let built = rawSections.compactMap { s -> ProfileAccordionSectionData? in
                guard let title = s["title"] as? String,
                      let rows = s["rows"] as? [[String: Any]] else { return nil }
                let kv = rows.compactMap { r -> ProfileKeyValueRow? in
                    guard let k = r["k"] as? String else { return nil }
                    let v = (r["v"] as? String) ?? ""
                    return ProfileKeyValueRow(key: k, value: v)
                }
                guard !kv.isEmpty else { return nil }
                return ProfileAccordionSectionData(title: title, rows: kv)
            }
            accordionSections = built.isEmpty ? nil : built
        } else {
            accordionSections = nil
        }

        var gradeRows: [GradeHistoryCourseRow] = []
        var ghCounter = 1
        if let ghSections = dict["gradeHistorySections"] as? [[String: Any]] {
            for sec in ghSections {
                let secTitle = sec["title"] as? String ?? "Record"
                guard let rows = sec["rows"] as? [[String: Any]] else { continue }
                for r in rows {
                    guard let code = r["courseCode"] as? String,
                          let grade = r["grade"] as? String else { continue }
                    let ctitle = r["courseTitle"] as? String
                    let cred = Self.doubleIfPresent(r["credits"])
                    gradeRows.append(GradeHistoryCourseRow(
                        id: ghCounter,
                        sectionTitle: secTitle,
                        courseCode: code,
                        courseTitle: ctitle,
                        credits: cred,
                        grade: grade,
                        examMonth: r["examMonth"] as? String
                    ))
                    ghCounter += 1
                }
            }
        }

        let rawGradeRowCount = gradeRows.count
        let dedupedGrades = Self.deduplicateGradeHistoryRows(gradeRows)
        let profile = StudentProfile(
            name: name,
            cgpa: cgpa,
            totalCredits: totalCredits,
            creditsRegistered: creditsRegistered,
            totalCreditsRequired: totalCreditsRequired,
            nonGradedCoreRequirement: nonGradedCoreRequirement,
            registrationNumber: registrationNumber,
            vitEmail: vitEmail,
            programBranch: programBranch,
            schoolName: schoolName,
            accordionSections: accordionSections,
            semester: semesterName,
            semesterId: semesterId,
            gender: gender
        )
        return ParsedStudentProfileWork(
            profile: profile,
            dedupedGrades: dedupedGrades,
            rawGradeRowCount: rawGradeRowCount,
            name: name,
            cgpa: cgpa,
            totalCredits: totalCredits
        )
    }

    /// Coerces NSNumber / Double / String from WKWebView JSON to `Double?`.
    private static func doubleIfPresent(_ any: Any?) -> Double? {
        guard let any, !(any is NSNull) else { return nil }
        if let d = any as? Double { return d }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    /// Merges duplicate course rows (same section + code), preferring a real letter grade over “-” and richer metadata.
    private static func deduplicateGradeHistoryRows(_ rows: [GradeHistoryCourseRow]) -> [GradeHistoryCourseRow] {
        struct Key: Hashable { let section: String; let code: String; let examMonthNorm: String }
        func gradeScore(_ g: String) -> Int {
            let t = g.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t == "-" { return 0 }
            if t.range(of: "^[SABCDEOWPFUIW][+-]?$", options: [.regularExpression, .caseInsensitive]) != nil { return 3 }
            if t.range(of: "^[0-9]+(\\.[0-9]+)?$", options: .regularExpression) != nil { return 2 }
            return 1
        }
        var best: [Key: GradeHistoryCourseRow] = [:]
        var order: [Key] = []
        for r in rows {
            let em = (r.examMonth ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let k = Key(section: r.sectionTitle, code: r.courseCode, examMonthNorm: em)
            if best[k] == nil {
                order.append(k)
                best[k] = r
                continue
            }
            guard let ex = best[k] else { continue }
            let sNew = gradeScore(r.grade)
            let sOld = gradeScore(ex.grade)
            if sNew > sOld || (sNew == sOld && (r.credits ?? 0) > (ex.credits ?? 0)) {
                best[k] = r
            }
        }
        return order.compactMap { k -> GradeHistoryCourseRow? in
            guard let r = best[k] else { return nil }
            var h = Hasher()
            h.combine(r.sectionTitle)
            h.combine(r.courseCode)
            h.combine(k.examMonthNorm)
            let hid = abs(h.finalize())
            let fallback = abs("\(r.sectionTitle)|\(r.courseCode)|\(k.examMonthNorm)".hashValue)
            let stableId = (hid != 0 ? hid : fallback != 0 ? fallback : 1)
            return GradeHistoryCourseRow(
                id: stableId,
                sectionTitle: r.sectionTitle,
                courseCode: r.courseCode,
                courseTitle: r.courseTitle,
                credits: r.credits,
                grade: r.grade,
                examMonth: r.examMonth
            )
        }
    }

    private static func imageDataFromVTOPDataURL(_ src: String?) -> Data? {
        guard let src, let comma = src.firstIndex(of: ",") else { return nil }
        let b64 = String(src[src.index(after: comma)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Data(base64Encoded: b64, options: [.ignoreUnknownCharacters])
    }

    private static func intFromJSON(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d.rounded()) }
        if let n = any as? NSNumber { return Int(n.doubleValue.rounded()) }
        if let s = any as? String { return Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    /// WKWebView / JSON may hand back `NSArray` of `NSDictionary`; normalize to `[[String: Any]]`.
    private static func coerceReceiptPayloadArray(_ any: Any?) -> [[String: Any]]? {
        guard let any else { return nil }
        if let a = any as? [[String: Any]] { return a }
        if let arr = any as? [Any] { return arr.compactMap { $0 as? [String: Any] } }
        return nil
    }

    private static func doubleFromJSON(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "")
            return Double(t)
        }
        return nil
    }

    /// Parses VTOP receipt dates like `31-JUL-2025` to epoch ms.
    private static func parseReceiptDateMillis(_ dateString: String) -> Int64 {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizeReceiptDateDayMonthYear(trimmed)
        let formats = ["dd-MMM-yyyy", "d-MMM-yyyy", "dd-MMM-yy", "d-MMM-yy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for f in formats {
            formatter.dateFormat = f
            if let date = formatter.date(from: normalized) {
                return Int64(date.timeIntervalSince1970 * 1000)
            }
        }
        return Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// `31-JUL-2025` → `31-Jul-2025` for `DateFormatter` month parsing.
    private static func normalizeReceiptDateDayMonthYear(_ s: String) -> String {
        let parts = s.split(separator: "-").map(String.init)
        guard parts.count == 3 else { return s }
        let day = parts[0]
        let monRaw = parts[1]
        let year = parts[2]
        let monLower = monRaw.lowercased()
        let mon = monLower.prefix(1).uppercased() + monLower.dropFirst()
        return "\(day)-\(mon)-\(year)"
    }

    private static func optionalTrimmedString(_ any: Any?) -> String? {
        if any is NSNull { return nil }
        guard let s = any as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: - Fetch Courses and Timetable
    /// Updates `courses` + `timetable` from `processViewTimeTable`. When `chainToAttendance` is false, the sync chain stops after this step (for Timetable screen semester changes).
    /// When `chainToAttendance` is true and `continueAfterAttendance` is false, loads attendance for the selected term then stops (no marks/exams chain).
    private func fetchCoursesAndTimetable(chainToAttendance: Bool = true, continueAfterAttendance: Bool = true, completion: (() -> Void)? = nil) {
        logger.info("📚 Fetching courses and timetable...", context: "DataManager")

        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let semesterId = selectedSemester?.id else {
            logger.error("Missing session or semester data", context: "DataManager")
            completion?()
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading courses..."
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { courses: [], timetable: [], rawProcessViewTimeTable: '' };

            function cellSlotToken(text) {
                if (!text) return null;
                var t = text.replace(/\\s+/g, ' ').trim();
                if (!t || t === '-' || /^lunch$/i.test(t)) return null;
                var first = t.split('-')[0].trim();
                if (!first || first === '-') return null;
                return first;
            }

            function parseTimeBandRowPair(trs, startIdx) {
                if (startIdx + 1 >= trs.length) return { times: [], nextIdx: startIdx };
                var r0 = $(trs[startIdx]).find('td').toArray();
                var r1 = $(trs[startIdx + 1]).find('td').toArray();
                if (r0.length < 3 || r1.length < 2) return { times: [], nextIdx: startIdx };
                var starts = r0.slice(2);
                var ends = r1.slice(1);
                var times = [];
                var n = Math.min(starts.length, ends.length);
                for (var k = 0; k < n; k++) {
                    var st = $(starts[k]).text().trim();
                    var en = $(ends[k]).text().trim();
                    if (/^lunch$/i.test(st) || /^lunch$/i.test(en)) {
                        times.push(null);
                    } else if (/^\\d{1,2}:\\d{2}$/.test(st) && /^\\d{1,2}:\\d{2}$/.test(en)) {
                        times.push({ start: st, end: en });
                    } else {
                        times.push(null);
                    }
                }
                return { times: times, nextIdx: startIdx + 2 };
            }

            function buildSlotGrid(timesArr) {
                return timesArr.map(function(t) {
                    if (!t) return null;
                    return {
                        startTime: t.start,
                        endTime: t.end,
                        sunday: null, monday: null, tuesday: null, wednesday: null,
                        thursday: null, friday: null, saturday: null
                    };
                });
            }

            $.ajax({
                type: 'POST',
                url: '/vtop/processViewTimeTable',
                data: {
                    semesterSubId: '\(semesterId)',
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)'
                },
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawProcessViewTimeTable = res; }
                    var courseCounter = 1;
                    var slotCounter = 1;

                    // Registration / courses table (Sl.No … columns; often no <tbody>)
                    $(res).find('#studentDetailsList table.table').first().find('tr').each(function() {
                        var cells = $(this).find('td');
                        if (cells.length < 11) return;
                        var slNo = cells.eq(0).text().trim();
                        if (!/^\\d+$/.test(slNo)) return;
                        var rowText = $(this).text();
                        if (/Total Number Of Credits/i.test(rowText)) return;

                        var coursePs = cells.eq(2).find('p');
                        var line0 = coursePs.eq(0).text().trim();
                        var dashSep = line0.indexOf(' - ');
                        if (dashSep < 0) return;
                        var courseCode = line0.substring(0, dashSep).trim();
                        var courseTitle = line0.substring(dashSep + 3).trim();
                        if (!courseCode) return;

                        var typeLine = (coursePs.eq(1).text() || '').toLowerCase();
                        var courseType = typeLine.indexOf('lab') >= 0 ? 'LAB'
                            : (typeLine.indexOf('project') >= 0 ? 'PROJECT' : 'THEORY');

                        var creditsRaw = cells.eq(3).text().trim().split(/\\s+/)[0];
                        var credits = Math.round(parseFloat(creditsRaw) || 0);

                        var slotVenueLines = cells.eq(7).text().split(/\\r?\\n/).map(function(x) { return x.trim(); }).filter(function(x) { return x.length > 0; });
                        var firstSlotLine = slotVenueLines.length ? slotVenueLines[0] : '';
                        var slotsPart = firstSlotLine.split('-')[0].trim();
                        var venue = slotVenueLines.length > 1 ? slotVenueLines[slotVenueLines.length - 1] : '';

                        var faculty = cells.eq(8).text().replace(/\\s+/g, ' ').trim();

                        var slots = [];
                        if (slotsPart && !/^nil$/i.test(slotsPart)) {
                            slotsPart.split('+').forEach(function(part) {
                                part = part.trim();
                                if (part) {
                                    slots.push({ id: slotCounter++, slot: part, courseId: courseCounter });
                                }
                            });
                        }

                        result.courses.push({
                            id: courseCounter++,
                            code: courseCode,
                            title: courseTitle,
                            type: courseType,
                            credits: credits,
                            venue: venue,
                            faculty: faculty,
                            slots: slots
                        });
                    });

                    // Timetable grid #timeTableStyle (theory/lab column headers + MON–SUN rows)
                    var $tt = $(res).find('#timeTableStyle');
                    if ($tt.length) {
                        var trs = $tt.find('tr').toArray();
                        var theoryHdr = parseTimeBandRowPair(trs, 0);
                        var labHdr = parseTimeBandRowPair(trs, theoryHdr.nextIdx);
                        var theorySlots = buildSlotGrid(theoryHdr.times);
                        var labSlots = buildSlotGrid(labHdr.times);
                        var dataStart = labHdr.nextIdx;
                        var dayMap = { 'SUN': 0, 'MON': 1, 'TUE': 2, 'WED': 3, 'THU': 4, 'FRI': 5, 'SAT': 6 };
                        var dayKeys = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
                        var lastDayIdx = null;

                        for (var r = dataStart; r < trs.length; r++) {
                            var cells = $(trs[r]).find('td').toArray();
                            if (cells.length < 2) continue;
                            var t0 = $(cells[0]).text().trim();
                            var t1 = $(cells[1]).text().trim();
                            var dayM = t0.match(/^(SUN|MON|TUE|WED|THU|FRI|SAT)$/i);
                            if (dayM) {
                                lastDayIdx = dayMap[dayM[1].toUpperCase()];
                                var isTheory = /^theory$/i.test(t1);
                                var targets = isTheory ? theorySlots : labSlots;
                                for (var col = 0; col < targets.length; col++) {
                                    if (!targets[col]) continue;
                                    var ci = col + 2;
                                    if (ci >= cells.length) break;
                                    var tok = cellSlotToken($(cells[ci]).text());
                                    if (tok && lastDayIdx !== null) {
                                        targets[col][dayKeys[lastDayIdx]] = tok;
                                    }
                                }
                            } else if (/^lab$/i.test(t0) && lastDayIdx !== null) {
                                var targetsL = labSlots;
                                for (var col2 = 0; col2 < targetsL.length; col2++) {
                                    if (!targetsL[col2]) continue;
                                    var ci2 = col2 + 1;
                                    if (ci2 >= cells.length) break;
                                    var tok2 = cellSlotToken($(cells[ci2]).text());
                                    if (tok2) {
                                        targetsL[col2][dayKeys[lastDayIdx]] = tok2;
                                    }
                                }
                            }
                        }

                        var timetableCounter = 1;
                        function appendSlots(arr) {
                            arr.forEach(function(s) {
                                if (!s) return;
                                result.timetable.push({
                                    id: timetableCounter++,
                                    startTime: s.startTime,
                                    endTime: s.endTime,
                                    sunday: s.sunday, monday: s.monday, tuesday: s.tuesday,
                                    wednesday: s.wednesday, thursday: s.thursday, friday: s.friday,
                                    saturday: s.saturday
                                });
                            });
                        }
                        appendSlots(theorySlots);
                        appendSlots(labSlots);
                    }
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch courses: \(error.localizedDescription)", context: "DataManager")
                if chainToAttendance && continueAfterAttendance {
                    self.fetchAttendance()
                } else if chainToAttendance && !continueAfterAttendance {
                    self.fetchAttendance(continueAfterMarks: false, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            guard let dict = result as? [String: Any] else {
                self.logger.error("Invalid processViewTimeTable response", context: "DataManager")
                if chainToAttendance && continueAfterAttendance {
                    self.fetchAttendance()
                } else if chainToAttendance && !continueAfterAttendance {
                    self.fetchAttendance(continueAfterMarks: false, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            let coursesData = dict["courses"] as? [[String: Any]] ?? []
            let timetableData = dict["timetable"] as? [[String: Any]] ?? []

            self.debugPrintFullVTOPResponse("processViewTimeTable", dict["rawProcessViewTimeTable"] as? String)

            // Parse courses
            var courses: [Course] = []
            for courseDict in coursesData {
                guard let id = courseDict["id"] as? Int,
                      let code = courseDict["code"] as? String,
                      let title = courseDict["title"] as? String,
                      let typeStr = courseDict["type"] as? String,
                      let venue = courseDict["venue"] as? String,
                      let faculty = courseDict["faculty"] as? String else { continue }

                let credits = Self.intFromJSON(courseDict["credits"]) ?? 0
                let type = CourseType(rawValue: typeStr.uppercased()) ?? .theory
                let slotsData = courseDict["slots"] as? [[String: Any]] ?? []
                let slots = slotsData.compactMap { slotDict -> Slot? in
                    guard let slotId = slotDict["id"] as? Int,
                          let slotName = slotDict["slot"] as? String,
                          let courseId = slotDict["courseId"] as? Int else { return nil }
                    return Slot(id: slotId, slot: slotName, courseId: courseId)
                }

                courses.append(Course(id: id, code: code, title: title, type: type,
                                    credits: credits, venue: venue, faculty: faculty, slots: slots))
            }

            // Parse timetable (slot tokens per weekday, from VTOP grid)
            var timetable: [TimetableSlot] = []
            for ttDict in timetableData {
                guard let id = ttDict["id"] as? Int,
                      let startTime = ttDict["startTime"] as? String,
                      let endTime = ttDict["endTime"] as? String else { continue }

                var slot = TimetableSlot(id: id, startTime: startTime, endTime: endTime)
                slot.sunday = Self.optionalTrimmedString(ttDict["sunday"])
                slot.monday = Self.optionalTrimmedString(ttDict["monday"])
                slot.tuesday = Self.optionalTrimmedString(ttDict["tuesday"])
                slot.wednesday = Self.optionalTrimmedString(ttDict["wednesday"])
                slot.thursday = Self.optionalTrimmedString(ttDict["thursday"])
                slot.friday = Self.optionalTrimmedString(ttDict["friday"])
                slot.saturday = Self.optionalTrimmedString(ttDict["saturday"])
                timetable.append(slot)
            }

            DispatchQueue.main.async {
                self.courses = courses
                self.timetable = timetable
                self.cacheCurrentSemesterScheduleIfNeeded()
                self.logger.success("✅ Loaded \(courses.count) courses and \(timetable.count) timetable slots", context: "DataManager")
                self.scheduleCachePersistence()
                if chainToAttendance {
                    if continueAfterAttendance {
                        self.fetchAttendance()
                    } else {
                        self.fetchAttendance(continueAfterMarks: false, completion: completion)
                    }
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    /// Selects semester and reloads only courses + timetable (does not run full `fetchAllData` chain).
    func refreshTimetableAndCoursesForSemester(_ semester: Semester, completion: (() -> Void)? = nil) {
        logger.info("📅 Timetable semester: \(semester.name)", context: "DataManager")
        selectedSemester = semester
        UserDefaults.standard.set(semester.id, forKey: "semesterId")
        UserDefaults.standard.set(semester.name, forKey: "semester")

        if let cachedCourses = coursesBySemesterId[semester.id],
           let cachedTimetable = timetableBySemesterId[semester.id] {
            courses = cachedCourses
            timetable = cachedTimetable
        }
        scheduleCachePersistence()

        guard webView != nil else {
            logger.warning("WebView not ready for timetable refresh", context: "DataManager")
            completion?()
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading timetable..."
        }
        fetchCoursesAndTimetable(chainToAttendance: false, continueAfterAttendance: true, completion: completion)
    }

    // MARK: - Fetch Marks
    private func fetchMarks(continueChain: Bool = true, completion: (() -> Void)? = nil) {
        logger.info("📈 Fetching marks and grades...", context: "DataManager")

        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let semesterId = selectedSemester?.id else {
            logger.error("Missing session or semester data", context: "DataManager")
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading marks..."
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { marks: [], cumulativeMarks: [], gpa: null, rawDoStudentMarkView: '', rawDoStudentGradeView: '' };
            var markCounter = 1;

            $.ajax({
                type: 'POST',
                url: '/vtop/examinations/doStudentMarkView',
                data: {
                    semesterSubId: '\(semesterId)',
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)'
                },
                async: false,
                success: function(resMarks) {
                    if (__VTOP_DEBUG__) { result.rawDoStudentMarkView = resMarks; }
                    $(resMarks).find('#fixedTableContainer table tbody tr').each(function() {
                        var cells = $(this).find('td');
                        if (cells.length >= 8) {
                            var courseCode = cells.eq(0).text().trim();
                            var courseType = cells.eq(1).text().trim();
                            var title = cells.eq(2).text().trim();
                            var score = parseFloat(cells.eq(3).text().trim()) || 0;
                            var maxScore = parseFloat(cells.eq(4).text().trim()) || 0;
                            var weightage = parseFloat(cells.eq(5).text().trim()) || 0;
                            var maxWeightage = parseFloat(cells.eq(6).text().trim()) || 0;
                            var average = parseFloat(cells.eq(7).text().trim()) || 0;
                            var status = cells.eq(8) ? cells.eq(8).text().trim() : 'Present';

                            result.marks.push({
                                id: markCounter++,
                                courseCode: courseCode,
                                courseType: courseType,
                                title: title,
                                score: score,
                                maxScore: maxScore,
                                weightage: weightage,
                                maxWeightage: maxWeightage,
                                average: average > 0 ? average : null,
                                status: status
                            });
                        }
                    });
                    $.ajax({
                type: 'POST',
                url: '/vtop/examinations/examGradeView/doStudentGradeView',
                data: {
                    semesterSubId: '\(semesterId)',
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)'
                },
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawDoStudentGradeView = res; }
                    if (!res || res.toLowerCase().indexOf('no records') >= 0) {
                        return;
                    }
                    var gpaMatch = res.match(/GPA\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)/i);
                    if (gpaMatch) {
                        result.gpa = gpaMatch[1];
                    }
                    var cumulativeCounter = 1;
                    var $wrap = $('<div>').html(res);
                    var $table = $wrap.find('.box-body table.table-bordered, .box-body table.table-hover, table.table-hover').first();
                    if (!$table.length) {
                        $table = $wrap.find('table').first();
                    }
                    $table.find('tr').each(function() {
                        var $tr = $(this);
                        if ($tr.find('th').length > 0) return;
                        var $tds = $tr.find('td');
                        if ($tds.length < 6) return;
                        var sl = $tds.eq(0).text().trim();
                        if (!/^\\d+$/.test(sl)) return;
                        var courseCode = $tds.eq(1).text().trim();
                        if (!courseCode || courseCode.length < 4) return;
                        var gradeIdx = $tds.length - 2;
                        if ($tds.eq($tds.length - 1).find('button').length === 0) {
                            gradeIdx = $tds.length - 2;
                        }
                        var grade = $tds.eq(gradeIdx).text().trim();
                        if (!grade || /^\\d+(\\.\\d+)?$/.test(grade)) return;
                        var courseTitle = $tds.eq(2).text().trim();
                        result.cumulativeMarks.push({
                            id: cumulativeCounter++,
                            courseCode: courseCode,
                            courseTitle: courseTitle,
                            grade: grade,
                            option: ''
                        });
                    });
                    if (result.cumulativeMarks.length === 0) {
                        try {
                            var doc = new DOMParser().parseFromString(res, 'text/html');
                            var table = doc.getElementsByTagName('table')[0];
                            if (!table) { return; }
                            var headings = table.getElementsByTagName('th');
                            var courseCodeIndex, gradeIndex, creditsIndex, creditsSpan;
                            for (var i = 0; i < headings.length; ++i) {
                                var heading = headings[i].innerText.toLowerCase();
                                if (heading.includes('code')) {
                                    courseCodeIndex = i;
                                } else if (heading.includes('credits')) {
                                    creditsIndex = i;
                                    creditsSpan = headings[i].colSpan || 1;
                                } else if (heading.includes('grade') && !heading.includes('view')) {
                                    gradeIndex = i;
                                }
                            }
                            if (courseCodeIndex == null || gradeIndex == null || creditsIndex == null) { return; }
                            if (courseCodeIndex > creditsIndex) {
                                courseCodeIndex += creditsSpan - 1;
                            }
                            if (gradeIndex > creditsIndex) {
                                gradeIndex += creditsSpan - 1;
                            }
                            var cells = table.getElementsByTagName('td');
                            var stride = headings.length - 1;
                            if (stride < 1) stride = 1;
                            cumulativeCounter = 1;
                            while (courseCodeIndex < cells.length && gradeIndex < cells.length) {
                                var cc = cells[courseCodeIndex].innerText.trim();
                                var gr = cells[gradeIndex].innerText.trim();
                                if (cc && gr && !/^\\d+$/.test(cc)) {
                                    result.cumulativeMarks.push({
                                        id: cumulativeCounter++,
                                        courseCode: cc,
                                        courseTitle: '',
                                        grade: gr,
                                        option: ''
                                    });
                                }
                                courseCodeIndex += stride;
                                gradeIndex += stride;
                            }
                            var lastCell = cells[cells.length - 1];
                            if (lastCell && lastCell.innerText && lastCell.innerText.indexOf(':') >= 0) {
                                var parts = lastCell.innerText.split(':');
                                if (parts.length > 1) {
                                    var maybe = parts[parts.length - 1].trim();
                                    if (/^[0-9]+(\\.[0-9]+)?$/.test(maybe)) result.gpa = maybe;
                                }
                            }
                        } catch (e) { }
                    }
                },
                error: function(xhr, st, err) { }
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch marks: \(error.localizedDescription)", context: "DataManager")
                if continueChain {
                    self.fetchExams()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            guard let dict = result as? [String: Any],
                  let marksData = dict["marks"] as? [[String: Any]],
                  let cumulativeData = dict["cumulativeMarks"] as? [[String: Any]] else {
                self.logger.error("Invalid marks response", context: "DataManager")
                if continueChain {
                    self.fetchExams()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            self.debugPrintFullVTOPResponse("doStudentMarkView", dict["rawDoStudentMarkView"] as? String)
            self.debugPrintFullVTOPResponse("doStudentGradeView", dict["rawDoStudentGradeView"] as? String)

            // Parse marks
            var marks: [Mark] = []
            for markDict in marksData {
                guard let id = markDict["id"] as? Int,
                      let courseCode = markDict["courseCode"] as? String,
                      let title = markDict["title"] as? String else { continue }

                let courseId = self.courses.first(where: { $0.code == courseCode })?.id ?? id
                let score = markDict["score"] as? Double ?? 0
                let maxScore = markDict["maxScore"] as? Double ?? 0
                let weightage = markDict["weightage"] as? Double ?? 0
                let maxWeightage = markDict["maxWeightage"] as? Double ?? 0
                let average = markDict["average"] as? Double
                let status = markDict["status"] as? String ?? "Present"

                let signature = title.hashValue ^ Int(score) ^ Int(weightage)
                marks.append(Mark(id: id, courseId: courseId, title: title,
                                score: score, maxScore: maxScore,
                                weightage: weightage, maxWeightage: maxWeightage,
                                average: average, status: status,
                                isRead: false, signature: signature))
            }

            // Parse cumulative marks
            var cumulativeMarks: [CumulativeMark] = []
            for cumDict in cumulativeData {
                guard let id = cumDict["id"] as? Int,
                      let courseCode = cumDict["courseCode"] as? String else { continue }

                let grade = cumDict["grade"] as? String

                cumulativeMarks.append(CumulativeMark(id: id, courseCode: courseCode,
                                                     grade: grade))
            }

            let semesterGpa = dict["gpa"] as? String

            DispatchQueue.main.async {
                self.marks = marks
                self.cumulativeMarks = cumulativeMarks
                if let semId = self.selectedSemester?.id, !semId.isEmpty {
                    self.marksBySemesterId[semId] = marks
                    self.cumulativeMarksBySemesterId[semId] = cumulativeMarks
                }
                if let g = semesterGpa, !g.isEmpty {
                    if var p = self.studentProfile {
                        p.gpa = g
                        self.studentProfile = p
                    }
                }
                self.logger.success("✅ Loaded \(marks.count) marks and \(cumulativeMarks.count) grades", context: "DataManager")
                self.scheduleCachePersistence()
                if continueChain {
                    self.fetchExams()
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    // MARK: - Fetch Attendance
    /// Refreshes attendance from `processViewStudentAttendance` for the selected semester only (does not continue the marks chain).
    func refreshAttendanceOnly(completion: (() -> Void)? = nil) {
        fetchAttendance(continueAfterMarks: false, semesterSubId: nil, completion: completion)
    }

    /// Loads attendance for a specific semester id (Attendance tab). Does not continue the marks chain.
    func refreshAttendance(semesterSubId: String, continueAfterMarks: Bool = false, completion: (() -> Void)? = nil) {
        fetchAttendance(continueAfterMarks: continueAfterMarks, semesterSubId: semesterSubId, completion: completion)
    }

    /// Parses `select#semesterSubId` from the Student Attendance page POST response.
    func loadAttendanceSemesterPicklist(completion: (() -> Void)? = nil) {
        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let webView = self.webView else {
            completion?()
            return
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { semesters: [] };
            $.ajax({
                type: 'POST',
                url: '/vtop/academics/common/StudentAttendance',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    $(res).find('select#semesterSubId option, select[name="semesterSubId"] option').each(function() {
                        var v = ($(this).attr('value') || '').trim();
                        var t = $(this).text().replace(/\\s+/g, ' ').trim();
                        if (v) result.semesters.push({ id: v, name: t });
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else {
                completion?()
                return
            }
            if let error = error {
                self.logger.error("Attendance picklist: \(error.localizedDescription)", context: "DataManager")
                completion?()
                return
            }
            guard let dict = result as? [String: Any],
                  let rows = dict["semesters"] as? [[String: Any]] else {
                completion?()
                return
            }
            let list: [Semester] = rows.compactMap { r in
                guard let id = r["id"] as? String, !id.isEmpty,
                      let name = r["name"] as? String else { return nil }
                return Semester(id: id, name: name)
            }
            DispatchQueue.main.async {
                self.attendanceSemesterOptions = list
                self.logger.success("✅ Attendance semester picklist: \(list.count) options", context: "DataManager")
                self.scheduleCachePersistence()
                completion?()
            }
        }
    }

    /// Loads semester options from `examinations/StudentMarkView` for the marks-by-semester screen.
    func loadMarksSemesterPicklist(completion: (() -> Void)? = nil) {
        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let webView = self.webView else {
            completion?()
            return
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { semesters: [] };
            $.ajax({
                type: 'POST',
                url: '/vtop/examinations/StudentMarkView',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    $(res).find('select#semesterSubId option, select[name="semesterSubId"] option').each(function() {
                        var v = ($(this).attr('value') || '').trim();
                        var t = $(this).text().replace(/\\s+/g, ' ').trim();
                        if (v) result.semesters.push({ id: v, name: t });
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else {
                completion?()
                return
            }
            if let error = error {
                self.logger.error("Marks picklist: \(error.localizedDescription)", context: "DataManager")
                completion?()
                return
            }
            guard let dict = result as? [String: Any],
                  let rows = dict["semesters"] as? [[String: Any]] else {
                completion?()
                return
            }
            let list: [Semester] = rows.compactMap { r in
                guard let id = r["id"] as? String, !id.isEmpty,
                      let name = r["name"] as? String else { return nil }
                return Semester(id: id, name: name)
            }
            DispatchQueue.main.async {
                self.marksReportSemesterOptions = list
                self.logger.success("✅ Marks semester picklist: \(list.count) options", context: "DataManager")
                self.scheduleCachePersistence()
                completion?()
            }
        }
    }

    /// Fetches `doStudentMarkView` for one semester and parses nested mark tables (Chennai `customTable` layout).
    func refreshMarksReport(semesterSubId: String, completion: (() -> Void)? = nil) {
        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let webView = self.webView,
              !semesterSubId.isEmpty else {
            completion?()
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading marks report…"
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { marksReport: [], rawDoStudentMarkView: '' };
            var idCounter = 1;
            var postBody = '_csrf=' + encodeURIComponent('\(csrfToken)') +
                '&semesterSubId=' + encodeURIComponent('\(semesterSubId)') +
                '&authorizedID=' + encodeURIComponent('\(authorizedID)');
            $.ajax({
                type: 'POST',
                url: '/vtop/examinations/doStudentMarkView',
                data: postBody,
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawDoStudentMarkView = res; }
                    var $doc = $(res);
                    var $mtable = $doc.find('#fixedTableContainer table.customTable').first();
                    if (!$mtable.length) {
                        $doc.find('table.customTable').each(function() {
                            if ($(this).find('tr.tableContent-level1').length) { $mtable = $(this); return false; }
                        });
                    }
                    if (!$mtable.length) { return; }
                    var kids = $mtable.children('tbody').length ? $mtable.children('tbody').children('tr') : $mtable.children('tr');
                    var arr = kids.get();
                    for (var i = 0; i < arr.length; i++) {
                        var $tr = $(arr[i]);
                        if ($tr.hasClass('tableHeader')) continue;
                        if (!$tr.hasClass('tableContent')) continue;
                        var $tds = $tr.children('td');
                        if ($tds.length < 9) continue;
                        var courseCode = $tds.eq(2).text().replace(/\\s+/g, ' ').trim();
                        var courseTitle = $tds.eq(3).text().replace(/\\s+/g, ' ').trim();
                        if (i + 1 < arr.length) {
                            var $n = $(arr[i + 1]);
                            var $nc = $n.children('td');
                            if ($n.hasClass('tableContent') && $nc.length === 1 && $nc.attr('colspan')) {
                                $n.find('tr.tableContent-level1').each(function() {
                                    var c = $(this).children('td');
                                    if (c.length < 7) return;
                                    var markTitle = c.eq(1).text().replace(/\\s+/g, ' ').trim();
                                    if (!markTitle) return;
                                    var maxMark = parseFloat(c.eq(2).text()) || 0;
                                    var wpct = parseFloat(c.eq(3).text()) || 0;
                                    var status = c.eq(4).text().replace(/\\s+/g, ' ').trim();
                                    var sm = parseFloat(c.eq(5).text()) || 0;
                                    var wm = parseFloat(c.eq(6).text()) || 0;
                                    var avgStr = c.eq(7).text().trim();
                                    var avg = parseFloat(avgStr);
                                    if (isNaN(avg)) avg = null;
                                    result.marksReport.push({
                                        id: idCounter++,
                                        courseCode: courseCode,
                                        courseTitle: courseTitle || null,
                                        markTitle: markTitle,
                                        maxMark: maxMark,
                                        weightagePercent: wpct,
                                        scoredMark: sm,
                                        weightageMark: wm,
                                        status: status,
                                        classAverage: avg
                                    });
                                });
                                i++;
                            }
                        }
                    }
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else {
                completion?()
                return
            }
            DispatchQueue.main.async {
                self.syncState.loadingMessage = ""
            }
            if let error = error {
                self.logger.error("Marks report: \(error.localizedDescription)", context: "DataManager")
                completion?()
                return
            }
            guard let dict = result as? [String: Any] else {
                completion?()
                return
            }
            let raw = dict["rawDoStudentMarkView"] as? String
            self.debugPrintFullVTOPResponse("doStudentMarkView(marksReport)", raw)

            let rowsData = dict["marksReport"] as? [[String: Any]] ?? []
            var rows: [MarkReportRow] = []
            for r in rowsData {
                guard let id = Self.intFromJSON(r["id"]),
                      let courseCode = r["courseCode"] as? String,
                      let markTitle = r["markTitle"] as? String else { continue }
                let courseTitle = r["courseTitle"] as? String
                let maxMark = Self.doubleIfPresent(r["maxMark"]) ?? 0
                let weightagePercent = Self.doubleIfPresent(r["weightagePercent"]) ?? 0
                let scoredMark = Self.doubleIfPresent(r["scoredMark"]) ?? 0
                let weightageMark = Self.doubleIfPresent(r["weightageMark"]) ?? 0
                let status = r["status"] as? String ?? ""
                let classAverage = Self.doubleIfPresent(r["classAverage"])
                rows.append(MarkReportRow(
                    id: id,
                    courseCode: courseCode,
                    courseTitle: courseTitle,
                    markTitle: markTitle,
                    maxMark: maxMark,
                    weightagePercent: weightagePercent,
                    scoredMark: scoredMark,
                    weightageMark: weightageMark,
                    status: status,
                    classAverage: classAverage
                ))
            }
            DispatchQueue.main.async {
                self.marksReportRows = rows
                self.marksReportSemesterId = semesterSubId
                self.logger.success("✅ Marks report: \(rows.count) entries", context: "DataManager")
                self.scheduleCachePersistence()
                completion?()
            }
        }
    }

    private func fetchAttendance(continueAfterMarks: Bool = true, semesterSubId: String? = nil, completion: (() -> Void)? = nil) {
        logger.info("📊 Fetching attendance...", context: "DataManager")

        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let semesterId = semesterSubId ?? selectedSemester?.id,
              !semesterId.isEmpty else {
            logger.error("Missing session or semester data", context: "DataManager")
            if !continueAfterMarks {
                DispatchQueue.main.async {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading attendance..."
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { attendance: [], rawProcessViewStudentAttendance: '' };
            var attendanceCounter = 1;
            var postBody = '_csrf=' + encodeURIComponent('\(csrfToken)') +
                '&semesterSubId=' + encodeURIComponent('\(semesterId)') +
                '&authorizedID=' + encodeURIComponent('\(authorizedID)') +
                '&x=' + encodeURIComponent(new Date().toUTCString());

            $.ajax({
                type: 'POST',
                url: '/vtop/processViewStudentAttendance',
                data: postBody,
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawProcessViewStudentAttendance = res; }
                    var $doc = $(res);
                    function compactThText($tbl) {
                        var parts = [];
                        $tbl.find('th').each(function() {
                            parts.push(($(this).text() || '').toLowerCase().replace(/\\s+/g, ''));
                        });
                        return parts.join('');
                    }
                    function attendanceTableMatches($tbl) {
                        var c = compactThText($tbl);
                        var courseOk = c.indexOf('coursecode') >= 0 || (c.indexOf('course') >= 0 && c.indexOf('code') >= 0);
                        var attOk = (c.indexOf('attended') >= 0 && c.indexOf('class') >= 0) || c.indexOf('attendedclasses') >= 0;
                        var totOk = (c.indexOf('total') >= 0 && c.indexOf('class') >= 0) || c.indexOf('totalclasses') >= 0;
                        return courseOk && attOk && totOk;
                    }
                    var $table = $doc.find('#getStudentDetails table').first();
                    if (!$table.length || !attendanceTableMatches($table)) {
                        $table = $doc.find('table').filter(function() { return attendanceTableMatches($(this)); }).first();
                    }
                    if (!$table.length) { return; }

                    var headers = [];
                    var $theadLast = $table.find('thead tr').last();
                    if ($theadLast.length) {
                        $theadLast.find('th, td').each(function() {
                            headers.push($(this).text().replace(/\\s+/g, ' ').trim().toLowerCase());
                        });
                    }
                    if (!headers.length) {
                        $table.find('tr').each(function() {
                            var $cells = $(this).children('th, td');
                            if ($cells.length < 8) return;
                            var rowTxt = ($cells.text() || '').toLowerCase().replace(/\\s+/g, ' ');
                            if (rowTxt.indexOf('course') < 0 || rowTxt.indexOf('attended') < 0) return;
                            $cells.each(function() {
                                headers.push($(this).text().replace(/\\s+/g, ' ').trim().toLowerCase());
                            });
                            return false;
                        });
                    }
                    function col(sub) {
                        for (var i = 0; i < headers.length; i++) {
                            if (headers[i].indexOf(sub) >= 0) return i;
                        }
                        if (sub === 'course code') {
                            for (var j = 0; j < headers.length - 1; j++) {
                                var hj = (headers[j] || '').replace(/\\s+/g, '');
                                if (/^sl\\.?no$/i.test(hj) || hj.indexOf('sl.no') === 0) continue;
                                var merged = (headers[j] + ' ' + headers[j + 1]).replace(/\\s+/g, ' ');
                                if (merged.indexOf('course code') >= 0) return j;
                            }
                        }
                        return -1;
                    }
                    var iCode = col('course code');
                    var iTitle = col('course title');
                    var iType = col('course type');
                    var iSlot = col('slot');
                    var iFac = col('faculty');
                    var iAttType = col('attendance type');
                    var iReg = col('registration');
                    var iAttDate = col('attendance date');
                    var iAttended = col('attended classes');
                    if (iAttended < 0) iAttended = col('attended');
                    var iTotal = col('total classes');
                    if (iTotal < 0) iTotal = col('total class');
                    var iPct = col('attendance percentage');
                    if (iPct < 0) iPct = col('percentage');
                    var iStatus = col('status');
                    if (iCode < 0 || iAttended < 0 || iTotal < 0) { return; }

                    $table.find('tr').each(function() {
                        if ($(this).closest('thead').length) return;
                        var $tds = $(this).find('td');
                        if ($tds.length < 8) return;
                        if ($tds.first().attr('colspan')) return;
                        var code = $tds.eq(iCode).text().trim();
                        if (!code) return;
                        var attended = parseInt($tds.eq(iAttended).text().trim(), 10) || 0;
                        var total = parseInt($tds.eq(iTotal).text().trim(), 10) || 0;
                        var pctFromCol = iPct >= 0 ? parseInt($tds.eq(iPct).text().trim(), 10) : NaN;
                        var percentage = !isNaN(pctFromCol) ? pctFromCol : (total > 0 ? Math.ceil((attended * 100.0) / total) : 0);
                        var title = iTitle >= 0 ? $tds.eq(iTitle).text().trim() : null;
                        var ctype = iType >= 0 ? $tds.eq(iType).text().trim() : null;
                        var slot = iSlot >= 0 ? $tds.eq(iSlot).text().trim() : null;
                        var faculty = iFac >= 0 ? $tds.eq(iFac).text().replace(/\\s+/g, ' ').trim() : null;
                        var attType = iAttType >= 0 ? $tds.eq(iAttType).text().trim() : null;
                        var regDt = iReg >= 0 ? $tds.eq(iReg).text().trim() : null;
                        var attDt = iAttDate >= 0 ? $tds.eq(iAttDate).text().trim() : null;
                        var status = iStatus >= 0 ? $tds.eq(iStatus).text().trim() : null;

                        result.attendance.push({
                            id: attendanceCounter++,
                            courseCode: code,
                            attended: attended,
                            total: total,
                            percentage: percentage,
                            courseTitle: title || null,
                            courseType: ctype || null,
                            slot: slot || null,
                            facultySummary: faculty || null,
                            attendanceType: attType || null,
                            registrationDateText: regDt || null,
                            attendanceDateText: attDt || null,
                            statusText: status || null
                        });
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch attendance: \(error.localizedDescription)", context: "DataManager")
                if continueAfterMarks {
                    self.fetchMarks()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            guard let dict = result as? [String: Any],
                  let attendanceData = dict["attendance"] as? [[String: Any]] else {
                self.logger.error("Invalid attendance response", context: "DataManager")
                if continueAfterMarks {
                    self.fetchMarks()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            self.debugPrintFullVTOPResponse("processViewStudentAttendance", dict["rawProcessViewStudentAttendance"] as? String)

            var attendance: [Attendance] = []
            for (index, attDict) in attendanceData.enumerated() {
                guard let courseCode = attDict["courseCode"] as? String,
                      let attended = Self.intFromJSON(attDict["attended"]),
                      let total = Self.intFromJSON(attDict["total"]),
                      let percentage = Self.intFromJSON(attDict["percentage"]) else { continue }

                let normalizedCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
                let courseId = self.courses.first(where: {
                    $0.code.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedCode) == .orderedSame
                })?.id ?? 0
                let courseTitle = attDict["courseTitle"] as? String
                let courseType = attDict["courseType"] as? String
                let slot = attDict["slot"] as? String
                let facultySummary = attDict["facultySummary"] as? String
                let attendanceType = attDict["attendanceType"] as? String
                let registrationDateText = attDict["registrationDateText"] as? String
                let attendanceDateText = attDict["attendanceDateText"] as? String
                let statusText = attDict["statusText"] as? String

                attendance.append(Attendance(
                    id: index + 1,
                    courseId: courseId,
                    attended: attended,
                    total: total,
                    percentage: percentage,
                    courseCode: courseCode,
                    courseTitle: courseTitle,
                    courseType: courseType,
                    slot: slot,
                    facultySummary: facultySummary,
                    attendanceType: attendanceType,
                    registrationDateText: registrationDateText,
                    attendanceDateText: attendanceDateText,
                    statusText: statusText
                ))
            }

            DispatchQueue.main.async {
                self.attendance = attendance
                self.logger.success("✅ Loaded attendance for \(attendance.count) courses", context: "DataManager")
                self.scheduleCachePersistence()
                if continueAfterMarks {
                    self.fetchMarks()
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    // MARK: - Exam schedule (semester picker + `customTable` parse)

    /// Loads `select#semesterSubId` from `examinations/StudExamSchedule`.
    func loadExamScheduleSemesterPicklist(completion: (() -> Void)? = nil) {
        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let webView = self.webView else {
            completion?()
            return
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { semesters: [] };
            $.ajax({
                type: 'POST',
                url: '/vtop/examinations/StudExamSchedule',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    $(res).find('select#semesterSubId option, select[name="semesterSubId"] option').each(function() {
                        var v = ($(this).attr('value') || '').trim();
                        var t = $(this).text().replace(/\\s+/g, ' ').trim();
                        if (v) result.semesters.push({ id: v, name: t });
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else {
                completion?()
                return
            }
            if let error = error {
                self.logger.error("Exam schedule picklist: \(error.localizedDescription)", context: "DataManager")
                completion?()
                return
            }
            guard let dict = result as? [String: Any],
                  let rows = dict["semesters"] as? [[String: Any]] else {
                completion?()
                return
            }
            let list: [Semester] = rows.compactMap { r in
                guard let id = r["id"] as? String, !id.isEmpty,
                      let name = r["name"] as? String else { return nil }
                return Semester(id: id, name: name)
            }
            DispatchQueue.main.async {
                self.examScheduleSemesterOptions = list
                self.logger.success("✅ Exam schedule semester picklist: \(list.count) options", context: "DataManager")
                self.scheduleCachePersistence()
                completion?()
            }
        }
    }

    /// Fetches exam rows for a term (used from Exam Schedule screen). Does not continue the sync chain.
    func refreshExamSchedule(semesterSubId: String, completion: (() -> Void)? = nil) {
        fetchExamScheduleForSemester(semesterSubId, continueSyncChain: false, completion: completion)
    }

    private func fetchExams() {
        logger.info("📅 Fetching exam schedule...", context: "DataManager")

        guard let semesterId = selectedSemester?.id, !semesterId.isEmpty else {
            logger.error("Missing semester for exams", context: "DataManager")
            fetchStaff()
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading exams..."
        }

        fetchExamScheduleForSemester(semesterId, continueSyncChain: true, completion: nil)
    }

    private func fetchExamScheduleForSemester(_ semesterSubId: String, continueSyncChain: Bool, completion: (() -> Void)?) {
        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let webView = self.webView else {
            if continueSyncChain { fetchStaff() }
            completion?()
            return
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = { exams: [], rawDoSearchExamScheduleForStudent: '' };
            var examCounter = 1;
            var postBody = 'authorizedID=' + encodeURIComponent('\(authorizedID)') +
                '&semesterSubId=' + encodeURIComponent('\(semesterSubId)') +
                '&_csrf=' + encodeURIComponent('\(csrfToken)');

            $.ajax({
                type: 'POST',
                url: '/vtop/examinations/doSearchExamScheduleForStudent',
                data: postBody,
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawDoSearchExamScheduleForStudent = res; }
                    var $table = $(res).find('table.customTable').first();
                    if (!$table.length) {
                        $table = $(res).find('#fixedTableContainer table').first();
                    }
                    var category = '';
                    $table.find('tr.tableContent').each(function() {
                        var $tds = $(this).find('td');
                        if ($tds.length === 1 && $tds.attr('colspan')) {
                            category = $tds.text().replace(/\\s+/g, ' ').trim();
                            return;
                        }
                        if ($tds.length < 13) return;
                        var sno = $tds.eq(0).text().trim();
                        if (!/^\\d+$/.test(sno)) return;
                        var courseCode = $tds.eq(1).text().trim();
                        var courseTitle = $tds.eq(2).text().trim();
                        var courseTypeAbbr = $tds.eq(3).text().trim();
                        var classId = $tds.eq(4).text().trim();
                        var slot = $tds.eq(5).text().trim();
                        var examDate = $tds.eq(6).text().trim();
                        var session = $tds.eq(7).text().trim();
                        var reporting = $tds.eq(8).text().trim();
                        var examTime = $tds.eq(9).text().trim();
                        var venue = $tds.eq(10).text().trim();
                        var seatLoc = $tds.eq(11).text().replace(/\\s+/g, ' ').trim();
                        if (seatLoc === '-' || seatLoc === '') seatLoc = '';
                        var seatNoStr = $tds.eq(12).text().trim();
                        var seatNo = parseInt(seatNoStr, 10);

                        result.exams.push({
                            id: examCounter++,
                            courseCode: courseCode,
                            courseTitle: courseTitle,
                            courseTypeAbbrev: courseTypeAbbr,
                            classId: classId,
                            slot: slot,
                            examDate: examDate,
                            session: session,
                            reporting: reporting,
                            examTime: examTime,
                            venue: venue,
                            seatLocation: seatLoc,
                            seatNumber: isNaN(seatNo) ? null : seatNo,
                            category: category,
                            listTitle: (category ? category + ' · ' : '') + courseCode
                        });
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch exams: \(error.localizedDescription)", context: "DataManager")
                if continueSyncChain { self.fetchStaff() }
                DispatchQueue.main.async { completion?() }
                return
            }

            guard let dict = result as? [String: Any],
                  let examsData = dict["exams"] as? [[String: Any]] else {
                self.logger.error("Invalid exams response", context: "DataManager")
                if continueSyncChain { self.fetchStaff() }
                DispatchQueue.main.async { completion?() }
                return
            }

            self.debugPrintFullVTOPResponse("doSearchExamScheduleForStudent", dict["rawDoSearchExamScheduleForStudent"] as? String)

            var exams: [Exam] = []
            for examDict in examsData {
                guard let id = examDict["id"] as? Int,
                      let courseCode = examDict["courseCode"] as? String, !courseCode.isEmpty,
                      let venueRaw = examDict["venue"] as? String else { continue }

                let listTitle = examDict["listTitle"] as? String ?? courseCode
                let category = examDict["category"] as? String
                let courseTitle = examDict["courseTitle"] as? String
                let normalizedCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
                let courseId = self.courses.first(where: {
                    $0.code.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedCode) == .orderedSame
                })?.id ?? 0

                let venue = venueRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                let seatLoc = (examDict["seatLocation"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let seatNum = Self.intFromJSON(examDict["seatNumber"])

                exams.append(Exam(
                    id: id,
                    courseId: courseId,
                    title: listTitle,
                    venue: venue.isEmpty ? nil : venue,
                    seatLocation: (seatLoc?.isEmpty ?? true) ? nil : seatLoc,
                    seatNumber: seatNum,
                    courseCode: courseCode,
                    courseTitle: courseTitle,
                    examCategory: category,
                    examDateText: examDict["examDate"] as? String,
                    sessionLabel: examDict["session"] as? String,
                    reportingTimeText: examDict["reporting"] as? String,
                    examTimeRangeText: examDict["examTime"] as? String,
                    slotText: examDict["slot"] as? String,
                    classIdText: examDict["classId"] as? String,
                    courseTypeAbbrev: examDict["courseTypeAbbrev"] as? String
                ))
            }

            DispatchQueue.main.async {
                self.exams = exams
                self.examScheduleSemesterId = semesterSubId
                self.logger.success("✅ Loaded \(exams.count) exam row(s)", context: "DataManager")
                self.scheduleCachePersistence()
                if continueSyncChain {
                    self.fetchStaff()
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    // MARK: - Fetch Staff
    private func fetchStaff(continueFullSyncChain: Bool = true, completion: (() -> Void)? = nil) {
        logger.info("👥 Fetching staff information...", context: "DataManager")

        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken else {
            logger.error("Missing session data", context: "DataManager")
            if !continueFullSyncChain {
                DispatchQueue.main.async { completion?() }
            }
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading staff info..."
        }

        let script = """
        (function() {
            \(VTOPJSConfig.debugVarInit)
            var result = {
                staff: [],
                portalCredentials: [],
                rankEntries: [],
                deanPhotoDataUrl: null,
                hodPhotoDataUrl: null,
                rawViewProctorDetails: '',
                rawViewHodDeanDetails: '',
                rawViewStudentCredentials: ''
            };
            var staffCounter = 1;
            var credCounter = 1;

            $.ajax({
                type: 'POST',
                url: '/vtop/proctor/viewProctorDetails',
                data: {
                    verifyMenu: 'true',
                    winImage: '',
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)',
                    nocache: Date.now()
                },
                async: false,
                success: function(res) {
                    if (__VTOP_DEBUG__) { result.rawViewProctorDetails = res; }
                    $(res).find('table tbody tr').each(function() {
                        var cells = $(this).find('td');
                        if (cells.length >= 2) {
                            var key = cells.eq(0).text().trim();
                            var value = cells.eq(1).text().trim();
                            if (key && value) {
                                result.staff.push({
                                    id: staffCounter++,
                                    type: 'Proctor',
                                    key: key,
                                    value: value
                                });
                            }
                        }
                    });
                },
                error: function() { }
            });

            $.ajax({
                type: 'POST',
                url: '/vtop/hrms/viewHodDeanDetails',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res2) {
                    if (__VTOP_DEBUG__) { result.rawViewHodDeanDetails = res2; }
                    var $res = $(res2);
                    $res.find('h3.box-title, .box-title').each(function() {
                        var heading = $(this).text().trim().toLowerCase();
                        var role = null;
                        if (heading === 'dean' || (heading.indexOf('dean') >= 0 && heading.indexOf('hod') < 0)) {
                            role = 'Dean';
                        } else if (heading.indexOf('hod') >= 0 || heading.indexOf('head of the department') >= 0) {
                            role = 'HOD';
                        }
                        if (!role) return;
                        var $table = $(this).closest('.box-header').next('table');
                        if (!$table.length) $table = $(this).parent().nextAll('table').first();
                        if (!$table.length) $table = $(this).closest('div').next('table');
                        if (!$table.length) return;
                        var $img = $table.find('img').first();
                        var src = ($img.attr('src') || '').trim();
                        if (src.indexOf('base64') >= 0) {
                            if (role === 'Dean') result.deanPhotoDataUrl = src;
                            else if (role === 'HOD') result.hodPhotoDataUrl = src;
                        }
                        $table.find('tr').each(function() {
                            var cells = $(this).find('td');
                            if (cells.length < 2) return;
                            var key = cells.eq(0).text().replace(/\\s+/g, ' ').trim();
                            var value = cells.eq(1).text().replace(/\\s+/g, ' ').trim();
                            if (key && value && key.length < 200) {
                                result.staff.push({
                                    id: staffCounter++,
                                    type: role,
                                    key: key,
                                    value: value
                                });
                            }
                        });
                    });
                },
                error: function() { }
            });

            $.ajax({
                type: 'POST',
                url: '/vtop/proctor/viewStudentCredentials',
                data: 'verifyMenu=true&authorizedID=' + encodeURIComponent('\(authorizedID)') + '&_csrf=' + encodeURIComponent('\(csrfToken)') + '&nocache=' + Date.now(),
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                async: false,
                success: function(res3) {
                    if (__VTOP_DEBUG__) { result.rawViewStudentCredentials = res3; }
                    var $r = $(res3);
                    $r.find('table.customTable').each(function() {
                        var headers = $(this).find('tr.tableHeader td').map(function() {
                            return $(this).text().trim().toLowerCase();
                        }).get();
                        var joined = headers.join('|');
                        if (joined.indexOf('account') >= 0 && joined.indexOf('user name') >= 0) {
                            $(this).find('tr.tableContent').each(function() {
                                var c = $(this).find('td');
                                if (c.length < 3) return;
                                var urlCell = c.eq(3);
                                var href = urlCell.find('a').attr('href');
                                var urlStr = (href && href.length) ? href : urlCell.text().trim();
                                result.portalCredentials.push({
                                    id: credCounter++,
                                    account: c.eq(0).text().trim(),
                                    userName: c.eq(1).text().trim(),
                                    defaultPassword: c.eq(2).text().trim(),
                                    urlString: urlStr || null,
                                    venueDate: c.length > 4 ? c.eq(4).text().trim() : '',
                                    seatLocation: c.length > 5 ? c.eq(5).text().trim() : ''
                                });
                            });
                        } else if (joined.indexOf('rank') >= 0) {
                            $(this).find('tr').not('.tableHeader').each(function() {
                                var c = $(this).find('td');
                                if (c.length >= 2) {
                                    var nm = c.eq(0).text().trim();
                                    var rk = c.eq(1).text().trim();
                                    if (nm.toLowerCase() === 'name' && rk.toLowerCase() === 'rank') return;
                                    if (nm && rk) result.rankEntries.push({ name: nm, rank: rk });
                                }
                            });
                        }
                    });
                },
                error: function() { }
            });

            return result;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch staff: \(error.localizedDescription)", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchSpotlight()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            guard let raw = result as? [String: Any] else {
                self.logger.error("Invalid staff response", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchSpotlight()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            self.debugPrintFullVTOPResponse("viewProctorDetails", raw["rawViewProctorDetails"] as? String)
            self.debugPrintFullVTOPResponse("viewHodDeanDetails", raw["rawViewHodDeanDetails"] as? String)
            let dict = Self.strippingDebugPayloads(raw)
            let staffData = dict["staff"] as? [[String: Any]] ?? []

            var staff: [Staff] = []
            for staffDict in staffData {
                guard let id = staffDict["id"] as? Int,
                      let typeString = staffDict["type"] as? String,
                      let key = staffDict["key"] as? String,
                      let value = staffDict["value"] as? String else { continue }

                let type: StaffType
                if typeString.lowercased().contains("proctor") {
                    type = .proctor
                } else if typeString.lowercased().contains("dean") {
                    type = .dean
                } else if typeString.lowercased().contains("hod") {
                    type = .hod
                } else {
                    continue
                }

                staff.append(Staff(id: id, type: type, key: key, value: value))
            }

            var credentials: [VTOPPortalCredential] = []
            if let credData = dict["portalCredentials"] as? [[String: Any]] {
                for c in credData {
                    guard let id = c["id"] as? Int,
                          let account = c["account"] as? String,
                          let userName = c["userName"] as? String,
                          let defaultPassword = c["defaultPassword"] as? String else { continue }
                    let urlString = (c["urlString"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    let venueDate = (c["venueDate"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    let seatLocation = (c["seatLocation"] as? String).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    credentials.append(VTOPPortalCredential(
                        id: id,
                        account: account,
                        userName: userName,
                        defaultPassword: defaultPassword,
                        urlString: urlString,
                        venueDate: venueDate,
                        seatLocation: seatLocation
                    ))
                }
            }

            var ranks: [VTOPRankEntry] = []
            if let rankData = dict["rankEntries"] as? [[String: Any]] {
                for r in rankData {
                    guard let name = r["name"] as? String,
                          let rank = r["rank"] as? String else { continue }
                    ranks.append(VTOPRankEntry(name: name, rank: rank))
                }
            }

            let deanPhoto = Self.imageDataFromVTOPDataURL(dict["deanPhotoDataUrl"] as? String)
            let hodPhoto = Self.imageDataFromVTOPDataURL(dict["hodPhotoDataUrl"] as? String)

            DispatchQueue.main.async {
                self.staff = staff
                self.portalCredentials = credentials
                self.rankEntries = ranks
                self.deanPortraitData = deanPhoto
                self.hodPortraitData = hodPhoto
                self.logger.success("✅ Loaded \(staff.count) staff, \(credentials.count) portal credential(s), \(ranks.count) rank row(s)", context: "DataManager")
                self.scheduleCachePersistence()
                if continueFullSyncChain {
                    self.fetchSpotlight()
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    // MARK: - Fetch Spotlight
    private func fetchSpotlight(continueFullSyncChain: Bool = true, completion: (() -> Void)? = nil) {
        logger.info("📢 Fetching announcements...", context: "DataManager")

        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken else {
            logger.error("Missing session data", context: "DataManager")
            if !continueFullSyncChain {
                DispatchQueue.main.async { completion?() }
            }
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading announcements..."
        }

        let script = """
        (function() {
            var result = { spotlights: [], rawHome: '' };
            var spotlightCounter = 1;

            $.ajax({
                type: 'POST',
                url: '/vtop/home',
                data: {
                    _csrf: '\(csrfToken)',
                    authorizedID: '\(authorizedID)',
                    x: ''
                },
                async: false,
                success: function(res) {
                    result.rawHome = res;
                    $(res).find('.offcanvas').each(function() {
                        var category = $(this).find('.offcanvas-header').text().trim();
                        var announcement = $(this).find('.offcanvas-body').text().trim();
                        var link = null;

                        // Try to find link
                        var linkElem = $(this).find('a[onclick], a[href]').first();
                        if (linkElem.length > 0) {
                            var onclick = linkElem.attr('onclick');
                            var href = linkElem.attr('href');
                            if (onclick) {
                                var match = onclick.match(/window\\.open\\(['"]([^'"]+)['"]/);
                                if (match) link = match[1];
                            } else if (href && href !== '#') {
                                link = href;
                            }
                        }

                        if (announcement) {
                            result.spotlights.push({
                                id: spotlightCounter++,
                                announcement: announcement,
                                category: category || 'General',
                                link: link
                            });
                        }
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch spotlight: \(error.localizedDescription)", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchReceipts()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            guard let raw = result as? [String: Any],
                  let spotlightsData = raw["spotlights"] as? [[String: Any]] else {
                self.logger.error("Invalid spotlight response", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchReceipts()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            self.debugPrintFullVTOPResponse("home", raw["rawHome"] as? String)

            var spotlights: [Spotlight] = []
            for spotDict in spotlightsData {
                guard let id = spotDict["id"] as? Int,
                      let announcement = spotDict["announcement"] as? String,
                      let category = spotDict["category"] as? String else { continue }

                let link = spotDict["link"] as? String

                // Create signature for tracking
                let signature = announcement.hashValue ^ category.hashValue

                spotlights.append(Spotlight(id: id, announcement: announcement,
                                          category: category, link: link,
                                          isRead: false, signature: signature))
            }

            DispatchQueue.main.async {
                self.spotlights = spotlights
                self.logger.success("✅ Loaded \(spotlights.count) announcements", context: "DataManager")
                self.scheduleCachePersistence()
                if continueFullSyncChain {
                    self.fetchReceipts()
                } else {
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    // MARK: - Fetch Receipts
    private func fetchReceipts(continueFullSyncChain: Bool = true, completion: (() -> Void)? = nil) {
        logger.info("💳 Fetching payment receipts...", context: "DataManager")

        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken else {
            logger.error("Missing session data", context: "DataManager")
            if continueFullSyncChain {
                fetchScheduledEvents()
            } else {
                DispatchQueue.main.async { completion?() }
            }
            return
        }

        DispatchQueue.main.async {
            self.syncState.loadingMessage = "Loading receipts..."
        }

        let script = """
        (function() {
            var result = { receipts: [], rawGetReceiptsApplno: '' };

            $.ajax({
                type: 'POST',
                url: '/vtop/p2p/getReceiptsApplno',
                data: {
                    verifyMenu: 'true',
                    winImage: '',
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)',
                    nocache: Date.now()
                },
                async: false,
                success: function(res) {
                    result.rawGetReceiptsApplno = res;
                    var $root = $(res);
                    // Prefer #onlineReceipt; fall back to full fragment (some responses differ slightly).
                    var $scope = $root.find('#onlineReceipt');
                    if (!$scope.length) { $scope = $root.filter('#onlineReceipt'); }
                    if (!$scope.length) { $scope = $root; }
                    // Any table under the receipt section (main + alumni use .table-bordered variants).
                    $scope.find('table tr').each(function() {
                        var cells = $(this).find('td');
                        if (cells.length < 5) { return; }
                        var numText = cells.eq(0).text().trim().replace(/,/g, '');
                        if (!/^\\d+$/.test(numText)) { return; }
                        var number = parseInt(numText, 10) || 0;
                        var dateStr = cells.eq(1).text().trim();
                        var amount = parseFloat(cells.eq(2).text().trim().replace(/[^0-9.]/g, '')) || 0;
                        var campus = cells.eq(3).text().trim();
                        if (number > 0 && dateStr.length > 0) {
                            result.receipts.push({
                                number: number,
                                amount: amount,
                                date: dateStr,
                                campus: campus
                            });
                        }
                    });
                },
                error: function(xhr, st, err) { }
            });
            // WKWebView bridging of nested objects is unreliable; return JSON like other evaluators.
            try {
                return JSON.stringify(result);
            } catch (e) {
                return JSON.stringify({ receipts: [], rawGetReceiptsApplno: '', error: String(e) });
            }
        })();
        """

        webView?.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to fetch receipts: \(error.localizedDescription)", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchScheduledEvents()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            let raw: [String: Any]?
            if let str = result as? String,
               let data = str.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                raw = obj
            } else if let dict = result as? [String: Any] {
                raw = dict
            } else {
                raw = nil
            }

            guard let raw,
                  let receiptsData = Self.coerceReceiptPayloadArray(raw["receipts"]) else {
                self.logger.error("Invalid receipts response", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchScheduledEvents()
                } else {
                    DispatchQueue.main.async {
                        self.syncState.loadingMessage = ""
                        completion?()
                    }
                }
                return
            }

            self.debugPrintFullVTOPResponse("getReceiptsApplno", raw["rawGetReceiptsApplno"] as? String)

            var receipts: [Receipt] = []
            for (index, receiptDict) in receiptsData.enumerated() {
                let number = Self.intFromJSON(receiptDict["number"]) ?? 0
                let amount = Self.doubleFromJSON(receiptDict["amount"]) ?? 0
                guard number > 0,
                      let dateString = receiptDict["date"] as? String else { continue }
                let campus = (receiptDict["campus"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let campusCode = (campus?.isEmpty == false) ? campus : nil

                let timestamp: Int64 = Self.parseReceiptDateMillis(dateString)
                receipts.append(Receipt(id: index + 1, number: number, amount: amount, date: timestamp, campusCode: campusCode))
            }

            DispatchQueue.main.async {
                self.receipts = receipts
                self.logger.success("✅ Loaded \(receipts.count) receipts", context: "DataManager")
                if continueFullSyncChain {
                    self.fetchScheduledEvents()
                } else {
                    self.scheduleCachePersistence()
                    self.syncState.loadingMessage = ""
                    completion?()
                }
            }
        }
    }

    // MARK: - Scheduled events (Event hub)
    private func fetchScheduledEvents() {
        evaluateScheduledEvents { [weak self] rows in
            guard let self else { return }
            DispatchQueue.main.async {
                self.scheduledEventRows = rows
                if !rows.isEmpty {
                    self.logger.success("✅ Loaded \(rows.count) scheduled event row(s)", context: "DataManager")
                }
                self.finishDataFetching()
            }
        }
    }

    func refreshScheduledEvents(completion: (() -> Void)? = nil) {
        evaluateScheduledEvents { [weak self] rows in
            guard let self else {
                completion?()
                return
            }
            DispatchQueue.main.async {
                self.scheduledEventRows = rows
                self.scheduleCachePersistence()
                if !rows.isEmpty {
                    self.logger.success("✅ Event hub: \(rows.count) row(s)", context: "DataManager")
                }
                completion?()
            }
        }
    }

    private func evaluateScheduledEvents(completion: @escaping ([VTOPScheduledEventRow]) -> Void) {
        guard let authorizedID = authorizedID,
              let csrfToken = csrfToken,
              let webView = webView else {
            completion([])
            return
        }

        let script = """
        (function() {
            var result = { rows: [], rawScheduledEvents: '' };
            var idCounter = 1;
            $.ajax({
                type: 'POST',
                url: '/vtop/get/scheduled/events',
                contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
                data: {
                    authorizedID: '\(authorizedID)',
                    _csrf: '\(csrfToken)',
                    x: new Date().toUTCString()
                },
                async: false,
                success: function(res) {
                    result.rawScheduledEvents = res;
                    // Multiple sibling root nodes: $(res) only keeps the first — wrap so every card is found.
                    var $doc = $('<div>').html(res);
                    var lastSectionBanner = '';
                    $doc.find('.card.lightGoldenbackground2').each(function() {
                        var $card = $(this);
                        var sectionBanner = '';
                        $card.find('.card-title').each(function() {
                            var t = $(this).text().replace(/\\s+/g, ' ').trim();
                            if (t) { sectionBanner = t; return false; }
                        });
                        if (!sectionBanner) { sectionBanner = lastSectionBanner; }
                        else { lastSectionBanner = sectionBanner; }
                        var $leftCol = $card.find('.col-2.border-bottom').first();
                        var dayNum = $leftCol.find('.h5').first().text().trim();
                        var monthY = '';
                        $leftCol.find('div').each(function() {
                            var cls = $(this).attr('class') || '';
                            if (cls.indexOf('subtitle') >= 0) {
                                monthY = $(this).text().replace(/\\s+/g, ' ').trim();
                                return false;
                            }
                        });
                        var groupKey = (sectionBanner || 'Events') + '|' + dayNum + '|' + monthY;
                        var $rightCol = $card.find('.col-10.border-bottom').first();
                        $rightCol.find('.card-body').each(function() {
                            var $b = $(this);
                            var plain = $b.text().replace(/\\s+/g, ' ').trim();
                            if ($b.hasClass('text-secondary') && plain.indexOf('No events') >= 0) {
                                result.rows.push({
                                    id: 'ev' + (idCounter++),
                                    groupKey: groupKey,
                                    sectionBanner: sectionBanner,
                                    day: dayNum,
                                    monthYear: monthY,
                                    title: null,
                                    detailLine: '',
                                    venue: '',
                                    isPlaceholder: true
                                });
                                return;
                            }
                            var title = $b.find('span.card-title').first().text().replace(/\\s+/g, ' ').trim();
                            if (!title) {
                                title = $b.find('.card-title').first().text().replace(/\\s+/g, ' ').trim();
                            }
                            var dates = $b.find('.card-text.fst-italic').first().text().replace(/\\s+/g, ' ').trim();
                            var venue = $b.find('small.text-dark').first().text().trim();
                            if (title) {
                                result.rows.push({
                                    id: 'ev' + (idCounter++),
                                    groupKey: groupKey,
                                    sectionBanner: sectionBanner,
                                    day: dayNum,
                                    monthYear: monthY,
                                    title: title,
                                    detailLine: dates || '',
                                    venue: venue || '',
                                    isPlaceholder: false
                                });
                            }
                        });
                    });
                },
                error: function(xhr, st, err) { }
            });
            return result;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else {
                completion([])
                return
            }
            if let error = error {
                self.logger.error("Scheduled events: \(error.localizedDescription)", context: "DataManager")
                completion([])
                return
            }
            guard let raw = result as? [String: Any] else {
                completion([])
                return
            }
            self.debugPrintFullVTOPResponse("get/scheduled/events", raw["rawScheduledEvents"] as? String)
            let dict = Self.strippingDebugPayloads(raw)
            let rowsData = dict["rows"] as? [[String: Any]] ?? []
            let rows: [VTOPScheduledEventRow] = rowsData.compactMap { r in
                guard let id = r["id"] as? String,
                      let groupKey = r["groupKey"] as? String,
                      let sectionBanner = r["sectionBanner"] as? String,
                      let day = r["day"] as? String,
                      let monthYear = r["monthYear"] as? String else { return nil }
                let isPlaceholder = (r["isPlaceholder"] as? Bool) ?? (r["isPlaceholder"] as? NSNumber)?.boolValue ?? false
                let title = r["title"] as? String
                let detailLine = r["detailLine"] as? String ?? ""
                let venue = r["venue"] as? String ?? ""
                return VTOPScheduledEventRow(
                    id: id,
                    groupKey: groupKey,
                    sectionBanner: sectionBanner,
                    day: day,
                    monthYear: monthYear,
                    title: title,
                    detailLine: detailLine,
                    venue: venue,
                    isPlaceholder: isPlaceholder
                )
            }
            completion(rows)
        }
    }

    // MARK: - Finish Data Fetching
    private func finishDataFetching() {
        let completedAt = Date()
        DispatchQueue.main.async {
            self.cancelFullSyncStallWatchdog()
            self.syncState.isLoading = false
            self.syncState.loadingMessage = ""
            self.syncState.lastDataFetchFailureReason = nil
            if self.countsCurrentSessionTowardManualFullSyncQuota {
                Self.recordFullSyncCompleted(at: completedAt)
                self.countsCurrentSessionTowardManualFullSyncQuota = false
            }
            self.syncState.lastSuccessfulSyncAt = completedAt
            self.scheduleCachePersistence()
            self.logger.success("🎉 All data fetched successfully!", context: "DataManager")
        }
    }

    private func scheduleCachePersistence() {
        cachePersistenceWorkItem?.cancel()
        let generation = UUID()
        cachePersistenceGeneration = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.cachePersistenceGeneration == generation else { return }
            self.persistCacheNow()
        }
        cachePersistenceWorkItem = work
        if Thread.isMainThread {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.cachePersistenceGeneration == generation else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
        }
    }

    private func persistCacheNow() {
        cacheCurrentSemesterScheduleIfNeeded()
        if let selectedSemester {
            VTOPSwiftDataStore.shared.upsert(
                semester: selectedSemester,
                courses: courses,
                timetable: timetable,
                attendance: attendance,
                marks: marks,
                cumulativeMarks: cumulativeMarks,
                exams: exams,
                marksReportRows: marksReportRows
            )
        }
        VTOPDataCache.persistSnapshot(
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
            cumulativeMarksBySemesterId: cumulativeMarksBySemesterId
        ) { [weak self] in
            guard let self else { return }
            self.syncState.cachePersistedAt = VTOPDiskCache.readMeta().lastPersistedAt
            self.publishGlanceSnapshotAndPeripherals()
        }
    }

    private func publishGlanceSnapshotAndPeripherals() {
        let snap = buildGlanceSnapshot()
        snap.writeToSharedContainer()
        VTOPNotificationScheduler.reschedule(
            from: snap,
            timetable: timetable,
            courses: courses,
            exams: exams,
            attendance: attendance
        )
        let next = VTOPScheduleEngine.nextUpcomingSlot(timetable: timetable, courses: courses)
        Task { @MainActor in
            VTOPLiveActivityManager.updateOrStart(upcoming: next)
        }
    }

    /// Re-applies local reminder preferences immediately after the user changes them.
    func refreshNotificationSchedule() {
        publishGlanceSnapshotAndPeripherals()
    }

    private func buildGlanceSnapshot() -> VTOPGlanceSnapshot {
        let next = VTOPScheduleEngine.nextUpcomingSlot(timetable: timetable, courses: courses)
        let lines = VTOPScheduleEngine.todaySlotSummaries(timetable: timetable, courses: courses)
        let nextExam = VTOPCockpitMetrics.nextExam(from: exams)
        let attendancePercent = studentProfile?.overallAttendance
        let riskLabel = VTOPCockpitMetrics.attendanceRiskLabel(for: attendancePercent)
        return VTOPGlanceSnapshot(
            updatedAt: Date(),
            semesterName: selectedSemester?.name,
            attendancePercent: attendancePercent,
            nextClassTitle: next?.course.title,
            nextClassVenue: next?.course.venue,
            nextClassStart: next?.startDate,
            nextClassEnd: next?.endDate,
            attendanceRiskLabel: riskLabel,
            nextExamTitle: nextExam?.0.courseTitle ?? nextExam?.0.title,
            nextExamDate: nextExam?.1,
            nextExamVenue: nextExam?.0.venue,
            todaySlotLines: lines
        )
    }

    // MARK: - Scoped refresh (pull-to-refresh; no full `syncAll` chain)

    /// Semester dropdown only (does not auto-select a term or start `fetchAllData`).
    func refreshSemesterPicklist(completion: (() -> Void)? = nil) {
        guard webView != nil else {
            completion?()
            return
        }
        DispatchQueue.main.async { self.syncState.loadingMessage = "Loading semesters…" }
        fetchSemesters(chainIntoSelectSemester: false, completion: completion)
    }

    /// Profile + grade history + courses + timetable for the selected term (stops before attendance).
    func refreshHomeSummary(completion: (() -> Void)? = nil) {
        guard webView != nil else {
            completion?()
            return
        }
        DispatchQueue.main.async { self.syncState.loadingMessage = "Refreshing…" }
        fetchStudentProfile(stopAfterTimetable: true, completion: completion)
    }

    /// Courses, timetable, and attendance for `selectedSemester` (stops before marks).
    func refreshCoursesWithAttendance(completion: (() -> Void)? = nil) {
        guard webView != nil, selectedSemester != nil else {
            completion?()
            return
        }
        fetchCoursesAndTimetable(chainToAttendance: true, continueAfterAttendance: false, completion: completion)
    }

    /// Marks + cumulative grades for `selectedSemester` (stops before exams/staff/…).
    func refreshMarksForSelectedSemester(completion: (() -> Void)? = nil) {
        guard webView != nil, selectedSemester != nil else {
            completion?()
            return
        }
        fetchMarks(continueChain: false, completion: completion)
    }

    func refreshStaffInformation(completion: (() -> Void)? = nil) {
        guard webView != nil else {
            completion?()
            return
        }
        fetchStaff(continueFullSyncChain: false, completion: completion)
    }

    func refreshSpotlightsOnly(completion: (() -> Void)? = nil) {
        guard webView != nil else {
            completion?()
            return
        }
        fetchSpotlight(continueFullSyncChain: false, completion: completion)
    }

    func refreshReceiptsOnly(completion: (() -> Void)? = nil) {
        guard webView != nil else {
            completion?()
            return
        }
        fetchReceipts(continueFullSyncChain: false, completion: completion)
    }

    // Async adapters keep SwiftUI refresh handlers concise while the WebView bridge remains callback-based.
    private func awaitCompletion(_ operation: (@escaping () -> Void) -> Void) async {
        await withCheckedContinuation { continuation in
            operation { continuation.resume() }
        }
    }

    func refreshHomeSummary() async {
        await awaitCompletion { completion in refreshHomeSummary(completion: completion) }
    }

    func refreshCoursesWithAttendance() async {
        await awaitCompletion { completion in refreshCoursesWithAttendance(completion: completion) }
    }

    func refreshMarksForSelectedSemester() async {
        await awaitCompletion { completion in refreshMarksForSelectedSemester(completion: completion) }
    }

    func refreshStaffInformation() async {
        await awaitCompletion { completion in refreshStaffInformation(completion: completion) }
    }

    func refreshSpotlightsOnly() async {
        await awaitCompletion { completion in refreshSpotlightsOnly(completion: completion) }
    }

    func refreshReceiptsOnly() async {
        await awaitCompletion { completion in refreshReceiptsOnly(completion: completion) }
    }

    func refreshTimetableAndCourses(for semester: Semester) async {
        await awaitCompletion { completion in
            refreshTimetableAndCoursesForSemester(semester, completion: completion)
        }
    }

    func refreshAttendance(for semesterID: String) async {
        await awaitCompletion { completion in
            refreshAttendance(semesterSubId: semesterID, continueAfterMarks: false, completion: completion)
        }
    }

    func loadAttendanceSemesterPicklist() async {
        await awaitCompletion { completion in loadAttendanceSemesterPicklist(completion: completion) }
    }

    func loadMarksSemesterPicklist() async {
        await awaitCompletion { completion in loadMarksSemesterPicklist(completion: completion) }
    }

    func refreshMarksReport(for semesterID: String) async {
        await awaitCompletion { completion in
            refreshMarksReport(semesterSubId: semesterID, completion: completion)
        }
    }

    func refreshScheduledEvents() async {
        await awaitCompletion { completion in refreshScheduledEvents(completion: completion) }
    }

    func loadExamScheduleSemesterPicklist() async {
        await awaitCompletion { completion in loadExamScheduleSemesterPicklist(completion: completion) }
    }

    func refreshExamSchedule(for semesterID: String) async {
        await awaitCompletion { completion in
            refreshExamSchedule(semesterSubId: semesterID, completion: completion)
        }
    }

    // MARK: - Sync All Data

    /// Call when the user taps toolbar or profile full sync (shows quota confirmation or blocked alert).
    func requestUserFullSyncFromToolbar() {
        guard webView != nil else { return }
        let pruned = Self.prunedFullSyncCompletionDates()
        if pruned.count >= Self.fullSyncQuotaMaxPerWindow {
            let oldest = pruned[0]
            let nextEligible = oldest.addingTimeInterval(Self.fullSyncQuotaWindow)
            let wait = max(0, nextEligible.timeIntervalSince(Date()))
            let human = Self.formattedCooldownRemaining(wait)
            logger.info("Full sync quota exhausted; next in \(human)", context: "DataManager")
            syncState.fullSyncQuotaBlockedMessage = "You’ve used all \(Self.fullSyncQuotaMaxPerWindow) full syncs allowed in the last hour. The next full sync is available in \(human). You can still pull to refresh on a page to update only that section."
            return
        }
        let remaining = Self.fullSyncQuotaMaxPerWindow - pruned.count
        syncState.fullSyncConfirmSlotsRemaining = remaining
    }

    func cancelUserFullSyncConfirmation() {
        syncState.fullSyncConfirmSlotsRemaining = nil
    }

    func confirmUserFullSyncAndExecute() {
        syncState.fullSyncConfirmSlotsRemaining = nil
        syncAll()
    }

    func syncAll() {
        logger.info("🔄 Manual sync requested (debounced)", context: "DataManager")
        syncDebounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.performSyncAll() }
        syncDebounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: item)
    }

    private func performSyncAll() {
        guard let _ = webView else {
            logger.warning("WebView not available for sync - user needs to login to fetch fresh data", context: "DataManager")
            DispatchQueue.main.async {
                self.syncState.lastDataFetchFailureReason = "Sign in required to refresh from VTOP."
                self.syncState.errorMessage = "Please login to sync latest data"
            }
            return
        }
        let pruned = Self.prunedFullSyncCompletionDates()
        if pruned.count >= Self.fullSyncQuotaMaxPerWindow {
            let oldest = pruned[0]
            let nextEligible = oldest.addingTimeInterval(Self.fullSyncQuotaWindow)
            let wait = max(0, nextEligible.timeIntervalSince(Date()))
            let human = Self.formattedCooldownRemaining(wait)
            logger.info("Full sync blocked at perform: quota; next in \(human)", context: "DataManager")
            DispatchQueue.main.async {
                self.syncState.fullSyncQuotaBlockedMessage = "You’ve used all \(Self.fullSyncQuotaMaxPerWindow) full syncs allowed in the last hour. The next full sync is available in \(human). You can still pull to refresh on a page to update only that section."
            }
            return
        }
        syncState.lastDataFetchFailureReason = nil
        syncState.isLoading = true
        syncState.loadingMessage = "Syncing…"
        scheduleFullSyncStallWatchdogIfNeeded()
        extractSessionData(attempt: 1, incrementManualFullSyncQuotaOnCompletion: true)
    }

    // MARK: - Load Cached Data
    func loadCachedData() {
        logger.info("📂 Restoring cached VTOP snapshot from UserDefaults...", context: "DataManager")
        let generation = UUID()
        cacheRestoreGeneration = generation
        VTOPDataCache.restoreInto(self) { [weak self] in
            guard let self, self.cacheRestoreGeneration == generation else { return false }
            let swiftData = VTOPSwiftDataStore.shared.semesterCaches()
            self.restoreSemesterScopedCache(
                coursesBySemesterId: swiftData.courses,
                timetableBySemesterId: swiftData.timetable,
                marksBySemesterId: swiftData.marks,
                cumulativeMarksBySemesterId: swiftData.cumulativeMarks
            )
            return true
        }
        logger.info("💡 Sign in and sync to refresh after the snapshot loads.", context: "DataManager")
    }

    /// Drops persisted VTOP snapshots and in-memory cached data. Web session / login state is not cleared.
    func clearCachedVTOPData() {
        VTOPDataCache.clearAll()
        VTOPSwiftDataStore.shared.deleteAll()
        Self.clearFullSyncQuotaStorage()
        DispatchQueue.main.async {
            self.syncState.lastSuccessfulSyncAt = nil
            self.studentProfile = nil
            self.courses = []
            self.timetable = []
            self.attendance = []
            self.marks = []
            self.cumulativeMarks = []
            self.exams = []
            self.staff = []
            self.spotlights = []
            self.receipts = []
            self.scheduledEventRows = []
            self.semesters = []
            self.selectedSemester = nil
            self.attendanceSemesterOptions = []
            self.marksReportSemesterOptions = []
            self.marksReportRows = []
            self.marksReportSemesterId = nil
            self.examScheduleSemesterOptions = []
            self.examScheduleSemesterId = nil
            self.gradeHistoryRows = []
            self.portalCredentials = []
            self.rankEntries = []
            self.deanPortraitData = nil
            self.hodPortraitData = nil
            self.coursesBySemesterId = [:]
            self.timetableBySemesterId = [:]
            self.syncState.errorMessage = nil
            self.syncState.loadingMessage = ""
        }
        logger.info("🗑️ Cleared VTOP cache (UserDefaults + in-memory snapshot)", context: "DataManager")
    }

    /// Updates disk + memory when the user toggles a VTOP cache bucket in Cache management.
    func applyVTOPCacheBucket(enabled: Bool, bucket: AppCacheSettings.VTOPBucket) {
        if enabled {
            loadCachedData()
        } else {
            VTOPDataCache.clearVTOPBucket(bucket)
            DispatchQueue.main.async {
                self.clearInMemoryVTOPFields(for: bucket)
            }
        }
    }

    private func clearInMemoryVTOPFields(for bucket: AppCacheSettings.VTOPBucket) {
        switch bucket {
        case .profileSummary:
            studentProfile = nil
        case .academic:
            courses = []
            timetable = []
            attendance = []
            semesters = []
            selectedSemester = nil
            attendanceSemesterOptions = []
            restoreSemesterScopedCache(coursesBySemesterId: [:], timetableBySemesterId: [:])
        case .marksAndGrades:
            gradeHistoryRows = []
            marks = []
            cumulativeMarks = []
            marksReportSemesterOptions = []
            marksReportRows = []
            marksReportSemesterId = nil
            restoreSemesterScopedCache(
                coursesBySemesterId: coursesBySemesterId,
                timetableBySemesterId: timetableBySemesterId,
                marksBySemesterId: [:],
                cumulativeMarksBySemesterId: [:]
            )
        case .exams:
            exams = []
            examScheduleSemesterOptions = []
            examScheduleSemesterId = nil
        case .receipts:
            receipts = []
        case .campusExtras:
            staff = []
            spotlights = []
            scheduledEventRows = []
            portalCredentials = []
            rankEntries = []
            deanPortraitData = nil
            hodPortraitData = nil
        }
    }

    // MARK: - Helper: Get WebView
    func getWebView() -> WKWebView? {
        return webView
    }
}
