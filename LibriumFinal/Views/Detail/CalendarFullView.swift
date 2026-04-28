import SwiftUI

struct CalendarFullView: View {
    let snapshot: CalendarSnapshot

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .day
    @State private var anchorDate: Date = Date()
    @State private var editingEvent: CalendarEventSummary?
    @State private var blockingStart: Date?

    enum Mode: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    Group {
                        switch mode {
                        case .day:
                            CalendarDayContent(snapshot: snapshot)
                        case .week:
                            CalendarWeekContent(anchorDate: $anchorDate, onTapEvent: { editingEvent = $0 })
                        case .month:
                            CalendarMonthContent(anchorDate: $anchorDate, onTapDay: { date in
                                anchorDate = date
                                mode = .week
                            })
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(headerTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .sheet(item: $editingEvent) { event in
                EventDetailSheet(event: event, onChange: notifyChange)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var headerTitle: String {
        let f = DateFormatter()
        switch mode {
        case .day:
            f.dateFormat = "EEE · MMM d"
        case .week:
            f.dateFormat = "MMM d"
            let interval = weekInterval(for: anchorDate)
            return "\(f.string(from: interval.start)) – \(f.string(from: interval.end))"
        case .month:
            f.dateFormat = "MMMM yyyy"
        }
        return f.string(from: anchorDate)
    }

    private func weekInterval(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let daysFromSunday = weekday - 1
        let start = cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: date)) ?? date
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .calendarDidChange, object: nil)
    }
}

// MARK: - Week

private struct CalendarWeekContent: View {
    @Binding var anchorDate: Date
    let onTapEvent: (CalendarEventSummary) -> Void

    @State private var events: [CalendarEventSummary] = []
    @State private var hourHeight: CGFloat = 72
    @State private var pinchAnchorHeight: CGFloat = 72
    @State private var priorityTarget: CalendarEventSummary?
    @ObservedObject private var priorityService = EventPriorityService.shared

    private let dayLabelHeight: CGFloat = 44
    private let hourLabelWidth: CGFloat = 44
    private let startHour: Int = 5
    private let endHour: Int = 23
    private let minHourHeight: CGFloat = 36
    private let maxHourHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            navHeader
            zoomControls
            ScrollView([.vertical]) {
                ZStack(alignment: .topLeading) {
                    timeGrid
                    eventsLayer
                }
                .padding(.bottom, 60)
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        let proposed = pinchAnchorHeight * scale
                        hourHeight = max(minHourHeight, min(maxHourHeight, proposed))
                    }
                    .onEnded { _ in
                        pinchAnchorHeight = hourHeight
                    }
            )
        }
        .task(id: anchorDate) { await loadEvents() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarDidChange)) { _ in
            Task { await loadEvents() }
        }
        .confirmationDialog(
            priorityTarget?.title ?? "",
            isPresented: Binding(
                get: { priorityTarget != nil },
                set: { if !$0 { priorityTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(EventPriority.Level.allCases, id: \.self) { level in
                Button(level.label) {
                    if let target = priorityTarget {
                        priorityService.set(eventIdentifier: target.id, level: level)
                    }
                    priorityTarget = nil
                }
            }
            if let target = priorityTarget, priorityService.priority(for: target.id) != nil {
                Button("Clear priority", role: .destructive) {
                    priorityService.clear(eventIdentifier: target.id)
                    priorityTarget = nil
                }
            }
            Button("Open event") {
                if let target = priorityTarget {
                    onTapEvent(target)
                }
                priorityTarget = nil
            }
            Button("Cancel", role: .cancel) { priorityTarget = nil }
        } message: {
            Text("Set priority — Maria uses this when rearranging your schedule.")
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Spacer()
            Button {
                hourHeight = max(minHourHeight, hourHeight - 12)
                pinchAnchorHeight = hourHeight
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
            }
            Text("\(Int(hourHeight))px/hr")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.tertiaryText)
                .frame(width: 56)
            Button {
                hourHeight = min(maxHourHeight, hourHeight + 12)
                pinchAnchorHeight = hourHeight
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .foregroundColor(EquilibriumColor.secondaryText)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    private var navHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Button { shiftWeeks(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Button { anchorDate = Date() } label: {
                    Text("Today").font(.system(size: 12, weight: .semibold))
                }
                Spacer()
                Button { shiftWeeks(1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundColor(EquilibriumColor.secondaryText)
            .padding(.horizontal, 24)

            HStack(spacing: 0) {
                Color.clear.frame(width: hourLabelWidth)
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 2) {
                        Text(weekdayLabel(date).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(EquilibriumColor.tertiaryText)
                        Text(dayNumberLabel(date))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Calendar.current.isDateInToday(date) ? EquilibriumColor.CardTint.calendar : EquilibriumColor.primaryText)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle().fill(Calendar.current.isDateInToday(date) ? EquilibriumColor.CardTint.calendar.opacity(0.18) : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: dayLabelHeight)
        }
    }

    private var timeGrid: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                HStack(spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .frame(width: hourLabelWidth, alignment: .trailing)
                        .padding(.trailing, 4)
                        .offset(y: -6)

                    HStack(spacing: 0) {
                        ForEach(weekDays, id: \.self) { _ in
                            Rectangle()
                                .fill(EquilibriumColor.primaryText.opacity(0.04))
                                .overlay(
                                    Rectangle()
                                        .fill(EquilibriumColor.primaryText.opacity(0.08))
                                        .frame(height: 0.5),
                                    alignment: .top
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: hourHeight)
                        }
                    }
                }
            }
        }
    }

    private var eventsLayer: some View {
        GeometryReader { proxy in
            let usable = proxy.size.width - hourLabelWidth
            let dayWidth = usable / 7
            ForEach(events.filter { !$0.isAllDay }, id: \.id) { event in
                let dayIdx = dayIndex(for: event.startDate)
                let (yOffset, height) = verticalRange(for: event)
                let level = priorityService.priority(for: event.id)
                let blockColor = level?.color ?? EquilibriumColor.CardTint.calendar
                if dayIdx >= 0 && dayIdx < 7 {
                    Button(action: { priorityTarget = event }) {
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(blockColor)
                                .frame(width: 3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .lineLimit(2)
                                Text(timeRangeLabel(event))
                                    .font(.system(size: 9))
                                    .monospacedDigit()
                                    .opacity(0.85)
                                if let level {
                                    Text(level.shortLabel)
                                        .font(.system(size: 8, weight: .heavy))
                                        .tracking(0.8)
                                        .foregroundColor(blockColor)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .foregroundColor(EquilibriumColor.primaryText)
                        }
                        .frame(width: max(dayWidth - 4, 0), height: max(height - 2, 22), alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(blockColor.opacity(0.30))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .offset(x: hourLabelWidth + dayWidth * CGFloat(dayIdx) + 1, y: yOffset)
                }
            }
        }
    }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: anchorDate)
        let daysFromSunday = weekday - 1
        let start = cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: anchorDate)) ?? anchorDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayIndex(for date: Date) -> Int {
        let cal = Calendar.current
        guard let weekStart = weekDays.first else { return -1 }
        return cal.dateComponents([.day], from: cal.startOfDay(for: weekStart), to: cal.startOfDay(for: date)).day ?? -1
    }

    private func verticalRange(for event: CalendarEventSummary) -> (CGFloat, CGFloat) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: event.startDate)
        let startH = Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
        let durationH = max(0.25, event.endDate.timeIntervalSince(event.startDate) / 3600)
        let topOffset = (startH - Double(startHour)) * Double(hourHeight)
        let height = durationH * Double(hourHeight)
        return (CGFloat(topOffset), CGFloat(height))
    }

    private func timeRangeLabel(_ event: CalendarEventSummary) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return "\(f.string(from: event.startDate))–\(f.string(from: event.endDate))"
    }

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "am" : "pm"
        return "\(h)\(suffix)"
    }

    private func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func dayNumberLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func shiftWeeks(_ delta: Int) {
        let cal = Calendar.current
        if let new = cal.date(byAdding: .day, value: delta * 7, to: anchorDate) {
            anchorDate = new
        }
    }

    @MainActor
    private func loadEvents() async {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: anchorDate)
        let daysFromSunday = weekday - 1
        guard let start = cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: anchorDate)),
              let end = cal.date(byAdding: .day, value: 7, to: start) else { return }
        events = CalendarService.shared.eventsInWindow(start: start, end: end)
    }
}

// MARK: - Month

private struct CalendarMonthContent: View {
    @Binding var anchorDate: Date
    let onTapDay: (Date) -> Void

    @State private var counts: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 12) {
            navHeader

            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(monthGrid, id: \.id) { cell in
                    dayCell(cell)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .task(id: monthKey) { await loadCounts() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarDidChange)) { _ in
            Task { await loadCounts() }
        }
    }

    private var navHeader: some View {
        HStack {
            Button { shiftMonths(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Button { anchorDate = Date() } label: {
                Text("Today").font(.system(size: 12, weight: .semibold))
            }
            Spacer()
            Button { shiftMonths(1) } label: { Image(systemName: "chevron.right") }
        }
        .foregroundColor(EquilibriumColor.secondaryText)
        .padding(.horizontal, 24)
    }

    private struct DayCell: Identifiable {
        let id = UUID()
        let date: Date?
    }

    private var monthGrid: [DayCell] {
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: anchorDate)) else { return [] }
        let weekday = cal.component(.weekday, from: monthStart)
        let leading = weekday - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var cells: [DayCell] = []
        for _ in 0..<leading { cells.append(DayCell(date: nil)) }
        for day in 1...daysInMonth {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(DayCell(date: d))
            }
        }
        // Pad to a full multiple of 7 for grid alignment
        while cells.count % 7 != 0 { cells.append(DayCell(date: nil)) }
        return cells
    }

    @ViewBuilder
    private func dayCell(_ cell: DayCell) -> some View {
        if let date = cell.date {
            let key = Self.dayKey(date)
            let count = counts[key] ?? 0
            let isToday = Calendar.current.isDateInToday(date)
            Button(action: { onTapDay(date) }) {
                VStack(spacing: 4) {
                    Text(dayNumber(date))
                        .font(.system(size: 13, weight: isToday ? .bold : .medium))
                        .foregroundColor(isToday ? EquilibriumColor.CardTint.calendar : EquilibriumColor.primaryText)
                    if count > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<min(count, 3), id: \.self) { _ in
                                Circle()
                                    .fill(EquilibriumColor.CardTint.calendar.opacity(0.7))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    } else {
                        Spacer().frame(height: 4)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isToday ? EquilibriumColor.CardTint.calendar.opacity(0.12) : EquilibriumColor.primaryText.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(minHeight: 48)
        }
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private var monthKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: anchorDate)
    }

    private func shiftMonths(_ delta: Int) {
        let cal = Calendar.current
        if let new = cal.date(byAdding: .month, value: delta, to: anchorDate) {
            anchorDate = new
        }
    }

    @MainActor
    private func loadCounts() async {
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: anchorDate)),
              let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else { return }
        let events = CalendarService.shared.eventsInWindow(start: monthStart, end: monthEnd)
        var tally: [String: Int] = [:]
        for event in events {
            let key = Self.dayKey(event.startDate)
            tally[key, default: 0] += 1
        }
        counts = tally
    }
}
