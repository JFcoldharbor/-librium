import Foundation

struct DreamEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var rawDescription: String
    var analysis: String?
    var symbols: [String]
    var dreamedAt: Date
    var createdAt: Date

    static func make(title: String, description: String, dreamedAt: Date = Date()) -> DreamEntry {
        DreamEntry(
            id: UUID(),
            title: title,
            rawDescription: description,
            analysis: nil,
            symbols: [],
            dreamedAt: dreamedAt,
            createdAt: Date()
        )
    }
}
