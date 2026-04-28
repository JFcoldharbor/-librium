import Foundation

@MainActor
final class IncomingLinkService: ObservableObject {
    static let shared = IncomingLinkService()

    @Published var pendingEvent: NetworkEvent?
    @Published var isResolving: Bool = false
    @Published var lastErrorMessage: String?

    private static let host = "librium-f1a78.web.app"

    private init() {}

    /// Returns true if we recognize and accept this URL.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let eventId = parseEventId(from: url) else { return false }
        Task { await resolve(eventId: eventId) }
        return true
    }

    func clear() {
        pendingEvent = nil
        lastErrorMessage = nil
    }

    // MARK: - Helpers

    private func parseEventId(from url: URL) -> UUID? {
        let isOurHost = (url.host ?? "").lowercased() == Self.host
        guard isOurHost else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        // Path looks like ["e", "{uuid}"]
        guard components.count >= 2, components[0].lowercased() == "e" else { return nil }
        return UUID(uuidString: components[1])
    }

    private func resolve(eventId: UUID) async {
        isResolving = true
        defer { isResolving = false }

        // Try local cache first
        if let local = NetworkEventService.shared.events.first(where: { $0.id == eventId }) {
            pendingEvent = local
            // Refresh from Firestore in background
            Task.detached {
                _ = await NetworkEventService.shared.pull(id: eventId)
            }
            return
        }

        // Pull from Firestore
        if let remote = await NetworkEventService.shared.pull(id: eventId) {
            pendingEvent = remote
        } else {
            lastErrorMessage = "That event link isn't valid anymore."
        }
    }
}
