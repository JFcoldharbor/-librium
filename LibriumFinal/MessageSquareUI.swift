import SwiftUI

// MARK: - Message Square UI
struct MessageSquareUI: View {
    @ObservedObject var uxManager: MessageSquareUX
    @ObservedObject var stateManager: ConversationStateManager
    
    // UI State
    @State private var isPressed = false
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Message Square
            messageSquare
                .gesture(tapGestures)
                .gesture(dragGesture)
            
            // History overlay
            if uxManager.isShowingHistory {
                MessageHistoryUI(
                    messages: uxManager.getDisplayHistory(),
                    onDismiss: {
                        uxManager.dismissHistory()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: uxManager.isShowingHistory)
    }
    
    // MARK: - Message Square View
    
    private var messageSquare: some View {
        HStack(spacing: 0) {
            // Message content
            Text(uxManager.getDisplayText())
                .font(.system(size: 15))
                .foregroundColor(textColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            // Truncation indicator
            if uxManager.isMessageTruncated {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 280)
        .background(backgroundView)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .offset(dragOffset)
        .opacity(uxManager.isShowingHistory ? 0.3 : 1.0)
    }
    
    // MARK: - Visual Components
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Colors
    
    private var textColor: Color {
        let metadata = uxManager.getMessageMetadata()
        switch metadata.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .normal:
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        let message = stateManager.currentMessage
        switch message.state {
        case .listening:
            return Color.red.opacity(0.1)
        case .processing:
            return Color.purple.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .success:
            return Color.green.opacity(0.1)
        default:
            return Color(UIColor.secondarySystemBackground).opacity(0.8)
        }
    }
    
    private var borderColor: Color {
        Color.primary.opacity(0.1)
    }
    
    private var shadowColor: Color {
        Color.black.opacity(0.1)
    }
    
    // MARK: - Gestures
    
    private var tapGestures: some Gesture {
        SimultaneousGesture(
            TapGesture(count: 2)
                .onEnded { _ in
                    uxManager.onDoubleTap?()
                },
            TapGesture(count: 1)
                .onEnded { _ in
                    uxManager.handleTap()
                }
        )
        .simultaneously(with:
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    uxManager.handleLongPress()
                    
                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
        )
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Visual feedback during drag
                dragOffset = value.translation
                
                // Detect swipe direction
                if abs(value.translation.height) > 30 {
                    withAnimation(.spring()) {
                        isPressed = true
                    }
                }
            }
            .onEnded { value in
                // Calculate velocity from translation
                let velocity = CGPoint(
                    x: value.translation.width,
                    y: value.translation.height
                )
                let translation = CGPoint(
                    x: value.translation.width,
                    y: value.translation.height
                )
                
                let gesture = uxManager.interpretGesture(
                    velocity: velocity,
                    translation: translation
                )
                
                // Handle gesture
                switch gesture {
                case .swipeUp:
                    uxManager.handleSwipeUp()
                case .swipeDown:
                    uxManager.handleSwipeDown()
                default:
                    break
                }
                
                // Reset visual state
                withAnimation(.spring()) {
                    dragOffset = .zero
                    isPressed = false
                }
            }
    }
}

// MARK: - Message History UI
struct MessageHistoryUI: View {
    let messages: [ConversationMessage]
    let onDismiss: () -> Void
    
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            historyHeader
            
            // Search bar
            searchBar
            
            // Messages
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredMessages) { message in
                        MessageRowUI(message: message)
                    }
                }
                .padding()
            }
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }
    
    private var historyHeader: some View {
        HStack {
            Text("History")
                .font(.headline)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search messages", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var filteredMessages: [ConversationMessage] {
        if searchText.isEmpty {
            return messages
        } else {
            return messages.filter { message in
                message.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Message Row UI
struct MessageRowUI: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Speaker indicator
            speakerView
            
            // Message content
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                
                Text(message.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var speakerView: some View {
        Circle()
            .fill(speakerColor)
            .frame(width: 8, height: 8)
            .padding(.top, 6)
    }
    
    private var speakerColor: Color {
        switch message.type {
        case .user:
            return .blue
        case .assistant:
            return .green
        case .system:
            return .orange
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
struct MessageSquareUI_Previews: PreviewProvider {
    static var previews: some View {
        // Create test instances
        let stateManager = ConversationStateManager()
        let uxManager = MessageSquareUX(conversationStateManager: stateManager)
        
        VStack {
            Spacer()
            
            MessageSquareUI(
                uxManager: uxManager,
                stateManager: stateManager
            )
            
            Spacer()
            
            // Test controls
            VStack(spacing: 20) {
                Button("Show Listening") {
                    stateManager.startListening()
                }
                
                Button("Show Response") {
                    stateManager.showResponse("Hello! How can I help you today?")
                }
                
                Button("Show Error") {
                    stateManager.showError("Sorry, I couldn't process that.")
                }
                
                Button("Toggle History") {
                    if uxManager.isShowingHistory {
                        uxManager.dismissHistory()
                    } else {
                        uxManager.showHistory()
                    }
                }
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - Preview
    struct MessageSquareUI_Previews: PreviewProvider {
        static var previews: some View {
            // Create test instances
            let stateManager = ConversationStateManager()
            let uxManager = MessageSquareUX(conversationStateManager: stateManager)
            
            VStack {
                Spacer()
                
                MessageSquareUI(
                    uxManager: uxManager,
                    stateManager: stateManager
                )
                
                Spacer()
                
                // Test controls
                VStack(spacing: 20) {
                    Button("Show Listening") {
                        stateManager.startListening()
                    }
                    
                    Button("Show Response") {
                        stateManager.showResponse("Hello! How can I help you today?")
                    }
                    
                    Button("Show Error") {
                        stateManager.showError("Sorry, I couldn't process that.")
                    }
                    
                    Button("Toggle History") {
                        if uxManager.isShowingHistory {
                            uxManager.dismissHistory()
                        } else {
                            uxManager.showHistory()
                        }
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.1))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Message Square")
        }
    }
}
