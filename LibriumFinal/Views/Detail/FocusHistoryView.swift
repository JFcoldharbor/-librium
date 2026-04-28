import SwiftUI

struct FocusHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [FocusSession] = []

    private var completedCount: Int { sessions.filter { $0.completed }.count }
    private var totalMinutes: Int { sessions.reduce(0) { $0 + $1.minutes } }

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
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
        .onAppear {
            sessions = FocusHistoryService.shared.loadAll().sorted { $0.startedAt > $1.startedAt }
        }
    }

    private var statsHeader: some View {
        HStack {
            statBlock(value: "\(sessions.count)", label: "started")
            Spacer()
            statBlock(value: "\(completedCount)", label: "completed")
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

    private func sessionRow(_ session: FocusSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeLabel(session.startedAt))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text("\(session.minutes) min")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer()
            if session.completed {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green.opacity(0.85))
            } else {
                Text("Cancelled")
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
        }
        .padding(14)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No focus sessions yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
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
