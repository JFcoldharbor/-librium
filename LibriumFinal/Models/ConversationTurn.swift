import Foundation

struct ConversationTurn: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let userMessage: String
    let mariaResponse: String
    let systemContext: String
    let memoriesUsed: [String]
    let isProactive: Bool
    let model: String
    let tokensUsed: Int?
}
