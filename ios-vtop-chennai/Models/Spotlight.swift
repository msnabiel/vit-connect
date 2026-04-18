import Foundation

struct Spotlight: Codable, Identifiable, Hashable {
    let id: Int
    var announcement: String
    var category: String
    var link: String?
    var isRead: Bool
    var signature: Int

    init(id: Int, announcement: String, category: String, link: String? = nil, isRead: Bool = false, signature: Int) {
        self.id = id
        self.announcement = announcement
        self.category = category
        self.link = link
        self.isRead = isRead
        self.signature = signature
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Spotlight, rhs: Spotlight) -> Bool {
        lhs.id == rhs.id
    }
}
