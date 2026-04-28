import SwiftUI

struct JournalHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [JournalEntry] = []

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                if entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(entries) { entry in
                                entryCard(entry)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
        }
        .onAppear {
            entries = JournalService.shared.loadAll()
                .filter { $0.hasContent }
                .sorted { $0.date > $1.date }
        }
    }

    private func entryCard(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dateLabel(entry.date))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                if entry.mood > 0 {
                    Text(emojiForMood(entry.mood))
                        .font(.system(size: 18))
                }
            }

            if !entry.intention.isEmpty {
                labeledLine(label: "INTENTION", text: entry.intention)
            }
            if !entry.gratitude.isEmpty {
                labeledLine(label: "GRATITUDE", text: entry.gratitude)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func labeledLine(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No journal entries yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add today's intention to get started.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
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

    private func emojiForMood(_ mood: Int) -> String {
        guard mood >= 1 && mood <= 5 else { return "" }
        return ["😞", "😐", "🙂", "😊", "😄"][mood - 1]
    }
}
