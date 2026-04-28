import EventKit
import SwiftUI

struct EventDetailSheet: View {
    let event: CalendarEventSummary
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var durationMinutes: Int = 30
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var attendees: [String] = []
    @State private var isAllDay: Bool = false
    @State private var isLoaded: Bool = false
    @State private var saving: Bool = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @StateObject private var statusService = CalendarEventStatusService.shared

    private let durationOptions: [Int] = [15, 30, 45, 60, 75, 90, 120, 180, 240]

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if isAllDay {
                            allDayBanner
                        }

                        statusRow

                        titleSection

                        if !isAllDay {
                            timeSection
                            durationSection
                        }

                        locationSection

                        notesSection

                        if !attendees.isEmpty {
                            attendeesSection
                        }

                        deleteButton

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Event")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        if saving {
                            ProgressView().tint(EquilibriumColor.CardTint.calendar)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                                .foregroundColor(EquilibriumColor.CardTint.calendar)
                        }
                    }
                    .disabled(saving || isAllDay || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete this event?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { delete() }
            } message: {
                Text("It will be removed from your calendar.")
            }
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { hydrate() }
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.calendar.opacity(0.22),
                    EquilibriumColor.CardTint.calendar.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var allDayBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .foregroundColor(EquilibriumColor.CardTint.calendar)
            Text("All-day event — open the iOS Calendar app to edit.")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(EquilibriumColor.CardTint.calendar.opacity(0.10))
        )
    }

    // MARK: - Sections

    private var statusRow: some View {
        let current = statusService.status(for: event.id)?.status

        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader("STATUS")
            HStack(spacing: 8) {
                statusButton(.completed, current: current, tint: EquilibriumColor.CardTint.health)
                statusButton(.missed, current: current, tint: Color.red.opacity(0.85))
                statusButton(.needsReschedule, current: current, tint: EquilibriumColor.CardTint.calendar)
            }
        }
    }

    private func statusButton(
        _ status: CalendarEventStatus.Status,
        current: CalendarEventStatus.Status?,
        tint: Color
    ) -> some View {
        let isSelected = current == status
        return Button {
            if isSelected {
                statusService.clear(eventIdentifier: event.id)
            } else {
                statusService.set(eventIdentifier: event.id, status: status)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(status.label)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundColor(isSelected ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? tint : tint.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tint.opacity(isSelected ? 0 : 0.30), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TITLE")
            TextField("Event title", text: $title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .disabled(isAllDay)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("STARTS")
            DatePicker(
                "Start",
                selection: $startDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .tint(EquilibriumColor.CardTint.calendar)
            .colorScheme(.dark)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                quickShiftButton(label: "−15m", minutes: -15)
                quickShiftButton(label: "−1h", minutes: -60)
                quickShiftButton(label: "+1h", minutes: 60)
                quickShiftButton(label: "+1d", minutes: 60 * 24)
            }
        }
    }

    private func quickShiftButton(label: String, minutes: Int) -> some View {
        Button {
            startDate = startDate.addingTimeInterval(TimeInterval(minutes * 60))
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EquilibriumColor.CardTint.calendar.opacity(0.15))
                )
                .foregroundColor(EquilibriumColor.CardTint.calendar)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DURATION")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(durationOptions, id: \.self) { minutes in
                        durationChip(minutes: minutes)
                    }
                }
            }
            HStack {
                Text(durationLabel(durationMinutes))
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
                Spacer()
                Text("ends \(formattedTime(startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))))")
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
    }

    private func durationChip(minutes: Int) -> some View {
        let isSelected = durationMinutes == minutes
        return Button {
            durationMinutes = minutes
        } label: {
            Text(durationLabel(minutes))
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected
                        ? EquilibriumColor.CardTint.calendar.opacity(0.30)
                        : EquilibriumColor.primaryText.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? EquilibriumColor.CardTint.calendar.opacity(0.6) : Color.clear,
                        lineWidth: 1
                    )
                )
                .foregroundColor(isSelected ? EquilibriumColor.CardTint.calendar : EquilibriumColor.secondaryText)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("LOCATION")
            TextField("Where", text: $location)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
                .disabled(isAllDay)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("NOTES")
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...8)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
                .disabled(isAllDay)
        }
    }

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("ATTENDEES (\(attendees.count))")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(attendees, id: \.self) { person in
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(EquilibriumColor.tertiaryText)
                        Text(person)
                            .font(.system(size: 13))
                            .foregroundColor(EquilibriumColor.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(EquilibriumColor.primaryText.opacity(0.04))
            )
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete event")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.15))
            )
            .foregroundColor(Color.red)
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
        guard !isLoaded else { return }
        isLoaded = true

        if let ek = CalendarService.shared.event(withIdentifier: event.id) {
            title = ek.title ?? event.title
            startDate = ek.startDate
            durationMinutes = max(5, Int(ek.endDate.timeIntervalSince(ek.startDate) / 60))
            location = ek.location ?? ""
            notes = ek.notes ?? ""
            isAllDay = ek.isAllDay
            attendees = (ek.attendees ?? [])
                .filter { !$0.isCurrentUser }
                .map { participant in
                    let name = participant.name ?? ""
                    let url = participant.url.absoluteString
                    if !name.isEmpty { return name }
                    return url.hasPrefix("mailto:") ? String(url.dropFirst("mailto:".count)) : url
                }
        } else {
            title = event.title
            startDate = event.startDate
            durationMinutes = max(5, event.durationMinutes)
            isAllDay = event.isAllDay
        }
    }

    private func save() {
        guard !isAllDay else { return }
        saving = true
        Task {
            let success = await CalendarService.shared.updateEvent(
                id: event.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                durationMinutes: durationMinutes,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            saving = false
            if success {
                onChange()
                dismiss()
            } else {
                errorMessage = "Calendar wouldn't save the change. Make sure Equilibrium has full calendar access."
            }
        }
    }

    private func delete() {
        Task {
            let success = await CalendarService.shared.deleteEvent(id: event.id)
            if success {
                onChange()
                dismiss()
            } else {
                errorMessage = "Could not delete this event."
            }
        }
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
