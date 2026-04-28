import Foundation

struct Goal: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String?
    var timeframe: Timeframe
    var status: Status
    var targetDate: Date?
    var createdAt: Date
    var completedAt: Date?
    var parentGoalId: UUID?

    enum Timeframe: String, Codable, CaseIterable {
        case daily, weekly, q1, q2, q3, q4, yearly

        var label: String {
            switch self {
            case .daily: return "Today"
            case .weekly: return "This Week"
            case .q1: return "Q1"
            case .q2: return "Q2"
            case .q3: return "Q3"
            case .q4: return "Q4"
            case .yearly: return "This Year"
            }
        }

        var shortLabel: String {
            switch self {
            case .daily: return "DAY"
            case .weekly: return "WEEK"
            case .q1: return "Q1"
            case .q2: return "Q2"
            case .q3: return "Q3"
            case .q4: return "Q4"
            case .yearly: return "YEAR"
            }
        }

        static var quarters: [Timeframe] { [.q1, .q2, .q3, .q4] }

        static func currentQuarter(now: Date = Date()) -> Timeframe {
            let month = Calendar.current.component(.month, from: now)
            switch month {
            case 1...3: return .q1
            case 4...6: return .q2
            case 7...9: return .q3
            default: return .q4
            }
        }
    }

    enum Status: String, Codable, CaseIterable {
        case active, completed, dropped, missed

        var label: String {
            switch self {
            case .active: return "Active"
            case .completed: return "Completed"
            case .dropped: return "Dropped"
            case .missed: return "Missed"
            }
        }
    }

    var isToday: Bool {
        guard timeframe == .daily, let target = targetDate else { return timeframe == .daily }
        return Calendar.current.isDateInToday(target) || Calendar.current.isDateInToday(createdAt)
    }
}
