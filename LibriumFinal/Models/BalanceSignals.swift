import Foundation

struct BalanceSignals {
    let calendar: CalendarSnapshot
    let relationships: RelationshipSnapshot
    let journal: JournalEntry
    let wellness: WellnessLog
    let health: HealthSnapshot
    let reminders: [ReminderSummary]
    let obligationsDueSoon: [Obligation]
    let totalDueWithin7: Double
    let totalDueWithin30: Double
    let incomeSources: [IncomeSource]
    let activeDeals: [PipelineDeal]
    let totalPipelineValue: Double
    let totalWeightedValue: Double
    let activeProjects: [Project]
    let upcomingDates: [ImportantDate]
    let breathingMinutesToday: Int
    let breathingCyclesToday: Int
    let journalStreak: Int

    static let empty = BalanceSignals(
        calendar: .empty,
        relationships: .empty,
        journal: .makeForToday(),
        wellness: .makeForToday(),
        health: .empty,
        reminders: [],
        obligationsDueSoon: [],
        totalDueWithin7: 0,
        totalDueWithin30: 0,
        incomeSources: [],
        activeDeals: [],
        totalPipelineValue: 0,
        totalWeightedValue: 0,
        activeProjects: [],
        upcomingDates: [],
        breathingMinutesToday: 0,
        breathingCyclesToday: 0,
        journalStreak: 0
    )
}
