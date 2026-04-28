import AVFoundation
import Foundation
import Speech

enum SpeechServiceError: Error, LocalizedError {
    case permissionDenied
    case recognitionUnavailable
    case audioEngineFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone or speech recognition permission denied."
        case .recognitionUnavailable: return "Speech recognition is not available right now."
        case .audioEngineFailed(let error): return "Audio engine failed: \(error.localizedDescription)"
        }
    }
}

@MainActor
final class SpeechService: ObservableObject {
    static let shared = SpeechService()

    enum AccessState {
        case unknown, denied, authorized
    }

    @Published private(set) var accessState: AccessState
    @Published private(set) var transcript: String = ""
    @Published private(set) var confidence: Float = 0
    @Published private(set) var isRecording: Bool = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Silence detection state
    private var lastTranscriptChangeAt: Date = .distantPast
    private var lastSeenTranscript: String = ""
    private var hasDetectedSpeech: Bool = false
    private var silenceTimeout: TimeInterval = 1.5
    private var onSilenceDetected: (@MainActor () -> Void)?
    private var silenceWatchdog: Task<Void, Never>?

    private init() {
        accessState = Self.computeAccessState()
    }

    func requestAccess() async {
        let speech = await requestSpeechAuth()
        let mic = await requestMicAuth()
        accessState = (speech && mic) ? .authorized : .denied
    }

    func start(
        silenceTimeout: TimeInterval? = nil,
        onSilence: (@MainActor () -> Void)? = nil
    ) throws {
        guard accessState == .authorized else {
            throw SpeechServiceError.permissionDenied
        }
        guard recognizer?.isAvailable == true else {
            throw SpeechServiceError.recognitionUnavailable
        }

        stop()

        transcript = ""
        confidence = 0
        self.silenceTimeout = silenceTimeout ?? 1.5
        self.onSilenceDetected = onSilence
        self.lastTranscriptChangeAt = Date()
        self.lastSeenTranscript = ""
        self.hasDetectedSpeech = false

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.request = request

        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if error != nil {
                    self.stop()
                    return
                }
                guard let result else { return }

                let segments = result.bestTranscription.segments
                let avg: Float = segments.isEmpty ? 0
                    : segments.map(\.confidence).reduce(0, +) / Float(segments.count)

                let newTranscript = result.bestTranscription.formattedString
                if newTranscript != self.lastSeenTranscript {
                    self.lastSeenTranscript = newTranscript
                    self.lastTranscriptChangeAt = Date()
                    if !newTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.hasDetectedSpeech = true
                    }
                }

                self.transcript = newTranscript
                self.confidence = avg

                if result.isFinal {
                    self.stop()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            stop()
            throw SpeechServiceError.audioEngineFailed(error)
        }

        if onSilence != nil {
            startSilenceWatchdog()
        }
    }

    private func startSilenceWatchdog() {
        silenceWatchdog?.cancel()
        silenceWatchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }
                guard let self else { return }
                guard self.isRecording else { return }
                guard self.hasDetectedSpeech else { continue }
                let elapsed = Date().timeIntervalSince(self.lastTranscriptChangeAt)
                if elapsed >= self.silenceTimeout {
                    let callback = self.onSilenceDetected
                    self.onSilenceDetected = nil
                    callback?()
                    return
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        silenceWatchdog?.cancel()
        silenceWatchdog = nil
        onSilenceDetected = nil
        hasDetectedSpeech = false
    }

    private static func computeAccessState() -> AccessState {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission

        if speech == .authorized && mic == .granted { return .authorized }
        if speech == .denied || speech == .restricted || mic == .denied { return .denied }
        return .unknown
    }

    private func requestSpeechAuth() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicAuth() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }
}
