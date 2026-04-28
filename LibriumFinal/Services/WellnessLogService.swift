import Foundation

@MainActor
final class WellnessLogService {
    static let shared = WellnessLogService()

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.wellness.logs"

    init(store: JSONStore = .shared) {
        self.store = store
    }

    func loadAll() -> [WellnessLog] {
        store.load([WellnessLog].self, key: Self.storageKey) ?? []
    }

    func today() -> WellnessLog {
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        return loadAll().first { cal.isDate($0.date, inSameDayAs: day) } ?? .makeForToday()
    }

    func upsert(_ log: WellnessLog) {
        var logs = loadAll()
        let cal = Calendar.current
        if let idx = logs.firstIndex(where: { cal.isDate($0.date, inSameDayAs: log.date) }) {
            logs[idx] = log
        } else {
            logs.append(log)
        }
        logs.sort { $0.date > $1.date }
        store.save(logs, key: Self.storageKey)
    }

    func incrementWater() {
        var entry = today()
        entry.waterGlasses += 1
        upsert(entry)
        Task {
            await HealthKitService.shared.logWater(ounces: 16)
        }
    }

    func setEnergyToday(_ level: Int) {
        var entry = today()
        entry.energyLevel = max(0, min(5, level))
        upsert(entry)
    }

    func sevenDayAverage() -> (sleep: Double, energy: Double, water: Double)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: today) else { return nil }
        let recent = loadAll().filter { $0.date >= weekAgo && $0.date <= today }
        let nonZero = recent.filter { $0.sleepHours > 0 || $0.energyLevel > 0 || $0.waterGlasses > 0 }
        guard !nonZero.isEmpty else { return nil }
        let sleep = nonZero.map(\.sleepHours).reduce(0, +) / Double(nonZero.count)
        let energy = Double(nonZero.map(\.energyLevel).reduce(0, +)) / Double(nonZero.count)
        let water = Double(nonZero.map(\.waterGlasses).reduce(0, +)) / Double(nonZero.count)
        return (sleep, energy, water)
    }
}
