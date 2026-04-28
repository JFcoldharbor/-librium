import SwiftUI

struct LifeMainCard: View {
    @ObservedObject var viewModel: LifeHubViewModel
    @ObservedObject private var dreamService = DreamService.shared
    @FocusState private var focusedField: Field?

    @State private var showHistory = false
    @State private var showDreamCapture = false
    @State private var selectedDream: DreamEntry?

    enum Field { case intention, gratitude }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 80)
                    .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 16) {
                        moodSection

                        intentionSection

                        gratitudeSection

                        if let yesterday = viewModel.yesterdayEntry, yesterday.hasContent {
                            yesterdayCard(yesterday)
                        }

                        dreamsSection

                        Spacer().frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    dreamPill
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .overlay(alignment: .topTrailing) {
            Button(action: { showHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(EquilibriumColor.CardTint.journalDream.opacity(0.8))
            }
            .padding(.top, 80)
            .padding(.trailing, 24)
        }
        .sheet(isPresented: $showHistory) {
            JournalHistoryView()
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showDreamCapture) {
            DreamCaptureSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedDream) { dream in
            DreamDetailSheet(dream: dream)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.journalDream.opacity(0.32),
                    EquilibriumColor.CardTint.journalDream.opacity(0.08),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 60,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("JOURNAL · DREAMS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(EquilibriumColor.CardTint.journalDream)
                Spacer()
                if viewModel.journalStreak > 0 {
                    streakBadge
                }
            }
            Text(headlineCopy)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var headlineCopy: String {
        let mood = viewModel.todayEntry.mood
        let hasIntention = !viewModel.todayEntry.intention.isEmpty
        if mood == 0 && !hasIntention { return "How is today landing?" }
        if mood >= 4 { return "A good one" }
        if mood > 0 && mood <= 2 { return "Heavy day" }
        if hasIntention { return "Intention set" }
        return "Today's reflection"
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11))
            Text("\(viewModel.journalStreak)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundColor(EquilibriumColor.CardTint.journalDream)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(EquilibriumColor.CardTint.journalDream.opacity(0.18))
        )
    }

    // MARK: - Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MOOD")
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    moodButton(value: value)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(blockBackground)
    }

    private func moodButton(value: Int) -> some View {
        let isSelected = viewModel.todayEntry.mood == value
        let isUnset = viewModel.todayEntry.mood == 0
        return Button(action: { viewModel.setMood(value) }) {
            Text(emojiForMood(value))
                .font(.system(size: 30))
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .opacity(isUnset || isSelected ? 1.0 : 0.30)
                .animation(.spring(response: 0.25), value: isSelected)
        }
    }

    private func emojiForMood(_ mood: Int) -> String {
        guard mood >= 1 && mood <= 5 else { return "" }
        return ["😞", "😐", "🙂", "😊", "😄"][mood - 1]
    }

    // MARK: - Intention / gratitude

    private var intentionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("TODAY'S INTENTION")
            TextField("What are you here to do?", text: $viewModel.todayEntry.intention, axis: .vertical)
                .focused($focusedField, equals: .intention)
                .lineLimit(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
                .onChange(of: focusedField) { _, newValue in
                    if newValue != .intention { viewModel.saveJournal() }
                }
        }
        .padding(16)
        .background(blockBackground)
    }

    private var gratitudeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("GRATITUDE")
            TextField("Small or large", text: $viewModel.todayEntry.gratitude, axis: .vertical)
                .focused($focusedField, equals: .gratitude)
                .lineLimit(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EquilibriumColor.primaryText.opacity(0.06))
                )
                .foregroundColor(EquilibriumColor.primaryText)
                .onChange(of: focusedField) { _, newValue in
                    if newValue != .gratitude { viewModel.saveJournal() }
                }
        }
        .padding(16)
        .background(blockBackground)
    }

    private func yesterdayCard(_ yesterday: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("YESTERDAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Spacer()
                if yesterday.mood > 0 {
                    Text(emojiForMood(yesterday.mood))
                        .font(.system(size: 14))
                }
            }
            if !yesterday.intention.isEmpty {
                Text(yesterday.intention)
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .italic()
                    .lineLimit(2)
            }
            if !yesterday.gratitude.isEmpty {
                Text("Grateful for: \(yesterday.gratitude)")
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.03))
        )
    }

    // MARK: - Dreams

    private var dreamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("DREAMS")
                Spacer()
                if dreamService.isAnalyzing {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.mini).tint(EquilibriumColor.CardTint.journalDream)
                        Text("analyzing")
                            .font(.system(size: 10))
                            .foregroundColor(EquilibriumColor.CardTint.journalDream)
                    }
                }
            }

            let recent = dreamService.recent(limit: 3)
            if recent.isEmpty {
                Button(action: { showDreamCapture = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(EquilibriumColor.CardTint.journalDream)
                        Text("Tell Maria your first dream")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(EquilibriumColor.primaryText)
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(EquilibriumColor.CardTint.journalDream)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(EquilibriumColor.CardTint.journalDream.opacity(0.30), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 8) {
                    ForEach(recent) { dream in
                        Button(action: { selectedDream = dream }) {
                            dreamRow(dream)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(blockBackground)
    }

    private func dreamRow(_ dream: DreamEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 0) {
                Text(dayLabel(dream.dreamedAt))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(EquilibriumColor.CardTint.journalDream)
                Text(monthLabel(dream.dreamedAt))
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(EquilibriumColor.tertiaryText)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dream.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                    if dream.analysis != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(EquilibriumColor.CardTint.journalDream)
                    }
                }
                Text(dream.rawDescription)
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    // MARK: - Dream pill

    private var dreamPill: some View {
        Button(action: { showDreamCapture = true }) {
            ZStack {
                Circle()
                    .fill(EquilibriumColor.CardTint.journalDream)
                    .frame(width: 56, height: 56)
                    .shadow(color: EquilibriumColor.CardTint.journalDream.opacity(0.45), radius: 16, y: 4)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var blockBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(EquilibriumColor.primaryText.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(EquilibriumColor.CardTint.journalDream.opacity(0.15), lineWidth: 0.5)
            )
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(EquilibriumColor.CardTint.journalDream)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date).uppercased()
    }
}
