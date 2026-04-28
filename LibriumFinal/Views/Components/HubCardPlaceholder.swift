import SwiftUI

struct HubCardPlaceholder: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            EquilibriumColor.background

            VStack(spacing: 12) {
                Text(title.uppercased())
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(EquilibriumColor.primaryText)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        }
    }
}
