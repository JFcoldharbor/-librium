import Foundation

struct DimensionSnapshot: Codable, Identifiable, Equatable {
    let id: String              // "yyyy-MM-dd" in local time
    let date: Date              // start of day
    var body: Double            // 0...100
    var mood: Double
    var relationships: Double
    var recreation: Double
    var achievement: Double
    var stress: Double
    var rest: Double
    var lifeComposite: Double   // weighted across dimensions
    var workComposite: Double   // pulled from accountability score (0...100)
    var overallComposite: Double // 50/50 blend of life + work, or weighted
    var createdAt: Date

    func value(for dimension: Dimension) -> Double {
        switch dimension {
        case .body: return body
        case .mood: return mood
        case .relationships: return relationships
        case .recreation: return recreation
        case .achievement: return achievement
        case .stress: return stress
        case .rest: return rest
        }
    }

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}
