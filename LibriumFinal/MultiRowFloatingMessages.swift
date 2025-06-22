import SwiftUI

// MARK: - Multi-Row Floating Messages (Standalone Component)
struct MultiRowFloatingMessages: View {
    @StateObject private var messageManager = FloatingMessageManager()
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1 - High priority
            FloatingMessageRow(
                messages: messageManager.highPriorityMessages,
                urgency: .high,
                delay: 0
            )
            
            // Row 2 - Medium priority
            FloatingMessageRow(
                messages: messageManager.mediumPriorityMessages,
                urgency: .medium,
                delay: 7
            )
            
            // Row 3 - Low priority
            FloatingMessageRow(
                messages: messageManager.lowPriorityMessages,
                urgency: .low,
                delay: 14
            )
        }
        .onAppear {
            messageManager.startFloating()
        }
        .onDisappear {
            messageManager.stopFloating()
        }
    }
}

// MARK: - Floating Message Row
struct FloatingMessageRow: View {
    let messages: [FloatingMessageData]
    let urgency: MessageUrgency
    let delay: Double
    
    @State private var offset: CGFloat = UIScreen.main.bounds.width
    @State private var currentIndex = 0
    @State private var isActive = false
    
    var body: some View {
        HStack(spacing: 20) {
            if !messages.isEmpty {
                SimpleFloatingBubble(
                    message: messages[currentIndex],
                    isVisible: isActive
                )
            }
        }
        .offset(x: offset)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            isActive = true
            startScrollCycle()
        }
    }
    
    private func startScrollCycle() {
        // Start scrolling
        withAnimation(.linear(duration: urgency.scrollDuration)) {
            offset = -UIScreen.main.bounds.width * 1.2
        }
        
        // Handle end behavior
        DispatchQueue.main.asyncAfter(deadline: .now() + urgency.scrollDuration) {
            if urgency.shouldRepeat {
                // Pause then repeat with next message
                DispatchQueue.main.asyncAfter(deadline: .now() + urgency.pauseDuration) {
                    currentIndex = (currentIndex + 1) % messages.count
                    offset = UIScreen.main.bounds.width
                    startScrollCycle()
                }
            } else {
                // Disappear
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = false
                }
            }
        }
    }
}

// MARK: - Simple Floating Message Bubble
struct SimpleFloatingBubble: View {
    let message: FloatingMessageData
    let isVisible: Bool
    
    var body: some View {
        Text(message.text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(message.urgency.textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(message.urgency.backgroundColor)
                    .opacity(0.85)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(message.urgency.borderColor, lineWidth: message.urgency.borderWidth)
            )
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .opacity(isVisible ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

// MARK: - Message Manager (Fixed)
class FloatingMessageManager: ObservableObject {
    @Published var highPriorityMessages: [FloatingMessageData] = []
    @Published var mediumPriorityMessages: [FloatingMessageData] = []
    @Published var lowPriorityMessages: [FloatingMessageData] = []
    
    private var timer: Timer?
    
    // Standard initializer - no override needed
    init() {
        loadInitialMessages()
    }
    
    func startFloating() {
        startMessageRotation()
    }
    
    func stopFloating() {
        timer?.invalidate()
        timer = nil
    }
    
    private func loadInitialMessages() {
        highPriorityMessages = [
            FloatingMessageData(text: "Breaking: Market update", urgency: .high),
            FloatingMessageData(text: "Important: Meeting in 10 min", urgency: .high),
            FloatingMessageData(text: "Alert: Battery low", urgency: .high)
        ]
        
        mediumPriorityMessages = [
            FloatingMessageData(text: "Your paragraph text", urgency: .medium),
            FloatingMessageData(text: "Slow scrolling updates", urgency: .medium),
            FloatingMessageData(text: "Calendar sync complete", urgency: .medium)
        ]
        
        lowPriorityMessages = [
            FloatingMessageData(text: "motivational quotes", urgency: .low),
            FloatingMessageData(text: "Weather: 72°F sunny", urgency: .low),
            FloatingMessageData(text: "Tip: Stay hydrated", urgency: .low)
        ]
    }
    
    private func startMessageRotation() {
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshMessages()
        }
    }
    
    private func refreshMessages() {
        // Add new messages or rotate existing ones
        // This is where you'd integrate with your AI system
    }
    
    // MARK: - Public Methods for Integration
    
    func addHighPriorityMessage(_ text: String) {
        let message = FloatingMessageData(text: text, urgency: .high)
        highPriorityMessages.append(message)
    }
    
    func addMediumPriorityMessage(_ text: String) {
        let message = FloatingMessageData(text: text, urgency: .medium)
        mediumPriorityMessages.append(message)
    }
    
    func addLowPriorityMessage(_ text: String) {
        let message = FloatingMessageData(text: text, urgency: .low)
        lowPriorityMessages.append(message)
    }
    
    // Integration with MariaBrain
    func updateFromBrain(_ brain: MariaBrain) {
        // Get context from brain
        let context = brain.getCurrentContext()
        
        // Update messages based on context
        switch context.situational.type {
        case .crisis:
            addHighPriorityMessage("⚠️ \(context.situational.description)")
        case .mealTime:
            addMediumPriorityMessage("🍽️ Time for a break")
        case .workFocus:
            addLowPriorityMessage("💪 Stay focused")
        default:
            break
        }
    }
}

// MARK: - Message Data Models
struct FloatingMessageData: Identifiable {
    let id = UUID()
    let text: String
    let urgency: MessageUrgency
    let timestamp = Date()
}

enum MessageUrgency {
    case high, medium, low
    
    var scrollDuration: Double {
        switch self {
        case .high: return 8.0
        case .medium: return 12.0
        case .low: return 16.0
        }
    }
    
    var pauseDuration: Double {
        switch self {
        case .high: return 2.0
        case .medium: return 4.0
        case .low: return 8.0
        }
    }
    
    var shouldRepeat: Bool {
        switch self {
        case .high: return true
        case .medium: return true
        case .low: return false
        }
    }
    
    var textColor: Color {
        switch self {
        case .high: return .red
        case .medium: return .primary
        case .low: return .secondary
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .high: return Color.red.opacity(0.1)
        case .medium: return Color(UIColor.systemBackground)
        case .low: return Color.gray.opacity(0.05)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .high: return .red.opacity(0.3)
        case .medium: return .primary.opacity(0.08)
        case .low: return .clear
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .high: return 1.0
        case .medium: return 0.5
        case .low: return 0.0
        }
    }
}

// MARK: - Preview
struct MultiRowFloatingMessages_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                MultiRowFloatingMessages()
                    .padding(.bottom, 50)
            }
        }
        .previewDisplayName("Multi-Row Messages")
    }
}
