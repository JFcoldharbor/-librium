import Foundation

struct ImportantDate: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let date: Date
    let recurrence: Recurrence
    let source: Source
    let relatedContactName: String?
    let relatedContactId: String?
    let icon: String
    let note: String?

    enum Recurrence: String, Codable, CaseIterable {
        case once, yearly

        var label: String {
            switch self {
            case .once: return "One-time"
            case .yearly: return "Yearly"
            }
        }
    }

    enum Source: String, Codable {
        case contactBirthday
        case contactAnniversary
        case contactCustomDate
        case userEntered
        case projectDeadline

        var label: String {
            switch self {
            case .contactBirthday: return "Birthday"
            case .contactAnniversary: return "Anniversary"
            case .contactCustomDate: return "Contact date"
            case .userEntered: return "Custom"
            case .projectDeadline: return "Project deadline"
            }
        }

        var isEditable: Bool {
            self == .userEntered
        }
    }

    func nextOccurrence(now: Date = Date()) -> Date {
        switch recurrence {
        case .once:
            return date
        case .yearly:
            let cal = Calendar.current
            var components = cal.dateComponents([.month, .day], from: date)
            components.year = cal.component(.year, from: now)
            guard var next = cal.date(from: components) else { return date }
            if next < cal.startOfDay(for: now) {
                next = cal.date(byAdding: .year, value: 1, to: next) ?? next
            }
            return next
        }
    }

    func daysUntil(now: Date = Date()) -> Int {
        let cal = Calendar.current
        let next = nextOccurrence(now: now)
        return cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: next)).day ?? 0
    }
}
