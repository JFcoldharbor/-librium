import Foundation

struct AccountabilityScore: Codable, Equatable {
    let daily: TimeframeStats
    let weekly: TimeframeStats
    let quarter: TimeframeStats
    let yearly: TimeframeStats
    let calendarCompleted7d: Int
    let calendarMissed7d: Int
    let calendarRescheduled7d: Int
    let overall: Double          // 0.0 ... 1.0, weighted across timeframes that have data

    struct TimeframeStats: Codable, Equatable {
        let completed: Int
        let missed: Int
        let dropped: Int
        let weight: Double           // contribution to the overall score
        let rate: Double?            // nil when there's no data — don't punish absence

        var hasData: Bool { rate != nil }
    }

    /// Weights for the overall composite. Sum to 1.0.
    /// Daily-most → near-term momentum reads loudest; yearly is the slowest signal.
    static let weights: (daily: Double, weekly: Double, quarter: Double, yearly: Double) =
        (daily: 0.35, weekly: 0.30, quarter: 0.20, yearly: 0.15)

    /// Percentage formatted (e.g. "81%"). Returns "—" when nil.
    static func percent(_ rate: Double?) -> String {
        guard let rate = rate else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }
}
