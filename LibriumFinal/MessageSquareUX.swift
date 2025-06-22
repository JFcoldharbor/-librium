//
//  MessageSquareUX.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


import Foundation
import Combine

// MARK: - Message Square UX Logic
class MessageSquareUX: ObservableObject {
    // MARK: - Published State
    @Published private(set) var isShowingHistory = false
    @Published private(set) var currentScrollPosition: Float = 1.0 // 0.0 = top, 1.0 = bottom
    @Published private(set) var hasUnreadMessages = false
    @Published private(set) var isMessageTruncated = false
    
    // MARK: - Private Properties
    private var conversationStateManager: ConversationStateManager
    private var tapCount = 0
    private var lastTapTime = Date()
    private let doubleTapThreshold: TimeInterval = 0.5
    private let maxVisibleCharacters = 120
    
    // Callbacks
    var onHistoryRequested: (() -> Void)?
    var onMessageCopy: ((String) -> Void)?
    var onDoubleTap: (() -> Void)?
    
    // MARK: - Initialization
    init(conversationStateManager: ConversationStateManager) {
        self.conversationStateManager = conversationStateManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Handle tap on message square
    func handleTap() {
        let now = Date()
        
        if now.timeIntervalSince(lastTapTime) < doubleTapThreshold {
            // Double tap detected
            handleDoubleTap()
        } else {
            // Single tap - show history
            showHistory()
        }
        
        lastTapTime = now
    }
    
    /// Handle long press on message square
    func handleLongPress() {
        // Copy current message
        let message = conversationStateManager.currentMessage
        onMessageCopy?(message.content)
    }
    
    /// Handle swipe up gesture
    func handleSwipeUp() {
        // Quick peek at recent history
        showRecentHistory()
    }
    
    /// Handle swipe down gesture
    func handleSwipeDown() {
        // Dismiss if history is showing
        if isShowingHistory {
            dismissHistory()
        }
    }
    
    /// Show full conversation history
    func showHistory() {
        isShowingHistory = true
        hasUnreadMessages = false
        onHistoryRequested?()
    }
    
    /// Dismiss history view
    func dismissHistory() {
        isShowingHistory = false
        // Scroll to bottom when dismissing
        currentScrollPosition = 1.0
    }
    
    /// Update scroll position
    func updateScrollPosition(_ position: Float) {
        currentScrollPosition = position
        
        // Clear unread indicator if scrolled to bottom
        if position > 0.95 {
            hasUnreadMessages = false
        }
    }
    
    /// Check if message should be truncated
    func checkMessageTruncation(_ message: String) -> (shouldTruncate: Bool, displayText: String) {
        if message.count > maxVisibleCharacters {
            isMessageTruncated = true
            let truncated = String(message.prefix(maxVisibleCharacters - 3)) + "..."
            return (true, truncated)
        } else {
            isMessageTruncated = false
            return (false, message)
        }
    }
    
    /// Get display text for current message
    func getDisplayText() -> String {
        let message = conversationStateManager.currentMessage
        let (_, displayText) = checkMessageTruncation(message.content)
        return displayText
    }
    
    /// Get message metadata for display
    func getMessageMetadata() -> MessageDisplayMetadata {
        let message = conversationStateManager.currentMessage
        
        return MessageDisplayMetadata(
            speaker: determineSpeaker(for: message),
            showTimestamp: shouldShowTimestamp(for: message),
            priority: determinePriority(for: message),
            animate: shouldAnimate(for: message)
        )
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor for new messages when history is shown
        conversationStateManager.$messageHistory
            .sink { [weak self] history in
                self?.handleHistoryUpdate(history)
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func handleDoubleTap() {
        tapCount = 0
        lastTapTime = Date()
        
        // Trigger repeat last message or other double tap action
        onDoubleTap?()
    }
    
    private func showRecentHistory() {
        // This would show last 3-5 messages in a peek view
        // For now, just set a flag that UI can use
        // Implementation depends on UI design
    }
    
    private func handleHistoryUpdate(_ history: [ConversationMessage]) {
        // Check if new message arrived while history is open
        if isShowingHistory && currentScrollPosition < 0.95 {
            hasUnreadMessages = true
        }
    }
    
    private func determineSpeaker(for message: ConversationMessage) -> MessageSpeaker {
        switch message.type {
        case .user:
            return .user
        case .assistant:
            return .assistant
        case .system:
            return .system
        }
    }
    
    private func shouldShowTimestamp(for message: ConversationMessage) -> Bool {
        // Show timestamp for:
        // - Error messages
        // - Success messages
        // - First message
        // - Messages with 5+ minute gap
        
        switch message.state {
        case .error, .success:
            return true
        default:
            return false
        }
    }
    
    private func determinePriority(for message: ConversationMessage) -> MessageDisplayPriority {
        switch message.state {
        case .error:
            return .high
        case .success, .processing, .listening:
            return .medium
        default:
            return .normal
        }
    }
    
    private func shouldAnimate(for message: ConversationMessage) -> Bool {
        switch message.state {
        case .listening, .processing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

struct MessageDisplayMetadata {
    let speaker: MessageSpeaker
    let showTimestamp: Bool
    let priority: MessageDisplayPriority
    let animate: Bool
}

enum MessageSpeaker {
    case user
    case assistant
    case system
}

enum MessageDisplayPriority {
    case high    // Errors, important alerts
    case medium  // Success, processing states
    case normal  // Regular conversation
}

// MARK: - History UX Logic

extension MessageSquareUX {
    /// Get filtered history for display
    func getDisplayHistory() -> [ConversationMessage] {
        conversationStateManager.getHistory(limit: 100)
    }
    
    /// Search history
    func searchHistory(_ query: String) -> [ConversationMessage] {
        let history = conversationStateManager.getHistory()
        
        guard !query.isEmpty else { return history }
        
        return history.filter { message in
            message.content.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Group messages by time
    func groupMessagesByTime() -> [(date: Date, messages: [ConversationMessage])] {
        let history = getDisplayHistory()
        
        let grouped = Dictionary(grouping: history) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }
        
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, messages: $0.value) }
    }
    
    /// Calculate read time for message
    func estimateReadTime(for message: String) -> TimeInterval {
        // Average reading speed: 250 words per minute
        let wordCount = message.split(separator: " ").count
        let minutes = Double(wordCount) / 250.0
        return max(1.5, minutes * 60) // Minimum 1.5 seconds
    }
}

// MARK: - Gesture Recognition Helpers

extension MessageSquareUX {
    /// Determine gesture type from velocity and translation
    func interpretGesture(velocity: CGPoint, translation: CGPoint) -> MessageGesture {
        let minSwipeVelocity: CGFloat = 50.0
        let minSwipeDistance: CGFloat = 20.0
        
        // Vertical swipes
        if abs(velocity.y) > abs(velocity.x) {
            if velocity.y < -minSwipeVelocity && translation.y < -minSwipeDistance {
                return .swipeUp
            } else if velocity.y > minSwipeVelocity && translation.y > minSwipeDistance {
                return .swipeDown
            }
        }
        
        // Horizontal swipes
        if abs(velocity.x) > abs(velocity.y) {
            if velocity.x < -minSwipeVelocity && translation.x < -minSwipeDistance {
                return .swipeLeft
            } else if velocity.x > minSwipeVelocity && translation.x > minSwipeDistance {
                return .swipeRight
            }
        }
        
        return .none
    }
}

enum MessageGesture {
    case swipeUp
    case swipeDown
    case swipeLeft
    case swipeRight
    case none
}

// MARK: - Accessibility Support

extension MessageSquareUX {
    /// Get accessibility label for current message
    func getAccessibilityLabel() -> String {
        let message = conversationStateManager.currentMessage
        let speaker = determineSpeaker(for: message)
        
        switch speaker {
        case .user:
            return "You said: \(message.content)"
        case .assistant:
            return "Maria said: \(message.content)"
        case .system:
            return "System: \(message.content)"
        }
    }
    
    /// Get accessibility hint
    func getAccessibilityHint() -> String {
        if isShowingHistory {
            return "Swipe down to close history"
        } else {
            return "Tap to show conversation history. Double tap to repeat last message."
        }
    }
}