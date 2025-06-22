import SwiftUI

// MARK: - Pure SwiftUI Blue Orb
struct BlueOrbSwiftUI: View {
    var isSpeaking: Bool = false
    
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
            
            // Main orb with 3D-like gradient
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
                
                // Highlight for 3D effect
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
                
                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.cyan.opacity(glowIntensity),
                                Color.blue.opacity(glowIntensity * 0.5),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)
            }
            .scaleEffect(isSpeaking ? 1.04 : idlePulse)
            .animation(
                isSpeaking ?
                Animation.easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true) :
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                value: isSpeaking
            )
        }
        .onAppear {
            // Start idle pulse
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                idlePulse = 1.02
            }
        }
        .onChange(of: isSpeaking) { _, newValue in
            if newValue {
                // Start wave animation
                withAnimation {
                    waveOpacity = 1.0
                }
                withAnimation(
                    Animation.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    waveScale = 1.35
                }
                // Increase glow
                withAnimation(.easeInOut(duration: 0.3)) {
                    glowIntensity = 1.0
                }
            } else {
                // Stop wave animation
                withAnimation {
                    waveOpacity = 0.0
                    waveScale = 1.0
                    glowIntensity = 0.8
                }
            }
        }
    }
}

// MARK: - Test View
struct BlueOrbSwiftUITest: View {
    @State private var isSpeaking = false
    
    var body: some View {
        ZStack {
            // Background
            Color(white: 0.1)
                .ignoresSafeArea()
            
            VStack(spacing: 50) {
                Spacer()
                
                // The orb
       BlueOrbSwiftUI(isSpeaking: isSpeaking)
                    .frame(width: 300, height: 300)
                
                Spacer()
                
                // Toggle button
                Button(action: {
                    isSpeaking.toggle()
                }) {
                    HStack(spacing: 15) {
                        Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.fill")
                            .font(.system(size: 24))
                        
                        Text(isSpeaking ? "Stop Speaking" : "Start Speaking")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 250, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(isSpeaking ? Color.red : Color.blue)
                    )
                }
                
                // Status text
                Text(isSpeaking ? "🎤 Speaking..." : "🔇 Silent")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                    .frame(height: 100)
            }
        }
    }
}

