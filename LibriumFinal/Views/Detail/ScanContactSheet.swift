import SwiftUI
#if !os(macOS)
import AVFoundation
import UIKit
#endif

struct ScanContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var meetingService = MeetingCaptureService.shared
    @ObservedObject private var notesService = ContactNotesService.shared

    @State private var scannedPayload: String?
    @State private var parsedContact: VCardEncoder.ParsedContact?
    @State private var parsedEvent: NetworkEvent?
    @State private var capturedContext: MeetingContext?
    @State private var saving: Bool = false
    @State private var savedContactId: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if let parsed = parsedContact {
                    confirmView(parsed)
                } else if parsedEvent != nil {
                    eventTransitionView
                } else {
                    scannerView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text(toolbarTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .sheet(item: $parsedEvent) { event in
                NetworkEventDetailSheet(event: event, mode: .confirmScan)
                    .preferredColorScheme(.dark)
                    .onDisappear {
                        // After event sheet closes, dismiss the scanner sheet too
                        dismiss()
                    }
            }
            .onAppear {
                meetingService.requestPermissionIfNeeded()
            }
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var toolbarTitle: String {
        if parsedContact != nil { return "Save contact" }
        if parsedEvent != nil { return "Event found" }
        return "Scan a card"
    }

    private var eventTransitionView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundColor(EquilibriumColor.CardTint.network)
            Text("Event detected")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Confirm or cancel in the next sheet.")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.20),
                    EquilibriumColor.CardTint.network.opacity(0.04),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Scanner

    @ViewBuilder
    private var scannerView: some View {
        #if os(macOS)
        VStack(spacing: 12) {
            Spacer()
            Text("Camera scanning is iOS only.")
                .foregroundColor(EquilibriumColor.secondaryText)
            Spacer()
        }
        #else
        VStack(spacing: 16) {
            Spacer().frame(height: 8)
            Text("Point at a vCard QR code")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)

            ZStack {
                QRScannerView(
                    onScan: { payload in handleScan(payload) },
                    onError: { message in errorMessage = message }
                )
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(EquilibriumColor.CardTint.network.opacity(0.6), lineWidth: 2)
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 22))

            Text("Capturing your location and current event for the note.")
                .font(.system(size: 11))
                .foregroundColor(EquilibriumColor.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
        }
        #endif
    }

    // MARK: - Confirm

    private func confirmView(_ parsed: VCardEncoder.ParsedContact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                identityCard(parsed)

                if let context = capturedContext {
                    contextCard(context)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.mini).tint(EquilibriumColor.CardTint.network)
                        Text("Capturing meeting context…")
                            .font(.system(size: 12))
                            .foregroundColor(EquilibriumColor.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(EquilibriumColor.primaryText.opacity(0.04))
                    )
                }

                if savedContactId != nil {
                    savedConfirmation
                } else {
                    saveButton(parsed)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    private func identityCard(_ parsed: VCardEncoder.ParsedContact) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(parsed.fullName)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(EquilibriumColor.primaryText)
            if let role = parsed.jobTitle, let org = parsed.organization {
                Text("\(role) at \(org)")
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.secondaryText)
            } else if let role = parsed.jobTitle {
                Text(role)
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.secondaryText)
            } else if let org = parsed.organization {
                Text(org)
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            if let email = parsed.email {
                Text(email)
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            if let phone = parsed.phone {
                Text(phone)
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(EquilibriumColor.CardTint.network.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(EquilibriumColor.CardTint.network.opacity(0.30), lineWidth: 0.5)
                )
        )
    }

    private func contextCard(_ context: MeetingContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))
                Text("MEETING NOTE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
            }
            .foregroundColor(EquilibriumColor.CardTint.network)
            Text(context.noteLine)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func saveButton(_ parsed: VCardEncoder.ParsedContact) -> some View {
        Button {
            save(parsed)
        } label: {
            HStack(spacing: 8) {
                if saving {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(saving ? "Saving…" : "Add to contacts")
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
        .disabled(saving)
    }

    private var savedConfirmation: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(EquilibriumColor.CardTint.health)
            Text("Saved. Note attached.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(EquilibriumColor.CardTint.network)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.06))
        )
    }

    // MARK: - Actions

    private func handleScan(_ payload: String) {
        guard parsedContact == nil, parsedEvent == nil else { return }

        // 1. Event URL (https://.../e/{uuid}) — fetch from Firestore
        if let eventId = NetworkEventEncoder.parseEventId(fromString: payload) {
            scannedPayload = payload
            Task {
                if let local = NetworkEventService.shared.events.first(where: { $0.id == eventId }) {
                    parsedEvent = local
                    return
                }
                if let remote = await NetworkEventService.shared.pull(id: eventId) {
                    parsedEvent = remote
                } else {
                    errorMessage = "Event not found or not yet synced."
                }
            }
            return
        }

        // 2. Inline EQUEVENT:: JSON payload (legacy / offline)
        if NetworkEventEncoder.looksLikeEvent(payload),
           let event = NetworkEventEncoder.decode(payload) {
            scannedPayload = payload
            parsedEvent = event
            return
        }

        // 3. vCard contact
        if let parsed = VCardEncoder.decode(payload) {
            scannedPayload = payload
            parsedContact = parsed
            Task {
                capturedContext = await meetingService.captureContext()
            }
            return
        }

        errorMessage = "That QR code wasn't a contact or event."
    }

    private func save(_ parsed: VCardEncoder.ParsedContact) {
        saving = true
        let context = capturedContext
        let note = context?.noteLine
        Task {
            #if !os(macOS)
            let id = VCardEncoder.saveToContacts(parsed: parsed, meetingNote: note)
            #else
            let id: String? = nil
            #endif
            if let id = id {
                ContactsService.shared.invalidateIndex()
                if let note = note {
                    let entry = ContactNote(
                        contactId: id,
                        notes: note,
                        nextFollowUp: nil,
                        followUpReason: nil,
                        status: .active,
                        updatedAt: Date()
                    )
                    notesService.upsert(entry)
                }
                savedContactId = id
            } else {
                errorMessage = "iOS wouldn't save the contact. Make sure Equilibrium has Contacts access."
            }
            saving = false
        }
    }
}

// MARK: - QR scanner UIViewRepresentable

#if !os(macOS)
struct QRScannerView: UIViewRepresentable {
    let onScan: (String) -> Void
    let onError: ((String) -> Void)?

    init(onScan: @escaping (String) -> Void, onError: ((String) -> Void)? = nil) {
        self.onScan = onScan
        self.onError = onError
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        context.coordinator.attach(to: view, onScan: onScan, onError: onError)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private var session: AVCaptureSession?
        private weak var view: CameraPreviewView?
        private var onScan: ((String) -> Void)?
        private var onError: ((String) -> Void)?
        private var hasScanned = false
        private let sessionQueue = DispatchQueue(label: "equilibrium.qr.session")

        func attach(
            to view: CameraPreviewView,
            onScan: @escaping (String) -> Void,
            onError: ((String) -> Void)?
        ) {
            self.view = view
            self.onScan = onScan
            self.onError = onError

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                buildAndStartSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted {
                            self?.buildAndStartSession()
                        } else {
                            self?.onError?("Camera access denied. Enable it in Settings → Equilibrium.")
                        }
                    }
                }
            case .denied, .restricted:
                onError?("Camera access denied. Enable it in Settings → Equilibrium.")
            @unknown default:
                onError?("Camera unavailable.")
            }
        }

        private func buildAndStartSession() {
            guard let view = view else { return }

            let session = AVCaptureSession()
            self.session = session
            session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(for: .video) else {
                onError?("No camera found.")
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    onError?("Could not add camera input.")
                    return
                }
                session.addInput(input)
            } catch {
                onError?("Could not open camera: \(error.localizedDescription)")
                return
            }

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                onError?("Could not add metadata output.")
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            let supported = output.availableMetadataObjectTypes
            output.metadataObjectTypes = supported.contains(.qr) ? [.qr] : supported

            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            if let connection = view.previewLayer.connection,
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            sessionQueue.async {
                session.startRunning()
            }
        }

        func tearDown() {
            sessionQueue.async { [weak self] in
                self?.session?.stopRunning()
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned else { return }
            for object in metadataObjects {
                guard let readable = object as? AVMetadataMachineReadableCodeObject,
                      let value = readable.stringValue else { continue }
                hasScanned = true
                tearDown()
                onScan?(value)
                return
            }
        }
    }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
#endif
