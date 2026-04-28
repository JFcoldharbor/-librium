import Combine
import Foundation

@MainActor
final class LifeHubViewModel: ObservableObject {
    // Journal
    @Published var todayEntry: JournalEntry = .makeForToday()
    @Published private(set) var yesterdayEntry: JournalEntry?
    @Published private(set) var journalStreak: Int = 0

    // Breathing
    @Published var selectedPattern: BreathingPattern = .fourSevenEight
    @Published private(set) var breathingActive: Bool = false
    @Published private(set) var breathingPhase: BreathingPhaseKind = .inhale
    @Published private(set) var breathingSecondsRemaining: Int = 4
    @Published private(set) var breathingCycleCount: Int = 0
    @Published private(set) var todayCycles: Int = 0
    @Published private(set) var todayMinutes: Int = 0

    // Wellness (self-reported)
    @Published var todayWellness: WellnessLog = .makeForToday()
    @Published private(set) var weeklyAverage: WeeklyAverage?

    // Health (Apple Health)
    @Published private(set) var healthSnapshot: HealthSnapshot = .empty
    @Published private(set) var healthAccess: HealthKitService.AccessState = .unknown

    struct WeeklyAverage: Equatable {
        let sleep: Double
        let energy: Double
        let water: Double
    }

    private var breathingTask: Task<Void, Never>?

    private let journalService: JournalService
    private let breathingService: BreathingHistoryService
    private let wellnessService: WellnessLogService
    private let healthKitService: HealthKitService
    private var cancellables = Set<AnyCancellable>()

    init(
        journalService: JournalService = .shared,
        breathingService: BreathingHistoryService = .shared,
        wellnessService: WellnessLogService = .shared,
        healthKitService: HealthKitService = .shared
    ) {
        self.journalService = journalService
        self.breathingService = breathingService
        self.wellnessService = wellnessService
        self.healthKitService = healthKitService
        healthAccess = healthKitService.accessState

        healthKitService.$accessState
            .receive(on: DispatchQueue.main)
            .assign(to: \.healthAccess, on: self)
            .store(in: &cancellables)

        loadAll()
    }

    func loadAll() {
        todayEntry = journalService.today()
        yesterdayEntry = journalService.yesterday()
        journalStreak = journalService.currentStreak()

        todayCycles = breathingService.cyclesToday()
        todayMinutes = breathingService.minutesToday()

        todayWellness = wellnessService.today()
        if let avg = wellnessService.sevenDayAverage() {
            weeklyAverage = WeeklyAverage(sleep: avg.sleep, energy: avg.energy, water: avg.water)
        } else {
            weeklyAverage = nil
        }

        Task { await refreshHealth() }
    }

    func refreshHealth() async {
        if healthKitService.accessState == .unknown {
            await healthKitService.requestAccess()
        }
        if healthKitService.accessState == .authorized {
            healthSnapshot = await healthKitService.loadSnapshot()
        }
    }

    // MARK: - Journal

    func saveJournal() {
        journalService.upsert(todayEntry)
        journalStreak = journalService.currentStreak()
    }

    func setMood(_ mood: Int) {
        todayEntry.mood = mood
        saveJournal()
    }

    // MARK: - Wellness

    func saveWellness() {
        wellnessService.upsert(todayWellness)
        if let avg = wellnessService.sevenDayAverage() {
            weeklyAverage = WeeklyAverage(sleep: avg.sleep, energy: avg.energy, water: avg.water)
        }
    }

    func incrementWater() {
        todayWellness.waterGlasses += 1
        saveWellness()
        Task { [weak self] in
            await self?.healthKitService.logWater(ounces: 16)
            await self?.refreshHealthSnapshot()
        }
    }

    private func refreshHealthSnapshot() async {
        guard healthKitService.accessState == .authorized else { return }
        healthSnapshot = await healthKitService.loadSnapshot()
    }

    func setEnergy(_ level: Int) {
        todayWellness.energyLevel = level
        saveWellness()
    }

    // MARK: - Breathing

    func toggleBreathing() {
        if breathingActive { stopBreathing() } else { startBreathing() }
    }

    private func startBreathing() {
        breathingActive = true
        breathingCycleCount = 0
        let firstPhase = selectedPattern.phases[0]
        breathingPhase = firstPhase.kind
        breathingSecondsRemaining = firstPhase.duration
        breathingTask = Task { [weak self] in
            await self?.breathingLoop()
        }
    }

    private func stopBreathing() {
        breathingActive = false
        breathingTask?.cancel()
        breathingTask = nil

        if breathingCycleCount > 0 {
            let session = BreathingSession(
                id: UUID(),
                date: Date(),
                pattern: selectedPattern,
                cyclesCompleted: breathingCycleCount
            )
            breathingService.record(session)
            todayCycles = breathingService.cyclesToday()
            todayMinutes = breathingService.minutesToday()
        }

        let firstPhase = selectedPattern.phases[0]
        breathingPhase = firstPhase.kind
        breathingSecondsRemaining = firstPhase.duration
    }

    private func breathingLoop() async {
        let phases = selectedPattern.phases
        while !Task.isCancelled {
            for step in phases {
                if Task.isCancelled { return }
                breathingPhase = step.kind
                for second in stride(from: step.duration, through: 1, by: -1) {
                    if Task.isCancelled { return }
                    breathingSecondsRemaining = second
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        return
                    }
                }
            }
            if !Task.isCancelled {
                breathingCycleCount += 1
            }
        }
    }
}
