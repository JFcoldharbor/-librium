import Foundation

struct ScannerOutput: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case morningBrief
        case middayCheck
        case eveningReview
        case nightReflection
        case eventTriggered
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let summary: String
    let surfacingNotes: [SurfacingNote]
    let suggestedActions: [SuggestedAction]
    let trigger: String?
}

struct SurfacingNote: Codable, Identifiable, Equatable {
    enum NoteKind: String, Codable {
        case prep
        case nudge
        case opportunity
        case risk
    }

    let id: UUID
    let kind: NoteKind
    let title: String
    let body: String
    let relatedEntityId: String?
    let priority: Int
}

struct SuggestedAction: Codable, Identifiable, Equatable {
    let id: UUID
    let label: String
    let toolName: String
    let argumentsJSON: String
}
