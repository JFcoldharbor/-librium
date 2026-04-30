import Foundation

struct MemoryExtractionJob: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let userMessage: String
    let mariaResponse: String
    var attempts: Int
    var lastError: String?
}
