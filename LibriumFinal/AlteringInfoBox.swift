//
//  AlteringInfoBox.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


import SwiftUI

// MARK: - Altering Info Box
struct AlteringInfoBox: View {
    let title: String
    let subtitle: String
    let message: String
    let isVisible: Bool
    
    @State private var animateIn = false
    
    init(title: String = "TEXT OR NEWS SCROLLS", subtitle: String = "DATE TIME", message: String = "motivational and inspirational quotes", isVisible: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.message = message
        self.isVisible = isVisible
    }
    
    var body: some View {
        VStack {
            if isVisible {
                // Info Box Container
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    Text(title)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.primary)
                        .tracking(0.5)
                    
                    // Main Title
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ALTERING")
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundColor(.primary)
                        
                        Text("INFO BOX")
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundColor(.primary)
                    }
                    
                    // Subtitle
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .default))
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
                    // Handle tap to dismiss or expand
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - Altering Info Box Manager
class AlteringInfoBoxManager: ObservableObject {
    @Published var isVisible = false
    @Published var currentTitle = "TEXT OR NEWS SCROLLS"
    @Published var currentSubtitle = "DATE TIME"
    @Published var currentMessage = "motivational and inspirational quotes"
    
    private var hideTimer: Timer?
    
    // Show important update
    func showImportantUpdate(title: String = "IMPORTANT UPDATE", subtitle: String? = nil, message: String) {
        currentTitle = title
        currentSubtitle = subtitle ?? getCurrentTimeString()
        currentMessage = message
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isVisible = true
        }
        
        // Auto-hide after 8 seconds
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.hideInfoBox()
        }
    }
    
    // Show news update
    func showNewsUpdate(message: String) {
        showImportantUpdate(title: "BREAKING NEWS", message: message)
    }
    
    // Show system alert
    func showSystemAlert(message: String) {
        showImportantUpdate(title: "SYSTEM ALERT", message: message)
    }
    
    // Show motivational quote
    func showQuote(quote: String) {
        showImportantUpdate(title: "DAILY INSPIRATION", message: quote)
    }
    
    // Hide the info box
    func hideInfoBox() {
        withAnimation(.easeOut(duration: 0.4)) {
            isVisible = false
        }
        hideTimer?.invalidate()
    }
    
    // Toggle visibility
    func toggleVisibility() {
        if isVisible {
            hideInfoBox()
        } else {
            showImportantUpdate(message: currentMessage)
        }
    }
    
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, h:mm a"
        return formatter.string(from: Date()).uppercased()
    }
}

// MARK: - Enhanced Version with Animation Types
struct AnimatedAlteringInfoBox: View {
    @ObservedObject var manager: AlteringInfoBoxManager
    
    var body: some View {
        VStack {
            if manager.isVisible {
                AlteringInfoBox(
                    title: manager.currentTitle,
                    subtitle: manager.currentSubtitle,
                    message: manager.currentMessage,
                    isVisible: manager.isVisible
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            Spacer()
        }
    }
}

// MARK: - Integration with ConversationView
extension AlteringInfoBoxManager {
    // Integration methods for your conversation system
    
    func showAIResponse(response: String) {
        showImportantUpdate(title: "MARIA RESPONDS", message: response)
    }
    
    func showCommandResult(command: String, success: Bool) {
        let title = success ? "COMMAND EXECUTED" : "COMMAND FAILED"
        showImportantUpdate(title: title, message: command)
    }
    
    func showSpeechError(error: String) {
        showImportantUpdate(title: "SPEECH ERROR", message: error)
    }
    
    func showWelcomeMessage() {
        showImportantUpdate(
            title: "WELCOME TO FINALE",
            message: "Your AI life operating system is ready"
        )
    }
    
    // Predefined messages for common scenarios
    func showRandomQuote() {
        let quotes = [
            "\"The future belongs to those who believe in the beauty of their dreams.\"",
            "\"Success is not final, failure is not fatal: it is the courage to continue that counts.\"",
            "\"The only impossible journey is the one you never begin.\"",
            "\"Innovation distinguishes between a leader and a follower.\"",
            "\"Your limitation—it's only your imagination.\""
        ]
        
        if let randomQuote = quotes.randomElement() {
            showQuote(quote: randomQuote)
        }
    }
}

// MARK: - Preset Message Types
enum InfoBoxType {
    case important
    case news
    case quote
    case system
    case response
    case error
    
    var defaultTitle: String {
        switch self {
        case .important:
            return "IMPORTANT UPDATE"
        case .news:
            return "BREAKING NEWS"
        case .quote:
            return "DAILY INSPIRATION"
        case .system:
            return "SYSTEM ALERT"
        case .response:
            return "MARIA RESPONDS"
        case .error:
            return "ATTENTION REQUIRED"
        }
    }
}

// MARK: - Preview
struct AlteringInfoBox_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack {
                    AlteringInfoBox()
                    
                    Spacer()
                    
                    // Simulate orb
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 150, height: 150)
                    
                    Spacer()
                }
            }
            .previewDisplayName("Default Info Box")
            
            // With custom message
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack {
                    AlteringInfoBox(
                        title: "BREAKING NEWS",
                        subtitle: "DEC 21, 2:45 PM",
                        message: "AI breakthrough announced: New language model achieves human-level reasoning"
                    )
                    
                    Spacer()
                }
            }
            .previewDisplayName("News Update")
            
            // Manager test
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                AnimatedAlteringInfoBox(manager: AlteringInfoBoxManager())
            }
            .previewDisplayName("Animated Version")
        }
    }
}