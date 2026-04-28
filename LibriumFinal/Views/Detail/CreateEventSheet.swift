import CoreLocation
import FirebaseAuth
import SwiftUI

struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profileService = UserProfileService.shared
    @ObservedObject private var meetingService = MeetingCaptureService.shared
    @ObservedObject private var eventService = NetworkEventService.shared

    @State private var name: String = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var venueSelection: VenueSelection?
    @State private var showVenuePicker: Bool = false
    @State private var attendeesText: String = ""
    @State private var saving: Bool = false
    @State private var savedEvent: NetworkEvent?
    @State private var errorMessage: String?

    init() {
        let now = Date()
        let defaultStart = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
        let defaultEnd = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now
        _startDate = State(initialValue: defaultStart)
        _endDate = State(initialValue: defaultEnd)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                Form {
                    Section("Event") {
                        TextField("Name (e.g. AI Builders Mixer)", text: $name)
                            .textInputAutocapitalization(.words)
                    }

                    Section(footer: Text("Pinned coords power geofencing — \"you're at this event\" prompts when guests arrive.").font(.system(size: 11))) {
                        Button {
                            showVenuePicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: venueSelection == nil ? "mappin.slash" : "mappin.and.ellipse")
                                    .foregroundColor(EquilibriumColor.CardTint.network)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let v = venueSelection {
                                        Text(v.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(EquilibriumColor.primaryText)
                                            .lineLimit(1)
                                        Text(v.address)
                                            .font(.system(size: 11))
                                            .foregroundColor(EquilibriumColor.secondaryText)
                                            .lineLimit(1)
                                    } else {
                                        Text("Choose location")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(EquilibriumColor.primaryText)
                                        Text("Search address or pick a venue")
                                            .font(.system(size: 11))
                                            .foregroundColor(EquilibriumColor.secondaryText)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(EquilibriumColor.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)

                        if venueSelection != nil {
                            Button(role: .destructive) {
                                venueSelection = nil
                            } label: {
                                Text("Remove location")
                                    .font(.system(size: 13))
                            }
                        }
                    }

                    Section("When") {
                        DatePicker("Starts", selection: $startDate)
                        DatePicker("Ends", selection: $endDate, in: startDate...)
                    }

                    Section("Initial attendees (optional)") {
                        TextField(
                            "One per line — Name <email>",
                            text: $attendeesText,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }

                    Section {
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Create event")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            ProgressView()
                                .tint(EquilibriumColor.CardTint.network)
                        } else {
                            Text("Create")
                                .fontWeight(.heavy)
                                .foregroundColor(EquilibriumColor.CardTint.network)
                        }
                    }
                    .disabled(saving || !canSave)
                }
            }
            .onAppear {
                meetingService.requestPermissionIfNeeded()
            }
            .sheet(item: $savedEvent) { event in
                EventShareSheet(event: event)
                    .preferredColorScheme(.dark)
                    .onDisappear {
                        dismiss()
                    }
            }
            .sheet(isPresented: $showVenuePicker) {
                VenueSearchSheet(selection: $venueSelection)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.22),
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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && endDate > startDate
    }

    // MARK: - Logic

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        saving = true
        defer { saving = false }

        // Ensure auth so hostUserId is set
        do {
            if Auth.auth().currentUser == nil {
                _ = try await Auth.auth().signInAnonymously()
            }
        } catch {
            errorMessage = "Couldn't sign in: \(error.localizedDescription)"
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No signed-in user."
            return
        }

        let attendees = parseAttendees(attendeesText)
        let profile = profileService.profile

        let venueLabel: String? = {
            guard let v = venueSelection else { return nil }
            if !v.address.isEmpty && v.address != v.name {
                return "\(v.name) · \(v.address)"
            }
            return v.name
        }()

        let event = NetworkEvent(
            id: UUID(),
            name: trimmedName,
            venue: venueLabel,
            latitude: venueSelection?.latitude,
            longitude: venueSelection?.longitude,
            startDate: startDate,
            endDate: endDate,
            host: profile.fullName.isEmpty ? nil : profile.fullName,
            hostEmail: profile.email.isEmpty ? nil : profile.email,
            hostUserId: uid,
            attendees: attendees,
            addedAt: Date()
        )

        do {
            let uploaded = try await FirestoreEventService.shared.upload(event)
            eventService.upsert(uploaded, syncToFirestore: false)
            savedEvent = uploaded
        } catch {
            errorMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func parseAttendees(_ raw: String) -> [NetworkEvent.Attendee] {
        let lines = raw.split(whereSeparator: { $0.isNewline })
        var result: [NetworkEvent.Attendee] = []
        for line in lines {
            let entry = String(line).trimmingCharacters(in: .whitespaces)
            guard !entry.isEmpty else { continue }
            // Format: "Name <email>" or just "Name" or just "email@x"
            if let openBracket = entry.firstIndex(of: "<"),
               let closeBracket = entry.firstIndex(of: ">"),
               openBracket < closeBracket {
                let name = entry[..<openBracket].trimmingCharacters(in: .whitespaces)
                let email = entry[entry.index(after: openBracket)..<closeBracket]
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                result.append(NetworkEvent.Attendee(
                    name: name.isEmpty ? email : name,
                    email: email.isEmpty ? nil : email
                ))
            } else if entry.contains("@") {
                result.append(NetworkEvent.Attendee(name: entry, email: entry.lowercased()))
            } else {
                result.append(NetworkEvent.Attendee(name: entry))
            }
        }
        return result
    }
}
