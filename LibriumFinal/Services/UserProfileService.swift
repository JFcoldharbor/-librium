import Foundation

@MainActor
final class UserProfileService: ObservableObject {
    static let shared = UserProfileService()

    @Published private(set) var profile: UserProfile = .empty

    private let store: JSONStore
    private static let storageKey = "equilibrium.user.profile"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        profile = store.load(UserProfile.self, key: Self.storageKey) ?? .empty
    }

    func save(_ profile: UserProfile) {
        self.profile = profile
        store.save(profile, key: Self.storageKey)
    }
}
