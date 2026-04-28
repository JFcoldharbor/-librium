import SwiftUI

struct BalancePill: View {
    let score: BalanceScore

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(EquilibriumColor.primaryText.opacity(0.15), lineWidth: 3)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: CGFloat(score.value) / 100.0)
                    .stroke(tierColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: score.value)
            }

            Text("\(score.value)")
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)

            Text(score.tier.label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(EquilibriumColor.primaryText.opacity(0.06), in: Capsule())
        .overlay(
            Capsule().stroke(EquilibriumColor.primaryText.opacity(0.08), lineWidth: 1)
        )
    }

    private var tierColor: Color {
        switch score.tier {
        case .burningOut: return Color.red.opacity(0.85)
        case .steady: return Color.yellow
        case .inFlow: return Color.green
        }
    }
}
