import SwiftUI

struct ConversationLogView: View {
    @ObservedObject private var service = ConversationLogService.shared
    @State private var showCopyConfirmation = false
    @State private var showClearConfirm = false
    @State private var expandedTurnId: UUID?

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headerControls

                    if service.turns.isEmpty {
                        emptyState
                    } else {
                        ForEach(service.turns.reversed()) { turn in
                            turnRow(turn)
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Conversation Log")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear all turns?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) { service.clear() }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if showCopyConfirmation {
                copyToast
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var headerControls: some View {
        HStack(spacing: 8) {
            Button(action: copyAll) {
                Label("Copy all (\(service.turns.count))", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(EquilibriumColor.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(EquilibriumColor.primaryText)
            }
            .disabled(service.turns.isEmpty)

            Button(action: { showClearConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 44, height: 40)
                    .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(.red.opacity(0.85))
            }
            .disabled(service.turns.isEmpty)
        }
    }

    private func turnRow(_ turn: ConversationTurn) -> some View {
        let isExpanded = expandedTurnId == turn.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(timeLabel(turn.timestamp))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                if turn.isProactive {
                    Text("PROACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(EquilibriumColor.accent.opacity(0.2), in: Capsule())
                        .foregroundColor(EquilibriumColor.accent)
                }
                Spacer()
                if let tokens = turn.tokensUsed {
                    Text("\(tokens)t")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
            }

            messageBlock(label: "USER", text: turn.userMessage.isEmpty ? "(auto-brief)" : turn.userMessage, color: EquilibriumColor.secondaryText)
            messageBlock(label: "MARIA", text: turn.mariaResponse, color: EquilibriumColor.primaryText)

            if isExpanded {
                Divider().background(EquilibriumColor.primaryText.opacity(0.1))

                if !turn.memoriesUsed.isEmpty {
                    Text("MEMORIES PASSED (\(turn.memoriesUsed.count))")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(EquilibriumColor.tertiaryText)
                    ForEach(turn.memoriesUsed, id: \.self) { mem in
                        Text("• \(mem)")
                            .font(.system(size: 11))
                            .foregroundColor(EquilibriumColor.secondaryText)
                    }
                }

                Text("SYSTEM CONTEXT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(EquilibriumColor.tertiaryText)
                Text(turn.systemContext)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { copyTurn(turn) }) {
                    Label("Copy this turn", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(EquilibriumColor.primaryText.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedTurnId = isExpanded ? nil : turn.id
            }
        }
    }

    private func messageBlock(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDateInToday(date) {
            f.dateFormat = "h:mm:ss a"
            return f.string(from: date)
        }
        f.dateFormat = "MMM d · h:mm a"
        return f.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No turns logged yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Talk to Maria — every exchange gets captured here for review.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var copyToast: some View {
        Text("Copied to clipboard")
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundColor(EquilibriumColor.primaryText)
    }

    private func copyAll() {
        UIPasteboard.general.string = service.exportAll()
        flashCopyToast()
    }

    private func copyTurn(_ turn: ConversationTurn) {
        UIPasteboard.general.string = service.exportTurn(turn)
        flashCopyToast()
    }

    private func flashCopyToast() {
        withAnimation(.easeIn(duration: 0.15)) {
            showCopyConfirmation = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) {
                showCopyConfirmation = false
            }
        }
    }
}
