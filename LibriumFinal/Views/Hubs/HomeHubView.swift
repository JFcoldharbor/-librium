import SwiftUI

struct HomeHubView: View {
    let geometry: GeometryProxy

    @StateObject private var viewModel = HomeHubViewModel()
    @State private var showSettings = false
    @State private var showBalanceDetail = false
    @State private var showImportantDates = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    EquilibriumColor.accent.opacity(0.3),
                    EquilibriumColor.accent.opacity(0.1),
                    EquilibriumColor.background
                ],
                center: .center,
                startRadius: 100,
                endRadius: geometry.size.width
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar

                Button(action: { showBalanceDetail = true }) {
                    BalancePill(score: viewModel.balanceScore)
                }
                .buttonStyle(.plain)

                ImportantDatesPill(dates: viewModel.upcomingDates) {
                    showImportantDates = true
                }

                Spacer()

                SpinningBlueOrb(state: viewModel.voiceState)
                    .frame(width: 280, height: 280)
                    .contentShape(Circle())
                    .onTapGesture {
                        viewModel.tapOrb()
                    }

                statusText
                    .frame(minHeight: 80)
                    .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }
        }
        .task {
            await viewModel.refreshBalance()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showBalanceDetail) {
            BalanceDetailView(breakdown: viewModel.balanceBreakdown)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showImportantDates) {
            ImportantDatesView()
                .preferredColorScheme(.dark)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer().frame(width: 40)

            Spacer()

            Text(headerText)
                .font(.system(size: 28, weight: .bold))
                .tracking(2)
                .foregroundColor(EquilibriumColor.primaryText.opacity(0.85))

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(EquilibriumColor.primaryText.opacity(0.5))
            }
            .frame(width: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
    }

    private var headerText: String {
        switch viewModel.voiceState {
        case .idle: return "EQUILIBRIUM"
        case .listening: return "LISTENING"
        case .processing: return "THINKING"
        case .speaking: return "MARIA"
        case .error: return "EQUILIBRIUM"
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.voiceState {
        case .idle:
            Text("Tap the orb to talk to Maria.")
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.secondaryText)
        case .listening:
            Text(viewModel.transcript.isEmpty ? "I'm listening." : viewModel.transcript)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.center)
        case .processing:
            Text("Thinking…")
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.secondaryText)
        case .speaking(let response):
            Text(response)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.center)
        case .error(let message):
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red.opacity(0.85))
                .multilineTextAlignment(.center)
        }
    }
}
