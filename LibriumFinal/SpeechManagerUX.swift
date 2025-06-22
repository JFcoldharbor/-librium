import Speech
import AVFoundation
import Combine

// MARK: - Speech Manager UX Logic
// Note: This file requires SharedTypes.swift for detectIntent() and detectEmotion() functions
class SpeechManagerUX: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var recordingState: RecordingState = .idle
    @Published var permissionState: PermissionState = .notDetermined
    @Published var transcribedText: String = ""
    @Published var confidence: Float = 0.0
    @Published var error: SpeechError?
    
    // MARK: - Private Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioSession: AVAudioSession?
    
    // Callbacks
    var onTranscriptionUpdate: ((String, Float) -> Void)?
    var onRecordingStateChange: ((RecordingState) -> Void)?
    var onError: ((SpeechError) -> Void)?
    
    // Configuration
    private let minimumConfidence: Float = 0.5
    private let silenceTimeout: TimeInterval = 2.0
    private var silenceTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
        checkInitialPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Request necessary permissions
        func requestPermissions() async -> Bool {
            // Request speech recognition permission
            let speechAuthorized = await requestSpeechPermission()
            guard speechAuthorized else {
                permissionState = .denied
                return false
            }
            
            // Request microphone permission
            let micAuthorized = await requestMicrophonePermission()
            guard micAuthorized else {
                permissionState = .denied
                return false
            }
            
            permissionState = .authorized
            return true
        }
        
        /// Start recording and transcribing
        func startRecording() async throws {
            // Check permissions first
            guard permissionState == .authorized else {
                let authorized = await requestPermissions()
                guard authorized else {
                    throw SpeechError.permissionDenied
                }
                // Permissions granted, continue with the rest of the function
                return try await performStartRecording()
            }
            
            // If we already have permissions, start recording directly
            try await performStartRecording()
        }
        
        private func performStartRecording() async throws {
        
        
        // Update state
        recordingState = .starting
        onRecordingStateChange?(.starting)
        
        // Reset previous session
        resetRecognition()
        
        // Configure audio session
        try configureAudioSession()
        
        // Start recognition
        try startSpeechRecognition()
        
        // Update state
        recordingState = .recording
        onRecordingStateChange?(.recording)
    }
    
    /// Stop recording
    func stopRecording() {
        guard recordingState == .recording else { return }
        
        // Update state
        recordingState = .stopping
        onRecordingStateChange?(.stopping)
        
        // Stop audio
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        // Cancel silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Update state after brief delay for final processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.recordingState = .idle
            self?.onRecordingStateChange?(.idle)
        }
    }
    
    /// Cancel recording without processing
    func cancelRecording() {
        guard recordingState == .recording else { return }
        
        // Update state
        recordingState = .cancelled
        onRecordingStateChange?(.cancelled)
        
        // Stop everything immediately
        audioEngine.stop()
        recognitionTask?.cancel()
        resetRecognition()
        
        // Clear transcription
        transcribedText = ""
        
        // Update state
        recordingState = .idle
        onRecordingStateChange?(.idle)
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
    }
    
    private func checkInitialPermissions() {
        // Check speech recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        
        // Check microphone
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        
        // Update permission state
        if speechStatus == .authorized && micStatus == .granted {
            permissionState = .authorized
        } else if speechStatus == .denied || micStatus == .denied {
            permissionState = .denied
        } else if speechStatus == .restricted {
            permissionState = .restricted
        } else {
            permissionState = .notDetermined
        }
    }
    
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func configureAudioSession() throws {
        try audioSession?.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startSpeechRecognition() throws {
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionUnavailable
        }
        
        // Configure request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Get input node
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(
            with: recognitionRequest
        ) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on audio input
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        // Handle error
        if let error = error {
            let speechError = mapError(error)
            self.error = speechError
            onError?(speechError)
            
            if speechError.isTerminal {
                stopRecording()
            }
            return
        }
        
        // Handle result
        if let result = result {
            // Update transcription
            let transcription = result.bestTranscription.formattedString
            let confidence = result.bestTranscription.segments.isEmpty ? 0.0 :
                result.bestTranscription.segments.map { $0.confidence }.reduce(0, +) / Float(result.bestTranscription.segments.count)
            
            DispatchQueue.main.async { [weak self] in
                self?.transcribedText = transcription
                self?.confidence = confidence
                self?.onTranscriptionUpdate?(transcription, confidence)
            }
            
            // Reset silence timer
            resetSilenceTimer()
            
            // Check if final
            if result.isFinal {
                stopRecording()
            }
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            self?.handleSilenceTimeout()
        }
    }
    
    private func handleSilenceTimeout() {
        // Auto-stop on silence
        if recordingState == .recording && !transcribedText.isEmpty {
            stopRecording()
        }
    }
    
    private func resetRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    private func mapError(_ error: Error) -> SpeechError {
        if let nsError = error as NSError? {
            switch nsError.code {
            case 203: // No speech detected
                return .noSpeechDetected
            case 216: // Audio engine error
                return .audioEngineError
            case 1110: // Network error
                return .networkError
            default:
                return .recognitionFailed(error.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Supporting Types

enum RecordingState {
    case idle
    case starting
    case recording
    case stopping
    case cancelled
    
    var isActive: Bool {
        switch self {
        case .recording, .starting:
            return true
        default:
            return false
        }
    }
}

enum PermissionState {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum SpeechError: LocalizedError {
    case permissionDenied
    case recognitionUnavailable
    case audioEngineError
    case networkError
    case noSpeechDetected
    case recognitionFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition permission denied"
        case .recognitionUnavailable:
            return "Speech recognition is not available"
        case .audioEngineError:
            return "Audio recording failed"
        case .networkError:
            return "Network connection required for speech recognition"
        case .noSpeechDetected:
            return "No speech detected"
        case .recognitionFailed(let reason):
            return "Recognition failed: \(reason)"
        case .unknown(let reason):
            return "Unknown error: \(reason)"
        }
    }
    
    var isTerminal: Bool {
        switch self {
        case .permissionDenied, .recognitionUnavailable, .audioEngineError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Integration Protocol
protocol SpeechManagerDelegate: AnyObject {
    func speechManager(_ manager: SpeechManagerUX, didUpdateTranscription text: String, confidence: Float)
    func speechManager(_ manager: SpeechManagerUX, didChangeState state: RecordingState)
    func speechManager(_ manager: SpeechManagerUX, didEncounterError error: SpeechError)
}

// MARK: - MariaBrain Integration Extension
extension SpeechManagerUX {
    /// Process speech and send to MariaBrain
    func processAndSendToMaria(brain: MariaBrain) async {
        guard !transcribedText.isEmpty else { return }
        
        // Send to brain for processing
        let response = await brain.processInput(transcribedText)
        
        // Clear transcription for next input
        transcribedText = ""
    }
    
    /// Create conversation turn for integration
    func createConversationTurn() -> ConversationTurn? {
        guard !transcribedText.isEmpty else { return nil }
        
        return ConversationTurn(
            id: UUID(),
            role: .user,
            content: transcribedText,
            timestamp: Date(),
            intent: detectIntent(from: transcribedText),
            emotion: detectEmotion(from: transcribedText)
        )
    }
}
