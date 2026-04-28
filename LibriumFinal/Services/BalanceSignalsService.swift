import Foundation

@MainActor
final class BalanceSignalsService {
    static let shared = BalanceSignalsService()

    private let calendarService: CalendarService
    private let relationshipService: RelationshipService
    private let journalService: JournalService
    private let breathingService: BreathingHistoryService
    private let wellnessService: WellnessLogService
    private let healthKitService: HealthKitService
    private let remindersService: RemindersService
    private let obligationsService: ObligationsService
    private let incomeSourcesService: IncomeSourcesService
    private let pipelineService: PipelineService
    private let projectsService: ProjectsService
    private let importantDatesService: ImportantDatesService

    init(
        calendarService: CalendarService = .shared,
        relationshipService: RelationshipService = .shared,
        journalService: JournalService = .shared,
        breathingService: BreathingHistoryService = .shared,
        wellnessService: WellnessLogService = .shared,
        healthKitService: HealthKitService = .shared,
        remindersService: RemindersService = .shared,
        obligationsService: ObligationsService = .shared,
        incomeSourcesService: IncomeSourcesService = .shared,
        pipelineService: PipelineService = .shared,
        projectsService: ProjectsService = .shared,
        importantDatesService: ImportantDatesService = .shared
    ) {
        self.calendarService = calendarService
        self.relationshipService = relationshipService
        self.journalService = journalService
        self.breathingService = breathingService
        self.wellnessService = wellnessService
        self.healthKitService = healthKitService
        self.remindersService = remindersService
        self.obligationsService = obligationsService
        self.incomeSourcesService = incomeSourcesService
        self.pipelineService = pipelineService
        self.projectsService = projectsService
        self.importantDatesService = importantDatesService
    }

    func loadSignals(now: Date = Date()) async -> BalanceSignals {
        if remindersService.accessState == .unknown {
            await remindersService.requestAccess()
        }

        obligationsService.load()
        incomeSourcesService.load()
        pipelineService.load()
        projectsService.load()
        importantDatesService.load()

        let calendar = await calendarService.loadTodaysSnapshot(now: now)
        let relationships = await relationshipService.loadSnapshot(now: now)
        let journal = journalService.today()
        let wellness = wellnessService.today()
        let health = await healthKitService.loadSnapshot(now: now)
        let reminders = await remindersService.loadActiveReminders(now: now)
        let breathingMinutes = breathingService.minutesToday()
        let breathingCycles = breathingService.cyclesToday()
        let journalStreak = journalService.currentStreak()

        let obligations = obligationsService.dueSoon(within: 30, now: now)
        let due7 = obligationsService.totalDue(within: 7, now: now)
        let due30 = obligationsService.totalDue(within: 30, now: now)
        let upcomingDates = await importantDatesService.loadUpcoming(within: 60, now: now)

        return BalanceSignals(
            calendar: calendar,
            relationships: relationships,
            journal: journal,
            wellness: wellness,
            health: health,
            reminders: reminders,
            obligationsDueSoon: obligations,
            totalDueWithin7: due7,
            totalDueWithin30: due30,
            incomeSources: incomeSourcesService.sources,
            activeDeals: pipelineService.activeDeals,
            totalPipelineValue: pipelineService.totalActiveValue,
            totalWeightedValue: pipelineService.totalWeightedValue,
            activeProjects: projectsService.activeProjects,
            upcomingDates: upcomingDates,
            breathingMinutesToday: breathingMinutes,
            breathingCyclesToday: breathingCycles,
            journalStreak: journalStreak
        )
    }
}
