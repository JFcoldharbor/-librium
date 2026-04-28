import SwiftUI

struct BlockTimeSheet: View {
    let initialStart: Date
    let initialDuration: Int
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var startDate: Date
    @State private var durationMinutes: Int
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var saving: Bool = false
    @State private var errorMessage: String?

    private let durationOptions: [Int] = [15, 30, 45, 60, 75, 90, 120, 180]

    init(initialStart: Date, initialDuration: Int, onChange: @escaping () -> Void) {
        self.initialStart = initialStart
        self.initialDuration = initialDuration
        self.onChange = onChange
        _startDate = State(initialValue: initialStart)
        _durationMinutes = State(initialValue: max(15, min(initialDuration, 240)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        suggestionRow

                        titleSection

                        timeSection

                        durationSection

                        locationSection

                        notesSection

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
                    Text("Block this time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        if saving {
                            ProgressView().tint(EquilibriumColor.CardTint.calendar)
                        } else {
                            Text("Block")
                                .fontWeight(.semibold)
                                .foregroundColor(EquilibriumColor.CardTint.calendar)
                        }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Could not block", isPresented: Binding(
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

    private var suggestionRow: some View {
        HStack(spacing: 8) {
            ForEach(commonBlocks, id: \.self) { label in
                Button {
                    title = label
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(EquilibriumColor.CardTint.calendar.opacity(0.15))
                        )
                        .foregroundColor(EquilibriumColor.CardTint.calendar)
                }
            }
        }
    }

    private var commonBlocks: [String] {
        ["Deep work", "Sales", "Lunch", "Recovery", "Planning"]
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WHAT FOR")
            TextField("e.g. Deep work, Lunch, Planning", text: $title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
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
            TextField("Optional", text: $location)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("NOTES")
            TextField("Optional", text: $notes, axis: .vertical)
                .lineLimit(2...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    private func save() {
        saving = true
        Task {
            let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let success = await CalendarService.shared.createEvent(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                durationMinutes: durationMinutes,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            saving = false
            if success {
                onChange()
                dismiss()
            } else {
                errorMessage = "Calendar wouldn't save the new block. Check that Equilibrium has full calendar access."
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
