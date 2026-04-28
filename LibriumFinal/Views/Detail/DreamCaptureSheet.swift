import SwiftUI

struct DreamCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dreamService = DreamService.shared
    @ObservedObject private var speechService = SpeechService.shared

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dreamedAt: Date = Date()
    @State private var saving: Bool = false
    @State private var isRecording: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intro
                        recordPill
                        descriptionSection
                        titleSection
                        dateSection
                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if isRecording { speechService.stop() }
                        dismiss()
                    }
                    .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Dream")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: {
                        if saving {
                            ProgressView().tint(EquilibriumColor.CardTint.journalDream)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(EquilibriumColor.CardTint.journalDream)
                        }
                    }
                    .disabled(saving || description.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: speechService.transcript) { _, newValue in
                if isRecording { description = newValue }
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.journalDream.opacity(0.32),
                    EquilibriumColor.CardTint.journalDream.opacity(0.08),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 60,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
    }

    private var intro: some View {
        Text("Tell Maria what you dreamed. Hold the orb to dictate, or type below. She'll write the analysis after you save.")
            .font(.system(size: 13))
            .foregroundColor(EquilibriumColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var recordPill: some View {
        Button {
            toggleRecording()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : EquilibriumColor.CardTint.journalDream)
                        .frame(width: 44, height: 44)
                        .shadow(color: (isRecording ? Color.red : EquilibriumColor.CardTint.journalDream).opacity(0.5), radius: 14, y: 4)
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRecording ? "Listening…" : "Hold to dictate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text(isRecording ? "Tap to stop" : "Or type your dream below")
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(EquilibriumColor.primaryText.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(EquilibriumColor.CardTint.journalDream.opacity(0.20), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WHAT HAPPENED")
            TextField("I was in a forest…", text: $description, axis: .vertical)
                .lineLimit(6...20)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 180, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TITLE (OPTIONAL)")
            TextField("A short label", text: $title)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("DREAMED ON")
            DatePicker("", selection: $dreamedAt, in: ...Date(), displayedComponents: [.date])
                .datePickerStyle(.compact)
                .tint(EquilibriumColor.CardTint.journalDream)
                .colorScheme(.dark)
                .labelsHidden()
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    private func toggleRecording() {
        if isRecording {
            speechService.stop()
            isRecording = false
        } else {
            Task {
                if speechService.accessState == .unknown {
                    await speechService.requestAccess()
                }
                guard speechService.accessState == .authorized else { return }
                do {
                    try speechService.start()
                    isRecording = true
                } catch {
                    isRecording = false
                }
            }
        }
    }

    private func save() {
        if isRecording { speechService.stop(); isRecording = false }
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = trimmedTitle.isEmpty
            ? autoTitle(from: trimmedDescription)
            : trimmedTitle

        saving = true
        let dream = DreamEntry.make(
            title: resolvedTitle,
            description: trimmedDescription,
            dreamedAt: dreamedAt
        )
        dreamService.upsert(dream)

        Task {
            await dreamService.analyze(dream)
            saving = false
            dismiss()
        }
    }

    private func autoTitle(from text: String) -> String {
        let words = text.split(separator: " ").prefix(6).joined(separator: " ")
        return words.isEmpty ? "Untitled dream" : String(words)
    }
}
