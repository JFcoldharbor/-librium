import Foundation
#if !os(macOS)
import UIKit
#endif

@MainActor
enum MariaTools {
    static let definitions: [[String: Any]] = [
        setReminderTool,
        addMemoryTool,
        forgetMemoryTool,
        addImportantDateTool,
        recallPeriodTool,
        moveEventTool,
        cancelEventTool,
        addEventTool,
        eventsInWindowTool,
        setEventPriorityTool,
        batchCalendarChangesTool,
        addPipelineDealTool,
        updateDealStageTool,
        markObligationPaidTool,
        addIncomeSourceTool,
        addProjectTool,
        logWaterTool,
        logMoodTool,
        logEnergyTool,
        saveJournalTool,
        saveDreamTool,
        addGoalTool,
        completeGoalTool,
        missGoalTool,
        setContactFollowupTool,
        updateContactFollowupTool,
        addContactNoteTool,
        assessRelationshipTool,
        dismissContactTool,
        callContactTool,
        textContactTool,
        logContactTouchTool,
        startNavigationTool,
        logIncomeTool,
        logExpenseTool,
        logLifeEventTool
    ]

    static let toolFamilies: [String: Set<ToolFamily>] = [
        "log_water": [.alwaysOn],
        "log_mood": [.alwaysOn],
        "log_energy": [.alwaysOn],
        "log_life_event": [.alwaysOn],
        "save_journal": [.alwaysOn],
        "add_memory": [.alwaysOn],
        "forget_memory": [.alwaysOn],
        "set_reminder": [.alwaysOn],
        "add_important_date": [.alwaysOn],
        "log_income": [.alwaysOn],
        "log_expense": [.alwaysOn],
        "mark_obligation_paid": [.alwaysOn],

        "save_dream": [.dreams],

        "add_pipeline_deal": [.pipeline],
        "update_deal_stage": [.pipeline],
        "add_income_source": [.pipeline],

        "add_project": [.projects],

        "add_goal": [.goals],
        "complete_goal": [.goals],
        "miss_goal": [.goals],

        "call_contact": [.contacts],
        "text_contact": [.contacts],
        "set_contact_followup": [.contacts],
        "update_contact_followup": [.contacts],
        "add_contact_note": [.contacts],
        "log_contact_touch": [.contacts],
        "dismiss_contact": [.contacts],
        "assess_relationship": [.contacts],

        "add_event": [.calendar],
        "move_event": [.calendar],
        "cancel_event": [.calendar],
        "batch_calendar_changes": [.calendar],
        "events_in_window": [.calendar],
        "set_event_priority": [.calendar],
        "start_navigation": [.calendar],

        "recall_period": [.past]
    ]

    private static let sliceFamilyMap: [SliceType: Set<ToolFamily>] = [
        .pipeline: [.pipeline],
        .contacts: [.contacts],
        .fullCalendar: [.calendar],
        .projects: [.projects],
        .accountabilityFull: [.goals],
        .dreams: [.dreams],
        .pastRecall: [.past]
    ]

    static func definitions(for classification: IntentClassification) -> [[String: Any]] {
        if classification.conversational {
            return []
        }
        var families: Set<ToolFamily> = [.alwaysOn]
        for slice in classification.slices {
            if let mapped = sliceFamilyMap[slice] {
                families.formUnion(mapped)
            }
        }
        return definitions.filter { tool in
            guard let function = tool["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let toolFams = toolFamilies[name] else {
                return true
            }
            return !toolFams.isDisjoint(with: families)
        }
    }

    private static var setReminderTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "set_reminder",
                "description": "Create an iOS reminder for the user. Use when they ask to be reminded, or when you commit to a follow-up.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Short reminder title. Phrase as the action to take."
                        ],
                        "due_iso_datetime": [
                            "type": "string",
                            "description": "Due date/time in ISO 8601 (e.g. 2026-05-01T15:00:00Z). Optional — only include if a specific time is implied."
                        ],
                        "notes": [
                            "type": "string",
                            "description": "Optional context for the reminder."
                        ]
                    ],
                    "required": ["title"]
                ]
            ]
        ]
    }

    private static var addMemoryTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_memory",
                "description": "Save a long-term memory about the user. Use when they explicitly say 'remember this' or share a meaningful fact, preference, commitment, win, or struggle worth holding onto.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "content": [
                            "type": "string",
                            "description": "The memory phrased clearly in one sentence."
                        ],
                        "category": [
                            "type": "string",
                            "enum": ["fact", "preference", "win", "struggle", "commitment", "context"]
                        ],
                        "keywords": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Lowercase keywords to help retrieval later."
                        ]
                    ],
                    "required": ["content", "category", "keywords"]
                ]
            ]
        ]
    }

    private static var forgetMemoryTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "forget_memory",
                "description": "Delete previously saved memories about the user. Use when the user corrects you, says 'forget that', 'that's wrong', 'discard', or denies something you'd said. Match by keywords from the wrong memory. ALWAYS use this when the user contradicts what you remembered — don't just acknowledge, actually delete.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "keywords": [
                            "type": "array",
                            "items": ["type": "string"],
                            "description": "Keywords identifying the memory to forget. Be specific — include names, topics, or distinctive words from the wrong memory."
                        ],
                        "category": [
                            "type": "string",
                            "enum": ["fact", "preference", "win", "struggle", "commitment", "context"],
                            "description": "Optional. Limit deletion to memories of this category."
                        ]
                    ],
                    "required": ["keywords"]
                ]
            ]
        ]
    }

    private static var addImportantDateTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_important_date",
                "description": "Add a date the user wants tracked (anniversary, court date, kid's milestone, etc.).",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "What the date is for. e.g. 'Wife's anniversary', 'Court hearing'."
                        ],
                        "iso_date": [
                            "type": "string",
                            "description": "Date in ISO 8601 (YYYY-MM-DD or full datetime)."
                        ],
                        "recurrence": [
                            "type": "string",
                            "enum": ["once", "yearly"]
                        ],
                        "related_contact_name": [
                            "type": "string",
                            "description": "Person this date relates to. Optional."
                        ]
                    ],
                    "required": ["title", "iso_date", "recurrence"]
                ]
            ]
        ]
    }

    static func execute(name: String, arguments: String) async -> String {
        switch name {
        case "set_reminder":
            return await executeSetReminder(args: arguments)
        case "add_memory":
            return await executeAddMemory(args: arguments)
        case "forget_memory":
            return await executeForgetMemory(args: arguments)
        case "add_important_date":
            return await executeAddImportantDate(args: arguments)
        case "recall_period":
            return await executeRecallPeriod(args: arguments)
        case "move_event":
            return await executeMoveEvent(args: arguments)
        case "cancel_event":
            return await executeCancelEvent(args: arguments)
        case "events_in_window":
            return await executeEventsInWindow(args: arguments)
        case "set_event_priority":
            return await executeSetEventPriority(args: arguments)
        case "batch_calendar_changes":
            return await executeBatchCalendarChanges(args: arguments)
        case "add_event":
            return await executeAddEvent(args: arguments)
        case "add_pipeline_deal":
            return await executeAddPipelineDeal(args: arguments)
        case "update_deal_stage":
            return await executeUpdateDealStage(args: arguments)
        case "mark_obligation_paid":
            return await executeMarkObligationPaid(args: arguments)
        case "add_income_source":
            return await executeAddIncomeSource(args: arguments)
        case "add_project":
            return await executeAddProject(args: arguments)
        case "log_water":
            return await executeLogWater(args: arguments)
        case "log_mood":
            return await executeLogMood(args: arguments)
        case "log_energy":
            return await executeLogEnergy(args: arguments)
        case "save_journal":
            return await executeSaveJournal(args: arguments)
        case "save_dream":
            return await executeSaveDream(args: arguments)
        case "add_goal":
            return await executeAddGoal(args: arguments)
        case "complete_goal":
            return await executeCompleteGoal(args: arguments)
        case "miss_goal":
            return await executeMissGoal(args: arguments)
        case "set_contact_followup":
            return await executeSetContactFollowup(args: arguments)
        case "update_contact_followup":
            return await executeUpdateContactFollowup(args: arguments)
        case "assess_relationship":
            return await executeAssessRelationship(args: arguments)
        case "add_contact_note":
            return await executeAddContactNote(args: arguments)
        case "dismiss_contact":
            return await executeDismissContact(args: arguments)
        case "call_contact":
            return await executeCallContact(args: arguments)
        case "text_contact":
            return await executeTextContact(args: arguments)
        case "log_contact_touch":
            return await executeLogContactTouch(args: arguments)
        case "start_navigation":
            return await executeStartNavigation(args: arguments)
        case "log_life_event":
            return await executeLogLifeEvent(args: arguments)
        case "log_income":
            return await executeLogIncome(args: arguments)
        case "log_expense":
            return await executeLogExpense(args: arguments)
        default:
            return "{\"error\": \"unknown tool '\(name)'\"}"
        }
    }

    private static var recallPeriodTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "recall_period",
                "description": "Pull aggregated life-graph data for a past period and return a summary. Use whenever the user asks about how a stretch of time WAS — 'how was March?', 'what was my best week last quarter?', 'how did I do in Q1?', 'what happened the week of April 15?'. Specify either a month name (with optional year) OR an explicit start_iso + end_iso. Returns averages across life dimensions, best/worst days, top events by intensity, and detected patterns inside the window. Use the result to ground your reply with real numbers — don't make up averages.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "month": [
                            "type": "string",
                            "description": "Month name like 'March' or 'march 2026'. Resolves to that calendar month. Use this OR start_iso/end_iso, not both."
                        ],
                        "start_iso": [
                            "type": "string",
                            "description": "Window start (ISO 8601). Required when not using month."
                        ],
                        "end_iso": [
                            "type": "string",
                            "description": "Window end (ISO 8601). Required when not using month."
                        ]
                    ]
                ]
            ]
        ]
    }

    private static func executeRecallPeriod(args: String) async -> String {
        struct RecallArgs: Codable {
            let month: String?
            let start_iso: String?
            let end_iso: String?
        }
        guard let parsed = try? JSONDecoder().decode(RecallArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }

        let cal = Calendar.current
        let now = Date()
        var start: Date?
        var end: Date?
        var label: String = ""

        if let monthInput = parsed.month?.trimmingCharacters(in: .whitespacesAndNewlines), !monthInput.isEmpty {
            // Try "March" or "March 2026"
            let parts = monthInput.split(separator: " ").map(String.init)
            let monthName = parts.first ?? monthInput
            let yearGuess = parts.count > 1 ? Int(parts[1]) : nil
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "MMMM"
            guard let monthDate = formatter.date(from: monthName.capitalized) else {
                return jsonResult(error: "could not parse month '\(monthInput)'")
            }
            let monthNum = cal.component(.month, from: monthDate)
            let year = yearGuess ?? cal.component(.year, from: now)
            // If user says "march" and we're past march this year, assume this year. If we're before, also this year.
            // If they specify explicit year, honor it.
            var comps = DateComponents()
            comps.year = year
            comps.month = monthNum
            comps.day = 1
            guard let s = cal.date(from: comps),
                  let e = cal.date(byAdding: .month, value: 1, to: s) else {
                return jsonResult(error: "could not resolve month boundaries")
            }
            start = s
            end = e
            let lf = DateFormatter(); lf.dateFormat = "MMMM yyyy"
            label = lf.string(from: s)
        } else if let s = parsed.start_iso.flatMap({ parseISODate($0) }),
                  let e = parsed.end_iso.flatMap({ parseISODate($0) }), e > s {
            start = s
            end = e
            let lf = DateFormatter(); lf.dateFormat = "MMM d"
            label = "\(lf.string(from: s)) – \(lf.string(from: e))"
        } else {
            return jsonResult(error: "specify month, or start_iso + end_iso")
        }

        guard let windowStart = start, let windowEnd = end else {
            return jsonResult(error: "could not resolve window")
        }

        let snapshots = DailySnapshotService.shared.snapshots.filter { $0.date >= windowStart && $0.date < windowEnd }
        let events = LifeEventsService.shared.events(since: windowStart, until: windowEnd)

        guard !snapshots.isEmpty || !events.isEmpty else {
            return jsonResult(success: true, summary: "No data tracked for \(label).")
        }

        // Composites
        let lifeAvg = snapshots.isEmpty ? 0 : snapshots.map { $0.lifeComposite }.reduce(0, +) / Double(snapshots.count)
        let workAvg = snapshots.isEmpty ? 0 : snapshots.map { $0.workComposite }.reduce(0, +) / Double(snapshots.count)
        let overallAvg = snapshots.isEmpty ? 0 : snapshots.map { $0.overallComposite }.reduce(0, +) / Double(snapshots.count)

        // Best / worst day by life composite
        let bestDay = snapshots.max(by: { $0.lifeComposite < $1.lifeComposite })
        let worstDay = snapshots.min(by: { $0.lifeComposite < $1.lifeComposite })

        // Dimension averages
        var dimAvgs: [String: Double] = [:]
        if !snapshots.isEmpty {
            for dim in Dimension.allCases {
                let total = snapshots.map { $0.value(for: dim) }.reduce(0, +)
                dimAvgs[dim.label] = total / Double(snapshots.count)
            }
        }

        // Top events
        let sortedEvents = events.sorted { $0.intensity > $1.intensity }.prefix(8)
        let topEventItems: [[String: Any]] = sortedEvents.map { ev in
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return [
                "date": f.string(from: ev.occurredAt),
                "category": ev.category.rawValue,
                "polarity": ev.polarity.rawValue,
                "intensity": ev.intensity,
                "note": ev.note
            ]
        }

        // Patterns inside the window
        let patterns = PatternDetector.detect(
            snapshots: snapshots,
            events: events,
            now: windowEnd,
            maxResults: 4
        ).map { $0.summary }

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "MMM d"

        var bestDayDict: [String: Any] = [:]
        if let b = bestDay {
            bestDayDict["date"] = dayFmt.string(from: b.date)
            bestDayDict["life_score"] = Int(b.lifeComposite.rounded())
        }
        var worstDayDict: [String: Any] = [:]
        if let w = worstDay {
            worstDayDict["date"] = dayFmt.string(from: w.date)
            worstDayDict["life_score"] = Int(w.lifeComposite.rounded())
        }

        let dimRounded: [String: Int] = dimAvgs.mapValues { Int($0.rounded()) }

        var payload: [String: Any] = [:]
        payload["success"] = true
        payload["label"] = label
        payload["snapshot_count"] = snapshots.count
        payload["event_count"] = events.count
        payload["life_avg"] = Int(lifeAvg.rounded())
        payload["work_avg"] = Int(workAvg.rounded())
        payload["overall_avg"] = Int(overallAvg.rounded())
        payload["best_day"] = bestDayDict.isEmpty ? NSNull() : bestDayDict
        payload["worst_day"] = worstDayDict.isEmpty ? NSNull() : worstDayDict
        payload["dimension_averages"] = dimRounded
        payload["top_events"] = topEventItems
        payload["patterns"] = patterns
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return jsonResult(success: true, summary: "Recall ready for \(label).")
    }

    private static var moveEventTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "move_event",
                "description": "Move a calendar event to a new time. ALWAYS ask the user to confirm before calling. Match the event by its title (case-insensitive contains). Use this when the user explicitly says 'move X' or agrees to a reschedule you proposed.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "event_title": [
                            "type": "string",
                            "description": "Title of the event to move (or unique substring of it)."
                        ],
                        "current_start_iso": [
                            "type": "string",
                            "description": "Optional. The event's current start time as ISO 8601 — helps disambiguate when multiple events share a title."
                        ],
                        "new_start_iso": [
                            "type": "string",
                            "description": "New start time in ISO 8601 (e.g. 2026-04-28T15:00:00Z)."
                        ]
                    ],
                    "required": ["event_title", "new_start_iso"]
                ]
            ]
        ]
    }

    private static var cancelEventTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "cancel_event",
                "description": "Delete a calendar event from the user's calendar. ALWAYS ask the user to confirm before calling. Match the event by title.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "event_title": [
                            "type": "string",
                            "description": "Title of the event to delete (or unique substring of it)."
                        ],
                        "current_start_iso": [
                            "type": "string",
                            "description": "Optional. Event's current start as ISO 8601 — helps disambiguate."
                        ]
                    ],
                    "required": ["event_title"]
                ]
            ]
        ]
    }

    private static var addEventTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_event",
                "description": "Create a new calendar event. Supports recurring blocks for daily/weekly structure. ALWAYS ask to confirm before calling. Note: third-party apps can't invite attendees on iOS — the user will need to add invitees manually if needed.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string"],
                        "start_iso": [
                            "type": "string",
                            "description": "Start time of the first occurrence in ISO 8601."
                        ],
                        "duration_minutes": [
                            "type": "integer",
                            "description": "Event duration in minutes."
                        ],
                        "recurrence": [
                            "type": "string",
                            "enum": ["none", "daily", "weekdays", "weekly"],
                            "description": "How often the event repeats. 'weekdays' = Mon–Fri only. 'weekly' = same day each week. Default 'none' for one-time events. Use 'weekdays' or 'weekly' for structural blocks (deep work, gym, recovery, etc.)."
                        ],
                        "recurrence_end_iso": [
                            "type": "string",
                            "description": "Optional. ISO 8601 date when the recurrence stops. Omit for indefinite repeat."
                        ],
                        "location": ["type": "string"],
                        "notes": ["type": "string"]
                    ],
                    "required": ["title", "start_iso", "duration_minutes"]
                ]
            ]
        ]
    }

    private static func executeMoveEvent(args: String) async -> String {
        struct MoveArgs: Codable {
            let event_title: String
            let current_start_iso: String?
            let new_start_iso: String
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(MoveArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        guard let newDate = parseISODate(parsed.new_start_iso) else {
            return jsonResult(error: "could not parse new_start_iso")
        }
        let hint = parsed.current_start_iso.flatMap { parseISODate($0) }
        let success = await CalendarService.shared.moveEvent(
            matchingTitle: parsed.event_title,
            near: hint,
            newStartDate: newDate
        )
        if success {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            return jsonResult(success: true, summary: "Moved '\(parsed.event_title)' to \(f.string(from: newDate)).")
        }
        return jsonResult(error: "could not find or move event '\(parsed.event_title)'")
    }

    private static func executeCancelEvent(args: String) async -> String {
        struct CancelArgs: Codable {
            let event_title: String
            let current_start_iso: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(CancelArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        let hint = parsed.current_start_iso.flatMap { parseISODate($0) }
        let success = await CalendarService.shared.deleteEvent(
            matchingTitle: parsed.event_title,
            near: hint
        )
        if success {
            return jsonResult(success: true, summary: "Cancelled '\(parsed.event_title)'.")
        }
        return jsonResult(error: "could not find or cancel event '\(parsed.event_title)'")
    }

    private static var eventsInWindowTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "events_in_window",
                "description": "List calendar events that fall inside a given time window. Use this BEFORE proposing a reschedule, to find conflicts. Required workflow when the user blocks off time (e.g. 'I'll be tied up 9-2:30 with Anderson'): (1) call this tool for that window, (2) read back the conflicts to the user, (3) propose moves/cancellations, (4) on confirmation, call move_event or cancel_event for each.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "start_iso": [
                            "type": "string",
                            "description": "Window start in ISO 8601."
                        ],
                        "end_iso": [
                            "type": "string",
                            "description": "Window end in ISO 8601."
                        ]
                    ],
                    "required": ["start_iso", "end_iso"]
                ]
            ]
        ]
    }

    private static func executeEventsInWindow(args: String) async -> String {
        struct WindowArgs: Codable {
            let start_iso: String
            let end_iso: String
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(WindowArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        guard let start = parseISODate(parsed.start_iso),
              let end = parseISODate(parsed.end_iso),
              end > start else {
            return jsonResult(error: "could not parse window or end <= start")
        }
        let events = CalendarService.shared.eventsInWindow(start: start, end: end)
        let priorityService = EventPriorityService.shared
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d, h:mm a"
        let items: [[String: Any]] = events.map { ev in
            var item: [String: Any] = [
                "id": ev.id,
                "title": ev.title,
                "start_iso": ISO8601DateFormatter().string(from: ev.startDate),
                "end_iso": ISO8601DateFormatter().string(from: ev.endDate),
                "start_label": f.string(from: ev.startDate),
                "duration_minutes": ev.durationMinutes,
                "is_all_day": ev.isAllDay,
                "attendee_count": ev.attendeeCount,
                "priority": "flexible"
            ]
            if let level = priorityService.priority(for: ev.id) {
                item["priority"] = level.rawValue
            }
            return item
        }
        let payload: [String: Any] = [
            "success": true,
            "count": items.count,
            "events": items
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return jsonResult(success: true, summary: "Found \(items.count) events in window.")
    }

    private static var setEventPriorityTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "set_event_priority",
                "description": "Tag a calendar event with a priority level so the user (and you, when rearranging) know what's movable. Levels: must_do (immovable, never touch without explicit permission), important (avoid cancelling, ask before moving), flexible (default — move freely), skippable (cancel or move freely; cancel these first when clearing time). Use when the user signals importance ('this Anderson meeting is critical', 'the standup can be skipped if needed') or when you infer it from context. Get the event_id from events_in_window.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "event_id": ["type": "string"],
                        "level": [
                            "type": "string",
                            "enum": ["mustDo", "important", "flexible", "skippable"]
                        ]
                    ],
                    "required": ["event_id", "level"]
                ]
            ]
        ]
    }

    private static func executeSetEventPriority(args: String) async -> String {
        struct PriorityArgs: Codable {
            let event_id: String
            let level: String
        }
        guard let parsed = try? JSONDecoder().decode(PriorityArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        guard let level = EventPriority.Level(rawValue: parsed.level) else {
            return jsonResult(error: "unknown level '\(parsed.level)'")
        }
        EventPriorityService.shared.set(eventIdentifier: parsed.event_id, level: level)
        return jsonResult(success: true, summary: "Set priority to \(level.label).")
    }

    private static var batchCalendarChangesTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "batch_calendar_changes",
                "description": "Apply MULTIPLE calendar changes in one call. PREFER this over calling move_event/cancel_event/add_event one at a time when the user wants several changes at once (e.g., 'rearrange around 9-2:30, push the 10am to 3, cancel the 1:15, add a 30min walk at 4'). Each operation in the array runs in turn. Returns a per-operation result. ALWAYS confirm with the user before calling — list the full plan first ('I'll move X to 3, cancel Y, and add Z — proceed?') and only call this on a yes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "operations": [
                            "type": "array",
                            "description": "Ordered list of changes to apply. Each item must include 'action' and the fields that action requires.",
                            "items": [
                                "type": "object",
                                "properties": [
                                    "action": [
                                        "type": "string",
                                        "enum": ["move", "cancel", "create"]
                                    ],
                                    "event_id": [
                                        "type": "string",
                                        "description": "For move and cancel — the event identifier from events_in_window."
                                    ],
                                    "event_title": [
                                        "type": "string",
                                        "description": "Fallback if event_id unavailable. Used by move/cancel to title-match within the day. Prefer event_id."
                                    ],
                                    "new_start_iso": [
                                        "type": "string",
                                        "description": "Required for move."
                                    ],
                                    "title": [
                                        "type": "string",
                                        "description": "Required for create."
                                    ],
                                    "start_iso": [
                                        "type": "string",
                                        "description": "Required for create."
                                    ],
                                    "duration_minutes": [
                                        "type": "integer",
                                        "description": "Required for create."
                                    ],
                                    "location": ["type": "string"],
                                    "notes": ["type": "string"]
                                ],
                                "required": ["action"]
                            ]
                        ]
                    ],
                    "required": ["operations"]
                ]
            ]
        ]
    }

    private static func executeBatchCalendarChanges(args: String) async -> String {
        struct Op: Codable {
            let action: String
            let event_id: String?
            let event_title: String?
            let new_start_iso: String?
            let title: String?
            let start_iso: String?
            let duration_minutes: Int?
            let location: String?
            let notes: String?
        }
        struct BatchArgs: Codable {
            let operations: [Op]
        }
        guard let parsed = try? JSONDecoder().decode(BatchArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        var results: [[String: Any]] = []
        var successCount = 0
        var failureCount = 0

        for (index, op) in parsed.operations.enumerated() {
            switch op.action {
            case "move":
                guard let newStart = op.new_start_iso.flatMap({ parseISODate($0) }) else {
                    results.append(["index": index, "action": "move", "success": false, "error": "missing or invalid new_start_iso"])
                    failureCount += 1
                    continue
                }
                if let id = op.event_id, !id.isEmpty {
                    let ok = await CalendarService.shared.moveEvent(id: id, newStartDate: newStart)
                    results.append(["index": index, "action": "move", "event_id": id, "success": ok])
                    ok ? (successCount += 1) : (failureCount += 1)
                } else if let title = op.event_title, !title.isEmpty {
                    let ok = await CalendarService.shared.moveEvent(matchingTitle: title, newStartDate: newStart)
                    results.append(["index": index, "action": "move", "event_title": title, "success": ok])
                    ok ? (successCount += 1) : (failureCount += 1)
                } else {
                    results.append(["index": index, "action": "move", "success": false, "error": "need event_id or event_title"])
                    failureCount += 1
                }
            case "cancel":
                if let id = op.event_id, !id.isEmpty {
                    let ok = await CalendarService.shared.deleteEvent(id: id)
                    results.append(["index": index, "action": "cancel", "event_id": id, "success": ok])
                    ok ? (successCount += 1) : (failureCount += 1)
                } else if let title = op.event_title, !title.isEmpty {
                    let ok = await CalendarService.shared.deleteEvent(matchingTitle: title)
                    results.append(["index": index, "action": "cancel", "event_title": title, "success": ok])
                    ok ? (successCount += 1) : (failureCount += 1)
                } else {
                    results.append(["index": index, "action": "cancel", "success": false, "error": "need event_id or event_title"])
                    failureCount += 1
                }
            case "create":
                guard let title = op.title, !title.isEmpty,
                      let startIso = op.start_iso, let start = parseISODate(startIso),
                      let duration = op.duration_minutes else {
                    results.append(["index": index, "action": "create", "success": false, "error": "missing title/start_iso/duration_minutes"])
                    failureCount += 1
                    continue
                }
                let ok = await CalendarService.shared.createEvent(
                    title: title,
                    startDate: start,
                    durationMinutes: duration,
                    location: op.location,
                    notes: op.notes
                )
                results.append(["index": index, "action": "create", "title": title, "success": ok])
                ok ? (successCount += 1) : (failureCount += 1)
            default:
                results.append(["index": index, "action": op.action, "success": false, "error": "unknown action"])
                failureCount += 1
            }
        }

        let payload: [String: Any] = [
            "success": failureCount == 0,
            "applied": successCount,
            "failed": failureCount,
            "results": results
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return jsonResult(success: failureCount == 0, summary: "Applied \(successCount) of \(successCount + failureCount).")
    }

    private static func executeAddEvent(args: String) async -> String {
        struct AddArgs: Codable {
            let title: String
            let start_iso: String
            let duration_minutes: Int
            let recurrence: String?
            let recurrence_end_iso: String?
            let location: String?
            let notes: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(AddArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        guard let startDate = parseISODate(parsed.start_iso) else {
            return jsonResult(error: "could not parse start_iso")
        }
        let recurrence = parsed.recurrence.flatMap { CalendarService.EventRecurrence(rawValue: $0) } ?? .none
        let endDate = parsed.recurrence_end_iso.flatMap { parseISODate($0) }
        let success = await CalendarService.shared.createEvent(
            title: parsed.title,
            startDate: startDate,
            durationMinutes: parsed.duration_minutes,
            location: parsed.location,
            notes: parsed.notes,
            recurrence: recurrence,
            recurrenceEndDate: endDate
        )
        if success {
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            let recLabel: String = {
                switch recurrence {
                case .none: return ""
                case .daily: return " (daily)"
                case .weekdays: return " (weekdays)"
                case .weekly: return " (weekly)"
                }
            }()
            return jsonResult(success: true, summary: "Created '\(parsed.title)' at \(f.string(from: startDate))\(recLabel).")
        }
        return jsonResult(error: "could not create event")
    }

    private static func executeForgetMemory(args: String) async -> String {
        struct ForgetArgs: Codable {
            let keywords: [String]
            let category: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ForgetArgs.self, from: data) else {
            return "{\"error\": \"could not parse args\"}"
        }
        let category = parsed.category.flatMap { MariaMemory.Category(rawValue: $0) }
        let removed = MemoryService.shared.deleteByKeywords(parsed.keywords, category: category)
        return jsonResult(success: true, summary: "Forgot \(removed) memor\(removed == 1 ? "y" : "ies").")
    }

    private static func executeSetReminder(args: String) async -> String {
        struct ReminderArgs: Codable {
            let title: String
            let due_iso_datetime: String?
            let notes: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ReminderArgs.self, from: data) else {
            return "{\"error\": \"could not parse args\"}"
        }

        var dueDate: Date?
        if let iso = parsed.due_iso_datetime {
            dueDate = parseISODate(iso)
        }

        let success = await RemindersService.shared.createReminder(
            title: parsed.title,
            dueDate: dueDate,
            notes: parsed.notes
        )

        if success {
            var summary = "Reminder created: '\(parsed.title)'"
            if let date = dueDate {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .short
                summary += " for \(f.string(from: date))"
            }
            return jsonResult(success: true, summary: summary)
        }
        return jsonResult(error: "failed to create reminder — check Reminders permission")
    }

    private static func executeAddMemory(args: String) async -> String {
        struct MemoryArgs: Codable {
            let content: String
            let category: String
            let keywords: [String]
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(MemoryArgs.self, from: data) else {
            return "{\"error\": \"could not parse args\"}"
        }
        guard let category = MariaMemory.Category(rawValue: parsed.category) else {
            return jsonResult(error: "invalid category")
        }

        let memory = MariaMemory(
            id: UUID(),
            content: parsed.content,
            category: category,
            keywords: parsed.keywords.map { $0.lowercased() },
            createdAt: Date(),
            mentionCount: 0
        )
        MemoryService.shared.add(memory)
        return jsonResult(success: true, summary: "Saved memory: \(parsed.content)")
    }

    private static func executeAddImportantDate(args: String) async -> String {
        struct DateArgs: Codable {
            let title: String
            let iso_date: String
            let recurrence: String
            let related_contact_name: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(DateArgs.self, from: data) else {
            return "{\"error\": \"could not parse args\"}"
        }
        guard let date = parseISODate(parsed.iso_date) else {
            return jsonResult(error: "could not parse date")
        }

        let recurrence: ImportantDate.Recurrence = parsed.recurrence == "yearly" ? .yearly : .once

        let item = ImportantDate(
            id: "user-\(UUID().uuidString)",
            title: parsed.title,
            date: date,
            recurrence: recurrence,
            source: .userEntered,
            relatedContactName: parsed.related_contact_name,
            relatedContactId: nil,
            icon: "📅",
            note: nil
        )
        ImportantDatesService.shared.upsert(item)
        return jsonResult(success: true, summary: "Added: \(parsed.title)")
    }

    // MARK: - Operator tool definitions

    private static var addPipelineDealTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_pipeline_deal",
                "description": "Add a new sales deal / opportunity / gig to the user's pipeline. Use when the user says they got a new lead, opportunity, gig, or potential client. Don't ask for confirmation — adding is non-destructive.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Short name of the deal or opportunity. e.g. 'Acme website redesign'."
                        ],
                        "contact_name": [
                            "type": "string",
                            "description": "Name of the prospect / contact on the deal."
                        ],
                        "contact_email": ["type": "string"],
                        "stage": [
                            "type": "string",
                            "enum": ["lead", "qualified", "proposal", "negotiation", "closedWon", "closedLost"],
                            "description": "Default 'lead' if not specified."
                        ],
                        "deal_value": [
                            "type": "number",
                            "description": "Estimated dollar value. Optional."
                        ],
                        "probability": [
                            "type": "number",
                            "description": "0.0 to 1.0. Optional — will default by stage if omitted."
                        ],
                        "next_action": [
                            "type": "string",
                            "description": "What needs to happen next. Optional."
                        ],
                        "next_action_iso_date": ["type": "string"],
                        "notes": ["type": "string"]
                    ],
                    "required": ["name", "contact_name"]
                ]
            ]
        ]
    }

    private static var updateDealStageTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "update_deal_stage",
                "description": "Move an existing pipeline deal to a new stage. Match the deal by name (case-insensitive contains). Use when the user says a deal advanced or fell through ('they signed', 'closed it', 'they passed'). For closedLost or other major shifts, ASK to confirm first.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "deal_name": [
                            "type": "string",
                            "description": "Name or distinctive substring of the deal to update."
                        ],
                        "new_stage": [
                            "type": "string",
                            "enum": ["lead", "qualified", "proposal", "negotiation", "closedWon", "closedLost"]
                        ]
                    ],
                    "required": ["deal_name", "new_stage"]
                ]
            ]
        ]
    }

    private static var markObligationPaidTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "mark_obligation_paid",
                "description": "Mark a bill / obligation as paid for this cycle. Match by title (case-insensitive contains). Recurring bills will roll forward automatically. Use when the user says they paid something ('paid rent', 'sent the car payment').",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Title or distinctive substring of the obligation."
                        ]
                    ],
                    "required": ["title"]
                ]
            ]
        ]
    }

    private static var addIncomeSourceTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_income_source",
                "description": "Add a new income path — a gig, client, salary, project, or passive stream. Use when the user mentions a new way they're earning money or a new client/contract. CRITICAL: For 'hourly' or 'perGig' rate_unit, you MUST ask the user how many hours or gigs per month they expect, then pass it as monthly_frequency. Without it, the monthly tally can't be computed. Adding is non-destructive once you have what you need — don't ask to confirm the save itself.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Short label for the income source."
                        ],
                        "type": [
                            "type": "string",
                            "enum": ["gig", "client", "salary", "project", "passive"]
                        ],
                        "typical_rate": [
                            "type": "number",
                            "description": "Dollar amount per rate_unit."
                        ],
                        "rate_unit": [
                            "type": "string",
                            "enum": ["hourly", "perGig", "monthly", "biweekly", "oneTime"]
                        ],
                        "reliability": [
                            "type": "string",
                            "enum": ["immediate", "daysOut", "weekly", "biweekly", "monthly", "projectBased"],
                            "description": "How fast cash arrives after work is done."
                        ],
                        "monthly_frequency": [
                            "type": "integer",
                            "description": "REQUIRED for hourly (hours/month) or perGig (gigs/month). Used to compute monthly tally. Omit for salary, monthly, biweekly, oneTime, project, passive."
                        ],
                        "notes": ["type": "string"]
                    ],
                    "required": ["title", "type", "typical_rate", "rate_unit", "reliability"]
                ]
            ]
        ]
    }

    private static var addProjectTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_project",
                "description": "Add a new project the user is working on. Adding is non-destructive — don't ask to confirm.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "detail": [
                            "type": "string",
                            "description": "Short description of what the project is. Optional."
                        ],
                        "deadline_iso_date": [
                            "type": "string",
                            "description": "ISO 8601 date if the project has a deadline. Optional."
                        ],
                        "status": [
                            "type": "string",
                            "enum": ["active", "paused", "completed", "dropped"],
                            "description": "Defaults to 'active' if omitted."
                        ]
                    ],
                    "required": ["name"]
                ]
            ]
        ]
    }

    // MARK: - Operator tool execution

    private static func executeAddPipelineDeal(args: String) async -> String {
        struct DealArgs: Codable {
            let name: String
            let contact_name: String
            let contact_email: String?
            let stage: String?
            let deal_value: Double?
            let probability: Double?
            let next_action: String?
            let next_action_iso_date: String?
            let notes: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(DealArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        let stage = parsed.stage.flatMap { PipelineDeal.Stage(rawValue: $0) } ?? .lead
        let probability = parsed.probability ?? defaultProbability(for: stage)
        let deal = PipelineDeal(
            id: UUID(),
            name: parsed.name,
            contactName: parsed.contact_name,
            contactEmail: parsed.contact_email,
            stage: stage,
            dealValue: parsed.deal_value ?? 0,
            probability: max(0, min(1, probability)),
            nextAction: parsed.next_action,
            nextActionDate: parsed.next_action_iso_date.flatMap { parseISODate($0) },
            lastContact: nil,
            notes: parsed.notes,
            createdAt: Date()
        )
        PipelineService.shared.upsert(deal)
        let valueStr = deal.dealValue > 0 ? " · $\(Int(deal.dealValue))" : ""
        return jsonResult(success: true, summary: "Added '\(parsed.name)' (\(stage.label)\(valueStr)).")
    }

    private static func executeUpdateDealStage(args: String) async -> String {
        struct StageArgs: Codable {
            let deal_name: String
            let new_stage: String
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(StageArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        guard let newStage = PipelineDeal.Stage(rawValue: parsed.new_stage) else {
            return jsonResult(error: "invalid stage")
        }
        let needle = parsed.deal_name.lowercased()
        let deals = PipelineService.shared.deals
        guard var match = deals.first(where: { $0.name.lowercased().contains(needle) }) else {
            return jsonResult(error: "no deal matching '\(parsed.deal_name)'")
        }
        match.stage = newStage
        match.probability = defaultProbability(for: newStage)
        PipelineService.shared.upsert(match)
        return jsonResult(success: true, summary: "Moved '\(match.name)' to \(newStage.label).")
    }

    private static func executeMarkObligationPaid(args: String) async -> String {
        struct PaidArgs: Codable { let title: String }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(PaidArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        let needle = parsed.title.lowercased()
        let obligations = ObligationsService.shared.obligations
        guard let match = obligations.first(where: { $0.title.lowercased().contains(needle) && !$0.isPaidThisCycle }) else {
            if let alreadyPaid = obligations.first(where: { $0.title.lowercased().contains(needle) }) {
                return jsonResult(success: true, summary: "'\(alreadyPaid.title)' was already marked paid.")
            }
            return jsonResult(error: "no obligation matching '\(parsed.title)'")
        }
        ObligationsService.shared.markPaid(id: match.id)
        return jsonResult(success: true, summary: "Marked '\(match.title)' paid ($\(Int(match.amount))).")
    }

    private static func executeAddIncomeSource(args: String) async -> String {
        struct SourceArgs: Codable {
            let title: String
            let type: String
            let typical_rate: Double
            let rate_unit: String
            let reliability: String
            let monthly_frequency: Int?
            let notes: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(SourceArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        guard let type = IncomeSource.IncomeType(rawValue: parsed.type),
              let rateUnit = IncomeSource.RateUnit(rawValue: parsed.rate_unit),
              let reliability = IncomeSource.Reliability(rawValue: parsed.reliability) else {
            return jsonResult(error: "invalid type, rate_unit, or reliability")
        }
        let source = IncomeSource(
            id: UUID(),
            title: parsed.title,
            type: type,
            typicalRate: parsed.typical_rate,
            rateUnit: rateUnit,
            reliability: reliability,
            monthlyFrequency: parsed.monthly_frequency,
            notes: parsed.notes
        )
        IncomeSourcesService.shared.upsert(source)
        let monthly = source.monthlyEstimate
        let monthlyPart = monthly > 0 ? " · ≈$\(Int(monthly))/mo" : ""
        return jsonResult(success: true, summary: "Added income path: \(parsed.title) ($\(Int(parsed.typical_rate)) \(rateUnit.label))\(monthlyPart).")
    }

    private static func executeAddProject(args: String) async -> String {
        struct ProjectArgs: Codable {
            let name: String
            let detail: String?
            let deadline_iso_date: String?
            let status: String?
        }
        guard let data = args.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ProjectArgs.self, from: data) else {
            return jsonResult(error: "could not parse args")
        }
        let status = parsed.status.flatMap { Project.Status(rawValue: $0) } ?? .active
        let project = Project(
            id: UUID(),
            name: parsed.name,
            detail: parsed.detail,
            deadline: parsed.deadline_iso_date.flatMap { parseISODate($0) },
            status: status,
            milestones: [],
            createdAt: Date()
        )
        ProjectsService.shared.upsert(project)
        return jsonResult(success: true, summary: "Added project: \(parsed.name).")
    }

    // MARK: - Life-side tool definitions

    private static var logWaterTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_water",
                "description": "Log water the user just drank. One glass = 16 oz. Use when they say 'I had a glass of water', 'just drank water', etc. Non-destructive — don't ask to confirm.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "ounces": [
                            "type": "integer",
                            "description": "Total ounces. Default 16 if user says 'a glass'. Multiply by glasses if they say 'two glasses'."
                        ]
                    ],
                    "required": []
                ]
            ]
        ]
    }

    private static var logMoodTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_mood",
                "description": "Log the user's mood as a 1–5 score. 1=very low, 2=low, 3=okay, 4=good, 5=great. Map their words: 'rough'=1-2, 'meh'=3, 'good'=4, 'amazing'=5.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "level": ["type": "integer", "description": "1 to 5"]
                    ],
                    "required": ["level"]
                ]
            ]
        ]
    }

    private static var logEnergyTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_energy",
                "description": "Log the user's physical energy level 1–5. Use when they explicitly mention energy ('feeling drained', 'wired today').",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "level": ["type": "integer", "description": "1 to 5"]
                    ],
                    "required": ["level"]
                ]
            ]
        ]
    }

    private static var saveJournalTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "save_journal",
                "description": "Save the user's intention or gratitude to today's journal. Use when they explicitly state an intention for the day or share something they're grateful for. Updates today's entry — overwrites existing intention/gratitude.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "intention": [
                            "type": "string",
                            "description": "The intention they set for today. Optional."
                        ],
                        "gratitude": [
                            "type": "string",
                            "description": "What they're grateful for today. Optional."
                        ]
                    ],
                    "required": []
                ]
            ]
        ]
    }

    private static var saveDreamTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "save_dream",
                "description": "Save a dream the user just told you. Returns immediately; analysis happens in background and lands in the Dream log within ~10 seconds. Use when the user describes a dream they had.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Short title summarizing the dream (you write this, not the user)."
                        ],
                        "description": [
                            "type": "string",
                            "description": "The dream as the user described it. Capture their words faithfully."
                        ]
                    ],
                    "required": ["title", "description"]
                ]
            ]
        ]
    }

    private static var addGoalTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_goal",
                "description": "Add a goal to the user's motivation hub. Use when they say things like 'my goal is...', 'I want to...', 'this week I'm going to...'. Pick the right timeframe from context.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": ["type": "string"],
                        "timeframe": [
                            "type": "string",
                            "enum": ["daily", "weekly", "q1", "q2", "q3", "q4", "yearly"]
                        ],
                        "detail": [
                            "type": "string",
                            "description": "Why it matters or extra context. Optional."
                        ],
                        "target_date_iso": [
                            "type": "string",
                            "description": "Optional ISO 8601 date by when they want it done."
                        ]
                    ],
                    "required": ["title", "timeframe"]
                ]
            ]
        ]
    }

    private static var completeGoalTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "complete_goal",
                "description": "Mark a goal as completed. Match by title (case-insensitive contains). Use when the user says they finished something they had set as a goal.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Title or distinctive substring of the goal."
                        ]
                    ],
                    "required": ["title"]
                ]
            ]
        ]
    }

    // MARK: - Life-side execution

    private static func executeLogWater(args: String) async -> String {
        struct WaterArgs: Codable { let ounces: Int? }
        let parsed = (try? JSONDecoder().decode(WaterArgs.self, from: Data(args.utf8))) ?? WaterArgs(ounces: nil)
        let ounces = parsed.ounces ?? 16
        let glasses = max(1, Int(round(Double(ounces) / 16.0)))
        for _ in 0..<glasses {
            WellnessLogService.shared.incrementWater()
        }
        return jsonResult(success: true, summary: "Logged \(ounces) oz of water.")
    }

    private static func executeLogMood(args: String) async -> String {
        struct LevelArgs: Codable { let level: Int }
        guard let parsed = try? JSONDecoder().decode(LevelArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let level = max(1, min(5, parsed.level))
        var entry = JournalService.shared.today()
        entry.mood = level
        JournalService.shared.upsert(entry)
        let labels = ["very low", "low", "okay", "good", "great"]
        return jsonResult(success: true, summary: "Logged mood: \(level)/5 (\(labels[level - 1])).")
    }

    private static func executeLogEnergy(args: String) async -> String {
        struct LevelArgs: Codable { let level: Int }
        guard let parsed = try? JSONDecoder().decode(LevelArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let level = max(1, min(5, parsed.level))
        WellnessLogService.shared.setEnergyToday(level)
        return jsonResult(success: true, summary: "Logged energy: \(level)/5.")
    }

    private static func executeSaveJournal(args: String) async -> String {
        struct JournalArgs: Codable {
            let intention: String?
            let gratitude: String?
        }
        guard let parsed = try? JSONDecoder().decode(JournalArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        var entry = JournalService.shared.today()
        var saved: [String] = []
        if let intention = parsed.intention?.trimmingCharacters(in: .whitespacesAndNewlines), !intention.isEmpty {
            entry.intention = intention
            saved.append("intention")
        }
        if let gratitude = parsed.gratitude?.trimmingCharacters(in: .whitespacesAndNewlines), !gratitude.isEmpty {
            entry.gratitude = gratitude
            saved.append("gratitude")
        }
        guard !saved.isEmpty else {
            return jsonResult(error: "no intention or gratitude provided")
        }
        JournalService.shared.upsert(entry)
        return jsonResult(success: true, summary: "Saved \(saved.joined(separator: " + ")) for today.")
    }

    private static func executeSaveDream(args: String) async -> String {
        struct DreamArgs: Codable {
            let title: String
            let description: String
        }
        guard let parsed = try? JSONDecoder().decode(DreamArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let dream = DreamEntry.make(
            title: parsed.title,
            description: parsed.description
        )
        DreamService.shared.upsert(dream)
        Task.detached {
            await DreamService.shared.analyze(dream)
        }
        return jsonResult(success: true, summary: "Saved dream '\(parsed.title)'. Analysis is rolling in.")
    }

    private static func executeAddGoal(args: String) async -> String {
        struct GoalArgs: Codable {
            let title: String
            let timeframe: String
            let detail: String?
            let target_date_iso: String?
        }
        guard let parsed = try? JSONDecoder().decode(GoalArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        guard let timeframe = Goal.Timeframe(rawValue: parsed.timeframe) else {
            return jsonResult(error: "invalid timeframe")
        }
        let goal = Goal(
            id: UUID(),
            title: parsed.title,
            detail: parsed.detail,
            timeframe: timeframe,
            status: .active,
            targetDate: parsed.target_date_iso.flatMap { parseISODate($0) },
            createdAt: Date(),
            completedAt: nil,
            parentGoalId: nil
        )
        GoalsService.shared.upsert(goal)
        return jsonResult(success: true, summary: "Added \(timeframe.label.lowercased()) goal: \(parsed.title).")
    }

    private static func executeCompleteGoal(args: String) async -> String {
        struct CompleteArgs: Codable { let title: String }
        guard let parsed = try? JSONDecoder().decode(CompleteArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let needle = parsed.title.lowercased()
        let goals = GoalsService.shared.goals.filter { $0.status == .active }
        guard let match = goals.first(where: { $0.title.lowercased().contains(needle) }) else {
            return jsonResult(error: "no active goal matching '\(parsed.title)'")
        }
        GoalsService.shared.markCompleted(id: match.id)
        return jsonResult(success: true, summary: "Marked '\(match.title)' complete.")
    }

    private static var missGoalTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "miss_goal",
                "description": "Mark a goal as missed — the user didn't complete it within the timeframe. Use when they admit a goal slipped or the deadline passed without it being done. This is for honest tracking, not punishment.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "title": [
                            "type": "string",
                            "description": "Title or substring of the goal to mark missed."
                        ]
                    ],
                    "required": ["title"]
                ]
            ]
        ]
    }

    private static func executeMissGoal(args: String) async -> String {
        struct MissArgs: Codable { let title: String }
        guard let parsed = try? JSONDecoder().decode(MissArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let needle = parsed.title.lowercased()
        let goals = GoalsService.shared.goals.filter { $0.status == .active }
        guard let match = goals.first(where: { $0.title.lowercased().contains(needle) }) else {
            return jsonResult(error: "no active goal matching '\(parsed.title)'")
        }
        GoalsService.shared.markMissed(id: match.id)
        return jsonResult(success: true, summary: "Marked '\(match.title)' missed.")
    }

    // MARK: - Contact tools

    private static var setContactFollowupTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "set_contact_followup",
                "description": "Schedule a follow-up reminder with a contact. Matches by name (case-insensitive contains across all iOS contacts). If multiple matches, the result lists them so you can ask the user to disambiguate. Non-destructive — don't ask to confirm.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Person's name or distinctive substring (e.g. 'Sarah Chen' or 'Sarah')."
                        ],
                        "iso_date": [
                            "type": "string",
                            "description": "When to follow up — ISO 8601 date or datetime."
                        ],
                        "reason": [
                            "type": "string",
                            "description": "Why — what's the next step. Optional."
                        ]
                    ],
                    "required": ["name", "iso_date"]
                ]
            ]
        ]
    }

    private static var updateContactFollowupTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "update_contact_followup",
                "description": "Update an existing follow-up with an outcome note, optionally complete it (clear next_followup), or reschedule it. Use after the user has actually had the conversation/meeting and wants to capture what happened. The note appends to the contact's saved notes AND saves to your long-term memory so you remember it next time. Examples: 'I just talked to Cedrick — he wants to meet next month, said the timing is tight right now.' / 'Talked to Sarah, she's good for the demo Thursday.'",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": [
                            "type": "string",
                            "description": "Person's name or distinctive substring."
                        ],
                        "outcome_note": [
                            "type": "string",
                            "description": "What happened in the follow-up. Will append to the contact's notes."
                        ],
                        "completed": [
                            "type": "boolean",
                            "description": "True if the follow-up is done and no new one is needed yet. Clears the scheduled date. Defaults to false if a new date is provided."
                        ],
                        "next_followup_iso": [
                            "type": "string",
                            "description": "Optional. ISO 8601 — reschedule for the next round."
                        ],
                        "next_followup_reason": [
                            "type": "string",
                            "description": "Optional reason for the next follow-up."
                        ]
                    ],
                    "required": ["name", "outcome_note"]
                ]
            ]
        ]
    }

    private static var addContactNoteTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "add_contact_note",
                "description": "Append a note to a contact's record. Use when the user shares something worth remembering about a person ('Sarah's dad just had heart surgery', 'David is allergic to shellfish'). If multiple name matches, returns them so you can disambiguate.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "note": [
                            "type": "string",
                            "description": "What to remember. One sentence is fine."
                        ]
                    ],
                    "required": ["name", "note"]
                ]
            ]
        ]
    }

    private static var assessRelationshipTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "assess_relationship",
                "description": "Update how the user feels about a contact across TWO dimensions: personal (friend/family warmth) and business (professional working relationship). CALL THIS AUTOMATICALLY whenever the user mentions a person in a way that reveals sentiment — don't ask them to rate. Pull cues from their words ('great conversation, lunch to catch up' → personal warmth up. 'frustrating client, can't pick a direction' → business friction). Pass `delta_personal` / `delta_business` to NUDGE existing scores by that amount (positive or negative integer; typical range ±3 to ±15 per signal). Pass `personal_score` / `business_score` only when you have a strong, fresh read or the user gives a direct rating. A single exchange can fire BOTH deltas — type doesn't suppress an off-axis cue. Optionally set `type` (personal/business/both) to record the contact's primary frame; this is a tiebreaker for ambiguous cues, not a content suppressor.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "delta_personal": [
                            "type": "integer",
                            "description": "Nudge personal score by this amount (-100 to +100). Use ±3 for soft signal, ±8 for clear sentiment, ±15 for major event. Defaults existing → 50 if no score yet. Omit if no personal-side signal."
                        ],
                        "delta_business": [
                            "type": "integer",
                            "description": "Nudge business score the same way. Omit if no business-side signal."
                        ],
                        "personal_score": [
                            "type": "integer",
                            "description": "Absolute set 0-100 — only if user gave a direct rating or you have a definitive read. Overrides delta_personal."
                        ],
                        "business_score": [
                            "type": "integer",
                            "description": "Absolute set 0-100 — same rules as personal_score."
                        ],
                        "type": [
                            "type": "string",
                            "enum": ["personal", "business", "both"],
                            "description": "Optional. Record the contact's primary frame. Set this when the user explicitly states the relationship type ('he's personal', 'this is a client'), or when promoting from one type to 'both' after repeated cross-axis cues. Tiebreaker only — doesn't suppress off-axis content cues."
                        ],
                        "context": [
                            "type": "string",
                            "description": "Optional one-sentence summary in the user's voice. REPLACES previous context, so include accumulated nuance ('reliable client but indecisive on big calls')."
                        ]
                    ],
                    "required": ["name"]
                ]
            ]
        ]
    }

    private static func executeAssessRelationship(args: String) async -> String {
        struct AssessArgs: Codable {
            let name: String
            let delta_personal: Int?
            let delta_business: Int?
            let personal_score: Int?
            let business_score: Int?
            let type: String?
            let context: String?
        }
        guard let parsed = try? JSONDecoder().decode(AssessArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let trimmedContext = parsed.context?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedType = parsed.type.flatMap { ContactNote.RelationshipType(rawValue: $0) }
        let hasAnyChange = parsed.delta_personal != nil
            || parsed.delta_business != nil
            || parsed.personal_score != nil
            || parsed.business_score != nil
            || parsedType != nil
            || (trimmedContext?.isEmpty == false)
        guard hasAnyChange else {
            return jsonResult(error: "nothing to update — provide a delta, an absolute score, type, or context")
        }

        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            let existing = ContactNotesService.shared.note(for: contact.id)

            func resolved(absolute: Int?, delta: Int?, current: Int?) -> Int? {
                if let abs = absolute {
                    return max(0, min(100, abs))
                }
                if let d = delta {
                    let base = current ?? 50
                    return max(0, min(100, base + d))
                }
                return current
            }

            let newPersonal = resolved(
                absolute: parsed.personal_score,
                delta: parsed.delta_personal,
                current: existing.personalScore
            )
            let newBusiness = resolved(
                absolute: parsed.business_score,
                delta: parsed.delta_business,
                current: existing.businessScore
            )
            let newType = parsedType ?? existing.relationshipType

            let note = ContactNote(
                contactId: contact.id,
                notes: existing.notes,
                nextFollowUp: existing.nextFollowUp,
                followUpReason: existing.followUpReason,
                status: existing.status,
                lastTouchedAt: existing.lastTouchedAt,
                lastTouchChannel: existing.lastTouchChannel,
                relationshipType: newType,
                personalScore: newPersonal,
                businessScore: newBusiness,
                relationshipContext: (trimmedContext?.isEmpty == false ? trimmedContext : existing.relationshipContext),
                updatedAt: Date()
            )
            ContactNotesService.shared.upsert(note)

            var summaryParts: [String] = []
            if let parsedType { summaryParts.append("type \(parsedType.rawValue)") }
            if let p = newPersonal { summaryParts.append("personal \(p)") }
            if let b = newBusiness { summaryParts.append("business \(b)") }
            if let context = trimmedContext, !context.isEmpty {
                summaryParts.append("\"\(context)\"")
            }
            let memoryContent = "Relationship sentiment for \(contact.displayName): \(summaryParts.joined(separator: ", "))"
            saveContactMemory(contact: contact, content: memoryContent, category: .fact)
            return jsonResult(success: true, summary: "Updated \(contact.displayName) — \(summaryParts.joined(separator: ", ")).")
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    private static var callContactTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "call_contact",
                "description": "Open the iOS phone app with this person's number ready to dial. iOS will show a 'Call <name>?' confirmation — the user manually taps Call. You don't dial for them. Use when the user says 'call X' or 'I need to call X'.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"]
                    ],
                    "required": ["name"]
                ]
            ]
        ]
    }

    private static var logLifeEventTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_life_event",
                "description": "Capture a life event the user just mentioned that affects their state — relationship moment, achievement, setback, recreation, rest, stressor, body event. This logs to the Life Score graph and influences their dimensions for days. Use whenever they mention something happening to them, positive or negative. Examples: 'got into a fight with my wife' (relationship/negative/4), 'just passed my exam' (achievement/positive/4), 'watched a great movie' (recreation/positive/2), 'late on rent, freaking out' (stress/negative/5 — also call mark_obligation_paid or set_reminder if relevant), 'took a nap, feel better' (rest/positive/3), 'got the flu' (body/negative/4). Always pick a category that fits — don't force it.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "category": [
                            "type": "string",
                            "enum": ["relationship", "achievement", "setback", "recreation", "rest", "stress", "body", "other"]
                        ],
                        "polarity": [
                            "type": "string",
                            "enum": ["positive", "negative", "neutral", "signal"]
                        ],
                        "intensity": [
                            "type": "integer",
                            "description": "1 (mild) to 5 (major). Match the user's emotional weight."
                        ],
                        "note": [
                            "type": "string",
                            "description": "Brief description of what happened, in the user's voice."
                        ],
                        "when_iso": [
                            "type": "string",
                            "description": "Optional ISO 8601 datetime. Defaults to now."
                        ]
                    ],
                    "required": ["category", "polarity", "intensity", "note"]
                ]
            ]
        ]
    }

    private static var startNavigationTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "start_navigation",
                "description": "Open Apple Maps with directions to a destination. ALWAYS ASK the user first ('Want me to start directions?') — this pulls them out of the app and starts navigation. Use when they confirm a navigation prompt or explicitly ask 'navigate to X' / 'directions to X' / 'head there now'. The destination can be an address, business name, or venue name — Apple Maps geocodes.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "destination": [
                            "type": "string",
                            "description": "Address, business name, or venue. Pull from the calendar event's venue field when responding to a calendar-driven nav prompt."
                        ],
                        "transport_mode": [
                            "type": "string",
                            "enum": ["driving", "walking", "transit"],
                            "description": "Defaults to driving if omitted."
                        ]
                    ],
                    "required": ["destination"]
                ]
            ]
        ]
    }

    private static var logContactTouchTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_contact_touch",
                "description": "Record that the user just had contact with someone — call, text, email, in-person, anything. Updates the contact's 'last contact' timestamp so the network card reflects the real interaction, not just calendar history. Use whenever the user mentions communicating with someone ('just got off the phone with X', 'texted Y', 'met Z for lunch', 'spoke with him today at 12:45'). Non-destructive.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "when_iso": [
                            "type": "string",
                            "description": "Optional ISO 8601 datetime. Defaults to now if omitted."
                        ],
                        "channel": [
                            "type": "string",
                            "enum": ["call", "text", "email", "met", "video", "other"],
                            "description": "Optional. How the contact happened."
                        ]
                    ],
                    "required": ["name"]
                ]
            ]
        ]
    }

    private static var textContactTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "text_contact",
                "description": "Open the iOS Messages app with this person ready to text. The user reviews and manually taps Send — you don't send for them. Use when the user says 'text X', 'message X', or 'shoot X a quick note'. You can optionally pre-fill the message body so the user just taps send.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "initial_message": [
                            "type": "string",
                            "description": "Optional pre-filled message body. Keep it short and natural — the user reviews before sending."
                        ]
                    ],
                    "required": ["name"]
                ]
            ]
        ]
    }

    private static var dismissContactTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "dismiss_contact",
                "description": "Mark a contact as a dead lead so they stop appearing in the network card. Use when the user says they're done with someone or a deal/relationship is over. ASK to confirm before calling — this is destructive in spirit.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"]
                    ],
                    "required": ["name"]
                ]
            ]
        ]
    }

    // MARK: - Contact tool execution

    private static func resolveContact(name: String) async -> Result<ContactSummary, ContactLookupResult> {
        let needle = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let all = await ContactsService.shared.loadAllContacts()

        // Pass 1: exact substring match
        let exact = all.filter { $0.displayName.lowercased().contains(needle) }
        if exact.count == 1 { return .success(exact[0]) }
        if exact.count > 1 { return .failure(.multiple(exact)) }

        // Pass 2: fuzzy match (handles Cedric/Cedrick, voice transcription drift)
        let queryTokens = needle.split(separator: " ").map(String.init)
        var scored: [(ContactSummary, Double)] = []
        for contact in all {
            let nameTokens = contact.displayName.lowercased().split(separator: " ").map(String.init)
            let score = fuzzyNameScore(queryTokens: queryTokens, nameTokens: nameTokens)
            if score >= 0.72 {
                scored.append((contact, score))
            }
        }
        scored.sort { $0.1 > $1.1 }

        if scored.isEmpty { return .failure(.none) }

        // If top match is clearly ahead of the next, take it; otherwise return all close matches
        let topScore = scored[0].1
        let runnerUp = scored.dropFirst().first?.1 ?? 0
        if scored.count == 1 || (topScore - runnerUp) > 0.12 {
            return .success(scored[0].0)
        }
        return .failure(.multiple(Array(scored.prefix(5).map { $0.0 })))
    }

    private static func fuzzyNameScore(queryTokens: [String], nameTokens: [String]) -> Double {
        guard !queryTokens.isEmpty, !nameTokens.isEmpty else { return 0 }
        var total: Double = 0
        for qt in queryTokens {
            var bestForToken: Double = 0
            for nt in nameTokens {
                let distance = levenshtein(qt, nt)
                let maxLen = max(qt.count, nt.count)
                let sim = maxLen > 0 ? 1.0 - Double(distance) / Double(maxLen) : 0
                bestForToken = max(bestForToken, sim)
            }
            total += bestForToken
        }
        return total / Double(queryTokens.count)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }
        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            (prev, curr) = (curr, prev)
        }
        return prev[n]
    }

    private enum ContactLookupResult: Error {
        case none
        case multiple([ContactSummary])
    }

    private static func executeSetContactFollowup(args: String) async -> String {
        struct FollowupArgs: Codable {
            let name: String
            let iso_date: String
            let reason: String?
        }
        guard let parsed = try? JSONDecoder().decode(FollowupArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        guard let date = parseISODate(parsed.iso_date) else {
            return jsonResult(error: "could not parse iso_date")
        }
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            let existing = ContactNotesService.shared.note(for: contact.id)
            let note = ContactNote(
                contactId: contact.id,
                notes: existing.notes,
                nextFollowUp: date,
                followUpReason: parsed.reason,
                status: .active,
                updatedAt: Date()
            )
            ContactNotesService.shared.upsert(note)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let reasonPart = parsed.reason.map { ": \($0)" } ?? ""
            saveContactMemory(
                contact: contact,
                content: "Follow-up scheduled with \(contact.displayName) for \(dateFormatter.string(from: date))\(reasonPart).",
                category: .commitment
            )
            return jsonResult(success: true, summary: "Set follow-up with \(contact.displayName) on \(dateFormatter.string(from: date)).")
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { contact -> String in
                if let role = contact.role { return "\(contact.displayName) (\(role))" }
                return contact.displayName
            }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    private static func executeUpdateContactFollowup(args: String) async -> String {
        struct UpdateArgs: Codable {
            let name: String
            let outcome_note: String
            let completed: Bool?
            let next_followup_iso: String?
            let next_followup_reason: String?
        }
        guard let parsed = try? JSONDecoder().decode(UpdateArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            let existing = ContactNotesService.shared.note(for: contact.id)

            let trimmedNote = parsed.outcome_note.trimmingCharacters(in: .whitespacesAndNewlines)
            let stamp: String = {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                return f.string(from: Date())
            }()
            let combinedNotes: String
            if existing.notes.isEmpty {
                combinedNotes = "[\(stamp)] \(trimmedNote)"
            } else {
                combinedNotes = existing.notes + "\n\n[\(stamp)] " + trimmedNote
            }

            let nextDate = parsed.next_followup_iso.flatMap { parseISODate($0) }
            let shouldComplete = parsed.completed ?? (nextDate == nil)
            let resolvedNextDate = shouldComplete ? nil : nextDate
            let resolvedReason = shouldComplete ? nil : parsed.next_followup_reason

            let note = ContactNote(
                contactId: contact.id,
                notes: combinedNotes,
                nextFollowUp: resolvedNextDate,
                followUpReason: resolvedReason,
                status: existing.status,
                lastTouchedAt: existing.lastTouchedAt,
                lastTouchChannel: existing.lastTouchChannel,
                updatedAt: Date()
            )
            ContactNotesService.shared.upsert(note)

            // Also save a long-term memory so Maria remembers this beyond the rolling turn buffer.
            saveContactMemory(
                contact: contact,
                content: "Follow-up update with \(contact.displayName): \(trimmedNote)",
                category: .context
            )

            let summaryParts = ["Updated \(contact.displayName)'s follow-up notes"]
            var detail = summaryParts.joined()
            if let nextDate = resolvedNextDate {
                let f = DateFormatter()
                f.dateStyle = .medium
                detail += " · next round \(f.string(from: nextDate))"
            } else if shouldComplete {
                detail += " · marked complete"
            }
            return jsonResult(success: true, summary: detail + ".")

        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    /// Save a contact-tagged memory entry so Maria recalls context across sessions.
    private static func saveContactMemory(
        contact: ContactSummary,
        content: String,
        category: MariaMemory.Category
    ) {
        let nameKeywords = contact.displayName
            .lowercased()
            .split(separator: " ")
            .map(String.init)
        var keywords = nameKeywords + ["follow_up", "contact"]
        if let role = contact.role?.lowercased() {
            keywords.append(role)
        }
        let memory = MariaMemory(
            id: UUID(),
            content: content,
            category: category,
            keywords: keywords,
            createdAt: Date(),
            mentionCount: 0
        )
        MemoryService.shared.add(memory)
    }

    private static func executeAddContactNote(args: String) async -> String {
        struct NoteArgs: Codable {
            let name: String
            let note: String
        }
        guard let parsed = try? JSONDecoder().decode(NoteArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            let existing = ContactNotesService.shared.note(for: contact.id)
            let combined: String
            if existing.notes.isEmpty {
                combined = parsed.note
            } else {
                combined = existing.notes + "\n\n" + parsed.note
            }
            let note = ContactNote(
                contactId: contact.id,
                notes: combined,
                nextFollowUp: existing.nextFollowUp,
                followUpReason: existing.followUpReason,
                status: existing.status,
                updatedAt: Date()
            )
            ContactNotesService.shared.upsert(note)
            saveContactMemory(
                contact: contact,
                content: "About \(contact.displayName): \(parsed.note)",
                category: .fact
            )
            return jsonResult(success: true, summary: "Saved note on \(contact.displayName).")
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    // MARK: - Money tools

    private static var logIncomeTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_income",
                "description": "Log a real income receipt to the ledger. Use when the user says they got paid or received money ('got $500 from DoorDash today', 'Acme paid the invoice'). This drives the daily/weekly/monthly P/L. Non-destructive.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "amount": [
                            "type": "number",
                            "description": "Dollar amount, positive."
                        ],
                        "source": [
                            "type": "string",
                            "description": "Who/where it came from (e.g. 'DoorDash', 'Acme Corp')."
                        ],
                        "occurred_iso": [
                            "type": "string",
                            "description": "Optional ISO 8601 date for when. Defaults to now."
                        ],
                        "note": [
                            "type": "string",
                            "description": "Optional context."
                        ]
                    ],
                    "required": ["amount"]
                ]
            ]
        ]
    }

    private static var logExpenseTool: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": "log_expense",
                "description": "Log an expense to the ledger. Use when the user says they spent money ('spent $45 on groceries', 'paid $1800 for rent'). This drives the daily/weekly/monthly P/L. Non-destructive.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "amount": [
                            "type": "number",
                            "description": "Dollar amount, positive."
                        ],
                        "category": [
                            "type": "string",
                            "description": "What kind (e.g. 'Food', 'Transport', 'Subscription', 'Housing'). Free text."
                        ],
                        "occurred_iso": [
                            "type": "string",
                            "description": "Optional ISO 8601 date for when. Defaults to now."
                        ],
                        "note": [
                            "type": "string",
                            "description": "Optional context."
                        ]
                    ],
                    "required": ["amount"]
                ]
            ]
        ]
    }

    private static func executeLogIncome(args: String) async -> String {
        struct IncomeArgs: Codable {
            let amount: Double
            let source: String?
            let occurred_iso: String?
            let note: String?
        }
        guard let parsed = try? JSONDecoder().decode(IncomeArgs.self, from: Data(args.utf8)),
              parsed.amount > 0 else {
            return jsonResult(error: "could not parse args or amount is zero")
        }
        let occurred = parsed.occurred_iso.flatMap { parseISODate($0) } ?? Date()
        let tx = MoneyTransaction(
            id: UUID(),
            amount: parsed.amount,
            direction: .income,
            category: nil,
            source: parsed.source,
            note: parsed.note,
            occurredAt: occurred,
            createdAt: Date()
        )
        TransactionsService.shared.upsert(tx)
        let sourcePart = parsed.source.map { " from \($0)" } ?? ""
        return jsonResult(success: true, summary: "Logged $\(Int(parsed.amount)) income\(sourcePart).")
    }

    private static func executeLogExpense(args: String) async -> String {
        struct ExpenseArgs: Codable {
            let amount: Double
            let category: String?
            let occurred_iso: String?
            let note: String?
        }
        guard let parsed = try? JSONDecoder().decode(ExpenseArgs.self, from: Data(args.utf8)),
              parsed.amount > 0 else {
            return jsonResult(error: "could not parse args or amount is zero")
        }
        let occurred = parsed.occurred_iso.flatMap { parseISODate($0) } ?? Date()
        let tx = MoneyTransaction(
            id: UUID(),
            amount: parsed.amount,
            direction: .expense,
            category: parsed.category,
            source: nil,
            note: parsed.note,
            occurredAt: occurred,
            createdAt: Date()
        )
        TransactionsService.shared.upsert(tx)
        let catPart = parsed.category.map { " for \($0)" } ?? ""
        return jsonResult(success: true, summary: "Logged $\(Int(parsed.amount)) expense\(catPart).")
    }

    private static func executeCallContact(args: String) async -> String {
        struct CallArgs: Codable { let name: String }
        guard let parsed = try? JSONDecoder().decode(CallArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            guard let phone = contact.primaryPhone, !phone.isEmpty else {
                return jsonResult(error: "\(contact.displayName) has no phone number on file")
            }
            #if !os(macOS)
            let cleaned = phone.filter { "+0123456789".contains($0) }
            guard let url = URL(string: "tel:\(cleaned)") else {
                return jsonResult(error: "invalid phone number for \(contact.displayName)")
            }
            let opened = await UIApplication.shared.open(url)
            if opened {
                return jsonResult(success: true, summary: "Opening phone for \(contact.displayName) at \(phone). Tap Call to dial.")
            }
            return jsonResult(error: "iOS rejected the call URL — make sure this device can place calls.")
            #else
            return jsonResult(error: "Calling not available on macOS.")
            #endif
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    private static func executeLogLifeEvent(args: String) async -> String {
        struct EventArgs: Codable {
            let category: String
            let polarity: String
            let intensity: Int
            let note: String?
            let when_iso: String?
        }
        guard let parsed = try? JSONDecoder().decode(EventArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        guard let category = LifeEvent.Category(rawValue: parsed.category) else {
            return jsonResult(error: "invalid category")
        }
        guard let polarity = LifeEvent.Polarity(rawValue: parsed.polarity) else {
            return jsonResult(error: "invalid polarity")
        }
        let occurredAt = parsed.when_iso.flatMap { parseISODate($0) } ?? Date()
        let intensity = max(1, min(5, parsed.intensity))

        let event = LifeEvent(
            id: UUID(),
            occurredAt: occurredAt,
            category: category,
            polarity: polarity,
            intensity: intensity,
            note: parsed.note?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        LifeEventsService.shared.upsert(event)

        let intensityLabel: String = {
            switch intensity {
            case 1: return "mild"
            case 2: return "light"
            case 3: return "real"
            case 4: return "heavy"
            case 5: return "major"
            default: return "logged"
            }
        }()
        return jsonResult(success: true, summary: "Logged \(category.rawValue) (\(polarity.rawValue), \(intensityLabel)).")
    }

    private static func executeStartNavigation(args: String) async -> String {
        struct NavArgs: Codable {
            let destination: String
            let transport_mode: String?
        }
        guard let parsed = try? JSONDecoder().decode(NavArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let trimmed = parsed.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return jsonResult(error: "destination is empty")
        }
        #if !os(macOS)
        let dirflg: String
        switch (parsed.transport_mode ?? "driving").lowercased() {
        case "walking": dirflg = "w"
        case "transit": dirflg = "r"
        default: dirflg = "d"
        }
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)&dirflg=\(dirflg)") else {
            return jsonResult(error: "invalid destination")
        }
        let opened = await UIApplication.shared.open(url)
        if opened {
            let modeLabel = parsed.transport_mode ?? "driving"
            return jsonResult(success: true, summary: "Opening Maps — \(modeLabel) directions to \(trimmed).")
        }
        return jsonResult(error: "iOS rejected the maps URL")
        #else
        return jsonResult(error: "Maps not available on macOS")
        #endif
    }

    private static func executeLogContactTouch(args: String) async -> String {
        struct TouchArgs: Codable {
            let name: String
            let when_iso: String?
            let channel: String?
        }
        guard let parsed = try? JSONDecoder().decode(TouchArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        let when = parsed.when_iso.flatMap { parseISODate($0) } ?? Date()
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            let existing = ContactNotesService.shared.note(for: contact.id)
            let note = ContactNote(
                contactId: contact.id,
                notes: existing.notes,
                nextFollowUp: existing.nextFollowUp,
                followUpReason: existing.followUpReason,
                status: existing.status,
                lastTouchedAt: when,
                lastTouchChannel: parsed.channel,
                updatedAt: Date()
            )
            ContactNotesService.shared.upsert(note)
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            let channelPart = parsed.channel.map { " (\($0))" } ?? ""
            return jsonResult(success: true, summary: "Logged contact with \(contact.displayName) at \(f.string(from: when))\(channelPart).")
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    private static func executeTextContact(args: String) async -> String {
        struct TextArgs: Codable {
            let name: String
            let initial_message: String?
        }
        guard let parsed = try? JSONDecoder().decode(TextArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            guard let phone = contact.primaryPhone, !phone.isEmpty else {
                return jsonResult(error: "\(contact.displayName) has no phone number on file")
            }
            #if !os(macOS)
            let cleaned = phone.filter { "+0123456789".contains($0) }
            var urlString = "sms:\(cleaned)"
            if let body = parsed.initial_message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !body.isEmpty,
               let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?body=\(encoded)"
            }
            guard let url = URL(string: urlString) else {
                return jsonResult(error: "invalid SMS URL for \(contact.displayName)")
            }
            let opened = await UIApplication.shared.open(url)
            if opened {
                let bodyPart = (parsed.initial_message?.isEmpty == false) ? " with draft ready" : ""
                return jsonResult(success: true, summary: "Opening Messages for \(contact.displayName)\(bodyPart). Review and tap Send.")
            }
            return jsonResult(error: "iOS rejected the SMS URL — make sure this device can send messages.")
            #else
            return jsonResult(error: "Messages not available on macOS.")
            #endif
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    private static func executeDismissContact(args: String) async -> String {
        struct DismissArgs: Codable { let name: String }
        guard let parsed = try? JSONDecoder().decode(DismissArgs.self, from: Data(args.utf8)) else {
            return jsonResult(error: "could not parse args")
        }
        switch await resolveContact(name: parsed.name) {
        case .success(let contact):
            let existing = ContactNotesService.shared.note(for: contact.id)
            let note = ContactNote(
                contactId: contact.id,
                notes: existing.notes,
                nextFollowUp: nil,
                followUpReason: nil,
                status: .deadLead,
                updatedAt: Date()
            )
            ContactNotesService.shared.upsert(note)
            return jsonResult(success: true, summary: "Dismissed \(contact.displayName) as a dead lead.")
        case .failure(.none):
            return jsonResult(error: "no contact matching '\(parsed.name)'")
        case .failure(.multiple(let candidates)):
            let names = candidates.prefix(5).map { $0.displayName }
            return jsonResult(error: "multiple contacts match '\(parsed.name)': \(names.joined(separator: ", ")). Ask which one.")
        }
    }

    private static func defaultProbability(for stage: PipelineDeal.Stage) -> Double {
        switch stage {
        case .lead: return 0.1
        case .qualified: return 0.25
        case .proposal: return 0.5
        case .negotiation: return 0.75
        case .closedWon: return 1.0
        case .closedLost: return 0.0
        }
    }

    // MARK: - Helpers

    private static func parseISODate(_ string: String) -> Date? {
        let withTime = ISO8601DateFormatter()
        withTime.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withTime.date(from: string) { return d }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: string) { return d }

        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate]
        if let d = dateOnly.date(from: string) { return d }

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: string)
    }

    private static func jsonResult(success: Bool = false, summary: String? = nil, error: String? = nil) -> String {
        var dict: [String: Any] = [:]
        dict["success"] = success
        if let summary { dict["summary"] = summary }
        if let error { dict["error"] = error }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"success\": false}"
        }
        return str
    }
}
