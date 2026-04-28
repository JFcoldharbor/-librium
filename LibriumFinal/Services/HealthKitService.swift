import Foundation
#if !os(macOS)
import HealthKit
#endif

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    enum AccessState {
        case unknown, denied, authorized
    }

    @Published private(set) var accessState: AccessState = .unknown

    #if !os(macOS)
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        // Activity
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let active = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(active) }
        if let basal = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) { types.insert(basal) }
        if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exercise) }
        if let stand = HKObjectType.quantityType(forIdentifier: .appleStandTime) { types.insert(stand) }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(distance) }
        if let flights = HKObjectType.quantityType(forIdentifier: .flightsClimbed) { types.insert(flights) }
        // Sleep + Mindfulness
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(mindful) }
        // Nutrition
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        // Heart
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let resting = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(resting) }
        if let walking = HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage) { types.insert(walking) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        // Body
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(weight) }
        if let height = HKObjectType.quantityType(forIdentifier: .height) { types.insert(height) }
        if let bmi = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) { types.insert(bmi) }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(bodyFat) }
        // Vitals
        if let oxygen = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(oxygen) }
        if let respiratory = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { types.insert(respiratory) }
        if let systolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic) { types.insert(systolic) }
        if let diastolic = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) { types.insert(diastolic) }
        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        if let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) { types.insert(water) }
        return types
    }

    private init() {}

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            accessState = .denied
            return
        }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            accessState = .authorized
        } catch {
            accessState = .denied
        }
    }

    func loadSnapshot(now: Date = Date()) async -> HealthSnapshot {
        guard accessState == .authorized else { return .empty }

        async let activity = readActivitySnapshot(now: now)
        async let sleep = readSleepSnapshot(now: now)
        async let heart = readHeartSnapshot(now: now)
        async let mindfulness = readMindfulnessSnapshot(now: now)
        async let body = readBodySnapshot(now: now)
        async let vitals = readVitalsSnapshot(now: now)
        async let water = readWaterOuncesToday(now: now)

        return HealthSnapshot(
            activity: await activity,
            sleep: await sleep,
            heart: await heart,
            mindfulness: await mindfulness,
            body: await body,
            vitals: await vitals,
            waterOunces: await water
        )
    }

    @discardableResult
    func logWater(ounces: Double, now: Date = Date()) async -> Bool {
        guard accessState == .authorized,
              let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return false }
        let quantity = HKQuantity(unit: .fluidOunceUS(), doubleValue: ounces)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: now, end: now)
        do {
            try await store.save(sample)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Activity

    private func readActivitySnapshot(now: Date) async -> ActivitySnapshot {
        async let steps = sumQuantityToday(.stepCount, unit: .count(), now: now)
        async let active = sumQuantityToday(.activeEnergyBurned, unit: .kilocalorie(), now: now)
        async let basal = sumQuantityToday(.basalEnergyBurned, unit: .kilocalorie(), now: now)
        async let exercise = sumQuantityToday(.appleExerciseTime, unit: .minute(), now: now)
        async let stand = sumQuantityToday(.appleStandTime, unit: .minute(), now: now)
        async let distance = sumQuantityToday(.distanceWalkingRunning, unit: .meter(), now: now)
        async let flights = sumQuantityToday(.flightsClimbed, unit: .count(), now: now)

        let standMinutes = await stand
        return ActivitySnapshot(
            steps: Int(await steps),
            activeKcal: Int(await active),
            basalKcal: Int(await basal),
            exerciseMinutes: Int(await exercise),
            standHours: Int((standMinutes / 60).rounded()),
            distanceMeters: await distance,
            flightsClimbed: Int(await flights)
        )
    }

    // MARK: - Sleep

    private func readSleepSnapshot(now: Date) async -> SleepSnapshot {
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: now),
              let start = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
              let end = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now),
              let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return .empty
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let categorySamples = (samples ?? []).compactMap { $0 as? HKCategorySample }
                var rem = 0.0, deep = 0.0, core = 0.0, awake = 0.0, inBed = 0.0
                for sample in categorySamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    switch value {
                    case .asleepREM: rem += duration
                    case .asleepDeep: deep += duration
                    case .asleepCore, .asleepUnspecified, .asleep: core += duration
                    case .awake: awake += duration
                    case .inBed: inBed += duration
                    default: break
                    }
                }
                let total = rem + deep + core
                continuation.resume(returning: SleepSnapshot(
                    totalHours: total / 3600,
                    remHours: rem / 3600,
                    deepHours: deep / 3600,
                    coreHours: core / 3600,
                    awakeHours: awake / 3600,
                    inBedHours: inBed / 3600
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - Heart

    private func readHeartSnapshot(now: Date) async -> HeartSnapshot {
        async let avgHr = averageQuantityToday(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), now: now)
        async let restingHr = averageQuantityRecent(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 7, now: now)
        async let walkingHr = averageQuantityRecent(.walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()), days: 7, now: now)
        async let hrv = averageQuantityRecent(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), days: 7, now: now)

        return HeartSnapshot(
            restingBpm: Int(await restingHr),
            averageBpm: Int(await avgHr),
            walkingAverageBpm: Int(await walkingHr),
            hrvMs: await hrv
        )
    }

    // MARK: - Mindfulness

    private func readMindfulnessSnapshot(now: Date) async -> MindfulnessSnapshot {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return .empty }
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let totalSeconds = (samples ?? []).reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: MindfulnessSnapshot(
                    minutes: Int(totalSeconds / 60),
                    sessionCount: samples?.count ?? 0
                ))
            }
            store.execute(query)
        }
    }

    // MARK: - Body

    private func readBodySnapshot(now: Date) async -> BodySnapshot {
        async let weight = mostRecentQuantity(.bodyMass, unit: HKUnit.pound(), days: 90, now: now)
        async let height = mostRecentQuantity(.height, unit: HKUnit.inch(), days: 365, now: now)
        async let bmi = mostRecentQuantity(.bodyMassIndex, unit: HKUnit.count(), days: 90, now: now)
        async let bodyFat = mostRecentQuantity(.bodyFatPercentage, unit: HKUnit.percent(), days: 90, now: now)

        return BodySnapshot(
            weightLbs: await weight,
            heightInches: await height,
            bmi: await bmi,
            bodyFatPercent: (await bodyFat) * 100
        )
    }

    // MARK: - Vitals

    private func readVitalsSnapshot(now: Date) async -> VitalsSnapshot {
        async let oxygen = mostRecentQuantity(.oxygenSaturation, unit: HKUnit.percent(), days: 7, now: now)
        async let respiratory = mostRecentQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 7, now: now)
        async let systolic = mostRecentQuantity(.bloodPressureSystolic, unit: HKUnit.millimeterOfMercury(), days: 30, now: now)
        async let diastolic = mostRecentQuantity(.bloodPressureDiastolic, unit: HKUnit.millimeterOfMercury(), days: 30, now: now)

        return VitalsSnapshot(
            oxygenSaturationPercent: (await oxygen) * 100,
            respiratoryRatePerMin: await respiratory,
            systolicBp: Int(await systolic),
            diastolicBp: Int(await diastolic)
        )
    }

    // MARK: - Water (kept on snapshot root for backwards-compat)

    private func readWaterOuncesToday(now: Date) async -> Double {
        await sumQuantityToday(.dietaryWater, unit: .fluidOunceUS(), now: now)
    }

    // MARK: - Helpers

    private func sumQuantityToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit, now: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }

    private func averageQuantityToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit, now: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func averageQuantityRecent(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, now: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: now) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, _ in
                let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func mostRecentQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, now: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: now) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                if let sample = (samples?.first as? HKQuantitySample) {
                    continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            store.execute(query)
        }
    }
    #else
    private init() {}
    func requestAccess() async {}
    func loadSnapshot(now: Date = Date()) async -> HealthSnapshot { .empty }
    func logWater(ounces: Double, now: Date = Date()) async -> Bool { false }
    #endif
}
