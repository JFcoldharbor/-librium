import SwiftUI

struct NFCWriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileService = UserProfileService.shared

    @State private var status: Status = .ready
    @State private var errorMessage: String?

    enum Status {
        case ready, writing, success, failed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 22) {
                    Spacer().frame(height: 8)

                    if !profileService.profile.hasMinimumFields {
                        setupPrompt
                    } else {
                        instructions
                        writeIndicator
                        actionButton
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Write to NFC tag")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .alert("Couldn't write", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.28),
                    EquilibriumColor.CardTint.network.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .center,
                startRadius: 60,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var instructions: some View {
        VStack(spacing: 8) {
            Text("Write your card to an NFC tag")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.center)
            Text("Tap Begin, then hold the top of your iPhone against a writable NDEF tag (NTAG213/215/216 etc).")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    private var writeIndicator: some View {
        ZStack {
            Circle()
                .fill(EquilibriumColor.CardTint.network.opacity(0.16))
                .frame(width: 200, height: 200)
            Circle()
                .stroke(EquilibriumColor.CardTint.network.opacity(0.45), lineWidth: 1)
                .frame(width: 240, height: 240)
            iconForStatus
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var iconForStatus: some View {
        switch status {
        case .ready:
            Image(systemName: "wave.3.right")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(EquilibriumColor.CardTint.network)
        case .writing:
            ProgressView().tint(EquilibriumColor.CardTint.network).scaleEffect(1.6)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(EquilibriumColor.CardTint.health)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red.opacity(0.8))
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if !NFCService.isAvailable {
            VStack(spacing: 6) {
                Text("NFC not available")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("Requires iPhone 7 or later running iOS 13+.")
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        } else {
            Button {
                Task { await beginWrite() }
            } label: {
                Text(status == .success ? "Write again" : "Begin")
                    .font(.system(size: 15, weight: .heavy))
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(EquilibriumColor.CardTint.network)
                    )
                    .foregroundColor(.white)
            }
            .disabled(status == .writing)
        }
    }

    private var setupPrompt: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundColor(EquilibriumColor.CardTint.network)
            Text("Set up your card first")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Open Share my card to add your name and email.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func beginWrite() async {
        let payload = VCardEncoder.encode(profileService.profile)
        status = .writing
        let result = await NFCService.shared.writeVCard(payload)
        switch result {
        case .success:
            status = .success
        case .failure(let error):
            status = .failed
            errorMessage = error.errorDescription
        }
    }
}
