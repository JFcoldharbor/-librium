import SwiftUI

struct NetworkEventDetailSheet: View {
    let event: NetworkEvent
    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var eventService = NetworkEventService.shared
    @ObservedObject private var contactsService = ContactsService.shared

    @State private var matchedContacts: [String: ContactSummary] = [:]
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false

    enum Mode {
        case confirmScan
        case detail
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        whenWhereCard

                        if !event.attendees.isEmpty {
                            attendeesSection
                        }

                        if mode == .confirmScan {
                            saveButton
                        } else {
                            shareButton
                            deleteButton
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(mode == .confirmScan ? "Cancel" : "Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Event")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .alert("Delete event?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    eventService.delete(id: event.id)
                    dismiss()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                EventShareSheet(event: event)
                    .preferredColorScheme(.dark)
            }
            .task {
                await matchAttendeesToContacts()
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
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(event.statusLabel)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(statusTint.opacity(0.20)))
                    .foregroundColor(statusTint)
                if let host = event.host {
                    Text("hosted by \(host)")
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                Spacer()
            }

            Text(event.name)
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(EquilibriumColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusTint: Color {
        if event.isLive { return EquilibriumColor.CardTint.health }
        if event.isUpcoming { return EquilibriumColor.CardTint.network }
        return EquilibriumColor.tertiaryText
    }

    private var whenWhereCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(EquilibriumColor.CardTint.network)
                Text(formatDateRange())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
            }
            if let venue = event.venue {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(EquilibriumColor.CardTint.network)
                    Text(venue)
                        .font(.system(size: 14))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("ATTENDEES")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                Spacer()
                Text("\(event.attendees.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                if knownCount > 0 {
                    Text("· \(knownCount) you know")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(EquilibriumColor.CardTint.network)
                }
            }
            .foregroundColor(EquilibriumColor.CardTint.network)

            VStack(spacing: 6) {
                ForEach(event.attendees) { attendee in
                    attendeeRow(attendee)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func attendeeRow(_ attendee: NetworkEvent.Attendee) -> some View {
        let known = isKnown(attendee)
        return HStack(spacing: 12) {
            ContactAvatar(
                imageData: matchedContact(for: attendee)?.imageData,
                displayName: attendee.name,
                size: 32,
                tint: known ? EquilibriumColor.CardTint.network : EquilibriumColor.tertiaryText,
                strokeWidth: 1
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(attendee.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                    if known {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(EquilibriumColor.CardTint.network)
                    }
                }
                if let role = attendee.role {
                    Text(role)
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            if known, let email = attendee.email,
               let url = URL(string: "mailto:\(email)?subject=See%20you%20at%20\(event.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                Link(destination: url) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(8)
                        .background(Circle().fill(EquilibriumColor.CardTint.network.opacity(0.20)))
                        .foregroundColor(EquilibriumColor.CardTint.network)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var saveButton: some View {
        Button {
            eventService.upsert(event)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Save event")
                    .font(.system(size: 14, weight: .heavy))
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

    private var shareButton: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Share event")
                    .font(.system(size: 14, weight: .heavy))
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

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                Text("Delete event")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.15))
            )
            .foregroundColor(.red)
        }
    }

    // MARK: - Helpers

    private func formatDateRange() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mma"
        let start = f.string(from: event.startDate)
        let timeOnly = DateFormatter()
        timeOnly.dateFormat = "h:mma"
        let end = timeOnly.string(from: event.endDate)
        return "\(start) – \(end)".lowercased().replacingOccurrences(of: "am", with: "AM").replacingOccurrences(of: "pm", with: "PM")
    }

    private var knownCount: Int {
        event.attendees.filter { isKnown($0) }.count
    }

    private func isKnown(_ attendee: NetworkEvent.Attendee) -> Bool {
        matchedContact(for: attendee) != nil
    }

    private func matchedContact(for attendee: NetworkEvent.Attendee) -> ContactSummary? {
        if let email = attendee.email, !email.isEmpty {
            return matchedContacts[email.lowercased()]
        }
        return nil
    }

    private func matchAttendeesToContacts() async {
        let emailsToMatch = event.attendees.compactMap { $0.email?.lowercased() }
        guard !emailsToMatch.isEmpty else { return }
        var resolved: [String: ContactSummary] = [:]
        for email in emailsToMatch {
            if let contact = await contactsService.findContact(byEmail: email) {
                resolved[email] = contact
            }
        }
        matchedContacts = resolved
    }
}
