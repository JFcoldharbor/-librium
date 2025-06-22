import SwiftUI

// MARK: - Clean Conversation View (Plug Hub Only)
struct CleanConversationView: View {
    // Simple state
    @State private var currentMessage = "How can I help you today?"
    @State private var isListening = false
    @State private var isProcessing = false
    @State private var showInfoBox = false
    @State private var infoBoxMessage = "Welcome to FINALE"
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Main conversation interface
            conversationInterface
            
            // Altering Info Box (conditional)
            if showInfoBox {
                infoBoxOverlay
            }
            
            // Floating messages (always visible)
            floatingMessagesOverlay
        }
        .onAppear {
            // Show welcome info box after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showWelcomeInfoBox()
            }
        }
    }
    
    // MARK: - Main Interface
    
    private var conversationInterface: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Message box hovering above orb
            messageBox
                .padding(.bottom, 60)
            
            // Interactive orb - centered
            interactiveOrb
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var messageBox: some View {
        Text(currentMessage)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(getMessageColor())
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(getMessageBackground())
                    .opacity(0.85)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            .animation(.easeInOut(duration: 0.3), value: currentMessage)
    }
    
    private var interactiveOrb: some View {
        StandaloneBlueOrb(isSpeaking: isListening || isProcessing)
            .frame(width: 200, height: 200)
            .onLongPressGesture(
                minimumDuration: 0,
                pressing: { pressing in
                    if pressing {
                        startListening()
                    } else {
                        stopListening()
                    }
                }
            ) {
                // Long press action
            }
    }
    
    // MARK: - Info Box Overlay
    
    private var infoBoxOverlay: some View {
        VStack {
            HStack {
                SimpleInfoBox(
                    title: "TEXT OR NEWS SCROLLS",
                    subtitle: "DATE TIME",
                    message: infoBoxMessage,
                    onDismiss: {
                        hideInfoBox()
                    }
                )
                .padding(.top, 60) // Account for notch/status bar
                .padding(.leading, 20)
                
                Spacer()
            }
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    // MARK: - Floating Messages Overlay
    
    private var floatingMessagesOverlay: some View {
        VStack {
            Spacer()
            
            // Clean, separated multi-row floating messages
            MultiRowFloatingMessages()
                .padding(.bottom, 50)
        }
    }
    
    // MARK: - Actions
    
    private func startListening() {
        isListening = true
        currentMessage = "••• Listening •••"
        
        // Simulate speech recognition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isListening = false
            isProcessing = true
            currentMessage = "⟳ Understanding..."
            
            // Simulate AI processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isProcessing = false
                showAIResponse()
            }
        }
    }
    
    private func stopListening() {
        // Handle end of speech input
    }
    
    private func showAIResponse() {
        let responses = [
            "I'm here to help you with anything you need.",
            "What would you like to know today?",
            "I can assist with questions, reminders, and more.",
            "How can I make your day better?"
        ]
        
        if let response = responses.randomElement() {
            currentMessage = response
            
            // Show in info box if longer response
            if response.count > 30 {
                showInfoBox(message: response, title: "MARIA RESPONDS")
            }
        }
    }
    
    private func showWelcomeInfoBox() {
        showInfoBox(message: "Your AI life operating system is ready", title: "WELCOME TO FINALE")
    }
    
    private func showInfoBox(message: String, title: String = "IMPORTANT UPDATE") {
        infoBoxMessage = message
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showInfoBox = true
        }
        
        // Auto-hide after 6 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            hideInfoBox()
        }
    }
    
    private func hideInfoBox() {
        withAnimation(.easeOut(duration: 0.4)) {
            showInfoBox = false
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMessageColor() -> Color {
        if isListening {
            return .red
        } else if isProcessing {
            return .orange
        } else {
            return .primary
        }
    }
    
    private func getMessageBackground() -> Color {
        if isListening {
            return Color.red.opacity(0.25)
        } else if isProcessing {
            return Color.purple.opacity(0.25)
        } else {
            return Color(UIColor.systemBackground).opacity(0.95)
        }
    }
}

// MARK: - Standalone Blue Orb (No Dependencies)
struct StandaloneBlueOrb: View {
    let isSpeaking: Bool
    
    @State private var waveScale: CGFloat = 1.0
    @State private var waveOpacity: Double = 0.0
    @State private var glowIntensity: Double = 0.8
    @State private var idlePulse: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.cyan.opacity(0.2),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 40,
                        endRadius: 120
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 20)
                .scaleEffect(isSpeaking ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5), value: isSpeaking)
            
            // Speaking wave rings
            if isSpeaking {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.cyan.opacity(0.6),
                                    Color.blue.opacity(0.3)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 150 + CGFloat(index * 40),
                               height: 150 + CGFloat(index * 40))
                        .scaleEffect(waveScale)
                        .opacity(waveOpacity)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.2),
                            value: waveScale
                        )
                }
            }
            
            // Main orb
            ZStack {
                // Base sphere
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 0.0, green: 0.5, blue: 1.0), location: 0.0),
                                .init(color: Color(red: 0.0, green: 0.3, blue: 0.8), location: 0.6),
                                .init(color: Color(red: 0.0, green: 0.1, blue: 0.4), location: 1.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                // Highlight
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.8), location: 0.0),
                                .init(color: Color.white.opacity(0.3), location: 0.3),
                                .init(color: Color.clear, location: 0.7)
                            ]),
                            center: UnitPoint(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 140, height: 140)
                    .offset(x: -10, y: -10)
            }
            .scaleEffect(isSpeaking ? 1.04 : idlePulse)
            .animation(
                isSpeaking ?
                Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true) :
                Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                value: isSpeaking
            )
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                idlePulse = 1.02
            }
        }
        .onChange(of: isSpeaking) { _, newValue in
            if newValue {
                withAnimation {
                    waveOpacity = 1.0
                }
                withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    waveScale = 1.35
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    glowIntensity = 1.0
                }
            } else {
                withAnimation {
                    waveOpacity = 0.0
                    waveScale = 1.0
                    glowIntensity = 0.8
                }
            }
        }
    }
}

// MARK: - Simple Info Box (No Dependencies)
struct SimpleInfoBox: View {
    let title: String
    let subtitle: String
    let message: String
    let onDismiss: () -> Void
    
    @State private var animateIn = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .tracking(0.5)
            
            // Main Title
            VStack(alignment: .leading, spacing: 2) {
                Text("ALTERING")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.primary)
                
                Text("INFO BOX")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.primary)
            }
            
            // Subtitle
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .tracking(0.5)
            
            Spacer()
                .frame(height: 4)
            
            // Message
            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color(UIColor.systemBackground))
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                )
        )
        .frame(width: 280, height: 160)
        .scaleEffect(animateIn ? 1.0 : 0.95)
        .opacity(animateIn ? 1.0 : 0.0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateIn)
        .onAppear {
            animateIn = true
        }
        .onTapGesture {
            onDismiss()
        }
    }
}

// MARK: - Preview
struct CleanConversationView_Previews: PreviewProvider {
    static var previews: some View {
        CleanConversationView()
            .previewDisplayName("Clean Conversation Hub")
    }
}
