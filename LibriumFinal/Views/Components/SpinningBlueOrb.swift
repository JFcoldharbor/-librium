import SwiftUI

struct SpinningBlueOrb: View {
    let state: VoiceState

    @State private var waveScale: CGFloat = 1.0
    @State private var waveOpacity: Double = 0.0
    @State private var glowIntensity: Double = 0.6
    @State private var idlePulse: CGFloat = 1.0

    private var isActive: Bool {
        switch state {
        case .listening, .processing, .speaking:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            outerGlow

            if isActive {
                ForEach(0..<3) { index in
                    waveRing(index: index)
                }
            }

            mainOrb
                .scaleEffect(isActive ? 1.04 : idlePulse)
                .animation(
                    isActive
                        ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                        : .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isActive
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                idlePulse = 1.02
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                withAnimation { waveOpacity = 1.0 }
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    waveScale = 1.35
                }
                withAnimation(.easeInOut(duration: 0.3)) { glowIntensity = 1.0 }
            } else {
                withAnimation {
                    waveOpacity = 0.0
                    waveScale = 1.0
                    glowIntensity = 0.6
                }
            }
        }
    }

    private var outerGlow: some View {
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
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.5), value: isActive)
    }

    private func waveRing(index: Int) -> some View {
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
            .frame(
                width: 150 + CGFloat(index * 40),
                height: 150 + CGFloat(index * 40)
            )
            .scaleEffect(waveScale)
            .opacity(waveOpacity)
            .animation(
                Animation.easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                    .delay(Double(index) * 0.2),
                value: waveScale
            )
    }

    private var mainOrb: some View {
        ZStack {
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
    }
}
