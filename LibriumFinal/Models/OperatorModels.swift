import Foundation

// MARK: - Obligations

struct Obligation: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var amount: Double
    var dueDate: Date
    var recurrence: Recurrence
    var category: Category
    var consequencesIfMissed: String?
    var isPaidThisCycle: Bool

    enum Recurrence: String, Codable, CaseIterable {
        case once, weekly, biweekly, monthly, quarterly, yearly

        var label: String {
            switch self {
            case .once: return "One-time"
            case .weekly: return "Weekly"
            case .biweekly: return "Biweekly"
            case .monthly: return "Monthly"
            case .quarterly: return "Quarterly"
            case .yearly: return "Yearly"
            }
        }

        func nextDate(after date: Date) -> Date? {
            let cal = Calendar.current
            switch self {
            case .once: return nil
            case .weekly: return cal.date(byAdding: .day, value: 7, to: date)
            case .biweekly: return cal.date(byAdding: .day, value: 14, to: date)
            case .monthly: return cal.date(byAdding: .month, value: 1, to: date)
            case .quarterly: return cal.date(byAdding: .month, value: 3, to: date)
            case .yearly: return cal.date(byAdding: .year, value: 1, to: date)
            }
        }
    }

    enum Category: String, Codable, CaseIterable {
        case housing, utilities, debt, subscription, transportation, food, healthcare, insurance, taxes, other

        var label: String {
            switch self {
            case .housing: return "Housing"
            case .utilities: return "Utilities"
            case .debt: return "Debt"
            case .subscription: return "Subscription"
            case .transportation: return "Transportation"
            case .food: return "Food"
            case .healthcare: return "Healthcare"
            case .insurance: return "Insurance"
            case .taxes: return "Taxes"
            case .other: return "Other"
            }
        }
    }

    func daysUntilDue(now: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.startOfDay(for: dueDate)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    var isOverdue: Bool {
        !isPaidThisCycle && dueDate < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Income Sources

struct IncomeSource: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var type: IncomeType
    var typicalRate: Double
    var rateUnit: RateUnit
    var reliability: Reliability
    var monthlyFrequency: Int?
    var notes: String?

    var monthlyEstimate: Double {
        switch rateUnit {
        case .hourly:
            let freq = max(0, monthlyFrequency ?? 0)
            return typicalRate * Double(freq)
        case .perGig:
            let freq = max(0, monthlyFrequency ?? 0)
            return typicalRate * Double(freq)
        case .monthly:
            return typicalRate
        case .biweekly:
            return typicalRate * 2.17
        case .oneTime:
            return 0
        }
    }

    var monthlyEstimateLabel: String {
        let value = monthlyEstimate
        switch rateUnit {
        case .hourly:
            let freq = monthlyFrequency ?? 0
            if freq == 0 { return "Set hours/month for monthly tally" }
        case .perGig:
            let freq = monthlyFrequency ?? 0
            if freq == 0 { return "Set gigs/month for monthly tally" }
        case .oneTime:
            return "One-time"
        default: break
        }
        return "≈ $\(Int(value))/mo"
    }

    enum IncomeType: String, Codable, CaseIterable {
        case gig, client, salary, project, passive

        var label: String {
            switch self {
            case .gig: return "Gig"
            case .client: return "Client"
            case .salary: return "Salary"
            case .project: return "Project"
            case .passive: return "Passive"
            }
        }
    }

    enum RateUnit: String, Codable, CaseIterable {
        case hourly, perGig, monthly, biweekly, oneTime

        var label: String {
            switch self {
            case .hourly: return "per hour"
            case .perGig: return "per gig"
            case .monthly: return "per month"
            case .biweekly: return "biweekly"
            case .oneTime: return "one-time total"
            }
        }
    }

    enum Reliability: String, Codable, CaseIterable {
        case immediate, daysOut, weekly, biweekly, monthly, projectBased

        var label: String {
            switch self {
            case .immediate: return "Cash now (same day)"
            case .daysOut: return "A few days"
            case .weekly: return "Weekly"
            case .biweekly: return "Biweekly"
            case .monthly: return "Monthly"
            case .projectBased: return "When project closes"
            }
        }
    }
}

// MARK: - Pipeline Deals

struct PipelineDeal: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var contactName: String
    var contactEmail: String?
    var stage: Stage
    var dealValue: Double
    var probability: Double
    var nextAction: String?
    var nextActionDate: Date?
    var lastContact: Date?
    var notes: String?
    var createdAt: Date

    enum Stage: String, Codable, CaseIterable {
        case lead, qualified, proposal, negotiation, closedWon, closedLost

        var label: String {
            switch self {
            case .lead: return "Lead"
            case .qualified: return "Qualified"
            case .proposal: return "Proposal"
            case .negotiation: return "Negotiation"
            case .closedWon: return "Closed Won"
            case .closedLost: return "Closed Lost"
            }
        }

        var isActive: Bool {
            switch self {
            case .closedWon, .closedLost: return false
            default: return true
            }
        }
    }

    var weightedValue: Double { dealValue * probability }
}

// MARK: - Projects

struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var detail: String?
    var deadline: Date?
    var status: Status
    var milestones: [Milestone]
    var createdAt: Date

    enum Status: String, Codable, CaseIterable {
        case active, paused, completed, dropped

        var label: String {
            switch self {
            case .active: return "Active"
            case .paused: return "Paused"
            case .completed: return "Completed"
            case .dropped: return "Dropped"
            }
        }
    }

    struct Milestone: Codable, Identifiable, Equatable {
        let id: UUID
        var name: String
        var dueDate: Date?
        var isCompleted: Bool
    }

    var completedMilestones: Int { milestones.filter { $0.isCompleted }.count }
}
