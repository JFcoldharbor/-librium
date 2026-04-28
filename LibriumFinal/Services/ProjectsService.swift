import Foundation

@MainActor
final class ProjectsService: ObservableObject {
    static let shared = ProjectsService()

    @Published private(set) var projects: [Project] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.operator.projects"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
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
    }

    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        persist()
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
}
