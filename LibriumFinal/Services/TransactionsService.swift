import Foundation

@MainActor
final class TransactionsService: ObservableObject {
    static let shared = TransactionsService()

    @Published private(set) var transactions: [MoneyTransaction] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.finance.transactions"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let raw = store.load([MoneyTransaction].self, key: Self.storageKey) ?? []
        transactions = raw.sorted { $0.occurredAt > $1.occurredAt }
    }

    func upsert(_ transaction: MoneyTransaction) {
        if let idx = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[idx] = transaction
        } else {
            transactions.append(transaction)
        }
        transactions.sort { $0.occurredAt > $1.occurredAt }
        persist()
    }

    func delete(id: UUID) {
        transactions.removeAll { $0.id == id }
        persist()
    }

    func recent(limit: Int = 20) -> [MoneyTransaction] {
        Array(transactions.prefix(limit))
    }

    // MARK: - Aggregates

    func totalIncome(since start: Date, until end: Date = Date()) -> Double {
        var total: Double = 0
        for tx in transactions where tx.direction == .income && tx.occurredAt >= start && tx.occurredAt <= end {
            total += tx.amount
        }
        return total
    }

    func totalExpense(since start: Date, until end: Date = Date()) -> Double {
        var total: Double = 0
        for tx in transactions where tx.direction == .expense && tx.occurredAt >= start && tx.occurredAt <= end {
            total += tx.amount
        }
        return total
    }

    func plToday(now: Date = Date()) -> (income: Double, expense: Double) {
        let start = Calendar.current.startOfDay(for: now)
        return (totalIncome(since: start, until: now), totalExpense(since: start, until: now))
    }

    func plThisWeek(now: Date = Date()) -> (income: Double, expense: Double) {
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let start = cal.date(from: comps) ?? now
        return (totalIncome(since: start, until: now), totalExpense(since: start, until: now))
    }

    func plThisMonth(now: Date = Date()) -> (income: Double, expense: Double) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        let start = cal.date(from: comps) ?? now
        return (totalIncome(since: start, until: now), totalExpense(since: start, until: now))
    }

    private func persist() {
        store.save(transactions, key: Self.storageKey)
    }
}
