import SwiftUI

struct BreathingSheet: View {
    @ObservedObject var viewModel: LifeHubViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 16) {
                    Spacer().frame(height: 8)

                    patternSelector

                    Spacer()

                    breathingOrb

                    Spacer()

                    Text(viewModel.breathingActive ? viewModel.breathingPhase.label : "Tap Begin to start")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(EquilibriumColor.primaryText)

                    todayStats

                    Button(action: { viewModel.toggleBreathing() }) {
                        Text(viewModel.breathingActive ? "Stop" : "Begin")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: 200)
                            .frame(height: 50)
                            .background(
                                viewModel.breathingActive
                                    ? EquilibriumColor.primaryText.opacity(0.10)
                                    : EquilibriumColor.CardTint.spiritual,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .foregroundColor(viewModel.breathingActive ? EquilibriumColor.primaryText : .white)
                    }

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Breathe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(EquilibriumColor.CardTint.spiritual)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                BreathingHistoryView()
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.spiritual.opacity(0.22),
                    EquilibriumColor.CardTint.spiritual.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .center,
                startRadius: 60,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var patternSelector: some View {
        HStack(spacing: 8) {
            ForEach(BreathingPattern.allCases, id: \.self) { pattern in
                patternButton(pattern)
            }
        }
    }

    private func patternButton(_ pattern: BreathingPattern) -> some View {
        let selected = viewModel.selectedPattern == pattern
        return Button(action: {
            if !viewModel.breathingActive {
                viewModel.selectedPattern = pattern
            }
        }) {
            VStack(spacing: 2) {
                Text(pattern.label)
                    .font(.system(size: 14, weight: .semibold))
                Text(pattern.subtitle)
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(EquilibriumColor.primaryText)
            .background(
                selected
                    ? EquilibriumColor.CardTint.spiritual.opacity(0.30)
                    : EquilibriumColor.primaryText.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? EquilibriumColor.CardTint.spiritual : Color.clear, lineWidth: 1)
            )
        }
        .disabled(viewModel.breathingActive)
    }

    private var breathingOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        EquilibriumColor.CardTint.spiritual.opacity(0.7),
                        EquilibriumColor.CardTint.spiritual.opacity(0.2),
                        EquilibriumColor.CardTint.spiritual.opacity(0.05)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 120
                )
            )
            .frame(width: 200, height: 200)
            .scaleEffect(viewModel.breathingActive ? viewModel.breathingPhase.scale : 1.0)
            .animation(
                .easeInOut(duration: phaseDurationDouble),
                value: viewModel.breathingPhase
            )
            .overlay(
                Text("\(viewModel.breathingSecondsRemaining)")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .opacity(viewModel.breathingActive ? 1 : 0)
            )
    }

    private var phaseDurationDouble: Double {
        guard let step = viewModel.selectedPattern.phases.first(where: { $0.kind == viewModel.breathingPhase }) else {
            return 4
        }
        return Double(step.duration)
    }

    private var todayStats: some View {
        HStack(spacing: 24) {
            statBlock(value: "\(viewModel.todayCycles)", label: "cycles today")
            statBlock(value: "\(viewModel.todayMinutes)", label: "min today")
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }
}
