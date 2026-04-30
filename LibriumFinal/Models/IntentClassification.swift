import Foundation

struct IntentClassification: Codable, Equatable {
    let timeMode: TimeMode
    let slices: [SliceType]
    let confidence: Double
    let needsClarification: Bool
    let conversational: Bool
    let classifiedAt: Date
    let queryHash: String
}
