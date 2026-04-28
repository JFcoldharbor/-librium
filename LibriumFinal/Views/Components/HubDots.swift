import SwiftUI

struct HubDots: View {
    let currentIndex: Int

    private let labels = ["LIFE", "HOME", "WORK"]

    var body: some View {
        HStack(spacing: 24) {
            ForEach(0..<EquilibriumConfig.hubCount, id: \.self) { index in
                VStack(spacing: 6) {
                    Circle()
                        .fill(currentIndex == index ? EquilibriumColor.primaryText : EquilibriumColor.tertiaryText)
                        .frame(
                            width: currentIndex == index ? 10 : 8,
                            height: currentIndex == index ? 10 : 8
                        )
                        .animation(.spring(), value: currentIndex)

                    Text(labels[index])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(currentIndex == index ? EquilibriumColor.primaryText : EquilibriumColor.secondaryText)
                }
            }
        }
    }
}
