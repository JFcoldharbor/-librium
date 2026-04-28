import Foundation
import SwiftUI

struct EventPriority: Codable, Equatable, Identifiable {
    var id: String { eventIdentifier }
    let eventIdentifier: String
    var level: Level
    var setAt: Date

    enum Level: String, Codable, CaseIterable {
        case mustDo
        case important
        case flexible
        case skippable

        var label: String {
            switch self {
            case .mustDo: return "Must Do"
            case .important: return "Important"
            case .flexible: return "Flexible"
            case .skippable: return "Skippable"
            }
        }

        var shortLabel: String {
            switch self {
            case .mustDo: return "MUST"
            case .important: return "IMPORTANT"
            case .flexible: return "FLEX"
            case .skippable: return "SKIP"
            }
        }

        var color: Color {
            switch self {
            case .mustDo: return Color.red.opacity(0.85)
            case .important: return Color.orange
            case .flexible: return Color.yellow
            case .skippable: return Color.green
            }
        }

        /// Maria's behavior: how aggressively to leave this alone when rearranging.
        var rearrangeRule: String {
            switch self {
            case .mustDo: return "Never move or cancel without explicit user approval. Treat as immovable."
            case .important: return "Avoid cancelling. Ask before moving."
            case .flexible: return "Move freely if it resolves a conflict."
            case .skippable: return "Cancel or move freely. Prefer cancelling these first when clearing time."
            }
        }
    }
}
