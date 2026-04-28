import Foundation

@MainActor
final class DreamService: ObservableObject {
    static let shared = DreamService()

    @Published private(set) var dreams: [DreamEntry] = []
    @Published private(set) var isAnalyzing: Bool = false

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.dreams"
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        let raw = store.load([DreamEntry].self, key: Self.storageKey) ?? []
        dreams = raw.sorted { $0.dreamedAt > $1.dreamedAt }
    }

    func upsert(_ dream: DreamEntry) {
        if let idx = dreams.firstIndex(where: { $0.id == dream.id }) {
            dreams[idx] = dream
        } else {
            dreams.append(dream)
        }
        dreams.sort { $0.dreamedAt > $1.dreamedAt }
        persist()
    }

    func delete(id: UUID) {
        dreams.removeAll { $0.id == id }
        persist()
    }

    func recent(limit: Int = 10) -> [DreamEntry] {
        Array(dreams.prefix(limit))
    }

    private func persist() {
        store.save(dreams, key: Self.storageKey)
    }

    // MARK: - Analysis

    func analyze(_ dream: DreamEntry, context: String? = nil) async {
        guard !Secrets.openAIAPIKey.isEmpty else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        let contextLine = context.map { "Recent life context: \($0)\n\n" } ?? ""

        let prompt = """
        \(contextLine)A dream from the user:

        Title: \(dream.title)
        Description: \(dream.rawDescription)

        Write a tight, grounded analysis (~120 words) — themes, emotional through-line, what their subconscious might be processing. No mystical jargon, no astrology, no Freud labels. Just what's there. Then list 3-6 distinct symbols you noticed.

        Return JSON: {"analysis": "...", "symbols": ["...", "..."]}
        """

        struct Payload: Codable {
            let analysis: String
            let symbols: [String]
        }

        let body: [String: Any] = [
            "model": "gpt-4o",
            "max_tokens": 600,
            "temperature": 0.6,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "You analyze dreams for a personal-growth app. Grounded, specific, no jargon. JSON only."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Secrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }

        guard let outer = try? JSONDecoder().decode(DreamChatResponse.self, from: data),
              let content = outer.choices.first?.message.content,
              let payload = try? JSONDecoder().decode(Payload.self, from: Data(content.utf8)) else {
            return
        }

        var updated = dream
        updated.analysis = payload.analysis
        updated.symbols = payload.symbols
        upsert(updated)
    }
}

private struct DreamChatResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}
