import AVFoundation
import Foundation

@MainActor
final class OpenAITTSService: NSObject, AVAudioPlayerDelegate {
    static let shared = OpenAITTSService()

    enum Voice: String, CaseIterable, Codable {
        case alloy, echo, fable, onyx, nova, shimmer, coral, sage, ash, ballad, verse

        var displayName: String {
            rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }

        var description: String {
            switch self {
            case .alloy: return "Neutral · balanced"
            case .echo: return "Male · grounded"
            case .fable: return "British · expressive"
            case .onyx: return "Male · deep"
            case .nova: return "Female · friendly"
            case .shimmer: return "Female · soft"
            case .coral: return "Female · warm"
            case .sage: return "Female · calm"
            case .ash: return "Male · clear"
            case .ballad: return "Male · narrative"
            case .verse: return "Female · expressive"
            }
        }
    }

    private static let voiceKey = "equilibrium.openai.voice"
    private static let defaultVoice: Voice = .coral

    private let endpoint = URL(string: "https://api.openai.com/v1/audio/speech")!
    private var player: AVAudioPlayer?
    private var currentTask: Task<Bool, Never>?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    private override init() { super.init() }

    var selectedVoice: Voice {
        get {
            if let raw = UserDefaults.standard.string(forKey: Self.voiceKey),
               let voice = Voice(rawValue: raw) {
                return voice
            }
            return Self.defaultVoice
        }
    }

    func setSelectedVoice(_ voice: Voice) {
        UserDefaults.standard.set(voice.rawValue, forKey: Self.voiceKey)
    }

    @discardableResult
    func speak(_ text: String, voice: Voice? = nil) async -> Bool {
        stop()

        let key = Secrets.openAIAPIKey
        guard !key.isEmpty else { return false }

        let chosen = voice ?? selectedVoice
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            return await self.fetchAndPlay(text: text, voice: chosen, apiKey: key)
        }
        currentTask = task
        return await task.value
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        player?.stop()
        player = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    /// Strips characters and patterns OpenAI TTS dramatizes — ALL-CAPS shouting,
    /// exclamation runs, em-dash pauses, ellipsis stalls. Keeps natural speech rhythm.
    static func normalizeForTTS(_ text: String) -> String {
        var result = text

        // 1. Collapse !!! / ?! / !! into a single period — TTS yells multi-bang punctuation
        result = result.replacingOccurrences(of: #"!{2,}"#, with: ".", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\?+!+"#, with: "?", options: .regularExpression)
        result = result.replacingOccurrences(of: #"!+\?+"#, with: "?", options: .regularExpression)

        // 2. Drop trailing single exclamation points — replace with period for calm delivery
        result = result.replacingOccurrences(of: "!", with: ".")

        // 3. Em-dashes become commas — TTS reads em-dashes as dramatic pauses
        result = result.replacingOccurrences(of: "—", with: ", ")
        result = result.replacingOccurrences(of: " -- ", with: ", ")

        // 4. Ellipses — collapse to single period
        result = result.replacingOccurrences(of: "…", with: ".")
        result = result.replacingOccurrences(of: "...", with: ".")

        // 5. ALL-CAPS words → lowercase (preserves common acronyms via length+context check)
        if let regex = try? NSRegularExpression(pattern: #"\b[A-Z]{2,}\b"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let range = Range(match.range, in: result) else { continue }
                let word = String(result[range])
                // Preserve very short common acronyms — but most "MUST", "NEEDS" etc. are emphasis
                if word.count >= 2 && word.count <= 12 {
                    result.replaceSubrange(range, with: word.lowercased())
                }
            }
        }

        // 6. Multiple spaces collapse
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.playbackContinuation?.resume()
            self.playbackContinuation = nil
        }
    }

    private func fetchAndPlay(text: String, voice: Voice, apiKey: String) async -> Bool {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let cleaned = Self.normalizeForTTS(text)

        let body: [String: Any] = [
            "model": "tts-1",
            "voice": voice.rawValue,
            "input": cleaned,
            "speed": 0.95,
            "response_format": "mp3"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return true }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return false
            }

            #if !os(macOS)
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
            try? session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            self.player = player
            player.play()

            await withCheckedContinuation { continuation in
                if Task.isCancelled || self.player == nil {
                    continuation.resume()
                } else {
                    self.playbackContinuation = continuation
                }
            }
            return true
        } catch {
            return false
        }
    }
}
