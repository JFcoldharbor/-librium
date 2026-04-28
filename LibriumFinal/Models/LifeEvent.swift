import Foundation

struct LifeEvent: Codable, Identifiable, Equatable {
    let id: UUID
    var occurredAt: Date
    var category: Category
    var polarity: Polarity
    var intensity: Int          // 1...5
    var note: String?
    var createdAt: Date

    enum Category: String, Codable, CaseIterable {
        case relationship       // fights, dates, family moments
        case achievement        // non-work wins, milestones
        case setback            // losses, failures, disappointments
        case recreation         // movies, games, fun, leisure
        case rest               // naps, downtime, recovery
        case stress             // bills, deadlines, conflict, overload
        case body               // illness, injury, recovery from same
        case other

        /// Which dimensions this category influences and the impact weights.
        /// Negative weight inverts the polarity for that dimension.
        var dimensionImpacts: [(dimension: Dimension, weight: Double)] {
            switch self {
            case .relationship: return [(.relationships, 1.0), (.mood, 0.6), (.stress, -0.5)]
            case .achievement:  return [(.achievement, 1.0), (.mood, 0.6), (.stress, 0.4)]
            case .setback:      return [(.achievement, -0.8), (.mood, -0.6), (.stress, -0.5)]
            case .recreation:   return [(.recreation, 1.0), (.mood, 0.4), (.stress, 0.3)]
            case .rest:         return [(.rest, 1.0), (.mood, 0.3), (.body, 0.4)]
            case .stress:       return [(.stress, -1.0), (.mood, -0.4)]
            case .body:         return [(.body, 1.0), (.rest, 0.3)]
            case .other:        return [(.mood, 0.3)]
            }
        }

        /// Half-life in days — how quickly an event's influence fades.
        var halfLifeDays: Double {
            switch self {
            case .achievement, .setback: return 10   // big events stick longer
            case .body:                  return 7
            case .relationship:          return 5
            case .stress, .rest:         return 3
            case .recreation:            return 2
            case .other:                 return 5
            }
        }
    }

    enum Polarity: String, Codable {
        case positive, negative, neutral, signal
        var sign: Double {
            switch self {
            case .positive: return 1
            case .negative: return -1
            case .neutral, .signal: return 0
            }
        }
    }
}

/// The seven Life Score dimensions.
enum Dimension: String, Codable, CaseIterable {
    case body, mood, relationships, recreation, achievement, stress, rest

    var label: String {
        switch self {
        case .body: return "Body"
        case .mood: return "Mood"
        case .relationships: return "Relationships"
        case .recreation: return "Recreation"
        case .achievement: return "Achievement"
        case .stress: return "Stress"
        case .rest: return "Rest"
        }
    }

    /// Weight in the composite Life Score. Sums to 1.0.
    var lifeWeight: Double {
        switch self {
        case .body:          return 0.20
        case .mood:          return 0.20
        case .relationships: return 0.18
        case .recreation:    return 0.12
        case .achievement:   return 0.10
        case .stress:        return 0.10
        case .rest:          return 0.10
        }
    }
}
