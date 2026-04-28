import Foundation

@MainActor
final class BalanceScoreService {
    static let shared = BalanceScoreService()

    private init() {}

    func computeScore(signals: BalanceSignals, now: Date = Date()) -> BalanceScore {
        computeBreakdown(signals: signals, now: now).score
    }

    func computeBreakdown(signals: BalanceSignals, now: Date = Date()) -> BalanceScoreBreakdown {
        let meetingRaw = max(0, 1.0 - signals.calendar.busyPercent)

        let staleCount = signals.relationships.relationships.filter {
            $0.daysSinceContact(now: now) > 14
        }.count
        let connectionRaw = max(0, 1.0 - Double(staleCount) / 10.0)

        let effectiveSleepHours = signals.health.sleepHours > 0
            ? signals.health.sleepHours
            : signals.wellness.sleepHours
        let hasSleep = effectiveSleepHours > 0
        let hasEnergy = signals.wellness.energyLevel > 0
        let sleepRaw: Double = hasSleep ? min(1.0, effectiveSleepHours / 8.0) : 0
        let energyRaw: Double = hasEnergy ? Double(signals.wellness.energyLevel) / 5.0 : 0

        let hour = Calendar.current.component(.hour, from: now)
        let isWorkday = (hour >= 9 && hour < 18)

        let meetingWeight = isWorkday ? 0.5 : 0.2
        let connectionWeight = isWorkday ? 0.2 : 0.4
        let sleepWeight: Double = hasSleep ? 0.15 : 0
        let energyWeight: Double = hasEnergy ? 0.15 : 0

        let totalWeight = meetingWeight + connectionWeight + sleepWeight + energyWeight
        let normalizedMeeting = totalWeight > 0 ? meetingWeight / totalWeight : 0
        let normalizedConnection = totalWeight > 0 ? connectionWeight / totalWeight : 0
        let normalizedSleep = totalWeight > 0 ? sleepWeight / totalWeight : 0
        let normalizedEnergy = totalWeight > 0 ? energyWeight / totalWeight : 0

        let weighted = meetingRaw * normalizedMeeting
            + connectionRaw * normalizedConnection
            + sleepRaw * normalizedSleep
            + energyRaw * normalizedEnergy

        let recoveryMinutes = signals.breathingMinutesToday + signals.health.mindfulMinutes
        let recoveryBonus = min(Double(recoveryMinutes) / 10.0, 1.0) * 0.05
        let composite = min(1.0, weighted + recoveryBonus)
        let scoreValue = Int(round(composite * 100))

        let tier: BalanceTier
        switch scoreValue {
        case ..<35: tier = .burningOut
        case 35..<65: tier = .steady
        default: tier = .inFlow
        }

        let score = BalanceScore(value: scoreValue, tier: tier, asOf: now)

        return BalanceScoreBreakdown(
            score: score,
            meeting: .init(raw: meetingRaw, weight: normalizedMeeting, contribution: meetingRaw * normalizedMeeting),
            connection: .init(raw: connectionRaw, weight: normalizedConnection, contribution: connectionRaw * normalizedConnection),
            sleep: hasSleep ? .init(raw: sleepRaw, weight: normalizedSleep, contribution: sleepRaw * normalizedSleep) : nil,
            energy: hasEnergy ? .init(raw: energyRaw, weight: normalizedEnergy, contribution: energyRaw * normalizedEnergy) : nil,
            recoveryBonus: recoveryBonus
        )
    }
}
