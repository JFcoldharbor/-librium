import SwiftUI

struct WorkMainCard: View {
    @ObservedObject var viewModel: WorkHubViewModel
    @ObservedObject private var goalsService = GoalsService.shared
    @ObservedObject private var spiritualService = SpiritualContentService.shared

    @State private var showFocus = false
    @State private var showOverview = false
    @State private var listingTimeframe: Goal.Timeframe?
    @State private var addingTimeframe: Goal.Timeframe?
    @State private var editingGoal: Goal?
    @State private var showMotivationFull = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer().frame(height: 64)

                coverBand
                    .padding(.horizontal, 24)

                Spacer().frame(height: 14)

                if let anchor = anchorGoal {
                    anchorCard(anchor)
                        .padding(.horizontal, 20)
                } else {
                    emptyAnchor
                        .padding(.horizontal, 20)
                }

                Spacer().frame(height: 12)

                momentumStrip
                    .padding(.horizontal, 28)

                Spacer().frame(height: 10)

                timeframeGrid
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }

            // Floating focus pill
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    focusFloatingPill
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            Button(action: { showOverview = true }) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(EquilibriumColor.CardTint.motivation)
            }
            .padding(.top, 80)
            .padding(.trailing, 24)
        }
        .sheet(isPresented: $showFocus) {
            FocusSheet(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showOverview) {
            GoalsOverviewSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(item: $listingTimeframe) { tf in
            GoalListSheet(timeframe: tf)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $addingTimeframe) { tf in
            GoalEditSheet(existing: nil, defaultTimeframe: tf)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditSheet(existing: goal, defaultTimeframe: goal.timeframe)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showMotivationFull) {
            MotivationFullSheet(text: headlinePhrase, dateLabel: coverDateLabel)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        GeometryReader { geo in
            ZStack {
                EquilibriumColor.background
                LinearGradient(
                    colors: [
                        EquilibriumColor.CardTint.motivation.opacity(0.42),
                        EquilibriumColor.CardTint.motivation.opacity(0.10),
                        EquilibriumColor.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                EquilibriumColor.CardTint.motivation.opacity(0.32),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 240
                        )
                    )
                    .frame(width: 380, height: 380)
                    .offset(x: geo.size.width * 0.30, y: -120)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Cover band (date + bold headline)

    private var coverBand: some View {
        Button {
            showMotivationFull = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(coverDateLabel)
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(2.5)
                        .foregroundColor(EquilibriumColor.CardTint.motivation)
                    Spacer()
                    if hasFullMotivation {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(EquilibriumColor.CardTint.motivation.opacity(0.7))
                    }
                }

                Text(headlinePhrase)
                    .font(.system(size: 20, weight: .heavy, design: .default))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.plain)
    }

    private var hasFullMotivation: Bool {
        spiritualService.motivationForToday?.isEmpty == false
    }

    private var coverDateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMM d"
        return f.string(from: Date()).uppercased()
    }

    private var headlinePhrase: String {
        if let motivation = spiritualService.motivationForToday, !motivation.isEmpty {
            return motivation
        }
        if anchorGoal != nil { return "One thing at a time." }
        return "Pick the fight worth winning."
    }

    // MARK: - Anchor goal hero

    private var anchorGoal: Goal? {
        if let daily = goalsService.active(in: .daily).first { return daily }
        if let weekly = goalsService.active(in: .weekly).first { return weekly }
        return nil
    }

    private func anchorCard(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                Text("ANCHOR · \(goal.timeframe.shortLabel)")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if let target = goal.targetDate {
                    Text(target, style: .date)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Text(goal.title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = goal.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    goalsService.markCompleted(id: goal.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                        Text("Done")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white))
                    .foregroundColor(EquilibriumColor.CardTint.motivation)
                }
                .buttonStyle(.plain)

                Button {
                    editingGoal = goal
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Edit")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            EquilibriumColor.CardTint.motivation,
                            EquilibriumColor.CardTint.motivation.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: EquilibriumColor.CardTint.motivation.opacity(0.45), radius: 18, y: 6)
        )
    }

    private var emptyAnchor: some View {
        Button {
            addingTimeframe = .daily
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("NO ANCHOR YET")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundColor(EquilibriumColor.CardTint.motivation)
                Text("Set one thing for today.")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(EquilibriumColor.primaryText)
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .heavy))
                    Text("Set anchor")
                        .font(.system(size: 13, weight: .heavy))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(EquilibriumColor.CardTint.motivation))
                .foregroundColor(.white)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(EquilibriumColor.CardTint.motivation.opacity(0.50), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Momentum strip

    private var momentumStrip: some View {
        HStack(spacing: 0) {
            momentumPill(value: "\(activeCount)", label: "active")
            divider
            momentumPill(value: "\(doneTodayCount)", label: "done today")
            divider
            momentumPill(value: "\(doneThisWeekCount)", label: "this week")
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(EquilibriumColor.CardTint.motivation.opacity(0.30))
            .frame(width: 1, height: 26)
    }

    private func momentumPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeframe grid (2x2)

    private var timeframeGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                timeframeCell(.daily, label: "TODAY")
                timeframeCell(.weekly, label: "THIS WEEK")
            }
            HStack(spacing: 10) {
                timeframeCell(currentQuarter, label: currentQuarter.label.uppercased())
                timeframeCell(.yearly, label: "THIS YEAR")
            }
        }
    }

    private func timeframeCell(_ tf: Goal.Timeframe, label: String) -> some View {
        let active = goalsService.active(in: tf).filter { $0.id != anchorGoal?.id }
        let totalActive = goalsService.active(in: tf).count

        return Button {
            listingTimeframe = tf
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1.8)
                        .foregroundColor(EquilibriumColor.CardTint.motivation)
                        .lineLimit(1)
                    Spacer()
                    Text("\(totalActive)")
                        .font(.system(size: 11, weight: .heavy))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }

                if active.isEmpty {
                    emptyCellBody(tf)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(active.prefix(2)) { goal in
                            cellGoalRow(goal)
                        }
                        if active.count > 2 {
                            Text("+\(active.count - 2) more")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.5)
                                .foregroundColor(EquilibriumColor.CardTint.motivation.opacity(0.85))
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    addingTimeframe = tf
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .heavy))
                        Text("ADD")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(EquilibriumColor.CardTint.motivation.opacity(0.20)))
                    .foregroundColor(EquilibriumColor.CardTint.motivation)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(EquilibriumColor.primaryText.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(EquilibriumColor.CardTint.motivation.opacity(0.30), lineWidth: 0.5)
                    )
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(EquilibriumColor.CardTint.motivation)
                    .frame(width: 3, height: 28)
                    .padding(.leading, 0)
                    .padding(.top, 12)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .buttonStyle(.plain)
    }

    private func cellGoalRow(_ goal: Goal) -> some View {
        HStack(spacing: 6) {
            Button {
                goalsService.markCompleted(id: goal.id)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(EquilibriumColor.CardTint.motivation)
            }
            .buttonStyle(.plain)
            Text(goal.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .contextMenu {
            Button {
                goalsService.markCompleted(id: goal.id)
            } label: {
                Label("Mark done", systemImage: "checkmark.circle.fill")
            }
            Button(role: .destructive) {
                goalsService.markMissed(id: goal.id)
            } label: {
                Label("Mark missed", systemImage: "xmark.circle.fill")
            }
            Button {
                editingGoal = goal
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    private func emptyCellBody(_ tf: Goal.Timeframe) -> some View {
        Text("Nothing yet")
            .font(.system(size: 11))
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    // MARK: - Floating focus pill

    private var focusFloatingPill: some View {
        Button(action: { showFocus = true }) {
            ZStack {
                if viewModel.focusActive {
                    activePill
                } else {
                    idlePill
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.focusActive)
        }
        .buttonStyle(.plain)
    }

    private var idlePill: some View {
        ZStack {
            Circle()
                .fill(EquilibriumColor.CardTint.motivation)
                .frame(width: 56, height: 56)
                .shadow(color: EquilibriumColor.CardTint.motivation.opacity(0.5), radius: 18, y: 4)
            Image(systemName: "timer")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var activePill: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 28, height: 28)
                Circle()
                    .trim(from: 0, to: viewModel.focusProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.focusProgress)
            }
            Text(viewModel.focusFormattedRemaining)
                .font(.system(size: 16, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(EquilibriumColor.CardTint.motivation)
                .shadow(color: EquilibriumColor.CardTint.motivation.opacity(0.55), radius: 18, y: 4)
        )
    }

    // MARK: - Helpers

    private var currentQuarter: Goal.Timeframe {
        Goal.Timeframe.currentQuarter()
    }

    private var activeCount: Int {
        goalsService.goals.filter { $0.status == .active }.count
    }

    private var doneTodayCount: Int {
        goalsService.goals.filter { goal in
            guard let completedAt = goal.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
    }

    private var doneThisWeekCount: Int {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return doneTodayCount
        }
        return goalsService.goals.filter { goal in
            guard let completedAt = goal.completedAt else { return false }
            return completedAt >= weekStart
        }.count
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date).uppercased()
    }
}

// MARK: - Goals overview sheet (all timeframes in one place)

struct GoalsOverviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = GoalsService.shared

    @State private var listingTimeframe: Goal.Timeframe?

    private let allTimeframes: [Goal.Timeframe] = [.daily, .weekly, .q1, .q2, .q3, .q4, .yearly]

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(allTimeframes, id: \.self) { tf in
                            overviewRow(tf)
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("All goals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .sheet(item: $listingTimeframe) { tf in
                GoalListSheet(timeframe: tf)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private func overviewRow(_ tf: Goal.Timeframe) -> some View {
        let all = service.all(in: tf)
        let active = all.filter { $0.status == .active }.count
        let completed = all.filter { $0.status == .completed }.count
        let total = all.count

        return Button(action: { listingTimeframe = tf }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tf.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    HStack(spacing: 8) {
                        statChip("\(active)", "active", tint: EquilibriumColor.CardTint.motivation)
                        statChip("\(completed)", "done", tint: .green)
                        if total > 0 {
                            Text("\(Int(Double(completed) / Double(total) * 100))%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(EquilibriumColor.tertiaryText)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(EquilibriumColor.primaryText.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private func statChip(_ value: String, _ label: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }
}

extension Goal.Timeframe: Identifiable {
    public var id: String { rawValue }
}

// MARK: - Motivation full-screen sheet

struct MotivationFullSheet: View {
    let text: String
    let dateLabel: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(dateLabel)
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(3)
                            .foregroundColor(EquilibriumColor.CardTint.motivation)

                        Text(text)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(EquilibriumColor.primaryText)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer().frame(height: 60)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            LinearGradient(
                colors: [
                    EquilibriumColor.CardTint.motivation.opacity(0.30),
                    EquilibriumColor.CardTint.motivation.opacity(0.06),
                    EquilibriumColor.background
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
