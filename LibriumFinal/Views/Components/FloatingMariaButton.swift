import SwiftUI

struct FloatingMariaOrb: View {
    @ObservedObject private var viewModel = QuickMariaViewModel.shared
    @State private var pulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTranscript {
                transcriptBubble
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .bottomLeading)),
                        removal: .opacity
                    ))
            }

            Button(action: { viewModel.tapOrb() }) {
                orbVisual
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showTranscript)
        .animation(.easeInOut(duration: 0.2), value: stateKey)
    }

    // MARK: - Orb visual

    private var orbVisual: some View {
        ZStack {
            // Outer halo (only while listening / speaking)
            if isActive {
                Circle()
                    .stroke(haloTint.opacity(0.45), lineWidth: 1)
                    .frame(width: 64, height: 64)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
                    .onAppear { pulse = true }
                    .onDisappear { pulse = false }
            }

            Circle()
                .fill(orbGradient)
                .frame(width: 48, height: 48)
                .shadow(color: shadowTint.opacity(isActive ? 0.55 : 0.4), radius: isActive ? 18 : 12, y: 4)

            iconForState
        }
    }

    private var orbGradient: RadialGradient {
        switch viewModel.voiceState {
        case .listening:
            return RadialGradient(
                colors: [Color.green, Color.green.opacity(0.55), Color.green.opacity(0.25)],
                center: .center, startRadius: 0, endRadius: 28
            )
        case .processing:
            return RadialGradient(
                colors: [Color(red: 0.65, green: 0.45, blue: 1.0), Color(red: 0.45, green: 0.30, blue: 0.85).opacity(0.5)],
                center: .center, startRadius: 0, endRadius: 28
            )
        case .speaking:
            return RadialGradient(
                colors: [EquilibriumColor.accent, EquilibriumColor.accent.opacity(0.55), EquilibriumColor.accent.opacity(0.20)],
                center: .center, startRadius: 0, endRadius: 28
            )
        case .error:
            return RadialGradient(
                colors: [Color.red.opacity(0.85), Color.red.opacity(0.4)],
                center: .center, startRadius: 0, endRadius: 28
            )
        case .idle:
            return RadialGradient(
                colors: [EquilibriumColor.accent.opacity(0.85), EquilibriumColor.accent.opacity(0.50), EquilibriumColor.accent.opacity(0.20)],
                center: .center, startRadius: 0, endRadius: 24
            )
        }
    }

    private var shadowTint: Color {
        switch viewModel.voiceState {
        case .listening: return .green
        case .processing: return Color(red: 0.65, green: 0.45, blue: 1.0)
        case .speaking, .idle: return EquilibriumColor.accent
        case .error: return .red
        }
    }

    private var haloTint: Color {
        shadowTint
    }

    private var isActive: Bool {
        switch viewModel.voiceState {
        case .listening, .processing, .speaking: return true
        default: return false
        }
    }

    @ViewBuilder
    private var iconForState: some View {
        switch viewModel.voiceState {
        case .listening:
            Image(systemName: "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        case .processing:
            ProgressView()
                .tint(.white)
                .scaleEffect(0.7)
        case .speaking:
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        case .error:
            Image(systemName: "exclamationmark")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white)
        case .idle:
            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Transcript bubble

    private var showTranscript: Bool {
        switch viewModel.voiceState {
        case .listening, .processing, .speaking, .error: return true
        case .idle: return false
        }
    }

    private var transcriptText: String {
        switch viewModel.voiceState {
        case .listening:
            return viewModel.transcript.isEmpty ? "Listening…" : viewModel.transcript
        case .processing:
            return "Thinking…"
        case .speaking(let response):
            return response
        case .error(let message):
            return message
        case .idle:
            return ""
        }
    }

    private var transcriptBubble: some View {
        Text(transcriptText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(EquilibriumColor.primaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(haloTint.opacity(0.45), lineWidth: 0.5)
                    )
            )
            .frame(maxWidth: 240, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - State key for animation

    private var stateKey: String {
        switch viewModel.voiceState {
        case .idle: return "idle"
        case .listening: return "listening"
        case .processing: return "processing"
        case .speaking: return "speaking"
        case .error: return "error"
        }
    }
}
