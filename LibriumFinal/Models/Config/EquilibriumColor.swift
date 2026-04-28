import SwiftUI

enum EquilibriumColor {
    static let background = Color.black
    static let accent = Color.blue
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let tertiaryText = Color.white.opacity(0.3)

    enum CardTint {
        static let calendar = Color(red: 0.95, green: 0.65, blue: 0.25)   // amber
        static let network = Color(red: 0.25, green: 0.75, blue: 0.78)    // teal
        static let financial = Color(red: 0.85, green: 0.72, blue: 0.30)  // gold-green
        static let motivation = Color(red: 0.92, green: 0.36, blue: 0.36) // crimson
        static let spiritual = Color(red: 0.62, green: 0.45, blue: 0.92)  // violet
        static let journalDream = Color(red: 0.32, green: 0.36, blue: 0.78) // midnight indigo
        static let health = Color(red: 0.30, green: 0.78, blue: 0.55)     // vital green
    }
}
