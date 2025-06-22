//
//  MemorySystem.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation

// MARK: - Memory System (Implements MemoryProvider)
class MemorySystem: MemoryProvider {
    private var shortTermMemory: ShortTermMemory
    private var longTermMemory: LongTermMemory
    private var episodicMemory: EpisodicMemory
    private var workingMemory: WorkingMemory
    
    init() {
        self.shortTermMemory = ShortTermMemory()
        self.longTermMemory = LongTermMemory()
        self.episodicMemory = EpisodicMemory()
        self.workingMemory = WorkingMemory()
    }
    
    // MARK: - MemoryProvider Protocol Implementation
    
    func store(_ itemData: MemoryItemData) {
        // Convert DTO to internal type
        let item = MemoryItem(from: itemData)
        
        // First goes to short-term
        shortTermMemory.store(item)
        
        // If important enough, also store in long-term
        if item.importance > 0.7 {
            longTermMemory.store(item)
        }
        
        // If it's an experience, store in episodic
        if case .experience = item.type {
            episodicMemory.store(item)
        }
        
        // Update working memory for immediate access
        workingMemory.update(with: item)
    }
    
    func retrieve(query: String, context: MemoryContextData? = nil) -> [MemoryItemData] {
        var results: [MemoryItem] = []
        
        // Check working memory first (fastest)
        results.append(contentsOf: workingMemory.search(query))
        
        // Then short-term memory
        results.append(contentsOf: shortTermMemory.search(query))
        
        // Finally long-term memory if needed
        if results.count < 5 {
            results.append(contentsOf: longTermMemory.search(query, context: context))
        }
        
        // Remove duplicates, sort by relevance, and convert to DTOs
        return Array(Set(results))
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .map { $0.toDTO() }
    }
    
    func consolidate() {
        // Move important short-term memories to long-term
        let importantMemories = shortTermMemory.getImportantMemories()
        for memory in importantMemories {
            longTermMemory.store(memory)
        }
        
        // Clean up old short-term memories
        shortTermMemory.cleanup()
        
        // Update memory connections
        longTermMemory.updateConnections()
        
        // Refresh working memory
        workingMemory.refresh()
    }
    
    func findPatterns() -> [MemoryPatternData] {
        var patterns: [MemoryPattern] = []
        
        // Analyze episodic memories for behavioral patterns
        patterns.append(contentsOf: episodicMemory.analyzeBehavioralPatterns())
        
        // Analyze long-term memories for knowledge patterns
        patterns.append(contentsOf: longTermMemory.analyzeKnowledgePatterns())
        
        // Convert to DTOs
        return patterns.map { $0.toDTO() }
    }
}

// MARK: - Internal Memory Item (Business Logic)
class MemoryItem: Identifiable, Hashable {
    let id: UUID
    let type: MemoryType
    let content: String
    let timestamp: Date
    let source: MemorySource
    var category: MemoryCategory
    var tags: [String]
    var importance: Double
    var emotions: [EmotionType]
    var context: MemoryContextData?
    var accessCount: Int
    var lastAccessedAt: Date
    var relevanceScore: Double = 0.0
    
    init(from dto: MemoryItemData) {
        self.id = dto.id
        self.type = dto.type
        self.content = dto.content
        self.timestamp = dto.timestamp
        self.source = dto.source
        self.category = dto.category
        self.tags = dto.tags
        self.importance = dto.importance
        self.emotions = dto.emotions
        self.context = dto.context
        self.accessCount = 0
        self.lastAccessedAt = Date()
    }
    
    init(type: MemoryType, content: String, source: MemorySource, category: MemoryCategory, importance: Double = 0.5) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.timestamp = Date()
        self.source = source
        self.category = category
        self.tags = []
        self.importance = importance
        self.emotions = []
        self.context = nil
        self.accessCount = 0
        self.lastAccessedAt = Date()
    }
    
    func matches(query: String) -> Bool {
        content.lowercased().contains(query.lowercased()) ||
        tags.contains { $0.lowercased().contains(query.lowercased()) }
    }
    
    func toDTO() -> MemoryItemData {
        MemoryItemData(
            id: id,
            type: type,
            content: content,
            timestamp: timestamp,
            source: source,
            category: category,
            tags: tags,
            importance: importance,
            emotions: emotions,
            context: context
        )
    }
    
    static func == (lhs: MemoryItem, rhs: MemoryItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Internal Memory Pattern (Business Logic)
struct MemoryPattern: Identifiable {
    let id: UUID = UUID()
    let type: MemoryPatternType
    let description: String
    let confidence: Double
    let relatedMemories: [String]
    let discoveredAt: Date = Date()
    
    func toDTO() -> MemoryPatternData {
        MemoryPatternData(
            id: id,
            type: type,
            description: description,
            confidence: confidence,
            relatedMemories: relatedMemories,
            discoveredAt: discoveredAt
        )
    }
}

// MARK: - Short Term Memory
class ShortTermMemory {
    private var memories: [MemoryItem] = []
    private let capacity = 100
    private let retentionTime: TimeInterval = 24 * 60 * 60 // 24 hours
    
    func store(_ item: MemoryItem) {
        memories.append(item)
        
        // If over capacity, remove oldest unimportant memories
        if memories.count > capacity {
            memories.sort { $0.importance > $1.importance }
            memories = Array(memories.prefix(capacity))
        }
    }
    
    func search(_ query: String) -> [MemoryItem] {
        memories.filter { $0.matches(query: query) }
    }
    
    func getImportantMemories() -> [MemoryItem] {
        memories.filter { $0.importance > 0.7 }
    }
    
    func cleanup() {
        let cutoffDate = Date().addingTimeInterval(-retentionTime)
        memories.removeAll { $0.timestamp < cutoffDate && $0.importance < 0.5 }
    }
}

// MARK: - Long Term Memory
class LongTermMemory {
    private var memories: [String: MemoryItem] = [:]
    private var connections: [String: Set<String>] = [:]
    private var categories: [MemoryCategory: Set<String>] = [:]
    
    func store(_ item: MemoryItem) {
        memories[item.id.uuidString] = item
        
        // Categorize memory
        if categories[item.category] == nil {
            categories[item.category] = []
        }
        categories[item.category]?.insert(item.id.uuidString)
        
        // Create connections with related memories
        createConnections(for: item)
    }
    
    func search(_ query: String, context: MemoryContextData? = nil) -> [MemoryItem] {
        var results: [MemoryItem] = []
        
        // Direct content search
        for memory in memories.values {
            if memory.matches(query: query) {
                memory.relevanceScore = calculateRelevance(memory, query: query, context: context)
                results.append(memory)
            }
        }
        
        // If context provided, also search by category
        if let context = context {
            let categoryMemories = searchByCategory(context.relatedCategories)
            results.append(contentsOf: categoryMemories)
        }
        
        // Sort by relevance and recency
        return results.sorted {
            if abs($0.relevanceScore - $1.relevanceScore) < 0.1 {
                return $0.timestamp > $1.timestamp
            }
            return $0.relevanceScore > $1.relevanceScore
        }
    }
    
    func updateConnections() {
        for (id, memory) in memories {
            let relatedMemories = findRelatedMemories(memory)
            connections[id] = Set(relatedMemories.map { $0.id.uuidString })
        }
    }
    
    func analyzeKnowledgePatterns() -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        
        // Analyze category frequencies
        for (category, memoryIds) in categories {
            if memoryIds.count > 5 {
                let pattern = MemoryPattern(
                    type: .knowledge,
                    description: "Frequent interest in \(category.rawValue)",
                    confidence: Double(memoryIds.count) / Double(memories.count),
                    relatedMemories: Array(memoryIds.prefix(5))
                )
                patterns.append(pattern)
            }
        }
        
        // Analyze connection clusters
        let clusters = findMemoryClusters()
        for cluster in clusters {
            if cluster.count > 3 {
                let pattern = MemoryPattern(
                    type: .association,
                    description: "Related concepts cluster",
                    confidence: Double(cluster.count) / 10.0,
                    relatedMemories: Array(cluster.prefix(5))
                )
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
    
    private func createConnections(for memory: MemoryItem) {
        let related = findRelatedMemories(memory)
        connections[memory.id.uuidString] = Set(related.map { $0.id.uuidString })
    }
    
    private func findRelatedMemories(_ memory: MemoryItem) -> [MemoryItem] {
        memories.values.filter { other in
            other.id != memory.id &&
            (other.category == memory.category ||
             !Set(other.tags).intersection(memory.tags).isEmpty ||
             other.content.similarity(to: memory.content) > 0.5)
        }
    }
    
    private func searchByCategory(_ categories: [MemoryCategory]) -> [MemoryItem] {
        var results: [MemoryItem] = []
        for category in categories {
            if let memoryIds = self.categories[category] {
                let categoryMemories = memoryIds.compactMap { memories[$0] }
                results.append(contentsOf: categoryMemories)
            }
        }
        return results
    }
    
    private func calculateRelevance(_ memory: MemoryItem, query: String, context: MemoryContextData?) -> Double {
        var score = 0.0
        
        // Content match
        score += memory.content.similarity(to: query) * 0.4
        
        // Tag match
        let tagMatch = memory.tags.filter { $0.lowercased().contains(query.lowercased()) }.count
        score += Double(tagMatch) / Double(max(memory.tags.count, 1)) * 0.2
        
        // Recency
        let daysSince = Date().timeIntervalSince(memory.timestamp) / (24 * 60 * 60)
        score += max(0, 1 - daysSince / 365) * 0.2
        
        // Context relevance
        if let context = context {
            if context.relatedCategories.contains(memory.category) {
                score += 0.2
            }
        }
        
        return min(1.0, score)
    }
    
    private func findMemoryClusters() -> [[String]] {
        var clusters: [[String]] = []
        var visited = Set<String>()
        
        for memoryId in memories.keys {
            if !visited.contains(memoryId) {
                var cluster = [memoryId]
                visited.insert(memoryId)
                
                if let connected = connections[memoryId] {
                    for connectedId in connected {
                        if !visited.contains(connectedId) {
                            cluster.append(connectedId)
                            visited.insert(connectedId)
                        }
                    }
                }
                
                if cluster.count > 1 {
                    clusters.append(cluster)
                }
            }
        }
        
        return clusters
    }
}

// MARK: - Episodic Memory
class EpisodicMemory {
    private var episodes: [Episode] = []
    private let maxEpisodes = 1000
    
    func store(_ item: MemoryItem) {
        let episode = Episode(
            id: UUID(),
            timestamp: item.timestamp,
            location: item.context?.location,
            participants: item.context?.participants ?? [],
            emotions: item.emotions,
            events: [item],
            summary: item.content
        )
        
        episodes.append(episode)
        
        if episodes.count > maxEpisodes {
            episodes.sort { $0.timestamp > $1.timestamp }
            episodes = Array(episodes.prefix(maxEpisodes))
        }
    }
    
    func analyzeBehavioralPatterns() -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        
        patterns.append(contentsOf: analyzeTimePatterns())
        patterns.append(contentsOf: analyzeEmotionalPatterns())
        patterns.append(contentsOf: analyzeActivityPatterns())
        
        return patterns
    }
    
    private func analyzeTimePatterns() -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        var hourlyActivity: [Int: Int] = [:]
        
        for episode in episodes {
            let hour = Calendar.current.component(.hour, from: episode.timestamp)
            hourlyActivity[hour, default: 0] += 1
        }
        
        let sortedHours = hourlyActivity.sorted { $0.value > $1.value }
        if let peakHour = sortedHours.first, peakHour.value > episodes.count / 24 {
            let pattern = MemoryPattern(
                type: .temporal,
                description: "Most active around \(peakHour.key):00",
                confidence: Double(peakHour.value) / Double(episodes.count),
                relatedMemories: []
            )
            patterns.append(pattern)
        }
        
        return patterns
    }
    
    private func analyzeEmotionalPatterns() -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        var emotionFrequency: [EmotionType: Int] = [:]
        
        for episode in episodes {
            for emotion in episode.emotions {
                emotionFrequency[emotion, default: 0] += 1
            }
        }
        
        let sortedEmotions = emotionFrequency.sorted { $0.value > $1.value }
        for (emotion, count) in sortedEmotions.prefix(3) {
            if count > episodes.count / 10 {
                let pattern = MemoryPattern(
                    type: .emotional,
                    description: "Frequently experiences \(emotion.rawValue)",
                    confidence: Double(count) / Double(episodes.count),
                    relatedMemories: []
                )
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
    
    private func analyzeActivityPatterns() -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        var activityFrequency: [String: Int] = [:]
        
        for episode in episodes {
            let words = episode.summary.lowercased().split(separator: " ")
            for word in words {
                if word.count > 4 {
                    activityFrequency[String(word), default: 0] += 1
                }
            }
        }
        
        let sortedActivities = activityFrequency.sorted { $0.value > $1.value }
        for (activity, count) in sortedActivities.prefix(5) {
            if count > episodes.count / 20 {
                let pattern = MemoryPattern(
                    type: .behavioral,
                    description: "Frequently involved with: \(activity)",
                    confidence: Double(count) / Double(episodes.count * 2),
                    relatedMemories: []
                )
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
}

// MARK: - Working Memory
class WorkingMemory {
    private var activeItems: [MemoryItem] = []
    private let capacity = 7
    private var lastAccessTime: [UUID: Date] = [:]
    
    func update(with item: MemoryItem) {
        activeItems.removeAll { $0.id == item.id }
        activeItems.insert(item, at: 0)
        lastAccessTime[item.id] = Date()
        
        if activeItems.count > capacity {
            let sorted = activeItems.sorted {
                (lastAccessTime[$0.id] ?? Date.distantPast) >
                (lastAccessTime[$1.id] ?? Date.distantPast)
            }
            activeItems = Array(sorted.prefix(capacity))
        }
    }
    
    func search(_ query: String) -> [MemoryItem] {
        activeItems.filter { $0.matches(query: query) }
    }
    
    func refresh() {
        let cutoff = Date().addingTimeInterval(-5 * 60)
        activeItems.removeAll { item in
            (lastAccessTime[item.id] ?? Date.distantPast) < cutoff
        }
    }
}

// MARK: - Internal Episode Model
struct Episode: Identifiable {
    let id: UUID
    let timestamp: Date
    let location: String?
    let participants: [String]
    let emotions: [EmotionType]
    let events: [MemoryItem]
    let summary: String
}
