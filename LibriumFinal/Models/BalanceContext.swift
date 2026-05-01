import Foundation

struct BalanceContext: Codable {
    let timeOfDay: String
    let isoTimestamp: String
    let timezone: String
    let todayMeetings: Int
    let todayMeetingMinutes: Int
    let busyPercent: Double
    let nextEventTitle: String?
    let nextEventInMinutes: Int?
    let inProgressEventTitle: String?
    let inProgressEventStartedMinutesAgo: Int?
    let inProgressEventEndsInMinutes: Int?
    let staleRelationships: [StaleRelationshipSnapshot]
    let balanceScoreValue: Int
    let balanceTier: String

    let moodToday: Int
    let sleepHoursLastNight: Double
    let energyToday: Int
    let waterGlassesToday: Int
    let breathingMinutesToday: Int
    let breathingCyclesToday: Int
    let journalStreak: Int
    let hasIntention: Bool
    let hasGratitude: Bool

    let healthSleepHours: Double
    let healthStepCount: Int
    let healthActiveKcal: Int
    let healthMindfulMinutes: Int
    let healthExerciseMinutes: Int
    let healthRestingHeartRate: Int
    let healthHrvMs: Double
    let healthRemHours: Double
    let healthDeepHours: Double

    let todaysEvents: [EventSummary]
    let activeReminders: [ReminderItem]

    let obligationsDueSoon: [ObligationItem]
    let totalDueWithin7Days: Double
    let totalDueWithin30Days: Double
    let incomeSources: [IncomeItem]
    let activeDeals: [DealItem]
    let totalPipelineValue: Double
    let totalWeightedValue: Double
    let activeProjects: [ProjectItem]
    let upcomingDates: [ImportantDateItem]

    // Life-side awareness
    let zodiacSign: String?
    let zodiacElement: String?
    let moonPhase: String
    let moonIllumination: Int
    let todaysMotivation: String?
    let dailyGoals: [GoalItem]
    let weeklyGoals: [GoalItem]
    let quarterGoals: [GoalItem]
    let yearlyGoals: [GoalItem]
    let recentDreams: [DreamItem]
    let accountability: AccountabilityScore
    let lifeScoreToday: Int            // 0-100 composite Life Score for today (live)
    let lifeScoreYesterday: Int?       // for delta sense
    let lifeDimensionsToday: [LifeDimensionItem]
    let lifePatterns: [String]         // top 3 PatternDetector insight summaries
    let weather: WeatherSnapshot?

    struct LifeDimensionItem: Codable {
        let name: String
        let score: Int
    }

    struct GoalItem: Codable {
        let title: String
        let timeframe: String
        let status: String
        let targetDateLabel: String?
    }

    struct DreamItem: Codable {
        let title: String
        let dateLabel: String
        let snippet: String
        let hasAnalysis: Bool
    }

    struct StaleRelationshipSnapshot: Codable {
        let displayName: String
        let role: String?
        let daysSinceContact: Int
        let daysKnown: Int
        let meetingCount: Int
        let note: String?
        let relationshipType: String
        let personalScore: Int?
        let businessScore: Int?
        let relationshipContext: String?
    }

    struct DealItem: Codable {
        let name: String
        let contactName: String
        let stage: String
        let value: Double
        let probability: Double
        let nextAction: String?
        let nextActionLabel: String?
        let notes: String?
    }

    struct ProjectItem: Codable {
        let name: String
        let detail: String?
        let status: String
        let deadlineLabel: String?
        let daysUntilDeadline: Int?
        let totalMilestones: Int
        let completedMilestones: Int
    }

    struct ImportantDateItem: Codable {
        let title: String
        let daysUntil: Int
        let dateLabel: String
        let source: String
        let relatedContact: String?
        let note: String?
    }

    struct EventSummary: Codable {
        let title: String
        let startTime: String
        let durationMinutes: Int
        let attendeeCount: Int
        let isAllDay: Bool
        let isPast: Bool
    }

    struct ReminderItem: Codable {
        let title: String
        let dueLabel: String?
        let isOverdue: Bool
        let priority: String?
    }

    struct ObligationItem: Codable {
        let title: String
        let amount: Double
        let dueLabel: String
        let daysUntilDue: Int
        let isOverdue: Bool
        let recurrence: String
        let category: String
        let consequencesIfMissed: String?
    }

    struct IncomeItem: Codable {
        let title: String
        let type: String
        let typicalRate: Double
        let rateUnit: String
        let reliability: String
        let notes: String?
    }

    @MainActor
    static func snapshot(
        now: Date = Date(),
        signals: BalanceSignals,
        score: BalanceScore = .empty
    ) -> BalanceContext {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        let iso = ISO8601DateFormatter().string(from: now)

        let nextInMinutes: Int? = signals.calendar.nextEvent.map {
            max(0, Int($0.startDate.timeIntervalSince(now) / 60))
        }

        // In-progress event timing — minutes since start, minutes until end.
        let inProgressStartedMinutesAgo: Int? = signals.calendar.inProgressEvent.map {
            max(0, Int(now.timeIntervalSince($0.startDate) / 60))
        }
        let inProgressEndsInMinutes: Int? = signals.calendar.inProgressEvent.map {
            max(0, Int($0.endDate.timeIntervalSince(now) / 60))
        }

        let notesService = ContactNotesService.shared
        let stale = signals.relationships.relationships.prefix(3).map { rel -> StaleRelationshipSnapshot in
            let cn = notesService.notesByContactId[rel.id]
            return StaleRelationshipSnapshot(
                displayName: rel.displayName,
                role: rel.role,
                daysSinceContact: rel.daysSinceContact(now: now),
                daysKnown: rel.daysKnown(now: now),
                meetingCount: rel.interactionCount,
                note: rel.contactNote,
                relationshipType: (cn?.relationshipType ?? .unknown).rawValue,
                personalScore: cn?.personalScore,
                businessScore: cn?.businessScore,
                relationshipContext: cn?.relationshipContext
            )
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let events = signals.calendar.allEventsToday
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                EventSummary(
                    title: event.title,
                    startTime: event.isAllDay ? "all day" : timeFormatter.string(from: event.startDate),
                    durationMinutes: event.durationMinutes,
                    attendeeCount: event.attendeeCount,
                    isAllDay: event.isAllDay,
                    isPast: event.endDate < now
                )
            }

        let reminderItems = signals.reminders.map { r in
            ReminderItem(
                title: r.title,
                dueLabel: r.dueDate.map { Self.dueLabel(for: $0, now: now, formatter: timeFormatter) },
                isOverdue: r.isOverdue,
                priority: r.priorityLabel
            )
        }

        let obligationItems = signals.obligationsDueSoon.map { o in
            ObligationItem(
                title: o.title,
                amount: o.amount,
                dueLabel: Self.dueLabel(for: o.dueDate, now: now, formatter: timeFormatter),
                daysUntilDue: o.daysUntilDue(now: now),
                isOverdue: o.isOverdue,
                recurrence: o.recurrence.rawValue,
                category: o.category.rawValue,
                consequencesIfMissed: o.consequencesIfMissed
            )
        }

        let incomeItems = signals.incomeSources.map { s in
            IncomeItem(
                title: s.title,
                type: s.type.rawValue,
                typicalRate: s.typicalRate,
                rateUnit: s.rateUnit.rawValue,
                reliability: s.reliability.rawValue,
                notes: s.notes
            )
        }

        let dealItems = signals.activeDeals.map { d -> DealItem in
            let nextLabel = d.nextActionDate.map { Self.dueLabel(for: $0, now: now, formatter: timeFormatter) }
            return DealItem(
                name: d.name,
                contactName: d.contactName,
                stage: d.stage.rawValue,
                value: d.dealValue,
                probability: d.probability,
                nextAction: d.nextAction,
                nextActionLabel: nextLabel,
                notes: d.notes
            )
        }

        let dateItems = signals.upcomingDates.prefix(8).map { d -> ImportantDateItem in
            let f = DateFormatter()
            f.dateFormat = "EEE MMM d"
            return ImportantDateItem(
                title: d.title,
                daysUntil: d.daysUntil(now: now),
                dateLabel: f.string(from: d.nextOccurrence(now: now)),
                source: d.source.rawValue,
                relatedContact: d.relatedContactName,
                note: d.note
            )
        }

        let projectItems = signals.activeProjects.map { p -> ProjectItem in
            let label: String?
            let days: Int?
            if let deadline = p.deadline {
                let cal = Calendar.current
                let d = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: deadline)).day ?? 0
                label = Self.dueLabel(for: deadline, now: now, formatter: timeFormatter)
                days = d
            } else {
                label = nil
                days = nil
            }
            return ProjectItem(
                name: p.name,
                detail: p.detail,
                status: p.status.rawValue,
                deadlineLabel: label,
                daysUntilDeadline: days,
                totalMilestones: p.milestones.count,
                completedMilestones: p.completedMilestones
            )
        }

        // Life-side awareness — read from singleton services
        let zodiac = BirthdayService.shared.zodiac
        let moon = MoonPhase.current(now: now)
        let motivation = SpiritualContentService.shared.motivationForToday

        let snippetFormatter = DateFormatter()
        snippetFormatter.dateFormat = "MMM d"

        let goalsService = GoalsService.shared
        func goalItems(_ tf: Goal.Timeframe) -> [GoalItem] {
            goalsService.active(in: tf).prefix(3).map { goal in
                GoalItem(
                    title: goal.title,
                    timeframe: goal.timeframe.rawValue,
                    status: goal.status.rawValue,
                    targetDateLabel: goal.targetDate.map { snippetFormatter.string(from: $0) }
                )
            }
        }

        let dailyGoalItems = goalItems(.daily)
        let weeklyGoalItems = goalItems(.weekly)
        let quarterGoalItems = goalItems(Goal.Timeframe.currentQuarter())
        let yearlyGoalItems = goalItems(.yearly)

        let dreamItems = DreamService.shared.recent(limit: 3).map { dream -> DreamItem in
            let snippet = dream.rawDescription.prefix(80)
            return DreamItem(
                title: dream.title,
                dateLabel: snippetFormatter.string(from: dream.dreamedAt),
                snippet: String(snippet),
                hasAnalysis: dream.analysis != nil
            )
        }

        return BalanceContext(
            timeOfDay: timeOfDay,
            isoTimestamp: iso,
            timezone: TimeZone.current.identifier,
            todayMeetings: signals.calendar.totalEventsToday,
            todayMeetingMinutes: signals.calendar.totalMeetingMinutesToday,
            busyPercent: signals.calendar.busyPercent,
            nextEventTitle: signals.calendar.nextEvent?.title,
            nextEventInMinutes: nextInMinutes,
            inProgressEventTitle: signals.calendar.inProgressEvent?.title,
            inProgressEventStartedMinutesAgo: inProgressStartedMinutesAgo,
            inProgressEventEndsInMinutes: inProgressEndsInMinutes,
            staleRelationships: Array(stale),
            balanceScoreValue: score.value,
            balanceTier: score.tier.rawValue,
            moodToday: signals.journal.mood,
            sleepHoursLastNight: signals.wellness.sleepHours,
            energyToday: signals.wellness.energyLevel,
            waterGlassesToday: signals.wellness.waterGlasses,
            breathingMinutesToday: signals.breathingMinutesToday,
            breathingCyclesToday: signals.breathingCyclesToday,
            journalStreak: signals.journalStreak,
            hasIntention: !signals.journal.intention.isEmpty,
            hasGratitude: !signals.journal.gratitude.isEmpty,
            healthSleepHours: signals.health.sleepHours,
            healthStepCount: signals.health.stepCount,
            healthActiveKcal: signals.health.activeKcal,
            healthMindfulMinutes: signals.health.mindfulMinutes,
            healthExerciseMinutes: signals.health.activity.exerciseMinutes,
            healthRestingHeartRate: signals.health.heart.restingBpm,
            healthHrvMs: signals.health.heart.hrvMs,
            healthRemHours: signals.health.sleep.remHours,
            healthDeepHours: signals.health.sleep.deepHours,
            todaysEvents: events,
            activeReminders: reminderItems,
            obligationsDueSoon: obligationItems,
            totalDueWithin7Days: signals.totalDueWithin7,
            totalDueWithin30Days: signals.totalDueWithin30,
            incomeSources: incomeItems,
            activeDeals: dealItems,
            totalPipelineValue: signals.totalPipelineValue,
            totalWeightedValue: signals.totalWeightedValue,
            activeProjects: projectItems,
            upcomingDates: Array(dateItems),
            zodiacSign: zodiac?.label,
            zodiacElement: zodiac?.element,
            moonPhase: moon.kind.label,
            moonIllumination: Int(moon.illumination * 100),
            todaysMotivation: motivation,
            dailyGoals: dailyGoalItems,
            weeklyGoals: weeklyGoalItems,
            quarterGoals: quarterGoalItems,
            yearlyGoals: yearlyGoalItems,
            recentDreams: dreamItems,
            accountability: goalsService.accountabilityScore(now: now),
            lifeScoreToday: 0,
            lifeScoreYesterday: nil,
            lifeDimensionsToday: [],
            lifePatterns: [],
            weather: nil
        )
    }

    /// Async builder that resolves today's live Life Score (HealthKit + events).
    /// Use this when calling Maria so she gets the freshest dimension data.
    @MainActor
    static func snapshotAsync(
        now: Date = Date(),
        signals: BalanceSignals,
        score: BalanceScore = .empty
    ) async -> BalanceContext {
        var ctx = snapshot(now: now, signals: signals, score: score)
        let live = await DailySnapshotService.shared.currentLive(now: now)
        let yesterdayKey = DimensionSnapshot.dayKey(for: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
        let yesterdayScore = DailySnapshotService.shared.snapshots
            .first(where: { $0.id == yesterdayKey })?
            .lifeComposite

        ctx = BalanceContext(
            timeOfDay: ctx.timeOfDay,
            isoTimestamp: ctx.isoTimestamp,
            timezone: ctx.timezone,
            todayMeetings: ctx.todayMeetings,
            todayMeetingMinutes: ctx.todayMeetingMinutes,
            busyPercent: ctx.busyPercent,
            nextEventTitle: ctx.nextEventTitle,
            nextEventInMinutes: ctx.nextEventInMinutes,
            inProgressEventTitle: ctx.inProgressEventTitle,
            inProgressEventStartedMinutesAgo: ctx.inProgressEventStartedMinutesAgo,
            inProgressEventEndsInMinutes: ctx.inProgressEventEndsInMinutes,
            staleRelationships: ctx.staleRelationships,
            balanceScoreValue: ctx.balanceScoreValue,
            balanceTier: ctx.balanceTier,
            moodToday: ctx.moodToday,
            sleepHoursLastNight: ctx.sleepHoursLastNight,
            energyToday: ctx.energyToday,
            waterGlassesToday: ctx.waterGlassesToday,
            breathingMinutesToday: ctx.breathingMinutesToday,
            breathingCyclesToday: ctx.breathingCyclesToday,
            journalStreak: ctx.journalStreak,
            hasIntention: ctx.hasIntention,
            hasGratitude: ctx.hasGratitude,
            healthSleepHours: ctx.healthSleepHours,
            healthStepCount: ctx.healthStepCount,
            healthActiveKcal: ctx.healthActiveKcal,
            healthMindfulMinutes: ctx.healthMindfulMinutes,
            healthExerciseMinutes: ctx.healthExerciseMinutes,
            healthRestingHeartRate: ctx.healthRestingHeartRate,
            healthHrvMs: ctx.healthHrvMs,
            healthRemHours: ctx.healthRemHours,
            healthDeepHours: ctx.healthDeepHours,
            todaysEvents: ctx.todaysEvents,
            activeReminders: ctx.activeReminders,
            obligationsDueSoon: ctx.obligationsDueSoon,
            totalDueWithin7Days: ctx.totalDueWithin7Days,
            totalDueWithin30Days: ctx.totalDueWithin30Days,
            incomeSources: ctx.incomeSources,
            activeDeals: ctx.activeDeals,
            totalPipelineValue: ctx.totalPipelineValue,
            totalWeightedValue: ctx.totalWeightedValue,
            activeProjects: ctx.activeProjects,
            upcomingDates: ctx.upcomingDates,
            zodiacSign: ctx.zodiacSign,
            zodiacElement: ctx.zodiacElement,
            moonPhase: ctx.moonPhase,
            moonIllumination: ctx.moonIllumination,
            todaysMotivation: ctx.todaysMotivation,
            dailyGoals: ctx.dailyGoals,
            weeklyGoals: ctx.weeklyGoals,
            quarterGoals: ctx.quarterGoals,
            yearlyGoals: ctx.yearlyGoals,
            recentDreams: ctx.recentDreams,
            accountability: ctx.accountability,
            lifeScoreToday: Int(live.lifeComposite.rounded()),
            lifeScoreYesterday: yesterdayScore.map { Int($0.rounded()) },
            lifeDimensionsToday: Dimension.allCases.map { dim in
                LifeDimensionItem(name: dim.label, score: Int(live.value(for: dim).rounded()))
            },
            lifePatterns: PatternDetector.detect(
                snapshots: DailySnapshotService.shared.snapshots,
                events: LifeEventsService.shared.events,
                now: now,
                maxResults: 3
            ).map { $0.summary },
            weather: await WeatherService.shared.current(now: now)
        )
        return ctx
    }

    private static func dueLabel(for date: Date, now: Date, formatter: DateFormatter) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "today \(formatter.string(from: date))"
        }
        if cal.isDateInYesterday(date) {
            return "yesterday"
        }
        if cal.isDateInTomorrow(date) {
            return "tomorrow \(formatter.string(from: date))"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    static let empty = BalanceContext(
        timeOfDay: "unknown",
        isoTimestamp: "",
        timezone: "",
        todayMeetings: 0,
        todayMeetingMinutes: 0,
        busyPercent: 0,
        nextEventTitle: nil,
        nextEventInMinutes: nil,
        inProgressEventTitle: nil,
        inProgressEventStartedMinutesAgo: nil,
        inProgressEventEndsInMinutes: nil,
        staleRelationships: [],
        balanceScoreValue: 0,
        balanceTier: BalanceTier.steady.rawValue,
        moodToday: 0,
        sleepHoursLastNight: 0,
        energyToday: 0,
        waterGlassesToday: 0,
        breathingMinutesToday: 0,
        breathingCyclesToday: 0,
        journalStreak: 0,
        hasIntention: false,
        hasGratitude: false,
        healthSleepHours: 0,
        healthStepCount: 0,
        healthActiveKcal: 0,
        healthMindfulMinutes: 0,
        healthExerciseMinutes: 0,
        healthRestingHeartRate: 0,
        healthHrvMs: 0,
        healthRemHours: 0,
        healthDeepHours: 0,
        todaysEvents: [],
        activeReminders: [],
        obligationsDueSoon: [],
        totalDueWithin7Days: 0,
        totalDueWithin30Days: 0,
        incomeSources: [],
        activeDeals: [],
        totalPipelineValue: 0,
        totalWeightedValue: 0,
        activeProjects: [],
        upcomingDates: [],
        zodiacSign: nil,
        zodiacElement: nil,
        moonPhase: "",
        moonIllumination: 0,
        todaysMotivation: nil,
        dailyGoals: [],
        weeklyGoals: [],
        quarterGoals: [],
        yearlyGoals: [],
        recentDreams: [],
        accountability: AccountabilityScore(
            daily: .init(completed: 0, missed: 0, dropped: 0, weight: 0.35, rate: nil),
            weekly: .init(completed: 0, missed: 0, dropped: 0, weight: 0.30, rate: nil),
            quarter: .init(completed: 0, missed: 0, dropped: 0, weight: 0.20, rate: nil),
            yearly: .init(completed: 0, missed: 0, dropped: 0, weight: 0.15, rate: nil),
            calendarCompleted7d: 0,
            calendarMissed7d: 0,
            calendarRescheduled7d: 0,
            overall: 0
        ),
        lifeScoreToday: 50,
        lifeScoreYesterday: nil,
        lifeDimensionsToday: [],
        lifePatterns: [],
        weather: nil
    )
}
