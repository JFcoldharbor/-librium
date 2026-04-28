import Foundation

struct LifeInsight: Equatable, Identifiable {
    let id = UUID()
    let kind: Kind
    let priority: Int          // 0-100, higher = more useful for Maria to surface
    let summary: String        // human-readable, ready to drop into a prompt or UI
    let detail: String?        // optional supporting numbers

    enum Kind: String {
        case correlation       // "sleep 1d → mood: 0.72"
        case trend             // "stress trending up over last 7d"
        case streak            // "5 days mood ≥ 60"
        case eventCluster      // "3 stress events this week"
        case dayPattern        // "Mondays consistently low mood"
    }
}
