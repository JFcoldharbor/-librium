import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var preferences: NotificationPreferences
    @Published private(set) var authStatus: UNAuthorizationStatus = .notDetermined

    private let store: JSONStore
    private static let storageKey = "equilibrium.notifications.preferences"

    private static let hydrationHours = [9, 11, 13, 15, 17, 19]
    private static let meetingLeadTime: TimeInterval = -5 * 60          // 5 min before
    private static let billLeadTime: TimeInterval = -24 * 60 * 60       // 24 h before

    private var cancellables = Set<AnyCancellable>()

    init(store: JSONStore = .shared) {
        self.store = store
        self.preferences = store.load(NotificationPreferences.self, key: Self.storageKey) ?? .default
        wireAutoSync()
    }

    func refreshAuthStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthStatus()
            return granted
        } catch {
            return false
        }
    }

    func setMorningIntention(enabled: Bool) async {
        preferences.morningIntention = enabled
        savePreferences()
        if enabled {
            await scheduleDaily(
                id: "morning.intention",
                hour: 8,
                title: "Morning intention",
                body: "What do you want to bring into today?"
            )
        } else {
            unschedule(["morning.intention"])
        }
    }

    func setEveningReflection(enabled: Bool) async {
        preferences.eveningReflection = enabled
        savePreferences()
        if enabled {
            await scheduleDaily(
                id: "evening.reflection",
                hour: 20,
                title: "Evening reflection",
                body: "How was today? Take a moment to reflect."
            )
        } else {
            unschedule(["evening.reflection"])
        }
    }

    func setHydrationReminders(enabled: Bool) async {
        preferences.hydrationReminders = enabled
        savePreferences()
        let ids = Self.hydrationHours.map { "hydration.\($0)" }
        if enabled {
            for hour in Self.hydrationHours {
                await scheduleDaily(
                    id: "hydration.\(hour)",
                    hour: hour,
                    title: "Hydration",
                    body: "Time for water."
                )
            }
        } else {
            unschedule(ids)
        }
    }

    func setBreathingReminder(enabled: Bool) async {
        preferences.breathingReminder = enabled
        savePreferences()
        if enabled {
            await scheduleDaily(
                id: "breathing",
                hour: 15,
                title: "Breathe",
                body: "Take four cycles to reset."
            )
        } else {
            unschedule(["breathing"])
        }
    }

    func setMeetingHeadsUp(enabled: Bool) async {
        preferences.meetingHeadsUp = enabled
        savePreferences()
        await syncMeetingHeadsUps()
    }

    func setBillReminders(enabled: Bool) async {
        preferences.billReminders = enabled
        savePreferences()
        await syncBillReminders()
    }

    func setFollowUpReminders(enabled: Bool) async {
        preferences.followUpReminders = enabled
        savePreferences()
        await syncFollowUpReminders()
    }

    // MARK: - Auto-sync

    private func wireAutoSync() {
        NotificationCenter.default.publisher(for: .calendarDidChange)
            .sink { [weak self] _ in
                Task { await self?.syncMeetingHeadsUps() }
            }
            .store(in: &cancellables)

        ObligationsService.shared.$obligations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.syncBillReminders() }
            }
            .store(in: &cancellables)

        ContactNotesService.shared.$notesByContactId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.syncFollowUpReminders() }
            }
            .store(in: &cancellables)
    }

    /// Run on app launch to refresh all enabled syncs.
    func bootstrap() async {
        registerCategoriesAndDelegate()
        await refreshAuthStatus()
        await syncMeetingHeadsUps()
        await syncBillReminders()
        await syncFollowUpReminders()
    }

    private func registerCategoriesAndDelegate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationActionHandler.shared

        let directionsAction = UNNotificationAction(
            identifier: NotificationActionHandler.directionsActionID,
            title: "Directions",
            options: [.foreground]
        )
        let meetingCategory = UNNotificationCategory(
            identifier: NotificationActionHandler.meetingCategoryID,
            actions: [directionsAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([meetingCategory])
    }

    // MARK: - Sync: events / bills / follow-ups

    func syncMeetingHeadsUps() async {
        await cancelAll(withPrefix: "event.headsup.")
        guard preferences.meetingHeadsUp else { return }
        guard CalendarService.shared.accessState == .authorized else { return }

        let snapshot = await CalendarService.shared.loadTodaysSnapshot()
        let now = Date()
        for event in snapshot.allEventsToday where !event.isAllDay {
            let triggerDate = event.startDate.addingTimeInterval(Self.meetingLeadTime)
            guard triggerDate > now else { continue }

            // Resolve venue from the underlying EKEvent
            let venue: String? = CalendarService.shared.event(withIdentifier: event.id)?.location

            let bodyParts: [String] = {
                var p = ["\(event.title) starts in 5 minutes."]
                if let venue = venue, !venue.isEmpty {
                    p.append("At \(venue).")
                }
                return p
            }()

            await scheduleAt(
                id: "event.headsup.\(event.id)",
                date: triggerDate,
                title: "Coming up · \(timeLabel(event.startDate))",
                body: bodyParts.joined(separator: " "),
                categoryIdentifier: (venue?.isEmpty == false) ? NotificationActionHandler.meetingCategoryID : nil,
                userInfo: (venue?.isEmpty == false) ? [NotificationActionHandler.venueUserInfoKey: venue!] : [:]
            )
        }
    }

    func syncBillReminders() async {
        await cancelAll(withPrefix: "bill.")
        guard preferences.billReminders else { return }

        let now = Date()
        for obligation in ObligationsService.shared.obligations where !obligation.isPaidThisCycle {
            let triggerDate = obligation.dueDate.addingTimeInterval(Self.billLeadTime)
            guard triggerDate > now else { continue }
            await scheduleAt(
                id: "bill.\(obligation.id.uuidString)",
                date: triggerDate,
                title: "Bill due tomorrow",
                body: "\(obligation.title) — $\(Int(obligation.amount))."
            )
        }
    }

    func syncFollowUpReminders() async {
        await cancelAll(withPrefix: "followup.")
        guard preferences.followUpReminders else { return }

        let now = Date()
        let allContacts = await ContactsService.shared.loadAllContacts()
        var contactsByID: [String: ContactSummary] = [:]
        for contact in allContacts { contactsByID[contact.id] = contact }

        for note in ContactNotesService.shared.notesByContactId.values where note.status == .active {
            guard let due = note.nextFollowUp, due > now else { continue }
            let name = contactsByID[note.contactId]?.displayName ?? "Contact"
            let reasonPart: String = {
                guard let reason = note.followUpReason, !reason.isEmpty else { return "." }
                return ": \(reason)."
            }()
            await scheduleAt(
                id: "followup.\(note.contactId)",
                date: due,
                title: "Follow-up: \(name)",
                body: "Time to reach out\(reasonPart)"
            )
        }
    }

    private func scheduleDaily(id: String, hour: Int, title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let comps = DateComponents(hour: hour, minute: 0)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func unschedule(_ ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func scheduleAt(
        id: String,
        date: Date,
        title: String,
        body: String,
        categoryIdentifier: String? = nil,
        userInfo: [AnyHashable: Any] = [:]
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func cancelAll(withPrefix prefix: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let toCancel = pending.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toCancel)
        }
    }

    private func savePreferences() {
        store.save(preferences, key: Self.storageKey)
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f.string(from: date).lowercased()
    }
}
