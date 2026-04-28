import Combine
import SwiftUI

@MainActor
final class QuickMariaViewModel: ObservableObject {
    static let shared = QuickMariaViewModel()

    @Published var voiceState: VoiceState = .idle
    @Published var transcript: String = ""
    @Published private(set) var inConversation: Bool = false

    private let speechService: SpeechService
    private let mariaService: MariaService
    private let signalsService: BalanceSignalsService
    private let balanceScoreService: BalanceScoreService
    private var cancellables = Set<AnyCancellable>()

    init(
        speechService: SpeechService = .shared,
        mariaService: MariaService = .shared,
        signalsService: BalanceSignalsService = .shared,
        balanceScoreService: BalanceScoreService = .shared
    ) {
        self.speechService = speechService
        self.mariaService = mariaService
        self.signalsService = signalsService
        self.balanceScoreService = balanceScoreService

        speechService.$transcript
            .receive(on: DispatchQueue.main)
            .assign(to: \.transcript, on: self)
            .store(in: &cancellables)
    }

    func tapOrb() {
        switch voiceState {
        case .idle:
            // Start a conversation — auto-stops on silence, auto-resumes after Maria speaks
            inConversation = true
            Task { await beginListening() }
        case .listening, .speaking, .error:
            // User is bailing — exit conversation mode and silence everything
            inConversation = false
            speechService.stop()
            SpeechSynthesizerService.shared.stop()
            voiceState = .idle
        case .processing:
            break
        }
    }

    func teardown() {
        inConversation = false
        speechService.stop()
        SpeechSynthesizerService.shared.stop()
        voiceState = .idle
    }

    private func beginListening() async {
        if speechService.accessState == .unknown {
            await speechService.requestAccess()
        }
        guard speechService.accessState == .authorized else {
            voiceState = .error(message: "Microphone or speech permission needed.")
            inConversation = false
            return
        }
        do {
            try speechService.start(silenceTimeout: 1.6) { [weak self] in
                self?.handleSilenceDetected()
            }
            voiceState = .listening
        } catch {
            voiceState = .error(message: error.localizedDescription)
            inConversation = false
        }
    }

    private func handleSilenceDetected() {
        guard case .listening = voiceState else { return }
        stopListeningAndProcess()
    }

    private func stopListeningAndProcess() {
        speechService.stop()
        let prompt = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            // Silence with no real speech — if still in conversation, listen again
            if inConversation {
                Task { await beginListening() }
            } else {
                voiceState = .idle
            }
            return
        }
        voiceState = .processing
        Task {
            do {
                let signals = await signalsService.loadSignals()
                let breakdown = balanceScoreService.computeBreakdown(signals: signals)
                let context = await BalanceContext.snapshotAsync(signals: signals, score: breakdown.score)
                let response = try await mariaService.ask(prompt, context: context)
                voiceState = .speaking(response: response)
                await SpeechSynthesizerService.shared.speak(response)

                // After Maria finishes speaking, decide what's next
                if inConversation {
                    await beginListening()
                } else if case .speaking = voiceState {
                    voiceState = .idle
                }
            } catch {
                voiceState = .error(message: error.localizedDescription)
                inConversation = false
            }
        }
    }
}

struct QuickMariaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuickMariaViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 22) {
                    Spacer()

                    Text(headerText)
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(2)
                        .foregroundColor(EquilibriumColor.primaryText.opacity(0.7))

                    SpinningBlueOrb(state: viewModel.voiceState)
                        .frame(width: 220, height: 220)
                        .contentShape(Circle())
                        .onTapGesture {
                            viewModel.tapOrb()
                        }

                    statusText

                    Spacer()
                }
                .padding(.horizontal, 28)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        viewModel.teardown()
                        dismiss()
                    }
                    .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Maria")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .onDisappear {
                viewModel.teardown()
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.accent.opacity(0.30),
                    EquilibriumColor.accent.opacity(0.08),
                    EquilibriumColor.background
                ],
                center: .center,
                startRadius: 80,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var headerText: String {
        switch viewModel.voiceState {
        case .idle: return "TAP TO TALK"
        case .listening: return "LISTENING"
        case .processing: return "THINKING"
        case .speaking: return "MARIA"
        case .error: return "MARIA"
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.voiceState {
        case .idle:
            Text("She's ready when you are.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
        case .listening:
            Text(viewModel.transcript.isEmpty ? "I'm listening." : viewModel.transcript)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.center)
        case .processing:
            Text("Thinking…")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
        case .speaking(let response):
            ScrollView {
                Text(response)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxHeight: 220)
        case .error(let message):
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.red.opacity(0.85))
                .multilineTextAlignment(.center)
        }
    }
}
