import SwiftUI

struct AllContactsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var contactsService = ContactsService.shared
    @ObservedObject private var notesService = ContactNotesService.shared

    @State private var allContacts: [ContactSummary] = []
    @State private var query: String = ""
    @State private var selected: Relationship?
    @State private var loading: Bool = true

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    if loading {
                        loadingState
                    } else if filtered.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("All contacts")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(allContacts.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }
            .task {
                contactsService.invalidateIndex()
                allContacts = await contactsService.loadAllContacts()
                loading = false
            }
            .sheet(item: $selected) { rel in
                ContactDetailSheet(relationship: rel)
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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.tertiaryText)
            TextField("Search by name, role, organization", text: $query)
                .foregroundColor(EquilibriumColor.primaryText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.06))
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(filtered) { contact in
                    Button {
                        selected = Relationship.fromContact(contact)
                    } label: {
                        contactRow(contact)
                    }
                    .buttonStyle(.plain)
                }
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 16)
        }
    }

    private func contactRow(_ contact: ContactSummary) -> some View {
        let savedNote = notesService.notesByContactId[contact.id]
        return HStack(spacing: 12) {
            avatar(contact)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(1)
                if let role = contact.role {
                    Text(role)
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let followUp = savedNote?.nextFollowUp, savedNote?.status == .active {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 9))
                        Text(followUp, style: .date)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(EquilibriumColor.CardTint.network)
                }
                if savedNote?.status == .deadLead {
                    Text("DISMISSED")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                if let notes = savedNote?.notes, !notes.isEmpty {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.CardTint.network.opacity(0.7))
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func avatar(_ contact: ContactSummary) -> some View {
        ContactAvatar(
            imageData: contact.imageData,
            displayName: contact.displayName,
            size: 36
        )
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            ProgressView().tint(EquilibriumColor.CardTint.network)
            Text("Loading contacts…")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 60)
            Image(systemName: query.isEmpty ? "person.2" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(query.isEmpty ? "No contacts yet" : "No matches")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            if query.isEmpty {
                Text("Add people in iOS Contacts and they'll show up here.")
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var filtered: [ContactSummary] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return allContacts
        }
        let needle = query.lowercased()
        return allContacts.filter { contact in
            contact.displayName.lowercased().contains(needle)
                || (contact.role?.lowercased().contains(needle) ?? false)
                || (contact.organization?.lowercased().contains(needle) ?? false)
        }
    }
}
