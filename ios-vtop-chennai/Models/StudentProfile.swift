import Foundation

struct StudentProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var cgpa: Double
    var totalCredits: Double
    /// Credits registered (when provided by CGPA summary table on grade history).
    var creditsRegistered: Double?
    var registrationNumber: String?
    var vitEmail: String?
    var programBranch: String?
    var schoolName: String?
    /// Parsed accordion sections from `StudentProfileAllView` (personal, education, family, etc.).
    var accordionSections: [ProfileAccordionSectionData]?
    var gpa: String?
    var overallAttendance: Int?
    var semester: String?
    var semesterId: String?
    /// From VTOP profile (e.g. Male / Female); used for salutation on home, etc.
    var gender: String?

    init(
        name: String,
        cgpa: Double,
        totalCredits: Double,
        creditsRegistered: Double? = nil,
        registrationNumber: String? = nil,
        vitEmail: String? = nil,
        programBranch: String? = nil,
        schoolName: String? = nil,
        accordionSections: [ProfileAccordionSectionData]? = nil,
        gpa: String? = nil,
        overallAttendance: Int? = nil,
        semester: String? = nil,
        semesterId: String? = nil,
        gender: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.cgpa = cgpa
        self.totalCredits = totalCredits
        self.creditsRegistered = creditsRegistered
        self.registrationNumber = registrationNumber
        self.vitEmail = vitEmail
        self.programBranch = programBranch
        self.schoolName = schoolName
        self.accordionSections = accordionSections
        self.gpa = gpa
        self.overallAttendance = overallAttendance
        self.semester = semester
        self.semesterId = semesterId
        self.gender = gender
    }
}

extension StudentProfile {
    /// "Mr." / "Mrs." from VTOP gender when unambiguous; otherwise no prefix.
    var salutationPrefix: String? {
        guard let gender else { return nil }
        let g = gender.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if g.isEmpty { return nil }
        if g == "female" || g == "f" || g.hasPrefix("female") { return "Mrs." }
        if g == "male" || g == "m" || (g.hasPrefix("male") && !g.contains("female")) { return "Mr." }
        return nil
    }

    var displayNameWithSalutation: String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return name }
        guard let p = salutationPrefix else { return n }
        return "\(p) \(n)"
    }
}
