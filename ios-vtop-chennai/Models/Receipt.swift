import Foundation

struct Receipt: Codable, Identifiable, Hashable {
    let id: Int
    var number: Int
    var amount: Double
    var date: Int64  // Timestamp

    init(id: Int, number: Int, amount: Double, date: Int64) {
        self.id = id
        self.number = number
        self.amount = amount
        self.date = date
    }

    var paymentDate: Date {
        return Date(timeIntervalSince1970: TimeInterval(date / 1000))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: paymentDate)
    }

    var formattedAmount: String {
        return String(format: "₹%.2f", amount)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Receipt, rhs: Receipt) -> Bool {
        lhs.id == rhs.id
    }
}
