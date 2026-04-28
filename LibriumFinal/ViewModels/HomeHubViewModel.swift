import Combine
import Foundation

@MainActor
final class HomeHubViewModel: ObservableObject {
    @Published private(set) var voiceState: VoiceState = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var accessState: SpeechService.AccessState = .unknown
    @Published private(set) var balanceScore: BalanceScore = .empty
    @Published private(set) var balanceBreakdown: BalanceScoreBreakdown = .empty
    @Published private(set) var upcomingDates: [ImportantDate] = []
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
        accessState = speechService.accessState

        speechService.$accessState
            .receive(on: DispatchQueue.main)
            .assign(to: \.accessState, on: self)
            .store(in: &cancellables)

        speechService.$transcript
            .receive(on: DispatchQueue.main)
            .assign(to: \.transcript, on: self)
            .store(in: &cancellables)
    }

    private static let lastProactiveKey = "equilibrium.maria.lastProactive"
    private static let lastMorningGreetingKey = "equilibrium.maria.lastMorningGreeting"

    func refreshBalance() async {
        let (signals, breakdown) = await loadSignalsAndBreakdown()
        balanceScore = breakdown.score
        balanceBreakdown = breakdown
        upcomingDates = await ImportantDatesService.shared.loadUpcoming(within: 30)

        // Morning greeting takes priority over the generic proactive brief.
        if await considerMorningGreeting(signals: signals, breakdown: breakdown) {
            return
        }
        await considerProactiveBrief(signals: signals, breakdown: breakdown)
    }

    /// Returns true if a morning greeting was triggered, so the caller can skip the regular brief.
    private func considerMorningGreeting(signals: BalanceSignals, breakdown: BalanceScoreBreakdown) async -> Bool {
        guard case .idle = voiceState else { return false }

        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        // Morning window: 5am – 11am. After that, fall through to the generic brief.
        guard hour >= 5 && hour < 11 else { return false }

        // Once-per-day gate: compare yyyy-MM-dd of last greeting to today.
        let todayKey = Self.dayKey(for: now)
        let lastKey = UserDefaults.standard.string(forKey: Self.lastMorningGreetingKey)
        guard lastKey != todayKey else { return false }

        // Only greet if we actually have sleep data — otherwise the greeting falls flat.
        let sleepHours = signals.health.sleepHours > 0 ? signals.health.sleepHours : signals.wellness.sleepHours
        guard sleepHours > 0 else { return false }

        voiceState = .processing
        do {
            let context = await BalanceContext.snapshotAsync(signals: signals, score: breakdown.score)
            let sleepLabel = String(format: "%.1f", sleepHours)
            let prompt = """
            Morning context — the user just opened the app for the first time today.
            They slept \(sleepLabel) hours last night.

            Greet them warmly by speaking ONE breath — under 30 words total. The greeting must:
            1. Acknowledge their sleep (e.g. "Solid 7.2 hours" or "Light night, only 5.4").
            2. Ask how they slept (rested, restless, anything in between).
            3. Ask if they had any dreams worth catching.

            If they share dream content in their reply, call save_dream with what they tell you.
            If they say they don't remember the dream, encourage them to jot anything down in the Dreams section while it's fresh — don't push.
            No preamble, no list, no exclamation points.
            """
            let response = try await mariaService.ask(prompt, context: context)
            voiceState = .speaking(response: response)
            UserDefaults.standard.set(todayKey, forKey: Self.lastMorningGreetingKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastProactiveKey)
            await SpeechSynthesizerService.shared.speak(response)
            if case .speaking = voiceState {
                voiceState = .idle
            }
            return true
        } catch {
            voiceState = .idle
            return false
        }
    }

    private func considerProactiveBrief(signals: BalanceSignals, breakdown: BalanceScoreBreakdown) async {
        guard case .idle = voiceState else { return }

        let lastTimestamp = UserDefaults.standard.double(forKey: Self.lastProactiveKey)
        let lastDate = lastTimestamp > 0 ? Date(timeIntervalSince1970: lastTimestamp) : .distantPast
        let elapsed = Date().timeIntervalSince(lastDate)
        guard elapsed >= EquilibriumConfig.proactiveCooldownSeconds else { return }

        voiceState = .processing
        do {
            let context = await BalanceContext.snapshotAsync(signals: signals, score: breakdown.score)
            let prompt = "Brief me. Open my session with one observation about today and one offer or question. No preamble."
            let response = try await mariaService.ask(prompt, context: context)
            voiceState = .speaking(response: response)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastProactiveKey)
            await SpeechSynthesizerService.shared.speak(response)
            if case .speaking = voiceState {
                voiceState = .idle
            }
        } catch {
            voiceState = .idle
        }
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func tapOrb() {
        switch voiceState {
        case .idle:
            inConversation = true
            Task { await beginListening() }
        case .listening, .speaking, .error:
            inConversation = false
            speechService.stop()
            SpeechSynthesizerService.shared.stop()
            voiceState = .idle
        case .processing:
            break
        }
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
                let (signals, breakdown) = await loadSignalsAndBreakdown()
                balanceScore = breakdown.score
                balanceBreakdown = breakdown
                let context = await BalanceContext.snapshotAsync(signals: signals, score: breakdown.score)
                let response = try await mariaService.ask(prompt, context: context)
                voiceState = .speaking(response: response)
                await SpeechSynthesizerService.shared.speak(response)

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

    private func loadSignalsAndBreakdown() async -> (BalanceSignals, BalanceScoreBreakdown) {
        let signals = await signalsService.loadSignals()
        let breakdown = balanceScoreService.computeBreakdown(signals: signals)
        return (signals, breakdown)
    }
}
