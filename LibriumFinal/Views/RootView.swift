import SwiftUI

struct RootView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var linkService = IncomingLinkService.shared

    var body: some View {
        Group {
            switch coordinator.route {
            case .loadingSession:
                LoadingView()
            case .auth:
                SignInView()
            case .main:
                MinimalFastNavigation()
            }
        }
        .onOpenURL { url in
            linkService.handle(url)
        }
        .task {
            await NotificationService.shared.bootstrap()
            await DailySnapshotService.shared.rollupIfNeeded()
            Task { _ = await WeatherService.shared.current() }
        }
        .sheet(item: $linkService.pendingEvent) { event in
            NetworkEventDetailSheet(event: event, mode: .detail)
                .preferredColorScheme(.dark)
        }
        .alert("Link error", isPresented: Binding(
            get: { linkService.lastErrorMessage != nil },
            set: { if !$0 { linkService.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkService.lastErrorMessage ?? "")
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            ProgressView()
                .tint(EquilibriumColor.primaryText)
        }
    }
}
