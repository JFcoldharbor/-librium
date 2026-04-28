import SwiftUI

struct GoalListSheet: View {
    let timeframe: Goal.Timeframe

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = GoalsService.shared

    @State private var editingGoal: Goal?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if scopedGoals.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            if !active.isEmpty {
                                section(label: "ACTIVE", goals: active)
                            }
                            if !completed.isEmpty {
                                section(label: "COMPLETED", goals: completed)
                            }
                            if !missed.isEmpty {
                                section(label: "MISSED", goals: missed)
                            }
                            if !dropped.isEmpty {
                                section(label: "DROPPED", goals: dropped)
                            }
                            Spacer().frame(height: 60)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text(timeframe.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(EquilibriumColor.CardTint.motivation)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                GoalEditSheet(existing: nil, defaultTimeframe: timeframe)
                    .preferredColorScheme(.dark)
            }
            .sheet(item: $editingGoal) { goal in
                GoalEditSheet(existing: goal, defaultTimeframe: goal.timeframe)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.motivation.opacity(0.18),
                    EquilibriumColor.CardTint.motivation.opacity(0.04),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var scopedGoals: [Goal] {
        service.all(in: timeframe)
    }
    private var active: [Goal] { scopedGoals.filter { $0.status == .active } }
    private var completed: [Goal] { scopedGoals.filter { $0.status == .completed } }
    private var missed: [Goal] { scopedGoals.filter { $0.status == .missed } }
    private var dropped: [Goal] { scopedGoals.filter { $0.status == .dropped } }

    private func section(label: String, goals: [Goal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.tertiaryText)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(goals) { goal in
                    GoalRow(
                        goal: goal,
                        onToggle: { toggle(goal) },
                        onTap: { editingGoal = goal }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: "target")
                .font(.system(size: 36))
                .foregroundColor(EquilibriumColor.CardTint.motivation.opacity(0.6))
            Text("No goals yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Tap + to add your first \(timeframe.label.lowercased()) goal.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private func toggle(_ goal: Goal) {
        switch goal.status {
        case .active: service.markCompleted(id: goal.id)
        case .completed, .dropped, .missed: service.markActive(id: goal.id)
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    let onToggle: () -> Void
    let onTap: () -> Void
    @ObservedObject private var service = GoalsService.shared

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(leadingTint)
            }
            .buttonStyle(.plain)

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .strikethrough(goal.status == .completed || goal.status == .missed, color: EquilibriumColor.tertiaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Text(goal.timeframe.shortLabel)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(EquilibriumColor.CardTint.motivation.opacity(0.18)))
                            .foregroundColor(EquilibriumColor.CardTint.motivation)
                        if let target = goal.targetDate {
                            Text(target, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(EquilibriumColor.secondaryText)
                        }
                        if goal.status == .missed {
                            Text("MISSED")
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(1)
                                .foregroundColor(.red.opacity(0.85))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if goal.status == .active {
                Button {
                    service.markMissed(id: goal.id)
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(EquilibriumColor.CardTint.motivation.opacity(0.10), lineWidth: 0.5)
                )
        )
    }

    private var leadingIcon: String {
        switch goal.status {
        case .completed: return "checkmark.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .dropped: return "minus.circle.fill"
        case .active: return "circle"
        }
    }

    private var leadingTint: Color {
        switch goal.status {
        case .completed: return EquilibriumColor.CardTint.motivation
        case .missed: return .red.opacity(0.85)
        case .dropped: return EquilibriumColor.tertiaryText
        case .active: return EquilibriumColor.tertiaryText
        }
    }
}
