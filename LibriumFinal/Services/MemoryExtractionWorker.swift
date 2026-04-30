import Foundation

@MainActor
final class MemoryExtractionWorker {
    static let shared = MemoryExtractionWorker()

    private let store: JSONStore
    private static let queueKey = "equilibrium.maria.memoryQueue"
    private static let batchSize = 5
    private static let maxAttempts = 3
    private static let drainEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let drainModel = "gpt-4o-mini"

    private var draining = false

    init(store: JSONStore = .shared) {
        self.store = store
    }

    func enqueue(userMessage: String, mariaResponse: String) {
        var queue = loadQueue()
        let job = MemoryExtractionJob(
            id: UUID(),
            createdAt: Date(),
            userMessage: userMessage,
            mariaResponse: mariaResponse,
            attempts: 0,
            lastError: nil
        )
        queue.append(job)
        saveQueue(queue)

        if queue.count >= Self.batchSize {
            Task { await drain() }
        }
    }

    func drainNow() async {
        await drain()
    }

    private func drain() async {
        guard !draining else { return }
        draining = true
        defer { draining = false }

        var queue = loadQueue()
        guard !queue.isEmpty else { return }

        let key = Secrets.openAIAPIKey
        guard !key.isEmpty else { return }

        let batch = Array(queue.prefix(Self.batchSize))
        let existing = MemoryService.shared.loadAll().suffix(30)

        do {
            let memories = try await extract(jobs: batch, existing: Array(existing), apiKey: key)
            if !memories.isEmpty {
                MemoryService.shared.addMany(memories)
            }
            queue.removeFirst(batch.count)
            saveQueue(queue)
        } catch {
            queue = loadQueue()
            for index in 0..<min(batch.count, queue.count) {
                queue[index].attempts += 1
                queue[index].lastError = String(describing: error)
            }
            queue.removeAll { $0.attempts >= Self.maxAttempts }
            saveQueue(queue)
        }
    }

    private func loadQueue() -> [MemoryExtractionJob] {
        store.load([MemoryExtractionJob].self, key: Self.queueKey) ?? []
    }

    private func saveQueue(_ queue: [MemoryExtractionJob]) {
        store.save(queue, key: Self.queueKey)
    }

    private func extract(
        jobs: [MemoryExtractionJob],
        existing: [MariaMemory],
        apiKey: String
    ) async throws -> [MariaMemory] {
        let existingSummary: String = existing.isEmpty
            ? "(none)"
            : existing.map { "- \($0.content)" }.joined(separator: "\n")

        let turnsBlock = jobs.enumerated().map { idx, job in
            """
            TURN \(idx + 1):
            USER: \(job.userMessage)
            MARIA: \(job.mariaResponse)
            """
        }.joined(separator: "\n\n")

        let prompt = """
        Below are \(jobs.count) turn(s) between a user and Maria. Across ALL turns, extract 0–\(jobs.count * 3) NEW memories about the user.

        STRICT RULES:
        1. Only extract from what the USER explicitly said — never from Maria's responses, suggestions, or assumptions.
        2. If Maria mentioned something the user didn't confirm or correct, DO NOT extract it.
        3. If the user denied or corrected something Maria said, DO NOT extract Maria's claim.
        4. Skip casual chit-chat, greetings, and Maria's coaching questions.
        5. Skip operator data already tracked structurally (pipeline values, bill amounts, calendar event details, exact dollar figures Maria recited).
        6. DO NOT duplicate existing memories listed below.

        Existing memories (DO NOT repeat these in any rewording):
        \(existingSummary)

        Categories: fact | preference | win | struggle | commitment | context

        Return JSON: {"memories": [{"content": string, "category": string, "keywords": [string]}]}
        Empty array if nothing genuinely new.

        TURNS:
        \(turnsBlock)
        """

        let body: [String: Any] = [
            "model": Self.drainModel,
            "max_tokens": 600,
            "temperature": 0.2,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": "You extract structured memories from conversations. Always respond in JSON."],
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: Self.drainEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MariaServiceError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        struct Envelope: Codable {
            let choices: [Choice]
            struct Choice: Codable { let message: Message }
            struct Message: Codable { let content: String }
        }
        struct Payload: Codable {
            let memories: [Item]
            struct Item: Codable {
                let content: String
                let category: String
                let keywords: [String]
            }
        }

        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let content = envelope.choices.first?.message.content,
              let payloadData = content.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: payloadData) else {
            throw MariaServiceError.decodingError
        }

        let now = Date()
        return payload.memories.compactMap { item in
            guard let category = MariaMemory.Category(rawValue: item.category),
                  !item.content.isEmpty else { return nil }
            return MariaMemory(
                id: UUID(),
                content: item.content,
                category: category,
                keywords: item.keywords.map { $0.lowercased() },
                createdAt: now,
                mentionCount: 0
            )
        }
    }
}
