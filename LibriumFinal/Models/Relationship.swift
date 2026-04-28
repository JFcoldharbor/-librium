import Foundation

struct Relationship: Equatable, Identifiable {
    let id: String
    let displayName: String
    let email: String
    let lastInteraction: Date
    let firstInteraction: Date
    let interactionCount: Int
    let decayScore: Double
    let role: String?
    let contactNote: String?
    let imageData: Data?

    static func fromContact(_ contact: ContactSummary) -> Relationship {
        Relationship(
            id: contact.id,
            displayName: contact.displayName,
            email: contact.primaryEmail ?? "",
            lastInteraction: .distantPast,
            firstInteraction: .distantPast,
            interactionCount: 0,
            decayScore: 0,
            role: contact.role,
            contactNote: contact.note,
            imageData: contact.imageData
        )
    }

    func daysSinceContact(now: Date = Date()) -> Int {
        max(0, Int(now.timeIntervalSince(lastInteraction) / 86_400))
    }

    func daysKnown(now: Date = Date()) -> Int {
        max(0, Int(now.timeIntervalSince(firstInteraction) / 86_400))
    }

    enum DecayState: Equatable {
        case fresh, warming, fading, stale, cold
    }

    func decayState(now: Date = Date()) -> DecayState {
        switch daysSinceContact(now: now) {
        case 0..<7: return .fresh
        case 7..<15: return .warming
        case 15..<31: return .fading
        case 31..<61: return .stale
        default: return .cold
        }
    }
}

struct RelationshipSnapshot: Equatable {
    let relationships: [Relationship]
    let asOf: Date

    static let empty = RelationshipSnapshot(relationships: [], asOf: .distantPast)
}
