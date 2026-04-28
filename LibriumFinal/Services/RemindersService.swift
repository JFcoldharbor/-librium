import EventKit
import Foundation

struct ReminderSummary: Equatable, Codable {
    let title: String
    let dueDate: Date?
    let isOverdue: Bool
    let priorityLabel: String?
    let notes: String?
}

@MainActor
final class RemindersService: ObservableObject {
    static let shared = RemindersService()

    enum AccessState {
        case unknown, denied, authorized
    }

    @Published private(set) var accessState: AccessState

    private let store = EKEventStore()

    private init() {
        accessState = Self.map(EKEventStore.authorizationStatus(for: .reminder))
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToReminders()
            accessState = granted ? .authorized : .denied
        } catch {
            accessState = .denied
        }
    }

    func createReminder(title: String, dueDate: Date? = nil, notes: String? = nil) async -> Bool {
        if accessState == .unknown {
            await requestAccess()
        }
        guard accessState == .authorized else { return false }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        if let notes, !notes.isEmpty {
            reminder.notes = notes
        }
        reminder.calendar = store.defaultCalendarForNewReminders()

        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }

    func loadActiveReminders(now: Date = Date(), limit: Int = 8) async -> [ReminderSummary] {
        guard accessState == .authorized else { return [] }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        let scored = reminders.map { reminder -> (EKReminder, Int) in
            let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
            let isOverdue = (due ?? .distantFuture) < now
            let dueToday = due.map { Calendar.current.isDateInToday($0) } ?? false
            let priority = reminder.priority

            var score = 0
            if isOverdue { score += 100 }
            if dueToday { score += 50 }
            if priority > 0 && priority < 5 { score += 30 }
            else if priority == 5 { score += 15 }
            if due != nil { score += 5 }
            return (reminder, score)
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { reminder, _ in
                let due = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                let isOverdue = (due ?? .distantFuture) < now
                return ReminderSummary(
                    title: reminder.title ?? "Untitled",
                    dueDate: due,
                    isOverdue: isOverdue,
                    priorityLabel: priorityLabel(reminder.priority),
                    notes: reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
    }

    private func priorityLabel(_ priority: Int) -> String? {
        switch priority {
        case 1...4: return "high"
        case 5: return "medium"
        case 6...9: return "low"
        default: return nil
        }
    }

    private static func map(_ status: EKAuthorizationStatus) -> AccessState {
        switch status {
        case .fullAccess, .authorized, .writeOnly: return .authorized
        case .denied, .restricted: return .denied
        default: return .unknown
        }
    }
}
