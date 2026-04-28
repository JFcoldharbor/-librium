import Foundation

@MainActor
final class MemoryService {
    static let shared = MemoryService()

    private let store: JSONStore
    private static let storageKey = "equilibrium.maria.memories"
    private static let cap = 500

    init(store: JSONStore = .shared) {
        self.store = store
    }

    func loadAll() -> [MariaMemory] {
        store.load([MariaMemory].self, key: Self.storageKey) ?? []
    }

    func add(_ memory: MariaMemory) {
        var memories = loadAll()
        if Self.isDuplicate(memory, in: memories) { return }
        memories.append(memory)
        if memories.count > Self.cap {
            memories = Array(memories.suffix(Self.cap))
        }
        store.save(memories, key: Self.storageKey)
    }

    func addMany(_ newMemories: [MariaMemory]) {
        guard !newMemories.isEmpty else { return }
        var memories = loadAll()
        for candidate in newMemories where !Self.isDuplicate(candidate, in: memories) {
            memories.append(candidate)
        }
        if memories.count > Self.cap {
            memories = Array(memories.suffix(Self.cap))
        }
        store.save(memories, key: Self.storageKey)
    }

    @discardableResult
    func deleteByKeywords(_ keywords: [String], category: MariaMemory.Category? = nil) -> Int {
        let needles = Set(keywords.map { $0.lowercased() })
        guard !needles.isEmpty else { return 0 }
        var memories = loadAll()
        let originalCount = memories.count
        memories.removeAll { mem in
            if let category, mem.category != category { return false }
            let memKeywords = Set(mem.keywords.map { $0.lowercased() })
            let memContent = mem.content.lowercased()
            let keywordOverlap = !memKeywords.intersection(needles).isEmpty
            let contentMatch = needles.contains { memContent.contains($0) }
            return keywordOverlap || contentMatch
        }
        let removed = originalCount - memories.count
        if removed > 0 {
            store.save(memories, key: Self.storageKey)
        }
        return removed
    }

    private static func isDuplicate(_ candidate: MariaMemory, in existing: [MariaMemory]) -> Bool {
        let candidateKeywords = Set(candidate.keywords.map { $0.lowercased() })
        let candidateWords = wordSet(candidate.content)
        for memory in existing where memory.category == candidate.category {
            let existingKeywords = Set(memory.keywords.map { $0.lowercased() })
            let keywordSim = jaccard(candidateKeywords, existingKeywords)
            let wordSim = jaccard(candidateWords, wordSet(memory.content))
            if keywordSim >= 0.6 || wordSim >= 0.7 {
                return true
            }
        }
        return false
    }

    private static func wordSet(_ text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 3 }
        )
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    func delete(id: UUID) {
        var memories = loadAll()
        memories.removeAll { $0.id == id }
        store.save(memories, key: Self.storageKey)
    }

    func deleteAll() {
        store.remove(key: Self.storageKey)
    }

    func incrementMentions(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let idSet = Set(ids)
        var memories = loadAll()
        for index in memories.indices where idSet.contains(memories[index].id) {
            memories[index].mentionCount += 1
        }
        store.save(memories, key: Self.storageKey)
    }

    func fetchForContext(query: String, limit: Int = 8, now: Date = Date()) -> [MariaMemory] {
        let memories = loadAll()
        guard !memories.isEmpty else { return [] }

        let queryWords = Self.tokenize(query)
        let scored = memories.map { ($0, relevanceScore(memory: $0, queryWords: queryWords, now: now)) }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    private func relevanceScore(memory: MariaMemory, queryWords: Set<String>, now: Date) -> Double {
        let memoryWords = Set(memory.keywords.map { $0.lowercased() })
        let overlap = Double(queryWords.intersection(memoryWords).count)

        let ageDays = now.timeIntervalSince(memory.createdAt) / 86_400
        let recency = exp(-ageDays / 30.0)

        let mentionPenalty = 1.0 / (1.0 + Double(memory.mentionCount) * 0.1)

        return (overlap * 2.0 + recency) * memory.category.weight * mentionPenalty
    }

    private static func tokenize(_ text: String) -> Set<String> {
        let cleaned = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }
        return Set(cleaned)
    }
}
