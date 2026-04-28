import Foundation

struct HealthSnapshot: Equatable {
    let activity: ActivitySnapshot
    let sleep: SleepSnapshot
    let heart: HeartSnapshot
    let mindfulness: MindfulnessSnapshot
    let body: BodySnapshot
    let vitals: VitalsSnapshot
    let waterOunces: Double

    // Backwards-compatible flat accessors (used by older call sites + Maria context).
    var sleepHours: Double { sleep.totalHours }
    var stepCount: Int { activity.steps }
    var activeKcal: Int { activity.activeKcal }
    var mindfulMinutes: Int { mindfulness.minutes }
    var restingHeartRate: Int { heart.restingBpm }
    var averageHeartRate: Int { heart.averageBpm }

    static let empty = HealthSnapshot(
        activity: .empty,
        sleep: .empty,
        heart: .empty,
        mindfulness: .empty,
        body: .empty,
        vitals: .empty,
        waterOunces: 0
    )
}

struct ActivitySnapshot: Equatable {
    let steps: Int
    let activeKcal: Int
    let basalKcal: Int
    let exerciseMinutes: Int
    let standHours: Int
    let distanceMeters: Double
    let flightsClimbed: Int

    static let empty = ActivitySnapshot(
        steps: 0,
        activeKcal: 0,
        basalKcal: 0,
        exerciseMinutes: 0,
        standHours: 0,
        distanceMeters: 0,
        flightsClimbed: 0
    )
}

struct SleepSnapshot: Equatable {
    let totalHours: Double
    let remHours: Double
    let deepHours: Double
    let coreHours: Double
    let awakeHours: Double
    let inBedHours: Double

    static let empty = SleepSnapshot(
        totalHours: 0,
        remHours: 0,
        deepHours: 0,
        coreHours: 0,
        awakeHours: 0,
        inBedHours: 0
    )
}

struct HeartSnapshot: Equatable {
    let restingBpm: Int
    let averageBpm: Int
    let walkingAverageBpm: Int
    let hrvMs: Double // SDNN, milliseconds

    static let empty = HeartSnapshot(restingBpm: 0, averageBpm: 0, walkingAverageBpm: 0, hrvMs: 0)
}

struct MindfulnessSnapshot: Equatable {
    let minutes: Int
    let sessionCount: Int

    static let empty = MindfulnessSnapshot(minutes: 0, sessionCount: 0)
}

struct BodySnapshot: Equatable {
    let weightLbs: Double
    let heightInches: Double
    let bmi: Double
    let bodyFatPercent: Double

    static let empty = BodySnapshot(weightLbs: 0, heightInches: 0, bmi: 0, bodyFatPercent: 0)
}

struct VitalsSnapshot: Equatable {
    let oxygenSaturationPercent: Double
    let respiratoryRatePerMin: Double
    let systolicBp: Int
    let diastolicBp: Int

    static let empty = VitalsSnapshot(
        oxygenSaturationPercent: 0,
        respiratoryRatePerMin: 0,
        systolicBp: 0,
        diastolicBp: 0
    )
}
