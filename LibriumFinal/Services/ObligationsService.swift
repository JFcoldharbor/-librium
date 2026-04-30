import FirebaseFirestore
import Foundation

@MainActor
final class ObligationsService: ObservableObject {
    static let shared = ObligationsService()

    @Published private(set) var obligations: [Obligation] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.obligations"
    private static let migrationFlagKey = "equilibrium.operator.obligations.firestoreMigrated"

    private var listener: ListenerRegistration?

    init(store: JSONStore = .shared) {
        self.store = store
        load()
        startSync()
    }

    deinit {
        listener?.remove()
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
        Task { try? await ObligationsFirestoreService.shared.upsert(obligation) }
    }

    func delete(id: UUID) {
        obligations.removeAll { $0.id == id }
        persist()
        Task { try? await ObligationsFirestoreService.shared.delete(id: id) }
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
        Task { try? await ObligationsFirestoreService.shared.upsert(item) }
    }

    func markUnpaid(id: UUID) {
        guard let idx = obligations.firstIndex(where: { $0.id == id }) else { return }
        obligations[idx].isPaidThisCycle = false
        let updated = obligations[idx]
        persist()
        Task { try? await ObligationsFirestoreService.shared.upsert(updated) }
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
        var changedItems: [Obligation] = []

        for index in obligations.indices {
            var item = obligations[index]
            var rolled = false
            while item.recurrence != .once,
                  item.isPaidThisCycle,
                  item.dueDate < today,
                  let next = item.recurrence.nextDate(after: item.dueDate) {
                item.dueDate = next
                item.isPaidThisCycle = false
                rolled = true
            }
            obligations[index] = item
            if rolled { changedItems.append(item) }
        }

        if !changedItems.isEmpty {
            persist()
            for item in changedItems {
                Task { try? await ObligationsFirestoreService.shared.upsert(item) }
            }
        }
    }

    private func persist() {
        store.save(obligations, key: Self.storageKey)
    }

    private func startSync() {
        Task { [weak self] in
            await self?.migrateLocalIfNeeded()
            await MainActor.run { self?.attachListener() }
        }
    }

    private func attachListener() {
        listener?.remove()
        listener = ObligationsFirestoreService.shared.listen { [weak self] remote in
            guard let self else { return }
            self.obligations = remote.sorted { $0.dueDate < $1.dueDate }
            self.persist()
        }
    }

    private func migrateLocalIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.migrationFlagKey) { return }
        let local = await MainActor.run { self.obligations }
        guard !local.isEmpty else {
            defaults.set(true, forKey: Self.migrationFlagKey)
            return
        }
        do {
            let remote = try await ObligationsFirestoreService.shared.fetchAll()
            if remote.isEmpty {
                for o in local {
                    try? await ObligationsFirestoreService.shared.upsert(o)
                }
            }
            defaults.set(true, forKey: Self.migrationFlagKey)
        } catch {}
    }
}
