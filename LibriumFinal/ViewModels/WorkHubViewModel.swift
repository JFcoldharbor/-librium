import Combine
import Foundation
#if !os(macOS)
import UIKit
#endif

@MainActor
final class WorkHubViewModel: ObservableObject {
    @Published private(set) var calendarSnapshot: CalendarSnapshot = .empty
    @Published private(set) var calendarAccess: CalendarService.AccessState = .unknown
    @Published private(set) var isLoadingCalendar: Bool = false

    @Published private(set) var relationshipSnapshot: RelationshipSnapshot = .empty
    @Published private(set) var contactsAccess: ContactsService.AccessState = .unknown
    @Published private(set) var isLoadingNetworking: Bool = false

    @Published private(set) var focusActive: Bool = false
    @Published private(set) var focusSecondsRemaining: Int = 25 * 60
    @Published private(set) var todayFocusSessions: Int = 0
    @Published private(set) var todayFocusMinutes: Int = 0
    @Published private(set) var weekFocusSessions: Int = 0

    private let focusDurationSeconds = 25 * 60
    private var focusTask: Task<Void, Never>?
    private var focusStartedAt: Date?

    private let calendarService: CalendarService
    private let contactsService: ContactsService
    private let relationshipService: RelationshipService
    private let focusHistoryService: FocusHistoryService
    private var cancellables = Set<AnyCancellable>()

    init(
        calendarService: CalendarService = .shared,
        contactsService: ContactsService = .shared,
        relationshipService: RelationshipService = .shared,
        focusHistoryService: FocusHistoryService = .shared
    ) {
        self.calendarService = calendarService
        self.contactsService = contactsService
        self.relationshipService = relationshipService
        self.focusHistoryService = focusHistoryService

        calendarAccess = calendarService.accessState
        contactsAccess = contactsService.accessState

        calendarService.$accessState
            .receive(on: DispatchQueue.main)
            .assign(to: \.calendarAccess, on: self)
            .store(in: &cancellables)

        contactsService.$accessState
            .receive(on: DispatchQueue.main)
            .assign(to: \.contactsAccess, on: self)
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .calendarDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshIfActive()
                }
            }
            .store(in: &cancellables)

        loadFocusStats()
    }

    func refreshIfActive() async {
        await refreshCalendar()
        await refreshNetworking()
        loadFocusStats()
    }

    private func refreshCalendar() async {
        switch calendarService.accessState {
        case .unknown:
            await calendarService.requestAccess()
            if calendarService.accessState == .authorized {
                await loadCalendarSnapshot()
            }
        case .authorized:
            await loadCalendarSnapshot()
        case .denied:
            break
        }
    }

    private func refreshNetworking() async {
        if contactsService.accessState == .unknown {
            await contactsService.requestAccess()
        }
        guard calendarService.accessState == .authorized,
              contactsService.accessState == .authorized else { return }
        contactsService.invalidateIndex()
        await loadRelationshipSnapshot()
    }

    private func loadCalendarSnapshot() async {
        isLoadingCalendar = true
        calendarSnapshot = await calendarService.loadTodaysSnapshot()
        isLoadingCalendar = false
    }

    private func loadRelationshipSnapshot() async {
        isLoadingNetworking = true
        relationshipSnapshot = await relationshipService.loadSnapshot()
        isLoadingNetworking = false
    }

    private func loadFocusStats() {
        todayFocusSessions = focusHistoryService.completedSessionsToday()
        todayFocusMinutes = focusHistoryService.minutesToday()
        weekFocusSessions = focusHistoryService.sessionsThisWeek().count
    }

    func toggleFocus() {
        if focusActive {
            stopFocus(completed: false)
        } else {
            startFocus()
        }
    }

    var focusFormattedRemaining: String {
        let m = focusSecondsRemaining / 60
        let s = focusSecondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var focusProgress: Double {
        let total = Double(focusDurationSeconds)
        guard total > 0 else { return 0 }
        return 1.0 - Double(focusSecondsRemaining) / total
    }

    private func startFocus() {
        focusActive = true
        focusSecondsRemaining = focusDurationSeconds
        focusStartedAt = Date()
        focusTask = Task { [weak self] in
            await self?.focusLoop()
        }
    }

    private func stopFocus(completed: Bool) {
        focusActive = false
        focusTask?.cancel()
        focusTask = nil

        if let startedAt = focusStartedAt {
            let elapsed = focusDurationSeconds - focusSecondsRemaining
            if elapsed >= 60 {
                let session = FocusSession(
                    id: UUID(),
                    startedAt: startedAt,
                    durationSeconds: elapsed,
                    completed: completed
                )
                focusHistoryService.record(session)
                loadFocusStats()
            }
        }

        focusStartedAt = nil
        focusSecondsRemaining = focusDurationSeconds
    }

    private func focusLoop() async {
        while focusSecondsRemaining > 0 && !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            if Task.isCancelled { return }
            focusSecondsRemaining -= 1
        }
        if !Task.isCancelled {
            stopFocus(completed: true)
            #if !os(macOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }
    }
}
