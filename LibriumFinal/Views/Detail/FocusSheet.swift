import SwiftUI

struct FocusSheet: View {
    @ObservedObject var viewModel: WorkHubViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 24) {
                    Spacer().frame(height: 16)

                    Text(viewModel.focusActive ? "Deep work in progress" : "25 min deep work")
                        .font(.system(size: 14))
                        .foregroundColor(EquilibriumColor.secondaryText)

                    Spacer()

                    timerRing

                    Spacer()

                    Button(action: { viewModel.toggleFocus() }) {
                        Text(viewModel.focusActive ? "Cancel" : "Start")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: 200)
                            .frame(height: 50)
                            .background(
                                viewModel.focusActive
                                    ? EquilibriumColor.primaryText.opacity(0.08)
                                    : EquilibriumColor.CardTint.motivation,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .foregroundColor(viewModel.focusActive ? EquilibriumColor.primaryText : .white)
                    }

                    todayStats

                    Spacer().frame(height: 30)
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
                    Text("Focus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(EquilibriumColor.CardTint.motivation)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                FocusHistoryView()
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.motivation.opacity(0.22),
                    EquilibriumColor.CardTint.motivation.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .center,
                startRadius: 60,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(EquilibriumColor.primaryText.opacity(0.10), lineWidth: 6)
                .frame(width: 240, height: 240)

            Circle()
                .trim(from: 0, to: viewModel.focusProgress)
                .stroke(EquilibriumColor.CardTint.motivation, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: viewModel.focusProgress)

            VStack(spacing: 4) {
                Text(viewModel.focusFormattedRemaining)
                    .font(.system(size: 56, weight: .light))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
                Text(viewModel.focusActive ? "remaining" : "ready")
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        }
    }

    private var todayStats: some View {
        HStack(spacing: 32) {
            statBlock(value: "\(viewModel.todayFocusSessions)", label: viewModel.todayFocusSessions == 1 ? "session today" : "sessions today")
            statBlock(value: "\(viewModel.todayFocusMinutes)", label: "min today")
            statBlock(value: "\(viewModel.weekFocusSessions)", label: "this week")
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }
}
