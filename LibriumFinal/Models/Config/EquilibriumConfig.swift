import SwiftUI

enum EquilibriumConfig {
    static let bypassAuth: Bool = false
    static let useDirectOpenAI: Bool = true

    static let hubCount: Int = 3
    static let homeHubIndex: Int = 1

    static let dragMinimumDistance: CGFloat = 10
    static let swipeThreshold: CGFloat = 50
    static let velocityThreshold: CGFloat = 300
    static let edgeResistance: CGFloat = 0.3
    static let horizontalDominanceRatio: CGFloat = 1.5

    static let hubSwipeAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.95)
    static let cardSwipeAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.9)
    static let dragOffsetAnimation: Animation = .interactiveSpring(response: 0.25, dampingFraction: 1.0)

    static let cardIndexMin: Int = -1
    static let cardIndexMax: Int = 2
    static let lifeCardIndexMax: Int = 1
    static let workCardIndexMax: Int = 2

    static let proactiveCooldownSeconds: TimeInterval = 4 * 3600

    static let contactsNotesEnabled: Bool = false
    static let relationshipLookbackDays: Int = 365
}
