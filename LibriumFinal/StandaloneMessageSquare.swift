//
//  StandaloneMessageSquare.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


import SwiftUI

// MARK: - Standalone Message Square (No Dependencies)
struct StandaloneMessageSquare: View {
    @State private var message = "How can I help you today?"
    @State private var isListening = false
    @State private var isProcessing = false
    @State private var showHistory = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Message Square
            messageSquare
                .onTapGesture {
                    withAnimation {
                        showHistory.toggle()
                    }
                }
            
            Spacer()
            
            // Test Controls
            testControls
            
            Spacer()
        }
        .background(Color.gray.opacity(0.1))
        .ignoresSafeArea()
    }
    
    // MARK: - Message Square
    private var messageSquare: some View {
        Text(message)
            .font(.system(size: 15))
            .foregroundColor(textColor)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: 280)
            .background(backgroundView)
            .scaleEffect(showHistory ? 0.95 : 1.0)
            .opacity(showHistory ? 0.7 : 1.0)
            .animation(.spring(), value: showHistory)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Colors
    private var textColor: Color {
        if isListening {
            return .red
        } else if isProcessing {
            return .orange
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isListening {
            return Color.red.opacity(0.1)
        } else if isProcessing {
            return Color.purple.opacity(0.1)
        } else {
            return Color(UIColor.secondarySystemBackground).opacity(0.8)
        }
    }
    
    // MARK: - Test Controls
    private var testControls: some View {
        VStack(spacing: 15) {
            Button("Start Listening") {
                withAnimation {
                    message = "••• Listening •••"
                    isListening = true
                    isProcessing = false
                }
            }
            .buttonStyle(TestButtonStyle(color: .red))
            
            Button("Show Processing") {
                withAnimation {
                    message = "⟳ Understanding..."
                    isListening = false
                    isProcessing = true
                }
            }
            .buttonStyle(TestButtonStyle(color: .purple))
            
            Button("Show Response") {
                withAnimation {
                    message = "Hello! How can I help you today?"
                    isListening = false
                    isProcessing = false
                }
            }
            .buttonStyle(TestButtonStyle(color: .green))
            
            Button("Show Error") {
                withAnimation {
                    message = "Sorry, I couldn't process that."
                    isListening = false
                    isProcessing = false
                }
            }
            .buttonStyle(TestButtonStyle(color: .red))
            
            Button("Toggle History") {
                withAnimation {
                    showHistory.toggle()
                }
            }
            .buttonStyle(TestButtonStyle(color: .blue))
        }
    }
}

// MARK: - Test Button Style
struct TestButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct StandaloneMessageSquare_Previews: PreviewProvider {
    static var previews: some View {
        StandaloneMessageSquare()
            .previewDisplayName("Message Square Test")
    }
}