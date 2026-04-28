import SwiftUI

struct WellnessHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [WellnessLog] = []

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                if logs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(logs) { log in
                                logCard(log)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Wellness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
        .onAppear {
            logs = WellnessLogService.shared.loadAll().sorted { $0.date > $1.date }
        }
    }

    private func logCard(_ log: WellnessLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateLabel(log.date))
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.tertiaryText)

            HStack(spacing: 24) {
                metric(label: "SLEEP", value: log.sleepHours > 0 ? String(format: "%.1fh", log.sleepHours) : "—")
                metric(label: "ENERGY", value: log.energyLevel > 0 ? "\(log.energyLevel)/5" : "—")
                metric(label: "WATER", value: log.waterGlasses > 0 ? "\(log.waterGlasses)" : "—")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No wellness logs yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Log sleep, energy, and water on the wellness card.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d, yyyy"
        return f.string(from: date).uppercased()
    }
}
