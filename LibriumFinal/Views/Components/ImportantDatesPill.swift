import SwiftUI

struct ImportantDatesPill: View {
    let dates: [ImportantDate]
    var onTap: () -> Void = {}

    @State private var currentIndex: Int = 0
    private let rotationInterval: TimeInterval = 4.5

    private var displayDates: [ImportantDate] {
        Array(dates.prefix(5))
    }

    private var current: ImportantDate? {
        guard !displayDates.isEmpty else { return nil }
        let safeIndex = min(currentIndex, displayDates.count - 1)
        return displayDates[safeIndex]
    }

    var body: some View {
        if displayDates.isEmpty {
            EmptyView()
        } else {
            Button(action: onTap) {
                pillView
            }
            .buttonStyle(.plain)
            .onReceive(Timer.publish(every: rotationInterval, on: .main, in: .common).autoconnect()) { _ in
                guard displayDates.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (currentIndex + 1) % displayDates.count
                }
            }
        }
    }

    @ViewBuilder
    private var pillView: some View {
        if let date = current {
            HStack(spacing: 8) {
                Text(date.icon)
                    .font(.system(size: 14))

                Text(date.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(1)

                Text("·")
                    .foregroundColor(EquilibriumColor.tertiaryText)

                Text(daysLabel(date.daysUntil()))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(urgencyColor(date.daysUntil()))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(urgencyColor(date.daysUntil()).opacity(0.3), lineWidth: 0.5)
            )
            .id(date.id)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                removal: .opacity
            ))
        }
    }

    private func daysLabel(_ days: Int) -> String {
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(days)d"
        }
    }

    private func urgencyColor(_ days: Int) -> Color {
        switch days {
        case 0...3: return .red.opacity(0.85)
        case 4...7: return .orange
        case 8...14: return .yellow
        default: return EquilibriumColor.secondaryText
        }
    }
}
