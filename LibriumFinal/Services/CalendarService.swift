import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    enum AccessState {
        case unknown, denied, authorized
    }

    @Published private(set) var accessState: AccessState

    private let store = EKEventStore()
    private let workdayStartHour = 9
    private let workdayEndHour = 18

    private init() {
        accessState = Self.map(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            accessState = granted ? .authorized : .denied
        } catch {
            accessState = .denied
        }
    }

    func loadTodaysSnapshot(now: Date = Date()) async -> CalendarSnapshot {
        guard accessState == .authorized else { return .empty }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return .empty
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        let timedEvents = events.filter { !$0.isAllDay }
        let totalMinutes = timedEvents.reduce(0) { acc, ev in
            acc + Int(ev.endDate.timeIntervalSince(ev.startDate) / 60)
        }

        let workdayMinutes = (workdayEndHour - workdayStartHour) * 60
        let busyPercent = workdayMinutes > 0
            ? min(1.0, Double(totalMinutes) / Double(workdayMinutes))
            : 0

        let nextEvent = events.first { $0.endDate > now && !$0.isAllDay }

        return CalendarSnapshot(
            totalEventsToday: events.count,
            totalMeetingMinutesToday: totalMinutes,
            busyPercent: busyPercent,
            nextEvent: nextEvent.map(Self.summarize),
            firstFreeBlock: Self.firstFreeBlock(after: now, in: timedEvents, workdayEndHour: workdayEndHour),
            allEventsToday: events.map(Self.summarize),
            asOf: now
        )
    }

    // MARK: - Write actions

    func findTodaysEvent(matching title: String, near hintTime: Date? = nil, now: Date = Date()) -> EKEvent? {
        guard accessState == .authorized else { return nil }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
        let needle = title.lowercased()
        let matches = events.filter { ($0.title ?? "").lowercased().contains(needle) }

        if matches.count == 1 { return matches.first }
        if let hintTime, !matches.isEmpty {
            return matches.min { abs($0.startDate.timeIntervalSince(hintTime)) < abs($1.startDate.timeIntervalSince(hintTime)) }
        }
        return matches.first
    }

    enum EventRecurrence: String {
        case none, daily, weekdays, weekly
    }

    @discardableResult
    func createEvent(
        title: String,
        startDate: Date,
        durationMinutes: Int,
        location: String? = nil,
        notes: String? = nil,
        recurrence: EventRecurrence = .none,
        recurrenceEndDate: Date? = nil
    ) async -> Bool {
        if accessState == .unknown {
            await requestAccess()
        }
        guard accessState == .authorized else { return false }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(max(5, durationMinutes) * 60))
        if let location, !location.isEmpty { event.location = location }
        if let notes, !notes.isEmpty { event.notes = notes }
        event.calendar = store.defaultCalendarForNewEvents

        if let rule = Self.makeRecurrenceRule(recurrence, endDate: recurrenceEndDate) {
            event.recurrenceRules = [rule]
        }

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    private static func makeRecurrenceRule(_ recurrence: EventRecurrence, endDate: Date?) -> EKRecurrenceRule? {
        let end = endDate.map { EKRecurrenceEnd(end: $0) }
        switch recurrence {
        case .none:
            return nil
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: end)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: end)
        case .weekdays:
            let weekdays: [EKRecurrenceDayOfWeek] = [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)]
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: weekdays,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end
            )
        }
    }

    @discardableResult
    func moveEvent(matchingTitle title: String, near hintTime: Date? = nil, newStartDate: Date) async -> Bool {
        guard accessState == .authorized,
              let event = findTodaysEvent(matching: title, near: hintTime) else {
            return false
        }
        let duration = event.endDate.timeIntervalSince(event.startDate)
        event.startDate = newStartDate
        event.endDate = newStartDate.addingTimeInterval(duration)
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func deleteEvent(matchingTitle title: String, near hintTime: Date? = nil) async -> Bool {
        guard accessState == .authorized,
              let event = findTodaysEvent(matching: title, near: hintTime) else {
            return false
        }
        do {
            try store.remove(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Direct edit by event ID

    func event(withIdentifier id: String) -> EKEvent? {
        guard accessState == .authorized else { return nil }
        return store.event(withIdentifier: id)
    }

    @discardableResult
    func updateEvent(
        id: String,
        title: String,
        startDate: Date,
        durationMinutes: Int,
        location: String?,
        notes: String?
    ) async -> Bool {
        guard accessState == .authorized,
              let event = store.event(withIdentifier: id) else {
            return false
        }
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(max(5, durationMinutes) * 60))
        event.location = (location?.isEmpty == false) ? location : nil
        event.notes = (notes?.isEmpty == false) ? notes : nil
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func deleteEvent(id: String) async -> Bool {
        guard accessState == .authorized,
              let event = store.event(withIdentifier: id) else {
            return false
        }
        do {
            try store.remove(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    /// Generic windowed query — events that intersect [start, end). Used by Maria's events_in_window tool
    /// and by week / month UI surfaces.
    func eventsInWindow(start: Date, end: Date) -> [CalendarEventSummary] {
        guard accessState == .authorized, end > start else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map(Self.summarize)
    }

    /// Move an event by its EventKit identifier. Preferred over title-matching when Maria already has the id.
    @discardableResult
    func moveEvent(id: String, newStartDate: Date, durationMinutes: Int? = nil) async -> Bool {
        guard accessState == .authorized,
              let event = store.event(withIdentifier: id) else {
            return false
        }
        let duration = durationMinutes.map { TimeInterval(max(5, $0) * 60) } ?? event.endDate.timeIntervalSince(event.startDate)
        event.startDate = newStartDate
        event.endDate = newStartDate.addingTimeInterval(duration)
        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    func eventsInPast(days: Int, now: Date = Date()) async -> [CalendarPastEvent] {
        guard accessState == .authorized else { return [] }

        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: start, end: now, calendars: nil)
        return store.events(matching: predicate).map { event in
            let emails: [String] = (event.attendees ?? [])
                .filter { !$0.isCurrentUser }
                .compactMap { participant -> String? in
                    let url = participant.url
                    guard url.scheme == "mailto" else { return nil }
                    return String(url.absoluteString.dropFirst("mailto:".count)).lowercased()
                }
            return CalendarPastEvent(
                startDate: event.startDate,
                endDate: event.endDate,
                attendeeEmails: emails
            )
        }
    }

    private static func map(_ status: EKAuthorizationStatus) -> AccessState {
        switch status {
        case .fullAccess, .writeOnly: return .authorized
        case .denied, .restricted: return .denied
        default: return .unknown
        }
    }

    private static func summarize(_ event: EKEvent) -> CalendarEventSummary {
        CalendarEventSummary(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Untitled",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            attendeeCount: event.attendees?.count ?? 0
        )
    }

    private static func firstFreeBlock(after now: Date, in events: [EKEvent], workdayEndHour: Int) -> CalendarFreeBlock? {
        let calendar = Calendar.current
        guard let endOfWorkday = calendar.date(bySettingHour: workdayEndHour, minute: 0, second: 0, of: now),
              endOfWorkday > now else {
            return nil
        }

        let upcoming = events.filter { $0.endDate > now }.sorted { $0.startDate < $1.startDate }
        var cursor = now

        for event in upcoming {
            if event.startDate > cursor {
                let gap = Int(event.startDate.timeIntervalSince(cursor) / 60)
                if gap >= 30 {
                    return CalendarFreeBlock(start: cursor, durationMinutes: gap)
                }
            }
            cursor = max(cursor, event.endDate)
        }

        let remainingMinutes = Int(endOfWorkday.timeIntervalSince(cursor) / 60)
        if remainingMinutes >= 30 {
            return CalendarFreeBlock(start: cursor, durationMinutes: remainingMinutes)
        }
        return nil
    }
}
