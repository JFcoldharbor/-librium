import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct LibriumFinalApp: App {
    @StateObject private var coordinator = AppCoordinator()

    init() {
        if !EquilibriumConfig.bypassAuth {
            FirebaseApp.configure()
            configureGoogleSignIn()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private func configureGoogleSignIn() {
        guard let clientId = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
}
