import Foundation

@MainActor
final class ObligationsService: ObservableObject {
    static let shared = ObligationsService()

    @Published private(set) var obligations: [Obligation] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.obligations"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        obligations = store.load([Obligation].self, key: Self.storageKey) ?? []
        rollForwardIfNeeded()
    }

    func upsert(_ obligation: Obligation) {
        if let idx = obligations.firstIndex(where: { $0.id == obligation.id }) {
            obligations[idx] = obligation
        } else {
            obligations.append(obligation)
        }
        persist()
    }

    func delete(id: UUID) {
        obligations.removeAll { $0.id == id }
        persist()
    }

    func markPaid(id: UUID) {
        guard let idx = obligations.firstIndex(where: { $0.id == id }) else { return }
        var item = obligations[idx]
        item.isPaidThisCycle = true
        if let next = item.recurrence.nextDate(after: item.dueDate) {
            item.dueDate = next
            item.isPaidThisCycle = false
        }
        obligations[idx] = item
        persist()
    }

    func markUnpaid(id: UUID) {
        guard let idx = obligations.firstIndex(where: { $0.id == id }) else { return }
        obligations[idx].isPaidThisCycle = false
        persist()
    }

    func dueSoon(within days: Int = 14, now: Date = Date()) -> [Obligation] {
        obligations
            .filter { !$0.isPaidThisCycle }
            .filter { $0.daysUntilDue(now: now) <= days }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func totalDue(within days: Int, now: Date = Date()) -> Double {
        dueSoon(within: days, now: now).reduce(0) { $0 + $1.amount }
    }

    private func rollForwardIfNeeded() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var changed = false

        for index in obligations.indices {
            var item = obligations[index]
            while item.recurrence != .once,
                  item.isPaidThisCycle,
                  item.dueDate < today,
                  let next = item.recurrence.nextDate(after: item.dueDate) {
                item.dueDate = next
                item.isPaidThisCycle = false
                changed = true
            }
            obligations[index] = item
        }

        if changed { persist() }
    }

    private func persist() {
        store.save(obligations, key: Self.storageKey)
    }
}
