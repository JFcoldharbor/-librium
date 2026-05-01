import Foundation

/// What stage of the journey an event is in for the user, given the current time.
///
/// `preEvent` — RSVP'd, more than 24h before start. Informational only.
/// `active`   — within the journey window: 24h pre-start through 48h post-end.
///              The whole app shifts: banner appears on Home, Event Mode unlocks,
///              Maria's chat baseline includes this event.
/// `postEvent` — ended more than 48h ago. Falls back to a normal recap entry.
enum EventState: Equatable {
    case preEvent
    case active
    case postEvent

    static let preWindow: TimeInterval = 24 * 3600
    static let postWindow: TimeInterval = 48 * 3600

    static func compute(for event: NetworkEvent, now: Date = Date()) -> EventState {
        let activeStart = event.startDate.addingTimeInterval(-Self.preWindow)
        let activeEnd = event.endDate.addingTimeInterval(Self.postWindow)
        if now < activeStart { return .preEvent }
        if now <= activeEnd { return .active }
        return .postEvent
    }

    var isActive: Bool { self == .active }
}
