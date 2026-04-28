import Foundation

struct CalendarSnapshot: Equatable {
    let totalEventsToday: Int
    let totalMeetingMinutesToday: Int
    let busyPercent: Double
    let nextEvent: CalendarEventSummary?
    let firstFreeBlock: CalendarFreeBlock?
    let allEventsToday: [CalendarEventSummary]
    let asOf: Date

    static let empty = CalendarSnapshot(
        totalEventsToday: 0,
        totalMeetingMinutesToday: 0,
        busyPercent: 0,
        nextEvent: nil,
        firstFreeBlock: nil,
        allEventsToday: [],
        asOf: .distantPast
    )
}

struct CalendarEventSummary: Equatable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let attendeeCount: Int

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }
}

struct CalendarFreeBlock: Equatable {
    let start: Date
    let durationMinutes: Int
}

struct CalendarPastEvent: Equatable {
    let startDate: Date
    let endDate: Date
    let attendeeEmails: [String]
}
