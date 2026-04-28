import SwiftUI

struct NFCReadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var meetingService = MeetingCaptureService.shared
    @ObservedObject private var notesService = ContactNotesService.shared

    @State private var parsedContact: VCardEncoder.ParsedContact?
    @State private var capturedContext: MeetingContext?
    @State private var saving: Bool = false
    @State private var savedContactId: String?
    @State private var errorMessage: String?
    @State private var status: Status = .idle

    enum Status {
        case idle, scanning
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if let parsed = parsedContact {
                    confirmView(parsed)
                } else {
                    scanView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text(parsedContact == nil ? "Tap a tag" : "Save contact")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .onAppear {
                meetingService.requestPermissionIfNeeded()
            }
            .alert("Couldn't read", isPresented: Binding(
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

    // MARK: - Scan view

    private var scanView: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 8)

            VStack(spacing: 8) {
                Text("Tap to read a card")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("Hold the top of your iPhone against an NFC card with someone's vCard on it.")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            ZStack {
                Circle()
                    .fill(EquilibriumColor.CardTint.network.opacity(0.16))
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(EquilibriumColor.CardTint.network.opacity(0.45), lineWidth: 1)
                    .frame(width: 240, height: 240)
                if status == .scanning {
                    ProgressView().tint(EquilibriumColor.CardTint.network).scaleEffect(1.6)
                } else {
                    Image(systemName: "wave.3.left")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(EquilibriumColor.CardTint.network)
                }
            }
            .padding(.vertical, 12)

            if !NFCService.isAvailable {
                Text("NFC not available on this device.")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
            } else {
                Button {
                    Task { await beginScan() }
                } label: {
                    Text(status == .scanning ? "Scanning…" : "Begin")
                        .font(.system(size: 15, weight: .heavy))
                        .frame(maxWidth: 240)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(EquilibriumColor.CardTint.network)
                        )
                        .foregroundColor(.white)
                }
                .disabled(status == .scanning)
            }

            Text("Capturing your location and current event for the note.")
                .font(.system(size: 11))
                .foregroundColor(EquilibriumColor.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Confirm view

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
                Text(role).font(.system(size: 14)).foregroundColor(EquilibriumColor.secondaryText)
            } else if let org = parsed.organization {
                Text(org).font(.system(size: 14)).foregroundColor(EquilibriumColor.secondaryText)
            }
            if let email = parsed.email {
                Text(email).font(.system(size: 12)).foregroundColor(EquilibriumColor.tertiaryText)
            }
            if let phone = parsed.phone {
                Text(phone).font(.system(size: 12)).foregroundColor(EquilibriumColor.tertiaryText)
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

    private func beginScan() async {
        status = .scanning
        let result = await NFCService.shared.readVCard()
        status = .idle
        switch result {
        case .success(let payload):
            guard let parsed = VCardEncoder.decode(payload) else {
                errorMessage = "Tag didn't contain a contact card."
                return
            }
            parsedContact = parsed
            capturedContext = await meetingService.captureContext()
        case .failure(let error):
            errorMessage = error.errorDescription
        }
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
                errorMessage = "iOS wouldn't save the contact."
            }
            saving = false
        }
    }
}
