import Foundation

@MainActor
final class SliceLoaderService {
    static let shared = SliceLoaderService()

    struct LoadedContext {
        let systemAddendum: String
        let classification: IntentClassification
        let memoriesUsed: [MariaMemory]
        let estimatedTokens: Int
    }

    private init() {}

    func load(
        userMessage: String,
        recentTurns: [IntentClassifierService.ClassifierTurn],
        context: BalanceContext,
        scannerSummary: String?
    ) async -> LoadedContext {
        let classification = await IntentClassifierService.shared.classify(
            userMessage: userMessage,
            recentTurns: recentTurns
        )

        let memories = MemoryService.shared.fetchForContext(query: userMessage, limit: 7)

        let baseline = MariaContextRenderer.renderBaseline(
            .init(context: context, recentMemories: memories, scannerSummary: scannerSummary)
        )

        var slices: [ContextSlice] = []
        for sliceType in classification.slices {
            if let slice = MariaContextRenderer.renderSlice(sliceType, context: context) {
                slices.append(slice)
            }
        }

        var addendum = baseline
        for slice in slices {
            addendum += "\n\n" + slice.content
        }

        let totalTokens = max(1, addendum.count / 4)

        return LoadedContext(
            systemAddendum: addendum,
            classification: classification,
            memoriesUsed: memories,
            estimatedTokens: totalTokens
        )
    }
}
