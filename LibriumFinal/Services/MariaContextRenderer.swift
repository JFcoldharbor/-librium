import Foundation

enum MariaContextRenderer {
    struct BaselineInput {
        let context: BalanceContext
        let recentMemories: [MariaMemory]
        let scannerSummary: String?
    }

    static func renderBaseline(_ input: BaselineInput) -> String {
        let ctx = input.context
        var parts: [String] = []

        parts.append("Current time: \(ctx.timeOfDay) (\(ctx.isoTimestamp), \(ctx.timezone))")
        parts.append("Balance score: \(ctx.balanceScoreValue)/100 (\(ctx.balanceTier))")

        let busyPct = Int((ctx.busyPercent * 100).rounded())
        parts.append("Today's calendar: \(ctx.todayMeetings) meetings, \(ctx.todayMeetingMinutes) min, \(busyPct)% booked.")

        // In-progress event takes priority over next event — if something is
        // happening RIGHT NOW, that's the more relevant signal. Maria should
        // never see "Next event: X in 0 min" for an event that started hours
        // ago.
        if let inProgress = ctx.inProgressEventTitle {
            let started = ctx.inProgressEventStartedMinutesAgo ?? 0
            let endsIn = ctx.inProgressEventEndsInMinutes ?? 0
            let startedLabel = started >= 60
                ? "\(started / 60)h \(started % 60)m ago"
                : "\(started) min ago"
            parts.append("In progress: \"\(inProgress)\" (started \(startedLabel), ends in \(endsIn) min).")
        }
        if let next = ctx.nextEventTitle {
            let inMin = ctx.nextEventInMinutes ?? 0
            parts.append("Next event: \"\(next)\" in \(inMin) min.")
        }

        var lifeParts: [String] = []
        if ctx.moodToday > 0 {
            let labels = ["very low", "low", "okay", "good", "great"]
            let idx = max(0, min(4, ctx.moodToday - 1))
            lifeParts.append("mood \(ctx.moodToday)/5 (\(labels[idx]))")
        }
        let displaySleep = ctx.healthSleepHours > 0 ? ctx.healthSleepHours : ctx.sleepHoursLastNight
        if displaySleep > 0 {
            lifeParts.append(String(format: "slept %.1fh", displaySleep))
        }
        if ctx.energyToday > 0 {
            lifeParts.append("energy \(ctx.energyToday)/5")
        }
        if ctx.waterGlassesToday > 0 {
            lifeParts.append("\(ctx.waterGlassesToday) water")
        }
        if ctx.breathingMinutesToday > 0 {
            lifeParts.append("\(ctx.breathingMinutesToday)m breathing")
        }
        if !lifeParts.isEmpty {
            parts.append("Life today: \(lifeParts.joined(separator: ", ")).")
        }

        if !ctx.activeDeals.isEmpty {
            parts.append("Pipeline: \(ctx.activeDeals.count) active deals · $\(Int(ctx.totalPipelineValue)) total · $\(Int(ctx.totalWeightedValue)) weighted.")
        }
        if !ctx.activeProjects.isEmpty {
            parts.append("Projects: \(ctx.activeProjects.count) active.")
        }

        if !ctx.staleRelationships.isEmpty {
            let names = ctx.staleRelationships.prefix(2).map { rel in
                "\(rel.displayName) (\(rel.daysSinceContact)d)"
            }
            parts.append("Stale: \(names.joined(separator: ", ")).")
        }

        var output = "Context:\n" + parts.map { "- \($0)" }.joined(separator: "\n")

        if !ctx.todaysEvents.isEmpty {
            output += "\n\nToday's events:\n"
            for event in ctx.todaysEvents.prefix(6) {
                let pastMark = event.isPast ? " (done)" : ""
                output += "- \(event.startTime): \(event.title)\(pastMark)\n"
            }
        }

        let urgentObligations = ctx.obligationsDueSoon.prefix(3)
        if !urgentObligations.isEmpty {
            output += "\nTop obligations:\n"
            for o in urgentObligations {
                let overdue = o.isOverdue ? " · OVERDUE" : ""
                output += "- \(o.title): $\(Int(o.amount)) · due \(o.dueLabel)\(overdue)\n"
            }
            output += "- Total due in 7d: $\(Int(ctx.totalDueWithin7Days))\n"
        }

        let urgentReminders = ctx.activeReminders.prefix(3)
        if !urgentReminders.isEmpty {
            output += "\nTop reminders:\n"
            for r in urgentReminders {
                let due = r.dueLabel.map { " · due \($0)" } ?? ""
                let overdue = r.isOverdue ? " · OVERDUE" : ""
                output += "- \(r.title)\(due)\(overdue)\n"
            }
        }

        let activeGoals = ctx.dailyGoals + ctx.weeklyGoals
        if !activeGoals.isEmpty {
            output += "\nActive goals:\n"
            for g in ctx.dailyGoals.prefix(3) {
                output += "- TODAY: \(g.title)\n"
            }
            for g in ctx.weeklyGoals.prefix(3) {
                output += "- WEEK: \(g.title)\n"
            }
        }

        if !input.recentMemories.isEmpty {
            output += "\nWhat you remember about them:\n"
            for memory in input.recentMemories.prefix(7) {
                output += "- [\(memory.category.label)] \(memory.content)\n"
            }
        }

        if let scannerSummary = input.scannerSummary, !scannerSummary.isEmpty {
            output += "\nWhat you've been thinking about (latest scan):\n\(scannerSummary)\n"
        }

        return output
    }

    static func renderSlice(_ type: SliceType, context ctx: BalanceContext) -> ContextSlice? {
        let body: String?
        switch type {
        case .pipeline:
            body = renderPipeline(ctx)
        case .projects:
            body = renderProjects(ctx)
        case .fullCalendar:
            body = renderFullCalendar(ctx)
        case .contacts:
            body = renderContacts(ctx)
        case .bodySignals:
            body = renderBodySignals(ctx)
        case .dreams:
            body = renderDreams(ctx)
        case .patterns:
            body = renderPatterns(ctx)
        case .accountabilityFull:
            body = renderAccountabilityFull(ctx)
        case .weather5Day:
            body = renderWeather5Day(ctx)
        case .pastRecall:
            return nil
        }

        guard let content = body, !content.isEmpty else { return nil }
        return ContextSlice(
            type: type,
            content: content,
            estimatedTokens: max(1, content.count / 4),
            renderedAt: Date()
        )
    }

    private static func renderPipeline(_ ctx: BalanceContext) -> String? {
        guard !ctx.activeDeals.isEmpty else { return nil }
        var out = "Sales pipeline (active deals):\n"
        out += "- Total: $\(Int(ctx.totalPipelineValue)) · weighted: $\(Int(ctx.totalWeightedValue))\n"
        for d in ctx.activeDeals {
            let nextStr: String = {
                guard let action = d.nextAction else { return "" }
                let label = d.nextActionLabel.map { " (\($0))" } ?? ""
                return " · next: \(action)\(label)"
            }()
            let notesStr = d.notes.map { " · \($0)" } ?? ""
            out += "- \(d.name) · \(d.contactName) · \(d.stage) · $\(Int(d.value)) @ \(Int(d.probability * 100))%\(nextStr)\(notesStr)\n"
        }
        return out
    }

    private static func renderProjects(_ ctx: BalanceContext) -> String? {
        guard !ctx.activeProjects.isEmpty else { return nil }
        var out = "Active projects:\n"
        for p in ctx.activeProjects {
            let detail = p.detail.map { " — \($0)" } ?? ""
            let progress = p.totalMilestones > 0 ? " · \(p.completedMilestones)/\(p.totalMilestones) milestones" : ""
            let deadline = p.deadlineLabel.map { " · deadline \($0)" } ?? ""
            out += "- \(p.name)\(detail)\(progress)\(deadline)\n"
        }
        return out
    }

    private static func renderFullCalendar(_ ctx: BalanceContext) -> String? {
        var out = """
        MANAGING THE CALENDAR
        Priority levels (events_in_window returns 'priority'):
        - must_do — never move/cancel without per-event approval. Surface conflicts to user first.
        - important — avoid cancelling. Ask before moving.
        - flexible — default. Move freely.
        - skippable — cancel/move freely. Prefer cancelling these first when clearing time.

        BATCH OPS — Use batch_calendar_changes when the user wants multiple changes. Don't call move/cancel/add one at a time. Confirm full plan first ("I'll move X to 3, cancel Y, add Z — proceed?"), then run the batch on yes.

        When user blocks off time ("tied up 9 to 2:30 with Anderson"):
        1. Call events_in_window for that range to find conflicts AND priority.
        2. Read the plan back: "You have X (flexible) at 10am and Y (skippable) at 1:15pm. I'll add the block, cancel Y, push X to 3pm. Sound good?"
        3. On yes, call batch_calendar_changes ONCE. Don't loop.
        4. If a must_do is in the window, name it specifically and ask before touching.

        When user wants a slot:
        1. Call events_in_window.
        2. Read gaps as plain English: "Thursday after 2pm you've got a clear stretch until your 5:30."

        Don't make them repeat themselves. Execute when they tell you what they want. Stop only on genuine ambiguity or must_do in the way.

        DESIGNING STRUCTURE (when user asks "design my week", "set up my structure", "I cleared my calendar"):
        Interview conversationally — one or two questions at a time:
        1. Sleep window — when asleep/awake?
        2. Non-negotiables — fixed commitments
        3. Deep-work window — when's their brain sharpest? (check what you know — pipeline tells you when sales calls happen)
        4. Weekly anchors — sales blocks, planning, admin
        5. White space — they want some unscheduled. Don't fill the week.

        Use what's already in Context (bills, deals, projects). Don't make them repeat. Propose a week template, read it back as recurring blocks, get confirmation, then write each with add_event using recurrence:"weekdays" or "weekly". Leave gaps.

        start_navigation: ASK FIRST. When user mentions an upcoming appointment with a venue, offer directions. If not on calendar, offer add_event first.
        """

        if !ctx.todaysEvents.isEmpty {
            out += "\n\nToday's events (full detail):\n"
            for event in ctx.todaysEvents {
                let pastMark = event.isPast ? " (done)" : ""
                let attendees = event.attendeeCount > 1 ? " · \(event.attendeeCount) attendees" : ""
                let duration = event.isAllDay ? "" : " · \(event.durationMinutes)m"
                out += "- \(event.startTime): \(event.title)\(duration)\(attendees)\(pastMark)\n"
            }
        }

        if !ctx.upcomingDates.isEmpty {
            out += "\nUpcoming important dates (next 30 days):\n"
            for d in ctx.upcomingDates {
                let dayLabel = d.daysUntil == 0 ? "TODAY" : (d.daysUntil == 1 ? "tomorrow" : "in \(d.daysUntil)d")
                let related = d.relatedContact.map { " · \($0)" } ?? ""
                let noteStr = d.note.map { " · \"\($0)\"" } ?? ""
                out += "- \(d.title) · \(dayLabel) (\(d.dateLabel))\(related)\(noteStr)\n"
            }
        }

        return out
    }

    private static func renderContacts(_ ctx: BalanceContext) -> String? {
        var out = """
        RELATIONSHIP SENTIMENT TRACKING
        Each contact has TYPE (personal/business/both/unknown) plus PERSONAL (0-100) and BUSINESS (0-100) scores, independent. A friend who's also a client can be 75 personal / 50 business.

        UPDATE SCORES SILENTLY as the user talks. Never ask "should I rate them?" — pull cues and call assess_relationship with deltas.

        FIRST CONTACT — when type=unknown, the FIRST time you act on a contact (text/call/schedule/touch), ask once IN THE SAME BREATH as your action: "Found David Neal at Lite Work. What would you like to say, and is this personal or business?" Skip if the user already said the type or is mid-flow on something urgent.

        OFF-AXIS — a personal-tagged contact can accumulate business score and vice versa. Type doesn't suppress content.

        PROMOTION to `both` — after ~3 cross-axis cues, surface ONCE: "You've talked business with David a few times — mark him as both?" If declined, don't ask again.

        AMBIGUOUS — no clear cue ("talked to David today"): use type as tiebreaker. personal → small +personal. business → small +business. both → split. unknown → don't move scores.

        Cue → action examples:
        - "lunch with Cedric, family talk" → delta_personal=+8, context="warm catch-up"
        - "Daniel never follows up, irritating" → delta_business=-10
        - "Sarah saved my ass" → delta_business=+12
        - "fight with my brother" → delta_personal=-8
        - "wedding was beautiful" → delta_personal=+6 across mentioned contacts

        Magnitude: ±3 soft, ±8 clear, ±15 major events only. Skip if you can't read the sentiment.

        Absolute scores only on direct ratings ("Daniel is a 30") or hard resets ("we're done" → business_score=0).

        Reference relationships with role and known-since when relevant. Contact tools fuzzy-match — if multiple match, ask, don't guess.
        """

        if !ctx.staleRelationships.isEmpty {
            out += "\n\nStale relationships (full):\n"
            for rel in ctx.staleRelationships {
                let roleStr = rel.role.map { " — \($0)" } ?? ""
                let knownStr = rel.daysKnown >= 30 ? " · known \(knownLabel(days: rel.daysKnown))" : ""
                let noteStr = rel.note.map { " · note: \"\($0)\"" } ?? ""
                var scoreParts: [String] = []
                if let p = rel.personalScore { scoreParts.append("personal \(p)") }
                if let b = rel.businessScore { scoreParts.append("business \(b)") }
                let scoreStr = scoreParts.isEmpty ? "" : " · " + scoreParts.joined(separator: "/")
                let typeStr = rel.relationshipType == "unknown" ? "" : " · type=\(rel.relationshipType)"
                let contextStr = rel.relationshipContext.map { " · \"\($0)\"" } ?? ""
                out += "- \(rel.displayName)\(roleStr) (\(rel.daysSinceContact)d ago, \(rel.meetingCount)x\(knownStr))\(noteStr)\(typeStr)\(scoreStr)\(contextStr)\n"
            }
        }
        return out
    }

    private static func renderBodySignals(_ ctx: BalanceContext) -> String? {
        var sections: [String] = []

        var todayParts: [String] = []
        if ctx.healthStepCount > 0 { todayParts.append("\(ctx.healthStepCount) steps") }
        if ctx.healthActiveKcal > 0 { todayParts.append("\(ctx.healthActiveKcal) active kcal") }
        if ctx.healthExerciseMinutes > 0 { todayParts.append("\(ctx.healthExerciseMinutes) exercise min") }
        if ctx.healthMindfulMinutes > 0 { todayParts.append("\(ctx.healthMindfulMinutes) mindful min") }
        if !todayParts.isEmpty {
            sections.append("Apple Health today: \(todayParts.joined(separator: ", ")).")
        }

        var bodyParts: [String] = []
        if ctx.healthRestingHeartRate > 0 { bodyParts.append("resting HR \(ctx.healthRestingHeartRate) bpm") }
        if ctx.healthHrvMs > 0 { bodyParts.append(String(format: "HRV %.0f ms", ctx.healthHrvMs)) }
        if ctx.healthRemHours > 0 || ctx.healthDeepHours > 0 {
            bodyParts.append(String(format: "%.1fh REM, %.1fh deep", ctx.healthRemHours, ctx.healthDeepHours))
        }
        if !bodyParts.isEmpty {
            sections.append("Body signals (week): \(bodyParts.joined(separator: ", ")).")
        }

        if !ctx.lifeDimensionsToday.isEmpty {
            let delta: String = {
                guard let yesterday = ctx.lifeScoreYesterday else { return "" }
                let diff = ctx.lifeScoreToday - yesterday
                if diff == 0 { return " (flat vs yesterday)" }
                let direction = diff > 0 ? "up" : "down"
                return " (\(direction) \(abs(diff)) from yesterday)"
            }()
            var dimBlock = "Life Score today: \(ctx.lifeScoreToday)/100\(delta)\n"
            dimBlock += "Dimensions: " + ctx.lifeDimensionsToday
                .map { "\($0.name) \($0.score)" }
                .joined(separator: " · ")
            sections.append(dimBlock)
        }

        let rules = """
        USING LIFE SCORE
        The Life Score reflects current state across body, mood, relationships, recreation, achievement, stress, rest. Reference it when they ask, when there's a meaningful shift, or when one dimension is dragging hard (stress < 30, mood < 35, relationships < 30). Don't drop the number every turn. Don't moralize. Don't compare to others. The dimensions exist so you can read between them — "stress is high, recreation is low" beats "your score is 58."
        """
        sections.append(rules)

        return sections.joined(separator: "\n\n")
    }

    private static func renderDreams(_ ctx: BalanceContext) -> String? {
        guard !ctx.recentDreams.isEmpty else { return nil }
        var out = "Recent dreams:\n"
        for d in ctx.recentDreams {
            let analyzed = d.hasAnalysis ? " · analyzed" : " · raw"
            out += "- \(d.title) (\(d.dateLabel))\(analyzed): \(d.snippet)\n"
        }
        return out
    }

    private static func renderPatterns(_ ctx: BalanceContext) -> String? {
        guard !ctx.lifePatterns.isEmpty else { return nil }
        var out = "Patterns detected:\n"
        for pattern in ctx.lifePatterns {
            out += "- \(pattern)\n"
        }
        out += """

        USING PATTERNS
        These are auto-detected correlations, trends, streaks, day-of-week patterns from snapshot history.
        - User asks "what's going on" or "any patterns" → name 1-2 directly.
        - A pattern explains something they're noticing → drop it as a single observation.
        - A planning question lines up with a pattern → use it to color advice.
        Don't dump every pattern. Don't repeat across turns. Patterns are signals, not commands.
        """
        return out
    }

    private static func renderAccountabilityFull(_ ctx: BalanceContext) -> String? {
        var out = "Accountability (composite weighted score):\n"
        out += accountabilityLine(label: "TODAY    ", stats: ctx.accountability.daily)
        out += accountabilityLine(label: "WEEK     ", stats: ctx.accountability.weekly)
        out += accountabilityLine(label: "QUARTER  ", stats: ctx.accountability.quarter)
        out += accountabilityLine(label: "YEAR     ", stats: ctx.accountability.yearly)
        out += "- CALENDAR last 7d: \(ctx.accountability.calendarCompleted7d) done, "
            + "\(ctx.accountability.calendarMissed7d) missed, "
            + "\(ctx.accountability.calendarRescheduled7d) rescheduled\n"
        let overallPct = AccountabilityScore.percent(ctx.accountability.overall)
        out += "- OVERALL: \(overallPct) (composite of timeframes with data)\n"

        out += """

        USING ACCOUNTABILITY
        Reference these numbers honestly when asked, when planning, or when patterns are worth naming. Do NOT moralize or shame.
        - Patterns matter more than single misses. "Slipped 3 weekly goals in a row — what's getting in the way?" is fair. "You missed today" alone isn't a pattern.
        - Wins deserve real acknowledgment. Don't undersell a 90% week.
        - "no data yet" timeframe → don't pretend you can score it.
        - Don't drop OVERALL every turn — only when asked, when planning, or when it shifted meaningfully.

        GOAL NUDGING (when user invites planning, NOT unsolicited):
        When user is in planning mode ("what should I focus on", "set my week", morning briefs), surface candidates from data:
        - High-probability deals → quarterly goals
        - Projects with near deadlines, no matching active goal → weekly goals
        - Recurring obligations slipping → daily/weekly goal
        Use add_goal when accepted. Don't push when they're just talking.
        """
        return out
    }

    private static func renderWeather5Day(_ ctx: BalanceContext) -> String? {
        guard let weather = ctx.weather else { return nil }
        var out = "Weather now: \(weather.contextLine).\n"
        if let hourly = weather.hourlyOutlook {
            out += "Today's outlook: \(hourly).\n"
        }
        if let daily = weather.dailyOutlook {
            out += "Next 5 days: \(daily).\n"
        }
        out += """

        USING WEATHER
        Use sparingly. Never lead with weather unless asked.
        - User mentions feeling off / low energy → if overcast/rainy, name as one possible factor, not the explanation.
        - Planning the day → factor today's hourly outlook ("rain breaks at 4pm, your walk window is then").
        - Planning the week → reference 5-day outlook for outdoor things, travel.
        - Don't pad responses with weather reports. If not relevant, don't mention.
        """
        return out
    }

    private static func accountabilityLine(label: String, stats: AccountabilityScore.TimeframeStats) -> String {
        let weightPct = Int((stats.weight * 100).rounded())
        let pct = AccountabilityScore.percent(stats.rate)
        let dataPart: String = stats.hasData
            ? "\(stats.completed) done, \(stats.missed) missed, \(stats.dropped) dropped → \(pct)"
            : "no data yet"
        return "- \(label): \(dataPart) (weight \(weightPct)%)\n"
    }

    private static func knownLabel(days: Int) -> String {
        if days >= 365 {
            let years = Double(days) / 365
            return String(format: "%.1f yr", years)
        }
        if days >= 30 {
            let months = days / 30
            return "\(months) mo"
        }
        return "\(days)d"
    }
}
