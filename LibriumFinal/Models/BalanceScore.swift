import Foundation

struct BalanceScore: Equatable {
    let value: Int
    let tier: BalanceTier
    let asOf: Date

    static let empty = BalanceScore(value: 0, tier: .steady, asOf: .distantPast)
}

enum BalanceTier: String, Equatable, CaseIterable {
    case burningOut
    case steady
    case inFlow

    var label: String {
        switch self {
        case .burningOut: return "Burning Out"
        case .steady: return "Steady"
        case .inFlow: return "In Flow"
        }
    }
}
