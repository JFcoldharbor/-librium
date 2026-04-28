import Charts
import SwiftUI

struct LifeTrendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var snapshotService = DailySnapshotService.shared
    @ObservedObject private var eventsService = LifeEventsService.shared

    @State private var window: Window = .thirty
    @State private var selectedDimension: Dimension = .mood

    enum Window: Int, CaseIterable, Identifiable {
        case seven = 7, thirty = 30, ninety = 90, year = 365
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .seven: return "7d"
            case .thirty: return "30d"
            case .ninety: return "90d"
            case .year: return "1y"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        windowPicker

                        if snapshotsInWindow.isEmpty {
                            emptyState
                        } else if window == .year {
                            yearOverview
                            patternsSection
                        } else {
                            patternsSection
                            compositeChart
                            dimensionPicker
                            dimensionChart
                            eventTimeline
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Life Trends")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.accent.opacity(0.18),
                    EquilibriumColor.accent.opacity(0.04),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Window picker

    private var windowPicker: some View {
        HStack(spacing: 8) {
            ForEach(Window.allCases) { w in
                Button {
                    window = w
                } label: {
                    Text(w.label)
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(window == w
                                ? EquilibriumColor.accent.opacity(0.30)
                                : EquilibriumColor.primaryText.opacity(0.06))
                        )
                        .foregroundColor(window == w ? EquilibriumColor.accent : EquilibriumColor.secondaryText)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Patterns

    private var patternsSection: some View {
        let insights = PatternDetector.detect(
            snapshots: snapshotsInWindow,
            events: eventsInWindow,
            now: Date(),
            maxResults: 4
        )
        return Group {
            if insights.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PATTERNS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.5)
                        .foregroundColor(EquilibriumColor.tertiaryText)
                    VStack(spacing: 6) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(EquilibriumColor.accent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(EquilibriumColor.accent.opacity(0.20), lineWidth: 0.5)
                        )
                )
            }
        }
    }

    private func insightRow(_ insight: LifeInsight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insightIcon(insight.kind))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EquilibriumColor.accent)
                .frame(width: 18)
            Text(insight.summary)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private func insightIcon(_ kind: LifeInsight.Kind) -> String {
        switch kind {
        case .correlation: return "link"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .streak: return "flame.fill"
        case .eventCluster: return "circle.grid.2x2.fill"
        case .dayPattern: return "calendar"
        }
    }

    // MARK: - Composite chart

    private var compositeChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LIFE COMPOSITE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                if let avg = averageLife {
                    Text("avg \(Int(avg))")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }

            Chart {
                ForEach(snapshotsInWindow) { snap in
                    LineMark(
                        x: .value("Day", snap.date),
                        y: .value("Life", snap.lifeComposite)
                    )
                    .foregroundStyle(EquilibriumColor.accent)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Day", snap.date),
                        y: .value("Life", snap.lifeComposite)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [EquilibriumColor.accent.opacity(0.30), EquilibriumColor.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }

                RuleMark(y: .value("baseline", 50))
                    .foregroundStyle(EquilibriumColor.primaryText.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisValueLabel()
                        .foregroundStyle(EquilibriumColor.tertiaryText)
                    AxisGridLine()
                        .foregroundStyle(EquilibriumColor.primaryText.opacity(0.06))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xStrideUnit, count: xStrideCount)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(EquilibriumColor.tertiaryText)
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    // MARK: - Dimension picker + chart

    private var dimensionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Dimension.allCases, id: \.self) { dim in
                    Button {
                        selectedDimension = dim
                    } label: {
                        Text(dim.label)
                            .font(.system(size: 11, weight: .heavy))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selectedDimension == dim
                                    ? dimensionTint(dim).opacity(0.30)
                                    : EquilibriumColor.primaryText.opacity(0.06))
                            )
                            .foregroundColor(selectedDimension == dim ? dimensionTint(dim) : EquilibriumColor.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dimensionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(selectedDimension.label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(dimensionTint(selectedDimension))
                Spacer()
                if let avg = averageForSelectedDim {
                    Text("avg \(Int(avg))")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }

            Chart {
                ForEach(snapshotsInWindow) { snap in
                    LineMark(
                        x: .value("Day", snap.date),
                        y: .value(selectedDimension.label, snap.value(for: selectedDimension))
                    )
                    .foregroundStyle(dimensionTint(selectedDimension))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                RuleMark(y: .value("baseline", 50))
                    .foregroundStyle(EquilibriumColor.primaryText.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { _ in
                    AxisValueLabel().foregroundStyle(EquilibriumColor.tertiaryText)
                    AxisGridLine().foregroundStyle(EquilibriumColor.primaryText.opacity(0.06))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xStrideUnit, count: xStrideCount)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(EquilibriumColor.tertiaryText)
                }
            }
            .frame(height: 140)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    // MARK: - Event timeline

    private var eventTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EVENT TIMELINE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                Text("\(eventsInWindow.count) events")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }

            if eventsInWindow.isEmpty {
                Text("No events in this window.")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(eventsInWindow) { event in
                        PointMark(
                            x: .value("When", event.occurredAt),
                            y: .value("Polarity", signedIntensity(event))
                        )
                        .foregroundStyle(eventTint(event))
                        .symbolSize(by: .value("Intensity", event.intensity * 18))
                    }
                    RuleMark(y: .value("zero", 0))
                        .foregroundStyle(EquilibriumColor.primaryText.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                }
                .chartYScale(domain: -5...5)
                .chartYAxis {
                    AxisMarks(values: [-5, 0, 5]) { _ in
                        AxisValueLabel().foregroundStyle(EquilibriumColor.tertiaryText)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xStrideUnit, count: xStrideCount)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(EquilibriumColor.tertiaryText)
                    }
                }
                .frame(height: 120)

                Text("Above zero = positive · below = negative · size = intensity")
                    .font(.system(size: 10))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    // MARK: - Empty state

    private var yearOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YEAR AT A GLANCE")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundColor(EquilibriumColor.secondaryText)

            let cells = monthCells
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cells, id: \.id) { cell in
                    monthTile(cell)
                }
            }

            yearLegend
        }
    }

    private struct MonthCell: Identifiable {
        let id: String          // yyyy-MM
        let label: String       // "Mar"
        let monthStart: Date
        let avgScore: Int?      // average lifeComposite across days that have data
        let dayScores: [Int]    // daily scores for the month, padded with 0 for empty days
    }

    private var monthCells: [MonthCell] {
        let cal = Calendar.current
        let now = Date()
        let snapshots = snapshotService.snapshots
        var map: [String: [DimensionSnapshot]] = [:]
        let keyFmt = DateFormatter(); keyFmt.dateFormat = "yyyy-MM"
        for s in snapshots {
            map[keyFmt.string(from: s.date), default: []].append(s)
        }

        var result: [MonthCell] = []
        guard let yearStart = cal.date(byAdding: .month, value: -11, to: cal.startOfDay(for: now)) else { return [] }
        let normalizedStart = cal.date(from: cal.dateComponents([.year, .month], from: yearStart)) ?? yearStart

        let labelFmt = DateFormatter(); labelFmt.dateFormat = "MMM"
        for offset in 0..<12 {
            guard let monthStart = cal.date(byAdding: .month, value: offset, to: normalizedStart),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let key = keyFmt.string(from: monthStart)
            let monthSnaps = (map[key] ?? []).filter { $0.date < monthEnd }
            let avg = monthSnaps.isEmpty ? nil : Int((monthSnaps.map { $0.lifeComposite }.reduce(0, +) / Double(monthSnaps.count)).rounded())
            let dayScores = monthSnaps.sorted { $0.date < $1.date }.map { Int($0.lifeComposite.rounded()) }
            result.append(MonthCell(
                id: key,
                label: labelFmt.string(from: monthStart),
                monthStart: monthStart,
                avgScore: avg,
                dayScores: dayScores
            ))
        }
        return result
    }

    private func monthTile(_ cell: MonthCell) -> some View {
        let tint = cell.avgScore.map(scoreTint) ?? Color.gray.opacity(0.3)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(cell.label.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(0.8)
                    .foregroundColor(EquilibriumColor.primaryText)
                Spacer()
                if let avg = cell.avgScore {
                    Text("\(avg)")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(tint)
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }
            HStack(spacing: 1) {
                ForEach(0..<cell.dayScores.count, id: \.self) { idx in
                    let v = cell.dayScores[idx]
                    Rectangle()
                        .fill(scoreTint(v))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                }
                if cell.dayScores.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tint.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private var yearLegend: some View {
        HStack(spacing: 12) {
            legendDot(label: "≥70", color: scoreTint(80))
            legendDot(label: "45–69", color: scoreTint(55))
            legendDot(label: "<45", color: scoreTint(30))
            legendDot(label: "no data", color: Color.gray.opacity(0.3))
            Spacer()
        }
    }

    private func legendDot(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    private func scoreTint(_ score: Int) -> Color {
        if score >= 70 { return Color.green.opacity(0.7) }
        if score >= 45 { return Color.yellow.opacity(0.7) }
        if score > 0 { return Color.red.opacity(0.7) }
        return Color.gray.opacity(0.25)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 80)
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundColor(EquilibriumColor.accent.opacity(0.6))
            Text("No daily snapshots yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Charts populate after each day rolls over. Today's score is live on the Balance view.")
                .font(.system(size: 12))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var snapshotsInWindow: [DimensionSnapshot] {
        snapshotService.snapshots(in: window.rawValue)
    }

    private var eventsInWindow: [LifeEvent] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -window.rawValue, to: Date()) else { return [] }
        return eventsService.events(since: start, until: Date())
    }

    private var averageLife: Double? {
        guard !snapshotsInWindow.isEmpty else { return nil }
        let sum = snapshotsInWindow.reduce(0.0) { $0 + $1.lifeComposite }
        return sum / Double(snapshotsInWindow.count)
    }

    private var averageForSelectedDim: Double? {
        guard !snapshotsInWindow.isEmpty else { return nil }
        let sum = snapshotsInWindow.reduce(0.0) { $0 + $1.value(for: selectedDimension) }
        return sum / Double(snapshotsInWindow.count)
    }

    private var xStrideUnit: Calendar.Component {
        switch window {
        case .seven: return .day
        case .thirty: return .day
        case .ninety: return .weekOfYear
        case .year: return .month
        }
    }

    private var xStrideCount: Int {
        switch window {
        case .seven: return 1
        case .thirty: return 5
        case .ninety: return 2
        case .year: return 1
        }
    }

    private func signedIntensity(_ event: LifeEvent) -> Double {
        Double(event.intensity) * event.polarity.sign
    }

    private func eventTint(_ event: LifeEvent) -> Color {
        switch event.polarity {
        case .positive: return .green
        case .negative: return .red.opacity(0.85)
        case .neutral: return EquilibriumColor.tertiaryText
        case .signal: return EquilibriumColor.CardTint.calendar
        }
    }

    private func dimensionTint(_ dimension: Dimension) -> Color {
        switch dimension {
        case .body: return EquilibriumColor.CardTint.health
        case .mood: return EquilibriumColor.CardTint.spiritual
        case .relationships: return EquilibriumColor.CardTint.network
        case .recreation: return EquilibriumColor.CardTint.calendar
        case .achievement: return EquilibriumColor.CardTint.motivation
        case .stress: return Color.red.opacity(0.85)
        case .rest: return EquilibriumColor.CardTint.journalDream
        }
    }
}
