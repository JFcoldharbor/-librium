import Foundation

struct CalendarEventStatus: Codable, Equatable, Identifiable {
    var id: String { eventIdentifier }
    let eventIdentifier: String
    var status: Status
    var statusSetAt: Date
    var note: String?

    enum Status: String, Codable, CaseIterable {
        case completed
        case missed
        case needsReschedule

        var label: String {
            switch self {
            case .completed: return "Done"
            case .missed: return "Missed"
            case .needsReschedule: return "Reschedule"
            }
        }

        var icon: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .missed: return "xmark.circle.fill"
            case .needsReschedule: return "arrow.clockwise.circle.fill"
            }
        }
    }
}
