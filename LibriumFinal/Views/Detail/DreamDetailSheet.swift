import SwiftUI

struct DreamDetailSheet: View {
    let dream: DreamEntry

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dreamService = DreamService.shared
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        descriptionBlock

                        if let analysis = currentDream.analysis {
                            analysisBlock(analysis: analysis)
                        } else {
                            pendingAnalysisBlock
                        }

                        if !currentDream.symbols.isEmpty {
                            symbolsBlock
                        }

                        deleteButton

                        Spacer().frame(height: 40)
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
                    Text("Dream")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if currentDream.analysis == nil {
                        Button {
                            Task { await dreamService.analyze(currentDream) }
                        } label: {
                            if dreamService.isAnalyzing {
                                ProgressView().tint(EquilibriumColor.CardTint.journalDream)
                            } else {
                                Image(systemName: "sparkles")
                                    .foregroundColor(EquilibriumColor.CardTint.journalDream)
                            }
                        }
                        .disabled(dreamService.isAnalyzing)
                    }
                }
            }
            .alert("Delete this dream?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    dreamService.delete(id: dream.id)
                    dismiss()
                }
            } message: {
                Text("It will be removed from your dream log.")
            }
        }
    }

    private var currentDream: DreamEntry {
        dreamService.dreams.first(where: { $0.id == dream.id }) ?? dream
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.journalDream.opacity(0.30),
                    EquilibriumColor.CardTint.journalDream.opacity(0.07),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedDate(currentDream.dreamedAt))
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.CardTint.journalDream)
            Text(currentDream.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("WHAT YOU DREAMED")
            Text(currentDream.rawDescription)
                .font(.system(size: 15))
                .foregroundColor(EquilibriumColor.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func analysisBlock(analysis: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text("MARIA'S READING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
            }
            .foregroundColor(EquilibriumColor.CardTint.journalDream)
            Text(analysis)
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.CardTint.journalDream.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.journalDream.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private var pendingAnalysisBlock: some View {
        HStack(spacing: 10) {
            if dreamService.isAnalyzing {
                ProgressView().tint(EquilibriumColor.CardTint.journalDream)
                Text("Maria's reading the dream…")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
            } else {
                Image(systemName: "sparkles")
                    .foregroundColor(EquilibriumColor.CardTint.journalDream)
                Text("Tap the sparkle in the top corner to ask Maria to read it.")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private var symbolsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("SYMBOLS")
            FlowLayout(spacing: 8) {
                ForEach(currentDream.symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(EquilibriumColor.CardTint.journalDream.opacity(0.18))
                        )
                        .foregroundColor(EquilibriumColor.CardTint.journalDream)
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete dream")
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }
}

// Minimal flow layout for symbol chips
private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + spacing > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
