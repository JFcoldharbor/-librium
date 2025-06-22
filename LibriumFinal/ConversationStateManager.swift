import Foundation
import Combine

// MARK: - Conversation State Manager
// Note: This file requires SharedTypes.swift for MessageRole and EmotionType
class ConversationStateManager: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentMessage: ConversationMessage
    @Published private(set) var conversationState: ConversationFlowState = .idle
    @Published private(set) var messageHistory: [ConversationMessage] = []
    @Published private(set) var isProcessing = false
    
    // MARK: - Private Properties
    private var messageQueue: [ConversationMessage] = []
    private var currentMessageTimer: Timer?
    private let minimumDisplayDuration: TimeInterval = 1.5
    private var lastMessageTimestamp = Date()
    
    // Configuration
    private let maxHistorySize = 100
    private let maxQueueSize = 5
    
    // Callbacks
    var onStateChange: ((ConversationFlowState) -> Void)?
    var onMessageChange: ((ConversationMessage) -> Void)?
    var onHistoryUpdate: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        // Start with welcome message
        self.currentMessage = ConversationMessage(
            content: "How can I help you today?",
            type: .assistant,
            state: .normal
        )
        messageHistory.append(currentMessage)
    }
    
    // MARK: - Public Methods
    
    /// Start listening state
    func startListening() {
        updateState(.listening)
        
        let listeningMessage = ConversationMessage(
            content: "••• Listening •••",
            type: .system,
            state: .listening
        )
        
        displayMessage(listeningMessage, priority: .immediate)
    }
    
    /// Update with live transcription
    func updateTranscription(_ text: String, confidence: Float) {
        guard conversationState == .listening else { return }
        
        let transcriptionMessage = ConversationMessage(
            content: text.isEmpty ? "••• Listening •••" : text,
            type: .user,
            state: .transcribing,
            metadata: ["confidence": confidence]
        )
        
        // Update immediately without queuing
        updateCurrentMessage(transcriptionMessage, shouldAddToHistory: false)
    }
    
    /// Process final transcription
    func finalizeTranscription(_ text: String) {
        guard !text.isEmpty else {
            showNoSpeechDetected()
            return
        }
        
        updateState(.processing)
        
        // Add final user message to history
        let userMessage = ConversationMessage(
            content: text,
            type: .user,
            state: .normal
        )
        
        addToHistory(userMessage)
        
        // Show processing state
        let processingMessage = ConversationMessage(
            content: "⟳ Understanding...",
            type: .system,
            state: .processing
        )
        
        displayMessage(processingMessage, priority: .high)
    }
    
    /// Display Maria's response
    func showResponse(_ response: String, emotion: EmotionType? = nil) {
        updateState(.responding)
        
        let responseMessage = ConversationMessage(
            content: response,
            type: .assistant,
            state: .normal,
            emotion: emotion
        )
        
        displayMessage(responseMessage, priority: .normal)
        
        // Return to idle after response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateState(.idle)
        }
    }
    
    /// Show command result
    func showCommandResult(_ result: CommandResultData) {
        let commandMessage = ConversationMessage(
            content: result.message,
            type: .system,
            state: result.success ? .success : .error,
            metadata: ["command": result.commandType]
        )
        
        displayMessage(commandMessage, priority: .high)
    }
    
    /// Show error message
    func showError(_ error: String) {
        updateState(.error)
        
        let errorMessage = ConversationMessage(
            content: error,
            type: .system,
            state: .error
        )
        
        displayMessage(errorMessage, priority: .immediate)
        
        // Return to idle after showing error
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.updateState(.idle)
        }
    }
    
    /// Clear conversation
    func clearConversation() {
        messageHistory.removeAll()
        messageQueue.removeAll()
        
        let resetMessage = ConversationMessage(
            content: "Conversation cleared. How can I help?",
            type: .assistant,
            state: .normal
        )
        
        currentMessage = resetMessage
        messageHistory.append(resetMessage)
        updateState(.idle)
    }
    
    /// Get filtered history
    func getHistory(limit: Int? = nil) -> [ConversationMessage] {
        let filtered = messageHistory.filter { message in
            // Exclude system messages except important ones
            if message.type == .system {
                return message.state == .success || message.state == .error
            }
            return true
        }
        
        if let limit = limit {
            return Array(filtered.suffix(limit))
        }
        return filtered
    }
    
    // MARK: - Private Methods
    
    private func displayMessage(_ message: ConversationMessage, priority: CSMMessagePriority) {
        switch priority {
        case .immediate:
            // Display immediately, clear queue
            messageQueue.removeAll()
            updateCurrentMessage(message)
            
        case .high:
            // Add to front of queue
            messageQueue.insert(message, at: 0)
            processQueue()
            
        case .normal:
            // Add to queue
            if messageQueue.count < maxQueueSize {
                messageQueue.append(message)
            }
            processQueue()
        }
    }
    
    private func updateCurrentMessage(_ message: ConversationMessage, shouldAddToHistory: Bool = true) {
        currentMessage = message
        onMessageChange?(message)
        
        // Only add to history if requested AND (it's not a system message OR it's an important system message)
        if shouldAddToHistory {
            if message.type != .system || message.state == .success || message.state == .error {
                addToHistory(message)
            }
        }
        
        lastMessageTimestamp = Date()
    }
    
    private func addToHistory(_ message: ConversationMessage) {
        messageHistory.append(message)
        
        // Maintain history size
        if messageHistory.count > maxHistorySize {
            messageHistory.removeFirst()
        }
        
        onHistoryUpdate?()
    }
    
    private func processQueue() {
        guard !messageQueue.isEmpty else { return }
        
        // Check if enough time has passed since last message
        let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTimestamp)
        
        if timeSinceLastMessage >= minimumDisplayDuration {
            // Show next message
            if let nextMessage = messageQueue.first {
                messageQueue.removeFirst()
                updateCurrentMessage(nextMessage)
            }
        } else {
            // Schedule next check
            let remainingTime = minimumDisplayDuration - timeSinceLastMessage
            currentMessageTimer?.invalidate()
            currentMessageTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                self?.processQueue()
            }
        }
    }
    
    private func updateState(_ newState: ConversationFlowState) {
        conversationState = newState
        isProcessing = newState.isProcessing
        onStateChange?(newState)
    }
    
    private func showNoSpeechDetected() {
        let noSpeechMessage = ConversationMessage(
            content: "I didn't hear anything. Try again?",
            type: .system,
            state: .error
        )
        
        displayMessage(noSpeechMessage, priority: .high)
        updateState(.idle)
    }
}

// MARK: - Supporting Types

struct ConversationMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let type: MessageRole
    let state: MessageState
    let timestamp = Date()
    let emotion: EmotionType?
    let metadata: [String: Any]
    
    init(
        content: String,
        type: MessageRole,
        state: MessageState,
        emotion: EmotionType? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.content = content
        self.type = type
        self.state = state
        self.emotion = emotion
        self.metadata = metadata
    }
    
    static func == (lhs: ConversationMessage, rhs: ConversationMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum MessageState {
    case normal
    case listening
    case transcribing
    case processing
    case success
    case error
}

enum ConversationFlowState {
    case idle
    case listening
    case processing
    case responding
    case error
    
    var isProcessing: Bool {
        switch self {
        case .listening, .processing, .responding:
            return true
        default:
            return false
        }
    }
}

// Internal priority enum for this file only - using unique name to avoid conflicts
private enum CSMMessagePriority {
    case immediate  // Show right away, clear queue
    case high      // Add to front of queue
    case normal    // Add to end of queue
}

// Data structure for command results
struct CommandResultData {
    let success: Bool
    let message: String
    let commandType: String
}

// MARK: - Integration Helpers

extension ConversationStateManager {
    /// Handle complete flow from speech to response
    func handleSpeechFlow(
        speechManager: SpeechManagerUX,
        brain: MariaBrain
    ) async {
        do {
            // Start listening
            startListening()
            try await speechManager.startRecording()
            
            // Wait for recording to complete
            // (This would be handled by callbacks in real implementation)
            
            // Get final transcription
            let transcription = speechManager.transcribedText
            finalizeTranscription(transcription)
            
            // Process with brain
            let response = await brain.processInput(transcription)
            
            // Show response
            showResponse(response)
            
        } catch {
            showError("Sorry, I couldn't process that. Please try again.")
        }
    }
    
    /// Create message from chat history
    func loadFromChatMessage(_ chatMessage: ChatMessage) -> ConversationMessage {
        ConversationMessage(
            content: chatMessage.content,
            type: chatMessage.role,
            state: .normal,
            emotion: chatMessage.metadata.emotion
        )
    }
}

// MARK: - Message Queue Logic

private extension ConversationStateManager {
    /// Determine if message should be queued or shown immediately
    func shouldQueueMessage(_ message: ConversationMessage) -> Bool {
        // System messages with state changes show immediately
        if message.type == .system && (message.state == .listening || message.state == .processing) {
            return false
        }
        
        // Errors show immediately
        if message.state == .error {
            return false
        }
        
        // Everything else respects minimum display time
        return true
    }
    
    /// Calculate priority based on message type and state
    func calculatePriority(for message: ConversationMessage) -> CSMMessagePriority {
        switch (message.type, message.state) {
        case (_, .error):
            return .immediate
        case (.system, .listening), (.system, .processing):
            return .immediate
        case (.system, .success):
            return .high
        case (.assistant, _):
            return .normal
        case (.user, .transcribing):
            return .immediate
        default:
            return .normal
        }
    }
}
