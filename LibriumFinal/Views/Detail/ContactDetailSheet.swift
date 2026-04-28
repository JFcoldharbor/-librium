import SwiftUI

struct ContactDetailSheet: View {
    let relationship: Relationship
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var notesService = ContactNotesService.shared

    @State private var noteText: String = ""
    @State private var followUpDate: Date = Date()
    @State private var hasFollowUp: Bool = false
    @State private var followUpReason: String = ""
    @State private var status: ContactNote.Status = .active
    @State private var showDismissConfirm = false
    @State private var phoneNumber: String?
    @State private var hasSentiment: Bool = false
    @State private var relationshipType: ContactNote.RelationshipType = .unknown
    @State private var personalScoreEnabled: Bool = false
    @State private var personalScoreValue: Double = 50
    @State private var businessScoreEnabled: Bool = false
    @State private var businessScoreValue: Double = 50
    @State private var sentimentContext: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header

                        statTiles

                        followUpSection

                        sentimentSection

                        notesSection

                        quickActions

                        statusActions

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .alert("Mark as dead lead?", isPresented: $showDismissConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Dismiss") { dismissAsDeadLead() }
            } message: {
                Text("Hides them from the network card. You can reactivate later.")
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { saveAndDismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(EquilibriumColor.CardTint.network)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { hydrate() }
            .task { await loadPhoneNumber() }
        }
    }

    // MARK: - Sections

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.25),
                    EquilibriumColor.CardTint.network.opacity(0.06),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(relationship.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(EquilibriumColor.primaryText)
                if let role = relationship.role {
                    Text(role)
                        .font(.system(size: 14))
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                Text(relationship.email)
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }

            Spacer()
        }
    }

    private var avatar: some View {
        ContactAvatar(
            imageData: relationship.imageData,
            displayName: relationship.displayName,
            size: 64,
            tint: decayColor,
            strokeWidth: 1.5
        )
    }

    private var statTiles: some View {
        HStack(spacing: 12) {
            statTile(label: "LAST CONTACT", value: lastContactLabel, accent: decayColor)
            statTile(label: "MEETINGS", value: "\(relationship.interactionCount)", accent: EquilibriumColor.CardTint.network)
            statTile(label: "KNOWN", value: knownLabel, accent: EquilibriumColor.CardTint.network)
        }
    }

    private func statTile(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent.opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("FOLLOW-UP")

            Toggle(isOn: $hasFollowUp) {
                Text("Schedule a follow-up")
                    .font(.system(size: 15))
                    .foregroundColor(EquilibriumColor.primaryText)
            }
            .tint(EquilibriumColor.CardTint.network)

            if hasFollowUp {
                DatePicker(
                    "Date",
                    selection: $followUpDate,
                    in: Date()...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .tint(EquilibriumColor.CardTint.network)
                .colorScheme(.dark)

                TextField("Reason — what's the next step?", text: $followUpReason, axis: .vertical)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(EquilibriumColor.primaryText.opacity(0.07))
                    )
                    .foregroundColor(EquilibriumColor.primaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("HOW THIS FEELS")

            Text("Maria updates these silently as you talk to her. You can override here.")
                .font(.system(size: 11))
                .foregroundColor(EquilibriumColor.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("RELATIONSHIP TYPE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(EquilibriumColor.secondaryText)
                Picker("Type", selection: $relationshipType) {
                    Text("Not set").tag(ContactNote.RelationshipType.unknown)
                    Text("Personal").tag(ContactNote.RelationshipType.personal)
                    Text("Business").tag(ContactNote.RelationshipType.business)
                    Text("Both").tag(ContactNote.RelationshipType.both)
                }
                .pickerStyle(.segmented)
            }

            scoreRow(
                label: "PERSONAL",
                hint: "friend / family warmth",
                isOn: $personalScoreEnabled,
                value: $personalScoreValue
            )

            scoreRow(
                label: "BUSINESS",
                hint: "professional working relationship",
                isOn: $businessScoreEnabled,
                value: $businessScoreValue
            )

            TextField("Why? (e.g. 'reliable client but indecisive on big calls')", text: $sentimentContext, axis: .vertical)
                .lineLimit(2...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EquilibriumColor.primaryText.opacity(0.07))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func scoreRow(label: String, hint: String, isOn: Binding<Bool>, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(EquilibriumColor.secondaryText)
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                Spacer()
                if isOn.wrappedValue {
                    Text("\(Int(value.wrappedValue))")
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(scoreColor(Int(value.wrappedValue)))
                }
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(scoreColor(Int(value.wrappedValue)))
            }
            if isOn.wrappedValue {
                HStack(spacing: 8) {
                    Text("avoid")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                    Slider(value: value, in: 0...100, step: 1)
                        .tint(scoreColor(Int(value.wrappedValue)))
                    Text("love")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                Text(scoreDescriptor(Int(value.wrappedValue)))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(scoreColor(Int(value.wrappedValue)))
            }
        }
    }

    private func scoreColor(_ v: Int) -> Color {
        if v < 40 { return Color.red.opacity(0.85) }
        if v < 70 { return Color.yellow }
        return Color.green
    }

    private func scoreDescriptor(_ v: Int) -> String {
        switch v {
        case 0..<25: return "AVOID"
        case 25..<40: return "DRAINING"
        case 40..<55: return "NEUTRAL"
        case 55..<70: return "FRIENDLY"
        case 70..<85: return "TRUSTED"
        default: return "INNER CIRCLE"
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("NOTES")

            TextField("What should you remember about them?", text: $noteText, axis: .vertical)
                .lineLimit(4...10)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 120, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.07))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            if !relationship.email.isEmpty {
                actionButton(label: "Email", icon: "envelope.fill") {
                    if let url = URL(string: "mailto:\(relationship.email)") {
                        openURL(url)
                    }
                }
            }
            if let phone = phoneNumber, !phone.isEmpty {
                actionButton(label: "Call", icon: "phone.fill") {
                    let cleaned = phone.filter { "+0123456789".contains($0) }
                    if let url = URL(string: "tel:\(cleaned)") {
                        openURL(url)
                    }
                }
                actionButton(label: "Text", icon: "message.fill") {
                    let cleaned = phone.filter { "+0123456789".contains($0) }
                    if let url = URL(string: "sms:\(cleaned)") {
                        openURL(url)
                    }
                }
            }
        }
    }

    private func loadPhoneNumber() async {
        if let contact = await ContactsService.shared.findContact(byId: relationship.id),
           let phone = contact.primaryPhone, !phone.isEmpty {
            phoneNumber = phone
        }
    }

    @ViewBuilder
    private var statusActions: some View {
        if status == .active {
            Button(role: .destructive) {
                showDismissConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                    Text("Dismiss as dead lead")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.12))
                )
                .foregroundColor(.red.opacity(0.85))
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: status == .deadLead ? "moon.zzz.fill" : "archivebox.fill")
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Text(status.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                Button("Reactivate") { reactivate() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EquilibriumColor.CardTint.network)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(EquilibriumColor.primaryText.opacity(0.04))
            )
        }
    }

    private func actionButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(EquilibriumColor.CardTint.network.opacity(0.20))
            )
            .foregroundColor(EquilibriumColor.CardTint.network)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    // MARK: - Logic

    private func hydrate() {
        let existing = notesService.note(for: relationship.id)
        noteText = !existing.notes.isEmpty
            ? existing.notes
            : (relationship.contactNote ?? "")
        if let due = existing.nextFollowUp {
            hasFollowUp = true
            followUpDate = due
        } else {
            hasFollowUp = false
            followUpDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        }
        followUpReason = existing.followUpReason ?? ""
        status = existing.status

        relationshipType = existing.relationshipType
        if let p = existing.personalScore {
            personalScoreEnabled = true
            personalScoreValue = Double(p)
        } else {
            personalScoreEnabled = false
            personalScoreValue = 50
        }
        if let b = existing.businessScore {
            businessScoreEnabled = true
            businessScoreValue = Double(b)
        } else {
            businessScoreEnabled = false
            businessScoreValue = 50
        }
        hasSentiment = personalScoreEnabled || businessScoreEnabled || (existing.relationshipContext?.isEmpty == false) || relationshipType != .unknown
        sentimentContext = existing.relationshipContext ?? ""
    }

    private func save() {
        let trimmedSentimentContext = sentimentContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = ContactNote(
            contactId: relationship.id,
            notes: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            nextFollowUp: hasFollowUp ? followUpDate : nil,
            followUpReason: hasFollowUp ? (followUpReason.isEmpty ? nil : followUpReason) : nil,
            status: status,
            relationshipType: relationshipType,
            personalScore: personalScoreEnabled ? Int(personalScoreValue) : nil,
            businessScore: businessScoreEnabled ? Int(businessScoreValue) : nil,
            relationshipContext: !trimmedSentimentContext.isEmpty ? trimmedSentimentContext : nil,
            updatedAt: Date()
        )
        notesService.upsert(note)
        if !personalScoreEnabled && !businessScoreEnabled && trimmedSentimentContext.isEmpty {
            notesService.clearSentiment(contactId: relationship.id)
        }
        dismiss()
    }

    private func saveAndDismiss() {
        save()
    }

    private func dismissAsDeadLead() {
        let note = ContactNote(
            contactId: relationship.id,
            notes: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            nextFollowUp: nil,
            followUpReason: nil,
            status: .deadLead,
            updatedAt: Date()
        )
        notesService.upsert(note)
        dismiss()
    }

    private func reactivate() {
        status = .active
        let note = ContactNote(
            contactId: relationship.id,
            notes: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            nextFollowUp: hasFollowUp ? followUpDate : nil,
            followUpReason: hasFollowUp ? (followUpReason.isEmpty ? nil : followUpReason) : nil,
            status: .active,
            updatedAt: Date()
        )
        notesService.upsert(note)
    }

    private var lastContactLabel: String {
        let now = Date()
        var mostRecent: Date?
        if relationship.interactionCount > 0 {
            mostRecent = relationship.lastInteraction
        }
        if let touched = notesService.notesByContactId[relationship.id]?.lastTouchedAt {
            mostRecent = mostRecent.map { max($0, touched) } ?? touched
        }
        guard let date = mostRecent else { return "—" }
        let days = max(0, Int(now.timeIntervalSince(date) / 86_400))
        if days == 0 { return "Today" }
        if days == 1 { return "1d ago" }
        if days < 30 { return "\(days)d ago" }
        return "\(days / 30)mo ago"
    }

    private var knownLabel: String {
        if relationship.interactionCount == 0 { return "New" }
        let days = relationship.daysKnown()
        if days < 30 { return "\(days)d" }
        if days < 365 { return "\(days / 30)mo" }
        let years = Double(days) / 365
        return String(format: "%.1fy", years)
    }

    private var initials: String {
        let parts = relationship.displayName.split(separator: " ")
        return parts.compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
    }

    private var decayColor: Color {
        switch relationship.decayState() {
        case .fresh: return Color.green
        case .warming: return Color.yellow
        case .fading: return Color.orange
        case .stale: return Color.red.opacity(0.85)
        case .cold: return Color.red
        }
    }
}
