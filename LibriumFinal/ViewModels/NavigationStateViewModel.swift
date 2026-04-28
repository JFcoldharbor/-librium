import Foundation
import Combine

@MainActor
final class NavigationStateViewModel: ObservableObject {
    @Published var currentHub: Int = EquilibriumConfig.homeHubIndex
    @Published var lifeCardIndex: Int = 0
    @Published var workCardIndex: Int = 0

    private enum Keys {
        static let lifeCardIndex = "equilibrium.nav.lifeCardIndex"
        static let workCardIndex = "equilibrium.nav.workCardIndex"
    }

    func saveState() {
        UserDefaults.standard.set(lifeCardIndex, forKey: Keys.lifeCardIndex)
        UserDefaults.standard.set(workCardIndex, forKey: Keys.workCardIndex)
    }

    func loadState() {
        currentHub = EquilibriumConfig.homeHubIndex
        lifeCardIndex = UserDefaults.standard.integer(forKey: Keys.lifeCardIndex)
        workCardIndex = UserDefaults.standard.integer(forKey: Keys.workCardIndex)
    }
}
