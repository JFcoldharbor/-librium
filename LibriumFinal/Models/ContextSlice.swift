import Foundation

struct ContextSlice: Codable, Equatable {
    let type: SliceType
    let content: String
    let estimatedTokens: Int
    let renderedAt: Date
}
