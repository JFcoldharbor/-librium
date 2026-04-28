import Foundation

struct BalanceScoreBreakdown: Equatable {
    let score: BalanceScore
    let meeting: Component
    let connection: Component
    let sleep: Component?
    let energy: Component?
    let recoveryBonus: Double

    struct Component: Equatable {
        let raw: Double
        let weight: Double
        let contribution: Double
    }

    static let empty = BalanceScoreBreakdown(
        score: .empty,
        meeting: Component(raw: 0, weight: 0, contribution: 0),
        connection: Component(raw: 0, weight: 0, contribution: 0),
        sleep: nil,
        energy: nil,
        recoveryBonus: 0
    )
}
