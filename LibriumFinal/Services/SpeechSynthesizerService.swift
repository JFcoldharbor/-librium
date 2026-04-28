import AVFoundation
import Foundation

@MainActor
final class SpeechSynthesizerService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechSynthesizerService()

    private let synthesizer = AVSpeechSynthesizer()
    private var iosContinuation: CheckedContinuation<Void, Never>?
    private static let voiceKey = "equilibrium.voice.identifier"

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - iOS voice catalog (fallback only)

    func availableEnglishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix("en") }
            .sorted { lhs, rhs in
                let qa = qualityRank(lhs)
                let qb = qualityRank(rhs)
                if qa != qb { return qa > qb }
                if lhs.language != rhs.language { return lhs.language < rhs.language }
                return lhs.name < rhs.name
            }
    }

    var selectedIOSVoiceIdentifier: String? {
        UserDefaults.standard.string(forKey: Self.voiceKey)
    }

    func setSelectedIOSVoice(_ identifier: String?) {
        if let identifier {
            UserDefaults.standard.set(identifier, forKey: Self.voiceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.voiceKey)
        }
    }

    private func currentIOSVoice() -> AVSpeechSynthesisVoice? {
        if let id = selectedIOSVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return availableEnglishVoices().first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private func qualityRank(_ voice: AVSpeechSynthesisVoice) -> Int {
        switch voice.quality {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
    }

    // MARK: - Speak / stop

    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !Secrets.openAIAPIKey.isEmpty {
            let ok = await OpenAITTSService.shared.speak(trimmed)
            if ok { return }
        }
        await speakIOS(trimmed)
    }

    func preview(_ voice: AVSpeechSynthesisVoice, sample: String = "Hi, I'm Maria. This is how I sound.") {
        stop()
        configurePlaybackSession()
        let utterance = AVSpeechUtterance(string: sample)
        utterance.rate = 0.5
        utterance.voice = voice
        synthesizer.speak(utterance)
    }

    func previewOpenAI(_ voice: OpenAITTSService.Voice, sample: String = "Hi, I'm Maria. This is how I sound.") {
        Task {
            await OpenAITTSService.shared.speak(sample, voice: voice)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        OpenAITTSService.shared.stop()
        iosContinuation?.resume()
        iosContinuation = nil
    }

    private func speakIOS(_ text: String) async {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        iosContinuation?.resume()
        iosContinuation = nil

        configurePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = currentIOSVoice()

        await withCheckedContinuation { continuation in
            iosContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            iosContinuation?.resume()
            iosContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            iosContinuation?.resume()
            iosContinuation = nil
        }
    }

    private func configurePlaybackSession() {
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }
}

extension AVSpeechSynthesisVoice {
    var qualityLabel: String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        case .default: return "Default"
        @unknown default: return ""
        }
    }
}
