import Combine
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published var route: AuthRoute = .loadingSession

    private var cancellables = Set<AnyCancellable>()

    init() {
        if EquilibriumConfig.bypassAuth {
            route = .main
            return
        }
        observeAuth()
    }

    private func observeAuth() {
        AuthService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.route = (user != nil) ? .main : .auth
            }
            .store(in: &cancellables)
    }
}
