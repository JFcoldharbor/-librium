import Combine
import Foundation

/// Watches the user's local NetworkEvents and exposes the single event currently
/// in its active window (24h pre-start through 48h post-end). Recomputes
/// whenever events change AND on a 60-second tick (state is time-based).
///
/// If the user has multiple events overlapping, picks the one with the earliest
/// startDate — i.e., the one they're "in" first.
@MainActor
final class ActiveEventCoordinator: ObservableObject {
    static let shared = ActiveEventCoordinator()

    @Published private(set) var activeEvent: NetworkEvent?

    private var cancellables = Set<AnyCancellable>()
    private var tickTask: Task<Void, Never>?

    private init() {
        recompute()
        // Recompute when the events collection changes
        NetworkEventService.shared.$events
            .sink { [weak self] _ in
                Task { @MainActor in self?.recompute() }
            }
            .store(in: &cancellables)
        startTicker()
    }

    deinit {
        tickTask?.cancel()
    }

    private func startTicker() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                await MainActor.run { self?.recompute() }
            }
        }
    }

    func recompute() {
        let now = Date()
        let active = NetworkEventService.shared.events
            .filter { EventState.compute(for: $0, now: now) == .active }
            .sorted { $0.startDate < $1.startDate }
            .first

        if active?.id != activeEvent?.id {
            activeEvent = active
        }
    }

    /// Convenience accessor for callers that just want a tier-aware "is anything
    /// happening right now" check.
    var hasActiveEvent: Bool { activeEvent != nil }
}
