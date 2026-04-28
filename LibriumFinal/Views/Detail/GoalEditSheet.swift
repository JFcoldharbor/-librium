import SwiftUI

struct GoalEditSheet: View {
    let existing: Goal?
    let defaultTimeframe: Goal.Timeframe

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = GoalsService.shared

    @State private var title: String = ""
    @State private var detail: String = ""
    @State private var timeframe: Goal.Timeframe = .daily
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        timeframePicker
                        titleSection
                        detailSection
                        targetDateSection
                        if existing != nil {
                            deleteButton
                        }
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text(existing == nil ? "New goal" : "Edit goal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(EquilibriumColor.CardTint.motivation)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.motivation.opacity(0.22),
                    EquilibriumColor.CardTint.motivation.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var timeframePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TIMEFRAME")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Goal.Timeframe.allCases, id: \.self) { tf in
                        timeframeChip(tf)
                    }
                }
            }
        }
    }

    private func timeframeChip(_ tf: Goal.Timeframe) -> some View {
        let isSelected = timeframe == tf
        return Button {
            timeframe = tf
        } label: {
            Text(tf.label)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected
                        ? EquilibriumColor.CardTint.motivation.opacity(0.30)
                        : EquilibriumColor.primaryText.opacity(0.06))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? EquilibriumColor.CardTint.motivation.opacity(0.6) : Color.clear,
                        lineWidth: 1
                    )
                )
                .foregroundColor(isSelected ? EquilibriumColor.CardTint.motivation : EquilibriumColor.secondaryText)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("GOAL")
            TextField("What do you want to do?", text: $title)
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("WHY IT MATTERS")
            TextField("Optional context", text: $detail, axis: .vertical)
                .lineLimit(2...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("TARGET DATE")
            Toggle(isOn: $hasTargetDate) {
                Text("Has a deadline")
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.primaryText)
            }
            .tint(EquilibriumColor.CardTint.motivation)
            if hasTargetDate {
                DatePicker("", selection: $targetDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(EquilibriumColor.CardTint.motivation)
                    .colorScheme(.dark)
                    .labelsHidden()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let existing { service.delete(id: existing.id) }
            dismiss()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete goal")
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.15))
            )
            .foregroundColor(.red)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    private func hydrate() {
        if let g = existing {
            title = g.title
            detail = g.detail ?? ""
            timeframe = g.timeframe
            if let target = g.targetDate {
                hasTargetDate = true
                targetDate = target
            }
        } else {
            timeframe = defaultTimeframe
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = Goal(
            id: existing?.id ?? UUID(),
            title: trimmedTitle,
            detail: trimmedDetail.isEmpty ? nil : trimmedDetail,
            timeframe: timeframe,
            status: existing?.status ?? .active,
            targetDate: hasTargetDate ? targetDate : nil,
            createdAt: existing?.createdAt ?? Date(),
            completedAt: existing?.completedAt,
            parentGoalId: existing?.parentGoalId
        )
        service.upsert(goal)
        dismiss()
    }
}
