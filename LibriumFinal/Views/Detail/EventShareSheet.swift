import CoreImage.CIFilterBuiltins
import SwiftUI
#if !os(macOS)
import UIKit
#endif

struct EventShareSheet: View {
    let event: NetworkEvent

    @Environment(\.dismiss) private var dismiss
    @State private var copied: Bool = false
    @State private var showNFCWrite: Bool = false
    @State private var nfcStatus: NFCStatus = .idle
    @State private var nfcError: String?

    enum NFCStatus {
        case idle, writing, success, failed
    }

    private var url: URL {
        NetworkEventEncoder.shareURL(for: event)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 22) {
                        Spacer().frame(height: 8)

                        eventHeader

                        qrTile

                        urlRow

                        #if !os(macOS)
                        shareLink
                        #endif

                        nfcWriteSection

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Share event")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .alert("Couldn't write tag", isPresented: Binding(
                get: { nfcError != nil },
                set: { if !$0 { nfcError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(nfcError ?? "")
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

    private var eventHeader: some View {
        VStack(spacing: 4) {
            Text(event.name)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let venue = event.venue {
                Text(venue)
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        }
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
            }
            #endif
        }
        .frame(width: 240, height: 240)
    }

    private var urlRow: some View {
        Button {
            #if !os(macOS)
            UIPasteboard.general.string = url.absoluteString
            #endif
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                copied = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: copied ? "checkmark.circle.fill" : "link")
                    .foregroundColor(EquilibriumColor.CardTint.network)
                Text(copied ? "Copied" : url.absoluteString)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(copied ? EquilibriumColor.CardTint.network : EquilibriumColor.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(EquilibriumColor.primaryText.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    #if !os(macOS)
    private var shareLink: some View {
        ShareLink(item: url, subject: Text(event.name), message: Text("Join me at \(event.name).")) {
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

    @ViewBuilder
    private var nfcWriteSection: some View {
        if NFCService.isAvailable {
            Button {
                Task { await writeNFCTag() }
            } label: {
                HStack(spacing: 8) {
                    if nfcStatus == .writing {
                        ProgressView().tint(EquilibriumColor.CardTint.network)
                    } else if nfcStatus == .success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(EquilibriumColor.CardTint.health)
                    } else {
                        Image(systemName: "wave.3.right")
                    }
                    Text(nfcButtonLabel)
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(EquilibriumColor.CardTint.network.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(EquilibriumColor.CardTint.network.opacity(0.30), lineWidth: 0.5)
                        )
                )
                .foregroundColor(EquilibriumColor.CardTint.network)
            }
            .disabled(nfcStatus == .writing)
        }
    }

    private var nfcButtonLabel: String {
        switch nfcStatus {
        case .idle: return "Write to NFC tag"
        case .writing: return "Hold tag near phone…"
        case .success: return "Written"
        case .failed: return "Write to NFC tag"
        }
    }

    private func writeNFCTag() async {
        nfcStatus = .writing
        let result = await NFCService.shared.writeVCard(url.absoluteString)
        switch result {
        case .success:
            nfcStatus = .success
        case .failure(let error):
            nfcStatus = .failed
            nfcError = error.errorDescription
        }
    }

    #if !os(macOS)
    private var qrImage: UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(url.absoluteString.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif
}
