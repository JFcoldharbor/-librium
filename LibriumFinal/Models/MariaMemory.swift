import Foundation

struct MariaMemory: Codable, Identifiable, Equatable {
    let id: UUID
    let content: String
    let category: Category
    let keywords: [String]
    let createdAt: Date
    var mentionCount: Int

    enum Category: String, Codable, CaseIterable {
        case fact
        case preference
        case win
        case struggle
        case commitment
        case context

        var label: String {
            switch self {
            case .fact: return "Fact"
            case .preference: return "Preference"
            case .win: return "Win"
            case .struggle: return "Struggle"
            case .commitment: return "Commitment"
            case .context: return "Context"
            }
        }

        var weight: Double {
            switch self {
            case .commitment: return 1.3
            case .preference: return 1.1
            case .fact: return 1.0
            case .struggle: return 1.0
            case .win: return 0.9
            case .context: return 0.8
            }
        }
    }
}
