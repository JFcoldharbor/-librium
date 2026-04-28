import Foundation

struct MoneyTransaction: Codable, Identifiable, Equatable {
    let id: UUID
    var amount: Double
    var direction: Direction
    var category: String?
    var source: String?
    var note: String?
    var occurredAt: Date
    var createdAt: Date

    enum Direction: String, Codable, Identifiable {
        case income
        case expense

        var id: String { rawValue }

        var label: String {
            switch self {
            case .income: return "Income"
            case .expense: return "Expense"
            }
        }

        var sign: Double {
            self == .income ? 1 : -1
        }
    }

    var signedAmount: Double {
        amount * direction.sign
    }
}
