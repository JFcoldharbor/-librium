import SwiftUI

struct WorkNetworkingCard: View {
    let snapshot: RelationshipSnapshot
    let calendarAccess: CalendarService.AccessState
    let contactsAccess: ContactsService.AccessState

    @StateObject private var notesService = ContactNotesService.shared
    @StateObject private var contactsService = ContactsService.shared
    @StateObject private var eventService = NetworkEventService.shared
    @State private var selectedRelationship: Relationship?
    @State private var selectedEvent: NetworkEvent?
    @State private var showAllContacts = false
    @State private var showShareCard = false
    @State private var showScan = false
    @State private var showNFCWrite = false
    @State private var showNFCRead = false
    @State private var showCreateEvent = false
    @State private var noteFlaggedContacts: [ContactSummary] = []

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 80)
                    .padding(.bottom, 18)

                eventStrip
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                content
            }
        }
        .sheet(item: $selectedRelationship) { rel in
            ContactDetailSheet(relationship: rel)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedEvent) { event in
            NetworkEventDetailSheet(event: event, mode: .detail)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAllContacts) {
            AllContactsSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showShareCard) {
            ShareMyCardSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showScan) {
            ScanContactSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showNFCWrite) {
            NFCWriteSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showNFCRead) {
            NFCReadSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showCreateEvent) {
            CreateEventSheet()
                .preferredColorScheme(.dark)
        }
        .task {
            await refreshNoteFlaggedContacts()
        }
        .onChange(of: notesService.notesByContactId) { _, _ in
            Task { await refreshNoteFlaggedContacts() }
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.30),
                    EquilibriumColor.CardTint.network.opacity(0.08),
                    EquilibriumColor.background
                ],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NETWORK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(EquilibriumColor.CardTint.network)
                Spacer()
                headerIcon("person.crop.rectangle.stack.fill") { showAllContacts = true }
            }

            Text("Reach back out")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)

            HStack(spacing: 8) {
                actionPill(icon: "qrcode", label: "Share QR") { showShareCard = true }
                actionPill(icon: "qrcode.viewfinder", label: "Scan QR") { showScan = true }
                actionPill(icon: "wave.3.right", label: "Write tag") { showNFCWrite = true }
                actionPill(icon: "wave.3.left", label: "Read tag") { showNFCRead = true }
            }

            if !snapshot.relationships.isEmpty {
                temperatureRow
            }
        }
    }

    private var eventStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EVENTS")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.CardTint.network)
                Spacer()
                Text("\(eventService.upcomingEvents.count) upcoming")
                    .font(.system(size: 10))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Button {
                    showCreateEvent = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .heavy))
                        Text("HOST")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                    }
                    .foregroundColor(EquilibriumColor.CardTint.network)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(EquilibriumColor.CardTint.network.opacity(0.20)))
                }
                .buttonStyle(.plain)
            }
            if eventService.upcomingEvents.isEmpty {
                Button {
                    showCreateEvent = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Host an event for your network")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(EquilibriumColor.CardTint.network)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(EquilibriumColor.CardTint.network.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(eventService.upcomingEvents) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                eventTile(event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func eventTile(_ event: NetworkEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.statusLabel)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundColor(event.isLive ? EquilibriumColor.CardTint.health : EquilibriumColor.CardTint.network)
            Text(event.name)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(EquilibriumColor.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let venue = event.venue {
                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.system(size: 8))
                    Text(venue)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 9))
                Text("\(event.attendees.count)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(EquilibriumColor.CardTint.network)
        }
        .padding(12)
        .frame(width: 180, height: 100, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            event.isLive
                                ? EquilibriumColor.CardTint.health.opacity(0.5)
                                : EquilibriumColor.CardTint.network.opacity(0.25),
                            lineWidth: event.isLive ? 1 : 0.5
                        )
                )
        )
    }

    private func headerIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(EquilibriumColor.CardTint.network)
                .padding(8)
                .background(
                    Circle().fill(EquilibriumColor.CardTint.network.opacity(0.18))
                )
        }
        .buttonStyle(.plain)
    }

    private func actionPill(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(EquilibriumColor.CardTint.network)
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(EquilibriumColor.CardTint.network)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(EquilibriumColor.CardTint.network.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(EquilibriumColor.CardTint.network.opacity(0.30), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var temperatureRow: some View {
        let buckets = Dictionary(grouping: snapshot.relationships, by: { $0.decayState() })
        return HStack(spacing: 18) {
            tempPill(label: "fresh", count: buckets[.fresh]?.count ?? 0, color: .green)
            tempPill(label: "warming", count: buckets[.warming]?.count ?? 0, color: .yellow)
            tempPill(label: "fading", count: buckets[.fading]?.count ?? 0, color: .orange)
            tempPill(label: "stale", count: buckets[.stale]?.count ?? 0, color: .red.opacity(0.85))
            tempPill(label: "cold", count: buckets[.cold]?.count ?? 0, color: .red)
        }
        .padding(.top, 4)
    }

    private func tempPill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(count > 0 ? EquilibriumColor.primaryText : EquilibriumColor.tertiaryText)
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if calendarAccess != .authorized {
            permissionState(text: "Calendar access needed", subtext: "Settings → Equilibrium → Calendars")
        } else if contactsAccess != .authorized {
            permissionState(text: "Contacts access needed", subtext: "Settings → Equilibrium → Contacts")
        } else if snapshot.relationships.isEmpty {
            emptyState
        } else {
            directoryList
        }
    }

    private var directoryList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(activeRelationships) { rel in
                    Button(action: { selectedRelationship = rel }) {
                        DirectoryRow(
                            relationship: rel,
                            note: notesService.notesByContactId[rel.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
                if dismissedCount > 0 {
                    Text("\(dismissedCount) dismissed lead\(dismissedCount == 1 ? "" : "s") hidden")
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
    }

    private var activeRelationships: [Relationship] {
        var seen = Set<String>()
        var merged: [Relationship] = []

        // Calendar-derived (with meeting history)
        for rel in snapshot.relationships {
            let status = notesService.notesByContactId[rel.id]?.status ?? .active
            guard status == .active else { continue }
            if seen.insert(rel.id).inserted {
                merged.append(rel)
            }
        }

        // Note-flagged (no calendar history but user has saved notes/follow-ups)
        for contact in noteFlaggedContacts {
            guard !seen.contains(contact.id) else { continue }
            let status = notesService.notesByContactId[contact.id]?.status ?? .active
            guard status == .active else { continue }
            seen.insert(contact.id)
            merged.append(Relationship.fromContact(contact))
        }

        // Sort: pending follow-ups first (overdue first), then by snapshot order
        return merged.sorted { lhs, rhs in
            let lhsFollowUp = notesService.notesByContactId[lhs.id]?.nextFollowUp
            let rhsFollowUp = notesService.notesByContactId[rhs.id]?.nextFollowUp
            switch (lhsFollowUp, rhsFollowUp) {
            case (let l?, let r?): return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.decayScore > rhs.decayScore
            }
        }
    }

    private var dismissedCount: Int {
        let allIds = Set(snapshot.relationships.map { $0.id }
            + noteFlaggedContacts.map { $0.id })
        let dismissedIds = allIds.filter { id in
            notesService.notesByContactId[id]?.status == .deadLead
        }
        return dismissedIds.count
    }

    private func refreshNoteFlaggedContacts() async {
        let trackedIds = Set(notesService.notesByContactId.keys)
        guard !trackedIds.isEmpty else {
            noteFlaggedContacts = []
            return
        }
        let all = await contactsService.loadAllContacts()
        noteFlaggedContacts = all.filter { trackedIds.contains($0.id) }
    }

    private func permissionState(text: String, subtext: String) -> some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 60)
            Image(systemName: "person.2.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text(subtext)
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 60)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundColor(EquilibriumColor.CardTint.network.opacity(0.6))
            Text("All caught up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("No stale connections in your last 90 days.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

private struct DirectoryRow: View {
    let relationship: Relationship
    let note: ContactNote?

    var body: some View {
        HStack(spacing: 14) {
            tempStripe

            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(relationship.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(1)
                if let role = relationship.role {
                    Text(role)
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if note?.personalScore != nil || note?.businessScore != nil {
                    HStack(spacing: 6) {
                        if let p = note?.personalScore {
                            scoreChip(label: "P", value: p)
                        }
                        if let b = note?.businessScore {
                            scoreChip(label: "B", value: b)
                        }
                    }
                }
                if let followUp = note?.nextFollowUp {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 10))
                        Text(followUp, style: .date)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(EquilibriumColor.CardTint.network)
                }
                if let savedNote = note?.notes, !savedNote.isEmpty {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.CardTint.network.opacity(0.7))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(EquilibriumColor.CardTint.network.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    private var tempStripe: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(decayColor)
            .frame(width: 3, height: 36)
    }

    private var avatar: some View {
        ContactAvatar(
            imageData: relationship.imageData,
            displayName: relationship.displayName,
            size: 38,
            tint: decayColor
        )
    }

    private var subtitle: String {
        let effectiveLast = effectiveLastContact()
        let calCount = relationship.interactionCount
        let dayLabel: String
        if let days = effectiveLast {
            dayLabel = days == 0 ? "today" : days == 1 ? "1d ago" : "\(days)d ago"
        } else {
            dayLabel = "—"
        }
        let countLabel = calCount == 1 ? "1 mtg" : "\(calCount) mtgs"
        return "\(dayLabel) · \(countLabel)"
    }

    /// Days since the most recent of: calendar attendance, manually-logged touch.
    private func effectiveLastContact(now: Date = Date()) -> Int? {
        var mostRecent: Date?
        if relationship.interactionCount > 0 {
            mostRecent = relationship.lastInteraction
        }
        if let touched = note?.lastTouchedAt {
            if let current = mostRecent {
                mostRecent = max(current, touched)
            } else {
                mostRecent = touched
            }
        }
        guard let date = mostRecent else { return nil }
        return max(0, Int(now.timeIntervalSince(date) / 86_400))
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

    private func sentimentColor(_ score: Int) -> Color {
        if score < 40 { return Color.red.opacity(0.85) }
        if score < 70 { return Color.yellow }
        return Color.green
    }

    @ViewBuilder
    private func scoreChip(label: String, value: Int) -> some View {
        let tint = sentimentColor(value)
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(tint.opacity(0.85))
            Text("\(value)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundColor(tint)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(tint.opacity(0.15))
        )
    }
}
