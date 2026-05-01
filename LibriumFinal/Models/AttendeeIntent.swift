import Foundation

/// What an attendee is hoping to get out of an event. Set per-RSVP, not
/// per-account — the same person can be `professional` at a Monday conference
/// and `romantic` at a Thursday mixer.
///
/// The Room view filters who an attendee sees through a compatibility matrix
/// (see `sees(_:)`). Default is `social` — never default to `romantic`.
enum AttendeeIntent: String, Codable, CaseIterable, Equatable {
    case professional
    case social
    case friends
    case romantic
    case observing

    static let `default`: AttendeeIntent = .social

    /// Soft, permissive phrasing for the declaration sheet — sounds like a
    /// preference, not a moral statement.
    var prompt: String {
        switch self {
        case .professional: return "Just professional, please"
        case .social:       return "Open to anything social"
        case .friends:      return "Looking for friends"
        case .romantic:     return "Open to meeting someone special"
        case .observing:    return "Just here to observe"
        }
    }

    /// Short label for badges, settings rows, and recap headers.
    var shortLabel: String {
        switch self {
        case .professional: return "Professional"
        case .social:       return "Social"
        case .friends:      return "Friends"
        case .romantic:     return "Romantic"
        case .observing:    return "Observing"
        }
    }

    var detail: String {
        switch self {
        case .professional: return "Networking, job stuff, business connections."
        case .social:       return "Friendly conversations, no expectations."
        case .friends:      return "People you'd grab coffee with again."
        case .romantic:     return "Only visible to others who chose this too."
        case .observing:    return "You see no one, no one sees you. You're just here."
        }
    }

    /// True if a person with `self` intent can see (and be seen by) a person
    /// with `other` intent in the Room. Symmetric: if A sees B, B sees A.
    ///
    ///   pro      ↔ pro / social
    ///   social   ↔ pro / social / friends
    ///   friends  ↔ social / friends
    ///   romantic ↔ romantic only
    ///   observing — invisible both ways
    func sees(_ other: AttendeeIntent) -> Bool {
        switch (self, other) {
        case (.professional, .professional),
             (.professional, .social),
             (.social,       .professional),
             (.social,       .social),
             (.social,       .friends),
             (.friends,      .social),
             (.friends,      .friends),
             (.romantic,     .romantic):
            return true
        default:
            return false
        }
    }

    /// True if this intent uses the mutual-interest mechanic (both must mark
    /// interest before either sees the match) rather than the default ping flow.
    var requiresMutualInterest: Bool {
        self == .romantic
    }
}
