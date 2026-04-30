import FirebaseFirestore
import Foundation

@MainActor
final class ProjectsService: ObservableObject {
    static let shared = ProjectsService()

    @Published private(set) var projects: [Project] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.projects"
    private static let migrationFlagKey = "equilibrium.operator.projects.firestoreMigrated"

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
        projects = store.load([Project].self, key: Self.storageKey) ?? []
    }

    func upsert(_ project: Project) {
        if let idx = projects.firstIndex(where: { $0.id == project.id }) {
            projects[idx] = project
        } else {
            projects.append(project)
        }
        persist()
        Task { try? await ProjectsFirestoreService.shared.upsert(project) }
    }

    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        persist()
        Task { try? await ProjectsFirestoreService.shared.delete(id: id) }
    }

    var activeProjects: [Project] {
        projects.filter { $0.status == .active }
            .sorted {
                let a = $0.deadline ?? .distantFuture
                let b = $1.deadline ?? .distantFuture
                return a < b
            }
    }

    private func persist() {
        store.save(projects, key: Self.storageKey)
    }

    private func startSync() {
        Task { [weak self] in
            await self?.migrateLocalIfNeeded()
            await MainActor.run { self?.attachListener() }
        }
    }

    private func attachListener() {
        listener?.remove()
        listener = ProjectsFirestoreService.shared.listen { [weak self] remote in
            guard let self else { return }
            self.projects = remote.sorted { $0.createdAt > $1.createdAt }
            self.persist()
        }
    }

    private func migrateLocalIfNeeded() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: Self.migrationFlagKey) { return }
        let local = await MainActor.run { self.projects }
        guard !local.isEmpty else {
            defaults.set(true, forKey: Self.migrationFlagKey)
            return
        }
        do {
            let remote = try await ProjectsFirestoreService.shared.fetchAll()
            if remote.isEmpty {
                for p in local {
                    try? await ProjectsFirestoreService.shared.upsert(p)
                }
            }
            defaults.set(true, forKey: Self.migrationFlagKey)
        } catch {}
    }
}
