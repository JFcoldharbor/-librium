import Foundation

@MainActor
final class PipelineService: ObservableObject {
    static let shared = PipelineService()

    @Published private(set) var deals: [PipelineDeal] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.pipeline"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
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
    }

    func delete(id: UUID) {
        deals.removeAll { $0.id == id }
        persist()
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
}
