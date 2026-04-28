import Foundation

/// Pure functions that derive `LifeInsight`s from snapshots + events.
/// No persistence — call on demand.
enum PatternDetector {

    /// Top insights ordered by priority. Returns empty array when there's not enough data.
    static func detect(
        snapshots: [DimensionSnapshot],
        events: [LifeEvent],
        now: Date = Date(),
        maxResults: Int = 3
    ) -> [LifeInsight] {
        guard snapshots.count >= 7 else { return [] }

        var insights: [LifeInsight] = []
        insights.append(contentsOf: correlations(snapshots: snapshots))
        insights.append(contentsOf: trends(snapshots: snapshots))
        insights.append(contentsOf: streaks(snapshots: snapshots))
        insights.append(contentsOf: eventClusters(events: events, now: now))
        insights.append(contentsOf: dayPatterns(snapshots: snapshots))

        return insights
            .sorted { $0.priority > $1.priority }
            .prefix(maxResults)
            .map { $0 }
    }

    // MARK: - Correlations

    private static let correlationPairs: [(Dimension, Dimension)] = [
        (.body, .mood),
        (.body, .stress),
        (.body, .rest),
        (.mood, .stress),
        (.mood, .relationships),
        (.mood, .recreation),
        (.stress, .achievement),
        (.stress, .relationships),
        (.recreation, .stress),
        (.rest, .mood),
        (.rest, .stress)
    ]

    private static func correlations(snapshots: [DimensionSnapshot]) -> [LifeInsight] {
        var out: [LifeInsight] = []
        for (a, b) in correlationPairs {
            let aSeries = snapshots.map { $0.value(for: a) }
            let bSeries = snapshots.map { $0.value(for: b) }

            // Lag 0, 1, 2 — does A predict B `lag` days later?
            var bestR: Double = 0
            var bestLag: Int = 0
            for lag in 0...2 {
                guard aSeries.count > lag + 4 else { continue }
                let aSlice = Array(aSeries.dropLast(lag))
                let bSlice = Array(bSeries.dropFirst(lag))
                let r = pearson(aSlice, bSlice)
                if abs(r) > abs(bestR) {
                    bestR = r
                    bestLag = lag
                }
            }

            // Only surface meaningful correlations
            guard abs(bestR) >= 0.5 else { continue }

            let direction = bestR > 0 ? "tracks with" : "moves against"
            let lagPart = bestLag == 0 ? "same day" : "\(bestLag)d lag"
            let summary = "\(a.label) \(direction) \(b.label.lowercased()) (\(lagPart), r=\(String(format: "%.2f", bestR)))"
            let priority = Int(abs(bestR) * 80) + (bestLag > 0 ? 10 : 0)

            out.append(LifeInsight(
                kind: .correlation,
                priority: priority,
                summary: summary,
                detail: nil
            ))
        }
        return out
    }

    // MARK: - Trends

    private static func trends(snapshots: [DimensionSnapshot]) -> [LifeInsight] {
        guard snapshots.count >= 7 else { return [] }
        let recent = Array(snapshots.suffix(7))
        var out: [LifeInsight] = []

        for dim in Dimension.allCases {
            let values = recent.map { $0.value(for: dim) }
            let slope = linearSlope(values)
            let absSlope = abs(slope)
            // slope is "points per day" — only surface meaningful drift
            guard absSlope >= 1.5 else { continue }

            let direction = slope > 0 ? "trending up" : "trending down"
            let totalDelta = slope * Double(values.count - 1)
            let summary = "\(dim.label) \(direction) (\(direction == "trending up" ? "+" : "")\(Int(totalDelta.rounded())) over 7d)"
            let priority = min(75, 40 + Int(absSlope * 6))
            out.append(LifeInsight(
                kind: .trend,
                priority: priority,
                summary: summary,
                detail: nil
            ))
        }
        return out
    }

    // MARK: - Streaks

    private static func streaks(snapshots: [DimensionSnapshot]) -> [LifeInsight] {
        guard let _ = snapshots.last else { return [] }
        var out: [LifeInsight] = []

        for dim in Dimension.allCases {
            // Walk backward from most recent
            var goodCount = 0
            var badCount = 0
            for snap in snapshots.reversed() {
                let v = snap.value(for: dim)
                if v >= 65 {
                    if badCount > 0 { break }
                    goodCount += 1
                } else if v <= 35 {
                    if goodCount > 0 { break }
                    badCount += 1
                } else {
                    break
                }
            }
            if goodCount >= 4 {
                out.append(LifeInsight(
                    kind: .streak,
                    priority: 55 + min(20, goodCount * 2),
                    summary: "\(goodCount)-day streak: \(dim.label.lowercased()) holding strong",
                    detail: nil
                ))
            } else if badCount >= 4 {
                out.append(LifeInsight(
                    kind: .streak,
                    priority: 70 + min(20, badCount * 2),
                    summary: "\(badCount)-day stretch: \(dim.label.lowercased()) low",
                    detail: nil
                ))
            }
        }
        return out
    }

    // MARK: - Event clusters

    private static func eventClusters(events: [LifeEvent], now: Date) -> [LifeInsight] {
        let cal = Calendar.current
        guard let weekStart = cal.date(byAdding: .day, value: -7, to: now) else { return [] }
        let recent = events.filter { $0.occurredAt >= weekStart }

        var byCategory: [LifeEvent.Category: [LifeEvent]] = [:]
        for event in recent {
            byCategory[event.category, default: []].append(event)
        }

        var out: [LifeInsight] = []
        for (category, list) in byCategory {
            let negativeCount = list.filter { $0.polarity == .negative }.count
            let positiveCount = list.filter { $0.polarity == .positive }.count

            if negativeCount >= 3 {
                out.append(LifeInsight(
                    kind: .eventCluster,
                    priority: 70 + min(20, negativeCount * 3),
                    summary: "\(negativeCount) negative \(category.rawValue) events this week",
                    detail: nil
                ))
            }
            if positiveCount >= 3 {
                out.append(LifeInsight(
                    kind: .eventCluster,
                    priority: 55 + min(15, positiveCount * 2),
                    summary: "\(positiveCount) positive \(category.rawValue) events this week",
                    detail: nil
                ))
            }
        }
        return out
    }

    // MARK: - Day patterns

    private static func dayPatterns(snapshots: [DimensionSnapshot]) -> [LifeInsight] {
        guard snapshots.count >= 14 else { return [] }
        let cal = Calendar.current
        var out: [LifeInsight] = []

        for dim in Dimension.allCases {
            // Group by weekday
            var byWeekday: [Int: [Double]] = [:]
            for snap in snapshots {
                let weekday = cal.component(.weekday, from: snap.date)
                byWeekday[weekday, default: []].append(snap.value(for: dim))
            }
            // Need at least 2 samples per weekday for meaningful average
            let averages = byWeekday.compactMapValues { values -> Double? in
                guard values.count >= 2 else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }
            guard averages.count >= 5 else { continue }

            let overallAvg = averages.values.reduce(0, +) / Double(averages.count)
            let lowest = averages.min { $0.value < $1.value }
            let highest = averages.max { $0.value < $1.value }

            // Surface only if a single weekday is meaningfully off the overall average
            if let (lowDay, lowVal) = lowest, overallAvg - lowVal >= 12 {
                let dayName = weekdayName(lowDay)
                out.append(LifeInsight(
                    kind: .dayPattern,
                    priority: 50 + Int((overallAvg - lowVal) * 1.5),
                    summary: "\(dayName)s: \(dim.label.lowercased()) consistently low (\(Int(lowVal)) vs \(Int(overallAvg)) overall)",
                    detail: nil
                ))
            } else if let (highDay, highVal) = highest, highVal - overallAvg >= 12 {
                let dayName = weekdayName(highDay)
                out.append(LifeInsight(
                    kind: .dayPattern,
                    priority: 45 + Int((highVal - overallAvg) * 1.2),
                    summary: "\(dayName)s: \(dim.label.lowercased()) consistently high (\(Int(highVal)) vs \(Int(overallAvg)) overall)",
                    detail: nil
                ))
            }
        }
        return out
    }

    // MARK: - Math

    private static func pearson(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, a.count > 2 else { return 0 }
        let n = Double(a.count)
        let meanA = a.reduce(0, +) / n
        let meanB = b.reduce(0, +) / n
        var num = 0.0, denomA = 0.0, denomB = 0.0
        for i in 0..<a.count {
            let da = a[i] - meanA
            let db = b[i] - meanB
            num += da * db
            denomA += da * da
            denomB += db * db
        }
        let denom = (denomA * denomB).squareRoot()
        return denom > 0 ? num / denom : 0
    }

    private static func linearSlope(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let n = Double(values.count)
        let xs = (0..<values.count).map { Double($0) }
        let meanX = xs.reduce(0, +) / n
        let meanY = values.reduce(0, +) / n
        var num = 0.0, denom = 0.0
        for i in 0..<values.count {
            let dx = xs[i] - meanX
            let dy = values[i] - meanY
            num += dx * dy
            denom += dx * dx
        }
        return denom > 0 ? num / denom : 0
    }

    private static func weekdayName(_ weekday: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let idx = max(0, min(6, weekday - 1))
        return names[idx]
    }
}
