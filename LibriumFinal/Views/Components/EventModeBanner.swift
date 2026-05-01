import SwiftUI

/// Pinned to the top of the Home tab whenever the user has an event in its
/// active window. One-line affordance: status pill + name + chevron. Tap to
/// open the event detail (later: Event Mode home).
struct EventModeBanner: View {
    let event: NetworkEvent
    let onTap: () -> Void

    private var accent: Color { EquilibriumColor.CardTint.network }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .overlay(
                            Circle().strokeBorder(accent.opacity(0.45), lineWidth: 1)
                        )
                    Text("⌬")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(accent)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.statusLabel)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.4)
                        .foregroundColor(accent)
                    Text(event.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(accent.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(accent.opacity(0.30), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
