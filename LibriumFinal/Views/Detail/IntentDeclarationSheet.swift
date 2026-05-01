import SwiftUI

/// Soft prompt that appears once per event RSVP. The user picks one of the
/// five intents — the platform is intent-agnostic; this is how filtering
/// happens. Editable later from inside Event Mode settings.
struct IntentDeclarationSheet: View {
    let event: NetworkEvent
    let initialIntent: AttendeeIntent?
    let onSelect: (AttendeeIntent) -> Void
    let onDismiss: () -> Void

    @State private var selected: AttendeeIntent

    init(
        event: NetworkEvent,
        initialIntent: AttendeeIntent? = nil,
        onSelect: @escaping (AttendeeIntent) -> Void,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.event = event
        self.initialIntent = initialIntent
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        _selected = State(initialValue: initialIntent ?? AttendeeIntent.default)
    }

    private var accent: Color { EquilibriumColor.CardTint.network }

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        optionsList
                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }

                bottomBar
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel", action: onDismiss)
                .foregroundColor(EquilibriumColor.secondaryText)
            Spacer()
        }
        .font(.system(size: 15))
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text("WHAT ARE YOU HERE FOR?")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .foregroundColor(accent)

            Text(event.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)

            Text("Pick a vibe. The room shows you only people whose vibe matches yours. Change it later if it shifts.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
        .padding(.top, 12)
    }

    private var optionsList: some View {
        VStack(spacing: 10) {
            ForEach(AttendeeIntent.allCases, id: \.self) { intent in
                IntentOptionRow(
                    intent: intent,
                    selected: selected == intent,
                    accent: accent
                ) {
                    selected = intent
                }
            }
        }
    }

    private var footnote: some View {
        Text("You can change this any time during the event.")
            .font(.system(size: 12))
            .foregroundColor(EquilibriumColor.tertiaryText)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(EquilibriumColor.tertiaryText.opacity(0.3))
            Button {
                onSelect(selected)
            } label: {
                Text("Confirm")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(accent)
                    .foregroundColor(.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(EquilibriumColor.background)
    }
}

private struct IntentOptionRow: View {
    let intent: AttendeeIntent
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? accent : EquilibriumColor.tertiaryText.opacity(0.6),
                            lineWidth: selected ? 6 : 1.5
                        )
                        .frame(width: 22, height: 22)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(intent.prompt)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text(intent.detail)
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? accent.opacity(0.10) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                selected ? accent.opacity(0.45) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
