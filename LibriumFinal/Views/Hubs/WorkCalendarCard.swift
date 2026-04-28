import SwiftUI

struct WorkCalendarCard: View {
    let snapshot: CalendarSnapshot
    let accessState: CalendarService.AccessState
    @State private var showDetail = false
    @State private var editingEvent: CalendarEventSummary?
    @State private var blockingFreeTime: CalendarFreeBlock?
    @State private var now: Date = Date()
    @ObservedObject private var statusService = CalendarEventStatusService.shared

    private let nowTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            background

            VStack(spacing: 24) {
                header

                switch accessState {
                case .unknown:
                    awaitingAccessState
                case .denied:
                    deniedState
                case .authorized:
                    authorizedContent
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 80)
        }
        .overlay(alignment: .topTrailing) {
            if accessState == .authorized {
                Button(action: { showDetail = true }) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(EquilibriumColor.CardTint.calendar.opacity(0.8))
                }
                .padding(.top, 80)
                .padding(.trailing, 24)
            }
        }
        .onReceive(nowTimer) { now = $0 }
        .sheet(isPresented: $showDetail) {
            CalendarFullView(snapshot: snapshot)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingEvent) { event in
            EventDetailSheet(event: event, onChange: notifyChange)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $blockingFreeTime) { block in
            BlockTimeSheet(
                initialStart: block.start,
                initialDuration: min(block.durationMinutes, 60),
                onChange: notifyChange
            )
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.calendar.opacity(0.32),
                    EquilibriumColor.CardTint.calendar.opacity(0.08),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 60,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("CALENDAR")
                .font(.system(size: 11, weight: .bold))
                .tracking(2.5)
                .foregroundColor(EquilibriumColor.CardTint.calendar)
            Text(dateLabel)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text(busyLabel)
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }

    // MARK: - Authorized

    private var authorizedContent: some View {
        VStack(spacing: 28) {
            DayDial(
                events: snapshot.allEventsToday,
                now: now,
                tint: EquilibriumColor.CardTint.calendar
            )

            upcomingSection
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if let next = snapshot.nextEvent {
            VStack(spacing: 8) {
                ForEach(upcomingEvents) { event in
                    Button(action: { editingEvent = event }) {
                        upcomingRow(event)
                    }
                    .buttonStyle(.plain)
                }
                if let free = snapshot.firstFreeBlock, isFreeBlockNotable(free, after: next) {
                    Button(action: { blockingFreeTime = free }) {
                        freeBlockRow(free)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if let free = snapshot.firstFreeBlock {
            Button(action: { blockingFreeTime = free }) {
                freeBlockRow(free)
            }
            .buttonStyle(.plain)
        } else {
            Text("Nothing scheduled.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    private func upcomingRow(_ event: CalendarEventSummary) -> some View {
        let countdown = countdownLabel(to: event.startDate)
        let isLive = event.startDate <= now && now < event.endDate
        let status = statusService.status(for: event.id)?.status
        return HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(timeOnly(event.startDate))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
                Text(amPm(event.startDate))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            .frame(width: 48)

            Rectangle()
                .fill(isLive ? EquilibriumColor.CardTint.calendar : EquilibriumColor.CardTint.calendar.opacity(0.4))
                .frame(width: 2)
                .frame(height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                        .strikethrough(status == .completed, color: EquilibriumColor.tertiaryText)
                    if isLive {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(EquilibriumColor.CardTint.calendar.opacity(0.3)))
                            .foregroundColor(EquilibriumColor.CardTint.calendar)
                    }
                }
                Text(rowSubtitle(event, countdown: countdown, isLive: isLive))
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if let status = status {
                Image(systemName: status.icon)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor(status))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(EquilibriumColor.CardTint.calendar.opacity(isLive ? 0.4 : 0.12), lineWidth: 0.5)
                )
        )
    }

    private func freeBlockRow(_ free: CalendarFreeBlock) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(timeOnly(free.start))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                Text(amPm(free.start))
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(EquilibriumColor.CardTint.calendar)
            .frame(width: 48)

            Image(systemName: "plus.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EquilibriumColor.CardTint.calendar)

            Text("Block \(formattedDuration(free.durationMinutes))")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(EquilibriumColor.CardTint.calendar)

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(EquilibriumColor.CardTint.calendar.opacity(0.30), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        )
    }

    // MARK: - States

    private var awaitingAccessState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            ProgressView().tint(EquilibriumColor.CardTint.calendar)
            Text("Loading…")
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("Calendar access off")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Settings → Equilibrium → Calendars")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }

    // MARK: - Helpers

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: now)
    }

    private var busyLabel: String {
        if snapshot.totalEventsToday == 0 { return "Day's clear" }
        let pct = Int(snapshot.busyPercent * 100)
        let hours = snapshot.totalMeetingMinutesToday / 60
        let minutes = snapshot.totalMeetingMinutesToday % 60
        let durLabel = hours > 0
            ? (minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h")
            : "\(minutes)m"
        return "\(durLabel) booked · \(pct)% of workday"
    }

    private var upcomingEvents: [CalendarEventSummary] {
        snapshot.allEventsToday
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { $0 }
    }

    private func isFreeBlockNotable(_ free: CalendarFreeBlock, after next: CalendarEventSummary) -> Bool {
        free.start > next.endDate && free.durationMinutes >= 30
    }

    private func countdownLabel(to date: Date) -> String {
        let interval = date.timeIntervalSince(now)
        if interval < 0 { return "started" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let m = minutes % 60
        return m == 0 ? "in \(hours)h" : "in \(hours)h \(m)m"
    }

    private func rowSubtitle(_ event: CalendarEventSummary, countdown: String, isLive: Bool) -> String {
        let attendeesPart = event.attendeeCount > 1 ? " · \(event.attendeeCount) people" : ""
        if isLive {
            let endsIn = max(0, Int(event.endDate.timeIntervalSince(now) / 60))
            return "ends in \(endsIn)m\(attendeesPart)"
        }
        return "\(countdown) · \(event.durationMinutes)m\(attendeesPart)"
    }

    private func timeOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: date)
    }

    private func amPm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: date).lowercased()
    }

    private func formattedDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .calendarDidChange, object: nil)
    }

    private func statusColor(_ status: CalendarEventStatus.Status) -> Color {
        switch status {
        case .completed: return EquilibriumColor.CardTint.health
        case .missed: return Color.red.opacity(0.85)
        case .needsReschedule: return EquilibriumColor.CardTint.calendar
        }
    }
}

extension Notification.Name {
    static let calendarDidChange = Notification.Name("equilibrium.calendar.didChange")
}

extension CalendarFreeBlock: Identifiable {
    public var id: String { "free-\(Int(start.timeIntervalSince1970))" }
}
