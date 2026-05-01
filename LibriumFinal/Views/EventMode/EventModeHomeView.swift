import SwiftUI

/// The "Event Mode" home screen — what the user lands on when they tap the
/// Event Mode banner during an active event window. Replaces the regular
/// `NetworkEventDetailSheet` for ACTIVE state.
///
/// v1 (this sprint): identity header + Room as a list of attendees (all, with
/// intent breakdown summary), plus access to intent-change and the standard
/// detail view.
///
/// Next sprints layer in:
/// - Intent-filtered Room (using AttendeeIntent.sees)
/// - Single-person-card "remote" view ("show me someone else")
/// - Server-side ranking ("who you should meet next")
/// - Romantic mutual-interest mechanic
struct EventModeHomeView: View {
    let event: NetworkEvent

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var eventService = NetworkEventService.shared
    @State private var showStandardDetail = false
    @State private var showIntentSheet = false
    @State private var myIntent: AttendeeIntent = .default
    @State private var roomMode: RoomMode = .remote
    @State private var currentIndex: Int = 0

    enum RoomMode { case remote, list }

    /// Live event from the service so attendees update in real-time during
    /// the active window without needing to dismiss + reopen.
    private var liveEvent: NetworkEvent {
        eventService.events.first { $0.id == event.id } ?? event
    }

    private var accent: Color { EquilibriumColor.CardTint.network }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 24) {
                        identityHeader
                        statsRow
                        roomSection
                        footerActions
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("EVENT MODE")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.5)
                        .foregroundColor(accent)
                }
            }
        }
        .sheet(isPresented: $showStandardDetail) {
            NetworkEventDetailSheet(event: liveEvent, mode: .detail)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showIntentSheet) {
            IntentDeclarationSheet(
                event: liveEvent,
                initialIntent: myIntent,
                onSelect: { picked in
                    myIntent = picked
                    showIntentSheet = false
                },
                onDismiss: { showIntentSheet = false }
            )
            .preferredColorScheme(.dark)
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    accent.opacity(0.30),
                    accent.opacity(0.06),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Identity header

    private var identityHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(liveEvent.statusLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(accent.opacity(0.20)))
                    .foregroundColor(accent)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(liveEvent.name)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let host = liveEvent.host {
                    Text("hosted by \(host)")
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(spacing: 6) {
                detailRow(icon: "calendar", text: formatRange())
                if let venue = liveEvent.venue {
                    detailRow(icon: "mappin.and.ellipse", text: venue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(accent)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile(value: "\(liveEvent.attendees.count)", label: "RSVPS")
            statTile(value: "\(intentBreakdown.matched)", label: "MATCH YOUR VIBE")
            statTile(value: myIntent.shortLabel.uppercased(), label: "YOUR VIBE")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(EquilibriumColor.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(EquilibriumColor.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private struct IntentBreakdown {
        let matched: Int
        let total: Int
    }

    private var intentBreakdown: IntentBreakdown {
        let visible = liveEvent.attendees.filter { attendee in
            myIntent.sees(attendee.resolvedIntent)
        }
        return IntentBreakdown(matched: visible.count, total: liveEvent.attendees.count)
    }

    // MARK: - Room

    private var roomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("THE ROOM")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(accent)
                Spacer()
                if myIntent == .observing {
                    Text("invisible")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                } else if !visibleAttendees.isEmpty {
                    modeToggle
                }
            }

            if myIntent == .observing {
                observingState
            } else if visibleAttendees.isEmpty {
                emptyRoomState
            } else {
                switch roomMode {
                case .remote:
                    remoteCardSection
                case .list:
                    listSection
                }
            }
        }
        .onChange(of: visibleAttendees.count) { _, newCount in
            if currentIndex >= newCount && newCount > 0 {
                currentIndex = 0
            }
        }
    }

    private var modeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                roomMode = roomMode == .remote ? .list : .remote
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: roomMode == .remote ? "list.bullet" : "person.crop.circle")
                    .font(.system(size: 10, weight: .semibold))
                Text(roomMode == .remote ? "see the whole room" : "back to remote")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            .foregroundColor(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(accent.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Remote (single-card) mode

    private var remoteCardSection: some View {
        let total = visibleAttendees.count
        let safeIndex = min(currentIndex, max(0, total - 1))
        let attendee = visibleAttendees[safeIndex]
        return VStack(spacing: 14) {
            remoteCard(for: attendee)

            HStack {
                Text("\(safeIndex + 1) of \(total)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
            }

            Button(action: advance) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                    Text(total > 1 ? "Show me someone else" : "Only one matching the room")
                        .font(.system(size: 14, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(total > 1 ? accent : accent.opacity(0.3))
                )
                .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            .disabled(total <= 1)
        }
    }

    private func remoteCard(for attendee: NetworkEvent.Attendee) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Identity block
            HStack(spacing: 14) {
                Circle()
                    .fill(accent.opacity(0.20))
                    .overlay(
                        Text(initials(for: attendee.name))
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(accent)
                    )
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(attendee.name)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(attendee.resolvedIntent.shortLabel.uppercased())
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(intentTint(attendee.resolvedIntent))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(intentTint(attendee.resolvedIntent).opacity(0.18)))

                        if attendee.resolvedIntent.requiresMutualInterest {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(EquilibriumColor.tertiaryText)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 14)

            // Attribution
            if let role = attendee.role, !role.isEmpty {
                Label(role, systemImage: "briefcase")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .padding(.bottom, 6)
            }
            if let org = attendee.organization, !org.isEmpty {
                Label(org, systemImage: "building.2")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .padding(.bottom, 6)
            }

            // Conversation opener placeholder (Sprint 2b-3 fills this with
            // server-side scanner-generated suggestions tied to mutuals + goals)
            VStack(alignment: .leading, spacing: 6) {
                Text("CONVERSATION OPENER")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(accent)
                Text(openerPlaceholder(for: attendee))
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.10),
                            EquilibriumColor.primaryText.opacity(0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(accent.opacity(0.30), lineWidth: 1)
                )
        )
    }

    private func openerPlaceholder(for attendee: NetworkEvent.Attendee) -> String {
        // TODO Sprint 2b-3: replace with server-side scanner-generated opener
        // tied to mutual connections + user's active goals + the attendee's role.
        switch attendee.resolvedIntent {
        case .professional:
            if let role = attendee.role, !role.isEmpty {
                return "Start with what they're working on. \"What's keeping you busy at \(attendee.organization ?? "work") right now?\""
            }
            return "Open with curiosity, not credentials. Ask what brought them here."
        case .social:
            return "Keep it light. \"How do you know the host?\" usually opens things up."
        case .friends:
            return "What do they actually like doing on weekends? That's the real signal."
        case .romantic:
            return "Lead with presence, not performance. Be more interested than interesting."
        case .observing:
            return "They're not in the discovery flow. Skip."
        }
    }

    private func advance() {
        let total = visibleAttendees.count
        guard total > 1 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex = (currentIndex + 1) % total
        }
    }

    // MARK: - List mode

    private var listSection: some View {
        VStack(spacing: 8) {
            ForEach(visibleAttendees) { attendee in
                attendeeRow(attendee)
            }
        }
    }

    private var visibleAttendees: [NetworkEvent.Attendee] {
        liveEvent.attendees.filter { attendee in
            myIntent.sees(attendee.resolvedIntent)
        }
    }

    private var observingState: some View {
        VStack(spacing: 8) {
            Text("Just observing.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("You're invisible to the room. No one sees you, you see no one.")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(EquilibriumColor.tertiaryText.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
        )
    }

    private var emptyRoomState: some View {
        VStack(spacing: 6) {
            Text("Quiet so far.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("No one matching your vibe in the room yet.")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func attendeeRow(_ attendee: NetworkEvent.Attendee) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accent.opacity(0.20))
                .overlay(
                    Text(initials(for: attendee.name))
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(accent)
                )
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(attendee.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(1)
                if let role = attendee.role, !role.isEmpty {
                    Text(role)
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(attendee.resolvedIntent.shortLabel)
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(intentTint(attendee.resolvedIntent))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(intentTint(attendee.resolvedIntent).opacity(0.18)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func intentTint(_ intent: AttendeeIntent) -> Color {
        switch intent {
        case .professional: return accent
        case .social:       return EquilibriumColor.CardTint.financial
        case .friends:      return EquilibriumColor.CardTint.health
        case .romantic:     return EquilibriumColor.CardTint.motivation
        case .observing:    return EquilibriumColor.tertiaryText
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2).map { String($0.prefix(1)) }
        return parts.joined().uppercased()
    }

    // MARK: - Footer actions

    private var footerActions: some View {
        VStack(spacing: 10) {
            Button { showIntentSheet = true } label: {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 14))
                    Text("Change my vibe · \(myIntent.shortLabel)")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(EquilibriumColor.primaryText.opacity(0.04))
                )
                .foregroundColor(EquilibriumColor.primaryText)
            }
            .buttonStyle(.plain)

            Button { showStandardDetail = true } label: {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                    Text("Event details")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(EquilibriumColor.primaryText.opacity(0.04))
                )
                .foregroundColor(EquilibriumColor.primaryText)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatRange() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mma"
        let start = f.string(from: liveEvent.startDate)
        let timeOnly = DateFormatter()
        timeOnly.dateFormat = "h:mma"
        let end = timeOnly.string(from: liveEvent.endDate)
        return "\(start) – \(end)".replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
    }
}
