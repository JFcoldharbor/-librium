import FirebaseFirestore
import Foundation

@MainActor
final class PipelineService: ObservableObject {
    static let shared = PipelineService()

    @Published private(set) var deals: [PipelineDeal] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.pipeline"
    private static let migrationFlagKey = "equilibrium.operator.pipeline.firestoreMigrated"

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
        deals = store.load([PipelineDeal].self, key: Self.storageKey) ?? []
    }

    func upsert(_ deal: PipelineDeal) {
        if let idx = deals.firstIndex(where: { $0.id == deal.id }) {
            deals[idx] = deal
        } else {
            deals.append(deal)
        }
        persist()
        Task { try? await DealsFirestoreService.shared.upsert(deal) }
    }

    func delete(id: UUID) {
        deals.removeAll { $0.id == id }
        persist()
        Task { try? await DealsFirestoreService.shared.delete(id: id) }
    }

    var activeDeals: [PipelineDeal] {
        deals.filter { $0.stage.isActive }
            .sorted { $0.weightedValue > $1.weightedValue }
    }

    var totalActiveValue: Double {
        activeDeals.reduce(0) { $0 + $1.dealValue }
    }

    var totalWeightedValue: Double {
        activeDeals.reduce(0) { $0 + $1.weightedValue }
    }

    private func persist() {
        store.save(deals, key: Self.storageKey)
    }

    private func startSync() {
        Task { [weak self] in
            await self?.migrateLocalIfNeeded()
            await MainActor.run {
                self?.attachListener()
            }
        }
    }

    private func attachListener() {
        listener?.remove()
        listener = DealsFirestoreService.shared.listen { [weak self] remote in
            guard let self else { return }
            self.deals = remote.sorted { $0.createdAt > $1.createdAt }
            self.persist()
        }
    }

    private func migrateLocalIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.migrationFlagKey) { return }

        let local = await MainActor.run { self.deals }
        guard !local.isEmpty else {
            defaults.set(true, forKey: Self.migrationFlagKey)
            return
        }

        do {
            let remote = try await DealsFirestoreService.shared.fetchAll()
            if remote.isEmpty {
                for deal in local {
                    try? await DealsFirestoreService.shared.upsert(deal)
                }
            }
            defaults.set(true, forKey: Self.migrationFlagKey)
        } catch {
            // Leave flag false so we retry on next launch.
        }
    }
}
