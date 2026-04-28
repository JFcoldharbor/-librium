import SwiftUI

struct ImportantDatesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = ImportantDatesService.shared

    @State private var upcoming: [ImportantDate] = []
    @State private var showAddForm = false
    @State private var editingDate: ImportantDate?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        Button(action: { showAddForm = true }) {
                            Label("Add custom date", systemImage: "plus.circle")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(EquilibriumColor.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundColor(EquilibriumColor.primaryText)
                        }

                        if isLoading && upcoming.isEmpty {
                            ProgressView()
                                .padding(.top, 40)
                        } else if upcoming.isEmpty {
                            emptyState
                        } else {
                            ForEach(upcoming) { date in
                                dateRow(date)
                            }
                        }

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Important Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .task { await refresh() }
            .sheet(isPresented: $showAddForm, onDismiss: { Task { await refresh() } }) {
                ImportantDateFormView(date: nil)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $editingDate, onDismiss: { Task { await refresh() } }) { date in
                ImportantDateFormView(date: date)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func refresh() async {
        isLoading = true
        upcoming = await service.loadUpcoming(within: 365)
        isLoading = false
    }

    private func dateRow(_ date: ImportantDate) -> some View {
        let canEdit = date.source.isEditable
        return Button(action: {
            if canEdit { editingDate = date }
        }) {
            HStack(spacing: 14) {
                Text(date.icon)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(daysLabel(date.daysUntil()))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(urgencyColor(date.daysUntil()))
                        Text("·")
                            .foregroundColor(EquilibriumColor.tertiaryText)
                        Text(formatDate(date.nextOccurrence()))
                            .font(.system(size: 12))
                            .foregroundColor(EquilibriumColor.secondaryText)
                    }
                }
                Spacer()
                if !canEdit {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }
            .padding(14)
            .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canEdit)
    }

    private func daysLabel(_ days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    private func urgencyColor(_ days: Int) -> Color {
        switch days {
        case 0...3: return .red.opacity(0.85)
        case 4...7: return .orange
        case 8...14: return .yellow
        default: return EquilibriumColor.secondaryText
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No upcoming dates")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add custom dates here. Birthdays and anniversaries from your contacts appear automatically.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

private struct ImportantDateFormView: View {
    let date: ImportantDate?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = ImportantDatesService.shared

    @State private var title: String = ""
    @State private var icon: String = "📅"
    @State private var theDate: Date = Date()
    @State private var recurrence: ImportantDate.Recurrence = .yearly
    @State private var relatedContactName: String = ""
    @State private var note: String = ""

    private let iconOptions = ["📅", "🎂", "💍", "🎉", "🎁", "🏆", "📍", "⚖️", "💼", "❤️", "🌟"]

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                Form {
                    Section("Date") {
                        TextField("Title (e.g. Wife's anniversary)", text: $title)
                        DatePicker("Date", selection: $theDate, displayedComponents: .date)
                        Picker("Recurrence", selection: $recurrence) {
                            ForEach(ImportantDate.Recurrence.allCases, id: \.self) { r in
                                Text(r.label).tag(r)
                            }
                        }
                    }

                    Section("Icon") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(iconOptions, id: \.self) { option in
                                    Button(action: { icon = option }) {
                                        Text(option)
                                            .font(.system(size: 28))
                                            .padding(8)
                                            .background(
                                                icon == option
                                                    ? EquilibriumColor.accent.opacity(0.3)
                                                    : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Related contact (optional)") {
                        TextField("Name", text: $relatedContactName)
                    }

                    Section("Note (optional)") {
                        TextField("Anything Maria should know", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if date != nil {
                        Section {
                            Button("Delete date", role: .destructive) {
                                if let id = date?.id {
                                    service.delete(id: id)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(date == nil ? "Add date" : "Edit date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(EquilibriumColor.primaryText)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let d = date else { return }
        title = d.title
        icon = d.icon
        theDate = d.date
        recurrence = d.recurrence
        relatedContactName = d.relatedContactName ?? ""
        note = d.note ?? ""
    }

    private func save() {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = relatedContactName.trimmingCharacters(in: .whitespaces)
        let item = ImportantDate(
            id: date?.id ?? "user-\(UUID().uuidString)",
            title: title.trimmingCharacters(in: .whitespaces),
            date: theDate,
            recurrence: recurrence,
            source: .userEntered,
            relatedContactName: trimmedContact.isEmpty ? nil : trimmedContact,
            relatedContactId: nil,
            icon: icon,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        service.upsert(item)
        dismiss()
    }
}
