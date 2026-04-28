import SwiftUI

struct CalendarDetailView: View {
    let snapshot: CalendarSnapshot

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()
                CalendarDayContent(snapshot: snapshot)
            }
            .navigationTitle(dateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
    }

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d"
        return f.string(from: Date())
    }
}

/// The actual day timeline — extracted so CalendarFullView can embed it without nesting NavigationStacks.
struct CalendarDayContent: View {
    let snapshot: CalendarSnapshot

    @State private var editingEvent: CalendarEventSummary?
    @State private var blockingGap: GapTarget?
    @ObservedObject private var statusService = CalendarEventStatusService.shared

    private struct GapTarget: Identifiable {
        let id = UUID()
        let start: Date
        let minutes: Int
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsHeader
                timeline
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .sheet(item: $editingEvent) { event in
            EventDetailSheet(event: event, onChange: notifyChange)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $blockingGap) { gap in
            BlockTimeSheet(
                initialStart: gap.start,
                initialDuration: min(gap.minutes, 60),
                onChange: notifyChange
            )
            .preferredColorScheme(.dark)
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .calendarDidChange, object: nil)
    }

    private var statsHeader: some View {
        HStack {
            statBlock(value: "\(snapshot.totalEventsToday)", label: "events")
            Spacer()
            statBlock(value: formattedDuration(snapshot.totalMeetingMinutesToday), label: "booked")
            Spacer()
            statBlock(value: "\(Int(snapshot.busyPercent * 100))%", label: "of workday")
        }
        .padding(16)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    @ViewBuilder
    private var timeline: some View {
        if snapshot.allEventsToday.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("TIMELINE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)

                ForEach(timelineRows, id: \.id) { row in
                    rowView(row)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No events today")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Your day is clear.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private struct TimelineRow: Identifiable {
        let id = UUID()
        enum Kind {
            case event(CalendarEventSummary)
            case gap(start: Date, minutes: Int)
        }
        let kind: Kind
    }

    private var timelineRows: [TimelineRow] {
        let timed = snapshot.allEventsToday
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        let allDay = snapshot.allEventsToday
            .filter { $0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        var rows: [TimelineRow] = []
        rows.append(contentsOf: allDay.map { TimelineRow(kind: .event($0)) })

        var cursor: Date?
        for event in timed {
            if let c = cursor, event.startDate > c {
                let gap = Int(event.startDate.timeIntervalSince(c) / 60)
                if gap >= 15 {
                    rows.append(TimelineRow(kind: .gap(start: c, minutes: gap)))
                }
            }
            rows.append(TimelineRow(kind: .event(event)))
            cursor = max(cursor ?? event.endDate, event.endDate)
        }
        return rows
    }

    @ViewBuilder
    private func rowView(_ row: TimelineRow) -> some View {
        switch row.kind {
        case .event(let event):
            Button(action: { editingEvent = event }) {
                eventRow(event)
            }
            .buttonStyle(.plain)
        case .gap(let start, let minutes):
            Button(action: { blockingGap = GapTarget(start: start, minutes: minutes) }) {
                gapRow(start: start, minutes: minutes)
            }
            .buttonStyle(.plain)
        }
    }

    private func eventRow(_ event: CalendarEventSummary) -> some View {
        let status = statusService.status(for: event.id)?.status
        return HStack(alignment: .top, spacing: 12) {
            timeColumn(event.startDate, isAllDay: event.isAllDay)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(2)
                    .strikethrough(status == .completed, color: EquilibriumColor.tertiaryText)
                if !event.isAllDay {
                    HStack(spacing: 8) {
                        Text("\(event.durationMinutes) min")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundColor(EquilibriumColor.secondaryText)
                        if event.attendeeCount > 0 {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                                .foregroundColor(EquilibriumColor.tertiaryText)
                            Text("\(event.attendeeCount)")
                                .font(.system(size: 12))
                                .monospacedDigit()
                                .foregroundColor(EquilibriumColor.secondaryText)
                        }
                    }
                }
            }

            Spacer()

            if let status = status {
                Image(systemName: status.icon)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor(status))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(12)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func statusColor(_ status: CalendarEventStatus.Status) -> Color {
        switch status {
        case .completed: return EquilibriumColor.CardTint.health
        case .missed: return Color.red.opacity(0.85)
        case .needsReschedule: return EquilibriumColor.CardTint.calendar
        }
    }

    private func gapRow(start: Date, minutes: Int) -> some View {
        HStack(spacing: 12) {
            timeColumn(start, isAllDay: false)
                .opacity(0.5)
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11, weight: .semibold))
                Text("Block \(formattedDuration(minutes))")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(EquilibriumColor.CardTint.calendar)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(EquilibriumColor.CardTint.calendar.opacity(0.25), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        )
    }

    private func timeColumn(_ date: Date, isAllDay: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isAllDay {
                Text("ALL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                Text("DAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
            } else {
                Text(date, style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
            }
        }
        .foregroundColor(EquilibriumColor.tertiaryText)
        .frame(width: 56, alignment: .leading)
    }

    private func formattedDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m) min"
    }
}
