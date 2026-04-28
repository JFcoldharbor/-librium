import SwiftUI

struct BreathingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [BreathingSession] = []

    private var totalCycles: Int { sessions.reduce(0) { $0 + $1.cyclesCompleted } }
    private var totalMinutes: Int { sessions.reduce(0) { $0 + $1.totalSeconds } / 60 }

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            statsHeader
                            ForEach(sessions) { session in
                                sessionRow(session)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Breathing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
        .onAppear {
            sessions = BreathingHistoryService.shared.loadAll().sorted { $0.date > $1.date }
        }
    }

    private var statsHeader: some View {
        HStack {
            statBlock(value: "\(sessions.count)", label: "sessions")
            Spacer()
            statBlock(value: "\(totalCycles)", label: "cycles")
            Spacer()
            statBlock(value: "\(totalMinutes)", label: "minutes")
        }
        .padding(16)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    private func sessionRow(_ session: BreathingSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.pattern.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text(timeLabel(session.date))
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.cyclesCompleted) cycles")
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("\(session.totalSeconds) sec")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        }
        .padding(14)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wind")
                .font(.system(size: 48))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No breathing sessions yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Start a session to build your practice.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDateInToday(date) {
            f.dateFormat = "h:mm a"
            return "Today · " + f.string(from: date)
        }
        if cal.isDateInYesterday(date) {
            f.dateFormat = "h:mm a"
            return "Yesterday · " + f.string(from: date)
        }
        f.dateFormat = "MMM d · h:mm a"
        return f.string(from: date)
    }
}
