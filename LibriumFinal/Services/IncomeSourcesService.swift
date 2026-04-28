import Foundation

@MainActor
final class IncomeSourcesService: ObservableObject {
    static let shared = IncomeSourcesService()

    @Published private(set) var sources: [IncomeSource] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.income"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        sources = store.load([IncomeSource].self, key: Self.storageKey) ?? []
    }

    func upsert(_ source: IncomeSource) {
        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx] = source
        } else {
            sources.append(source)
        }
        persist()
    }

    func delete(id: UUID) {
        sources.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        store.save(sources, key: Self.storageKey)
    }
}
