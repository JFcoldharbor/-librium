import CoreImage.CIFilterBuiltins
import SwiftUI
#if !os(macOS)
import UIKit
#endif

struct ShareMyCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileService = UserProfileService.shared

    @State private var showProfileEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if profileService.profile.hasMinimumFields {
                    cardLayout
                } else {
                    setupPrompt
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Share my card")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfileEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(EquilibriumColor.CardTint.network)
                    }
                }
            }
            .sheet(isPresented: $showProfileEditor) {
                UserProfileSheet()
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.30),
                    EquilibriumColor.CardTint.network.opacity(0.06),
                    EquilibriumColor.background
                ],
                center: .center,
                startRadius: 60,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var cardLayout: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 8)

            Text("Tap to swap. Scan, share, or AirDrop.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)

            qrTile

            identityBlock

            #if !os(macOS)
            shareButton
            #endif

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var qrTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: EquilibriumColor.CardTint.network.opacity(0.40), radius: 24, y: 8)

            #if !os(macOS)
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(20)
            } else {
                Text("Could not render QR")
                    .foregroundColor(.black)
            }
            #else
            Text("QR preview unavailable on macOS")
                .foregroundColor(.black)
                .padding()
            #endif
        }
        .frame(width: 260, height: 260)
    }

    private var identityBlock: some View {
        VStack(spacing: 4) {
            Text(profileService.profile.fullName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(EquilibriumColor.primaryText)
            if let subtitle = profileService.profile.displaySubtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Text(profileService.profile.email)
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    #if !os(macOS)
    private var shareButton: some View {
        ShareLink(item: vCardString) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Share via AirDrop / Messages")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(EquilibriumColor.CardTint.network)
            )
            .foregroundColor(.white)
        }
    }
    #endif

    private var setupPrompt: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundColor(EquilibriumColor.CardTint.network)
            Text("Set up your card first")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add your name and email so others can save your contact.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showProfileEditor = true
            } label: {
                Text("Set up card")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(EquilibriumColor.CardTint.network))
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }

    // MARK: - QR

    private var vCardString: String {
        VCardEncoder.encode(profileService.profile)
    }

    #if !os(macOS)
    private var qrImage: UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(vCardString.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif
}
