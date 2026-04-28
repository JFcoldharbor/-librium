import Foundation

/// Pure functions that turn events + body data into a DimensionSnapshot for a day.
///
/// Scoring model:
///   - Each dimension starts at a 50 baseline (neutral).
///   - Events contribute decayed point impacts: contributing weight = polarity_sign * intensity * categoryDimensionWeight * decayFactor.
///   - Body dimension folds in HealthKit signals (sleep ratio, steps ratio, water glasses, mindful).
///   - Mood dimension folds in self-reported mood from journal entry of the same day.
///   - All dimensions clamp to [0, 100].
enum LifeScoreCalculator {

    /// Compute a snapshot for the calendar day containing `date`.
    static func compute(
        for date: Date,
        events: [LifeEvent],
        sleepHours: Double,
        steps: Int,
        waterGlasses: Int,
        mindfulMinutes: Int,
        journalMood: Int,
        workComposite: Double
    ) -> DimensionSnapshot {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        // Only events occurring up to end-of-day for this snapshot
        let relevantEvents = events.filter { $0.occurredAt <= endOfDay }

        // Build dimension scores
        var scores: [Dimension: Double] = [:]
        for dim in Dimension.allCases {
            scores[dim] = 50.0
        }

        // Body baseline from physical signals (replaces the 50 baseline if any signals)
        scores[.body] = bodyBaseline(
            sleepHours: sleepHours,
            steps: steps,
            waterGlasses: waterGlasses,
            mindfulMinutes: mindfulMinutes
        )

        // Mood baseline modifier from journal
        if journalMood > 0 {
            // 1 → 30, 2 → 40, 3 → 50, 4 → 60, 5 → 70 (replaces baseline)
            scores[.mood] = 20.0 + Double(journalMood) * 10.0
        }

        // Apply event impacts (decayed by time-since)
        for event in relevantEvents {
            let daysSince = endOfDay.timeIntervalSince(event.occurredAt) / 86_400.0
            let halfLife = event.category.halfLifeDays
            // exp(-(t * ln2 / halfLife)) — true exponential half-life
            let decay = exp(-daysSince * 0.6931471805599453 / halfLife)
            for impact in event.category.dimensionImpacts {
                let basePoints = event.polarity.sign * Double(event.intensity) * impact.weight
                scores[impact.dimension, default: 50] += basePoints * decay * 4.0
            }
        }

        // Clamp
        for dim in Dimension.allCases {
            scores[dim] = clamp(scores[dim] ?? 50, min: 0, max: 100)
        }

        // Stress is inverted in the composite — high stress score (low stress dimension) hurts
        // We model it so "stress dimension" = 100 means low stress, 0 means high stress.
        // A negative event with category .stress reduces the dimension below 50, which is correct.

        let life = compositeLifeScore(from: scores)
        let work = clamp(workComposite, min: 0, max: 100)
        let overall = (life + work) / 2.0

        return DimensionSnapshot(
            id: DimensionSnapshot.dayKey(for: startOfDay),
            date: startOfDay,
            body: scores[.body] ?? 50,
            mood: scores[.mood] ?? 50,
            relationships: scores[.relationships] ?? 50,
            recreation: scores[.recreation] ?? 50,
            achievement: scores[.achievement] ?? 50,
            stress: scores[.stress] ?? 50,
            rest: scores[.rest] ?? 50,
            lifeComposite: life,
            workComposite: work,
            overallComposite: overall,
            createdAt: Date()
        )
    }

    // MARK: - Helpers

    private static func bodyBaseline(
        sleepHours: Double,
        steps: Int,
        waterGlasses: Int,
        mindfulMinutes: Int
    ) -> Double {
        // 4 sub-signals, each contributes 0-25 points to a 0-100 body score
        // No data → falls back to 50 baseline split evenly

        var components: [Double] = []
        if sleepHours > 0 {
            // Target 7.5h → 100. <5h → 0, 9h+ → 100, linear in between
            let sleepRatio = clamp((sleepHours - 5.0) / 4.0, min: 0, max: 1)
            components.append(sleepRatio * 100)
        }
        if steps > 0 {
            let stepsRatio = clamp(Double(steps) / 8000.0, min: 0, max: 1)
            components.append(stepsRatio * 100)
        }
        if waterGlasses > 0 {
            let waterRatio = clamp(Double(waterGlasses) / 8.0, min: 0, max: 1)
            components.append(waterRatio * 100)
        }
        if mindfulMinutes > 0 {
            let mindfulRatio = clamp(Double(mindfulMinutes) / 10.0, min: 0, max: 1)
            components.append(mindfulRatio * 100)
        }

        if components.isEmpty { return 50 }
        let sum = components.reduce(0, +)
        return sum / Double(components.count)
    }

    private static func compositeLifeScore(from dims: [Dimension: Double]) -> Double {
        var total = 0.0
        for dim in Dimension.allCases {
            total += (dims[dim] ?? 50) * dim.lifeWeight
        }
        return clamp(total, min: 0, max: 100)
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(upper, value))
    }
}
