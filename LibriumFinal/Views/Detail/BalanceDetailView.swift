import SwiftUI

struct BalanceDetailView: View {
    let breakdown: BalanceScoreBreakdown

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var goalsService = GoalsService.shared
    @ObservedObject private var snapshotService = DailySnapshotService.shared
    @ObservedObject private var lifeEventsService = LifeEventsService.shared

    @State private var liveSnapshot: DimensionSnapshot?
    @State private var activeTab: Tab = .overview
    @State private var showLifeTrends = false

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case life = "Life"
        case work = "Work"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        heroHeader
                            .padding(.horizontal, 24)
                            .padding(.top, 16)

                        tripleRing
                            .padding(.top, 24)
                            .padding(.bottom, 16)

                        scoreChips
                            .padding(.horizontal, 20)

                        if !patternSummaries.isEmpty {
                            patternsBand
                                .padding(.horizontal, 20)
                                .padding(.top, 18)
                        }

                        tabStrip
                            .padding(.horizontal, 20)
                            .padding(.top, 22)
                            .padding(.bottom, 14)

                        tabContent
                            .padding(.horizontal, 20)

                        Spacer().frame(height: 60)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .sheet(isPresented: $showLifeTrends) {
                LifeTrendsSheet().preferredColorScheme(.dark)
            }
            .task {
                liveSnapshot = await snapshotService.currentLive()
            }
            .onChange(of: lifeEventsService.events) { _, _ in
                Task { liveSnapshot = await snapshotService.currentLive() }
            }
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            LinearGradient(
                colors: [
                    overallTint.opacity(0.30),
                    overallTint.opacity(0.08),
                    EquilibriumColor.background
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateLabel)
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2.2)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
            }
            Text(headlineCopy)
                .font(.system(size: 28, weight: .black))
                .foregroundColor(EquilibriumColor.primaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: Date()).uppercased()
    }

    private var headlineCopy: String {
        let overall = overallScore
        let life = lifeScore
        let work = workScore

        if overall >= 80 { return "Real flow today." }
        if life < 40 && work >= 70 { return "Producing, not feeling it." }
        if life >= 70 && work < 40 { return "Recharging. Don't rush back." }
        if overall >= 60 { return "Holding the line." }
        if overall < 40 { return "Heavy day." }
        return "Steady — find the next move."
    }

    // MARK: - Triple ring

    private var tripleRing: some View {
        let outer = Double(breakdown.score.value) / 100.0  // BALANCE
        let middle = lifeScore / 100.0                     // LIFE
        let inner = workScore / 100.0                      // WORK

        return ZStack {
            ringTrack(diameter: 240, color: balanceTint)
            ringFill(diameter: 240, progress: outer, color: balanceTint)

            ringTrack(diameter: 190, color: lifeTint)
            ringFill(diameter: 190, progress: middle, color: lifeTint)

            ringTrack(diameter: 140, color: workTint)
            ringFill(diameter: 140, progress: inner, color: workTint)

            VStack(spacing: 2) {
                Text("OVERALL")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Text("\(Int(overallScore.rounded()))")
                    .font(.system(size: 56, weight: .black))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
                Text(overallTier.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(overallTint)
            }
        }
        .frame(height: 260)
    }

    private func ringTrack(diameter: CGFloat, color: Color) -> some View {
        Circle()
            .stroke(color.opacity(0.12), lineWidth: 7)
            .frame(width: diameter, height: diameter)
    }

    private func ringFill(diameter: CGFloat, progress: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(progress))
            .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.7, dampingFraction: 0.9), value: progress)
    }

    // MARK: - Score chips

    private var scoreChips: some View {
        HStack(spacing: 10) {
            scoreChip(label: "BALANCE", value: Int(breakdown.score.value), tint: balanceTint, kind: .balance)
            scoreChip(label: "LIFE", value: Int(lifeScore.rounded()), tint: lifeTint, kind: .life)
            scoreChip(label: "WORK", value: Int(workScore.rounded()), tint: workTint, kind: .work)
        }
    }

    fileprivate enum ChipKind { case balance, life, work }

    private func scoreChip(label: String, value: Int, tint: Color, kind: ChipKind) -> some View {
        Button {
            switch kind {
            case .balance: activeTab = .overview
            case .life: activeTab = .life
            case .work: activeTab = .work
            }
        } label: {
            VStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.3)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Text("\(value)")
                    .font(.system(size: 22, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(EquilibriumColor.primaryText.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(tint.opacity(activeTab.matches(kind) ? 0.6 : 0.20), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Patterns band

    private var patternSummaries: [String] {
        guard let liveSnapshot else { return [] }
        let _ = liveSnapshot
        return PatternDetector.detect(
            snapshots: snapshotService.snapshots,
            events: lifeEventsService.events,
            now: Date(),
            maxResults: 3
        ).map { $0.summary }
    }

    private var patternsBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PATTERNS")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.tertiaryText)

            VStack(spacing: 6) {
                ForEach(patternSummaries, id: \.self) { summary in
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(overallTint)
                        Text(summary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(EquilibriumColor.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(overallTint.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(overallTint.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    activeTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue.uppercased())
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.2)
                            .foregroundColor(activeTab == tab ? tabTint(tab) : EquilibriumColor.tertiaryText)
                        Rectangle()
                            .fill(activeTab == tab ? tabTint(tab) : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tabTint(_ tab: Tab) -> Color {
        switch tab {
        case .overview: return balanceTint
        case .life: return lifeTint
        case .work: return workTint
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .overview:
            overviewTab
        case .life:
            lifeTab
        case .work:
            workTab
        }
    }

    // Overview tab — original components + recovery, plus a compact heatmap (Phase E)
    private var overviewTab: some View {
        VStack(spacing: 14) {
            componentsCard

            if breakdown.recoveryBonus > 0 {
                recoveryCard
            }

            heatmapCard
        }
    }

    private var componentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BALANCE COMPONENTS")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.tertiaryText)

            componentRow(label: "Meetings", subtitle: "Calendar load", component: breakdown.meeting)
            componentRow(label: "Connections", subtitle: "Relationship freshness", component: breakdown.connection)

            if let sleep = breakdown.sleep {
                componentRow(label: "Sleep", subtitle: "Last night", component: sleep)
            } else {
                missingComponentRow(label: "Sleep", subtitle: "Not logged today")
            }

            if let energy = breakdown.energy {
                componentRow(label: "Energy", subtitle: "Self-reported", component: energy)
            } else {
                missingComponentRow(label: "Energy", subtitle: "Not logged today")
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var recoveryCard: some View {
        HStack {
            Image(systemName: "wind")
                .font(.system(size: 18))
                .foregroundColor(EquilibriumColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery bonus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("From breathing minutes today")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer()
            Text("+\(Int(breakdown.recoveryBonus * 100))")
                .font(.system(size: 18, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.accent.opacity(0.10))
        )
    }

    private func componentRow(label: String, subtitle: String, component: BalanceScoreBreakdown.Component) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                Spacer()
                Text("\(Int(component.raw * 100))")
                    .font(.system(size: 16, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("\(Int(component.weight * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(EquilibriumColor.primaryText.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(balanceTint)
                        .frame(width: geo.size.width * CGFloat(component.raw))
                }
            }
            .frame(height: 5)
        }
    }

    private func missingComponentRow(label: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            Spacer()
            Text("—")
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(.vertical, 4)
    }

    // Life tab — dimensions + recent events + Trends button
    private var lifeTab: some View {
        VStack(spacing: 14) {
            dimensionsCard

            recentEventsCard

            trendsButton
        }
    }

    private var dimensionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIMENSIONS")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.tertiaryText)

            if let snap = liveSnapshot {
                VStack(spacing: 6) {
                    ForEach(Dimension.allCases, id: \.self) { dim in
                        dimensionRow(dim, score: snap.value(for: dim))
                    }
                }
            } else {
                Text("Computing…")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func dimensionRow(_ dimension: Dimension, score: Double) -> some View {
        let tint = scoreTint(score)
        return HStack(spacing: 10) {
            Text(dimension.label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
                .frame(width: 92, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(EquilibriumColor.primaryText.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(score / 100.0))
                }
            }
            .frame(height: 5)

            Text("\(Int(score.rounded()))")
                .font(.system(size: 12, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(tint)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var recentEventsCard: some View {
        let recent = Array(lifeEventsService.events.prefix(5))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECENT EVENTS")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                Text("\(lifeEventsService.events.count) total")
                    .font(.system(size: 9))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            if recent.isEmpty {
                Text("Tell Maria about your day — fights, wins, rest, fun. Each event shapes the score.")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            } else {
                VStack(spacing: 6) {
                    ForEach(recent) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func eventRow(_ event: LifeEvent) -> some View {
        let tint: Color = {
            switch event.polarity {
            case .positive: return Color.green
            case .negative: return Color.red.opacity(0.85)
            case .neutral: return EquilibriumColor.tertiaryText
            case .signal: return EquilibriumColor.CardTint.calendar
            }
        }()
        return HStack(spacing: 8) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(event.category.rawValue.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
                .foregroundColor(tint)
                .frame(width: 80, alignment: .leading)
            if let note = event.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(relativeLabel(event.occurredAt))
                .font(.system(size: 9))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    private var trendsButton: some View {
        Button {
            showLifeTrends = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                Text("View trends + heatmap")
                    .font(.system(size: 14, weight: .heavy))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(16)
            .foregroundColor(lifeTint)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(lifeTint.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // Work tab — accountability composite (existing logic, restyled)
    private var workTab: some View {
        let score = goalsService.accountabilityScore()
        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ACCOUNTABILITY")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)

                VStack(spacing: 8) {
                    timeframeRow(label: "TODAY", stats: score.daily)
                    timeframeRow(label: "WEEK", stats: score.weekly)
                    timeframeRow(label: quarterLabel(), stats: score.quarter)
                    timeframeRow(label: "YEAR", stats: score.yearly)
                }
            }
            .padding(16)
            .background(cardBackground)

            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(workTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALENDAR · LAST 7d")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1)
                        .foregroundColor(EquilibriumColor.tertiaryText)
                    Text(calendarStatusLabel(score: score))
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                Spacer()
            }
            .padding(16)
            .background(cardBackground)

            Text("Composite weighs daily 35%, weekly 30%, quarter 20%, year 15%. Empty timeframes don't drag the score.")
                .font(.system(size: 10))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    private func timeframeRow(label: String, stats: AccountabilityScore.TimeframeStats) -> some View {
        let tint = scoreTint((stats.rate ?? 0) * 100)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("\(Int((stats.weight * 100).rounded()))%")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                Text(stats.hasData ? "\(stats.completed)/\(stats.completed + stats.missed)" : "no data")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.secondaryText)
                Text(AccountabilityScore.percent(stats.rate))
                    .font(.system(size: 14, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(EquilibriumColor.primaryText.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(stats.rate ?? 0))
                }
            }
            .frame(height: 4)
        }
    }

    private func calendarStatusLabel(score: AccountabilityScore) -> String {
        let total = score.calendarCompleted7d + score.calendarMissed7d + score.calendarRescheduled7d
        if total == 0 { return "No event status set this week" }
        return "\(score.calendarCompleted7d) done · \(score.calendarMissed7d) missed · \(score.calendarRescheduled7d) rescheduled"
    }

    private func quarterLabel() -> String {
        switch Goal.Timeframe.currentQuarter() {
        case .q1: return "Q1"
        case .q2: return "Q2"
        case .q3: return "Q3"
        case .q4: return "Q4"
        default: return "QUARTER"
        }
    }

    // MARK: - Heatmap (Phase E)

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LIFE HEATMAP · 35d")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                Text("dark = low · bright = high")
                    .font(.system(size: 9))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            heatmapGrid
        }
        .padding(16)
        .background(cardBackground)
    }

    private var heatmapGrid: some View {
        let days = 35
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let cells: [(date: Date, score: Double?)] = (0..<days).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = DimensionSnapshot.dayKey(for: date)
            let snap = snapshotService.snapshots.first(where: { $0.id == key })
            return (date, snap?.lifeComposite)
        }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(0..<cells.count, id: \.self) { idx in
                heatmapCell(score: cells[idx].score)
            }
        }
    }

    private func heatmapCell(score: Double?) -> some View {
        let color: Color = {
            guard let s = score else { return EquilibriumColor.primaryText.opacity(0.06) }
            if s >= 70 { return Color.green.opacity(0.85) }
            if s >= 55 { return Color.green.opacity(0.55) }
            if s >= 45 { return Color.yellow.opacity(0.65) }
            if s >= 30 { return Color.orange.opacity(0.65) }
            return Color.red.opacity(0.7)
        }()
        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Helpers

    private func relativeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        return "\(days)d ago"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(EquilibriumColor.primaryText.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(EquilibriumColor.primaryText.opacity(0.04), lineWidth: 0.5)
            )
    }

    private func scoreTint(_ value: Double) -> Color {
        if value >= 70 { return .green }
        if value >= 45 { return .yellow }
        return .red.opacity(0.85)
    }

    private var lifeScore: Double {
        liveSnapshot?.lifeComposite ?? 50
    }

    private var workScore: Double {
        goalsService.accountabilityScore().overall * 100.0
    }

    private var overallScore: Double {
        let balance = Double(breakdown.score.value)
        let life = lifeScore
        let work = workScore
        // Equal-weighted blend of all three; if work has no data (0%), exclude it
        if work < 1 {
            return (balance + life) / 2
        }
        return (balance + life + work) / 3
    }

    private var overallTier: String {
        if overallScore >= 75 { return "in flow" }
        if overallScore >= 55 { return "steady" }
        if overallScore >= 35 { return "strained" }
        return "burning out"
    }

    private var balanceTint: Color {
        switch breakdown.score.tier {
        case .burningOut: return Color.red.opacity(0.85)
        case .steady: return Color.yellow
        case .inFlow: return Color.green
        }
    }

    private var lifeTint: Color {
        scoreTint(lifeScore)
    }

    private var workTint: Color {
        scoreTint(workScore)
    }

    private var overallTint: Color {
        scoreTint(overallScore)
    }
}

fileprivate extension BalanceDetailView.Tab {
    func matches(_ kind: BalanceDetailView.ChipKind) -> Bool {
        switch (self, kind) {
        case (.overview, .balance): return true
        case (.life, .life): return true
        case (.work, .work): return true
        default: return false
        }
    }
}
