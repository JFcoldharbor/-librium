//
//  LearningEngine.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation
import Combine

// MARK: - Learning Engine (Implements LearningProvider)
class LearningEngine: ObservableObject, LearningProvider {
    @Published private(set) var learningState: LearningState
    private let memoryProvider: MemoryProvider
    private var cancellables = Set<AnyCancellable>()
    
    // Learning components
    private let patternRecognizer: PatternRecognizer
    private let preferenceTracker: PreferenceTracker
    private let behaviorAnalyzer: BehaviorAnalyzer
    private let feedbackProcessor: FeedbackProcessor
    private let adaptationEngine: AdaptationEngine
    
    init(memoryProvider: MemoryProvider) {
        self.memoryProvider = memoryProvider
        self.learningState = LearningState()
        self.patternRecognizer = PatternRecognizer()
        self.preferenceTracker = PreferenceTracker()
        self.behaviorAnalyzer = BehaviorAnalyzer()
        self.feedbackProcessor = FeedbackProcessor()
        self.adaptationEngine = AdaptationEngine()
        
        setupLearningPipeline()
    }
    
    // MARK: - LearningProvider Protocol Implementation
    
    func learn(from interaction: InteractionData) {
        // Convert DTO to internal type
        let internalInteraction = Interaction(from: interaction)
        
        // Extract features from interaction
        let features = extractFeatures(from: internalInteraction)
        
        // Update various learning components
        patternRecognizer.process(features)
        preferenceTracker.update(with: internalInteraction)
        behaviorAnalyzer.analyze(internalInteraction)
        
        // Store in memory
        let memoryItem = createMemoryItem(from: internalInteraction, features: features)
        memoryProvider.store(memoryItem)
        
        // Update learning state
        updateLearningState(with: internalInteraction)
        
        // Trigger adaptation if needed
        if shouldAdapt() {
            adapt()
        }
    }
    
    func processFeedback(_ feedback: UserFeedbackData) {
        // Convert DTO to internal type
        let internalFeedback = UserFeedback(from: feedback)
        
        feedbackProcessor.process(internalFeedback)
        
        // Adjust learning based on feedback
        if internalFeedback.isPositive {
            reinforceLastBehavior()
        } else {
            adjustLastBehavior()
        }
    }
    
    func getInsights() -> LearningInsightsData {
        let insights = LearningInsights(
            patterns: patternRecognizer.getTopPatterns(),
            preferences: preferenceTracker.getCurrentPreferences(),
            behaviors: behaviorAnalyzer.getKeyBehaviors(),
            adaptations: adaptationEngine.getRecentAdaptations(),
            confidence: calculateConfidence()
        )
        
        return insights.toDTO()
    }
    
    // MARK: - Private Methods
    private func setupLearningPipeline() {
        // Periodic learning tasks
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                self?.performPeriodicLearning()
            }
            .store(in: &cancellables)
    }
    
    private func extractFeatures(from interaction: Interaction) -> InteractionFeatures {
        InteractionFeatures(
            intent: detectIntent(from: interaction.message),
            emotion: detectEmotion(from: interaction.message),
            topics: extractTopics(from: interaction.message),
            entities: extractEntities(from: interaction.message),
            context: interaction.context,
            timestamp: interaction.timestamp,
            responseTime: interaction.responseTime
        )
    }
    
    private func createMemoryItem(from interaction: Interaction, features: InteractionFeatures) -> MemoryItemData {
        MemoryItemData(
            id: UUID(),
            type: .experience,
            content: interaction.message,
            timestamp: features.timestamp,
            source: .userInput,
            category: mapToMemoryCategory(features.intent),
            tags: features.topics,
            importance: calculateImportance(features),
            emotions: [features.emotion].compactMap { $0 },
            context: MemoryContextData(
                timestamp: features.timestamp,
                location: nil,
                participants: [],
                relatedCategories: [],
                relatedTags: features.topics
            )
        )
    }
    
    private func updateLearningState(with interaction: Interaction) {
        learningState.totalInteractions += 1
        learningState.lastInteractionDate = Date()
        
        // Update success metrics
        if interaction.wasSuccessful {
            learningState.successfulInteractions += 1
        }
        
        // Update topic frequencies
        let topics = extractTopics(from: interaction.message)
        for topic in topics {
            learningState.topicFrequency[topic, default: 0] += 1
        }
    }
    
    private func shouldAdapt() -> Bool {
        // Adapt every 50 interactions or when confidence drops
        learningState.totalInteractions % 50 == 0 ||
        calculateConfidence() < 0.7
    }
    
    private func adapt() {
        let patterns = memoryProvider.findPatterns()
        let insights = getInsights()
        
        adaptationEngine.adapt(
            patterns: patterns,
            insights: insights,
            currentState: learningState
        )
    }
    
    private func performPeriodicLearning() {
        // Consolidate memories
        memoryProvider.consolidate()
        
        // Update patterns
        let patterns = memoryProvider.findPatterns()
        patternRecognizer.updatePatterns(patterns)
        
        // Analyze long-term trends
        behaviorAnalyzer.analyzeTrends()
        
        // Update learning metrics
        updateLearningMetrics()
    }
    
    private func calculateConfidence() -> Double {
        guard learningState.totalInteractions > 0 else { return 0.5 }
        
        let successRate = Double(learningState.successfulInteractions) / Double(learningState.totalInteractions)
        let experienceFactor = min(1.0, Double(learningState.totalInteractions) / 1000.0)
        let adaptationLevel = adaptationEngine.getAdaptationLevel()
        
        return (successRate * 0.4 + experienceFactor * 0.3 + adaptationLevel * 0.3)
    }
    
    private func reinforceLastBehavior() {
        // Increase confidence in recent decisions
        if let lastPattern = patternRecognizer.getLastPattern() {
            patternRecognizer.reinforce(lastPattern)
        }
    }
    
    private func adjustLastBehavior() {
        // Decrease confidence and look for alternatives
        if let lastPattern = patternRecognizer.getLastPattern() {
            patternRecognizer.weaken(lastPattern)
        }
    }
    
    private func updateLearningMetrics() {
        learningState.learningRate = calculateLearningRate()
        learningState.adaptationLevel = adaptationEngine.getAdaptationLevel()
        learningState.patternCount = patternRecognizer.getPatternCount()
    }
    
    private func calculateLearningRate() -> Double {
        // Calculate how quickly the AI is learning new patterns
        let recentPatterns = patternRecognizer.getRecentPatternCount()
        let timeElapsed = Date().timeIntervalSince(learningState.startDate) / (24 * 60 * 60) // Days
        
        guard timeElapsed > 0 else { return 0.0 }
        return Double(recentPatterns) / timeElapsed
    }
    
    private func calculateImportance(_ features: InteractionFeatures) -> Double {
        var importance = 0.5
        
        // Increase importance for emotional content
        if features.emotion != nil {
            importance += 0.2
        }
        
        // Increase importance for questions
        if features.intent == .question {
            importance += 0.1
        }
        
        // Increase importance for multiple entities
        if features.entities.count > 1 {
            importance += 0.1
        }
        
        return min(1.0, importance)
    }
}

// MARK: - Internal Learning Models (Business Logic)

struct Interaction {
    let id: UUID = UUID()
    let message: String
    let action: InteractionAction
    let context: ConversationContext
    let timestamp: Date
    let responseTime: TimeInterval
    let wasSuccessful: Bool
    let outcome: ConversationOutcome?
    
    init(from dto: InteractionData) {
        self.message = dto.message
        self.action = dto.action
        self.context = dto.context
        self.timestamp = dto.timestamp
        self.responseTime = dto.responseTime
        self.wasSuccessful = dto.wasSuccessful
        self.outcome = dto.outcome
    }
}

struct InteractionFeatures {
    let intent: MessageIntent
    let emotion: EmotionType?
    let topics: [String]
    let entities: [String]
    let context: ConversationContext
    let timestamp: Date
    let responseTime: TimeInterval
}

struct LearningState: Codable {
    var totalInteractions: Int = 0
    var successfulInteractions: Int = 0
    var lastInteractionDate: Date = Date()
    var topicFrequency: [String: Int] = [:]
    var learningRate: Double = 0.0
    var adaptationLevel: Double = 0.5
    var patternCount: Int = 0
    let startDate: Date = Date()
    
    var successRate: Double? {
        guard totalInteractions > 0 else { return nil }
        return Double(successfulInteractions) / Double(totalInteractions)
    }
}

struct LearningInsights {
    let patterns: [LearningPattern]
    let preferences: [PreferenceCategory: UserPreferenceProfile]
    let behaviors: [UserBehavior]
    let adaptations: [Adaptation]
    let confidence: Double
    
    func toDTO() -> LearningInsightsData {
        LearningInsightsData(
            patternCount: patterns.count,
            preferenceCount: preferences.count,
            behaviorCount: behaviors.count,
            adaptationCount: adaptations.count,
            confidence: confidence
        )
    }
}

struct LearningPattern: Identifiable {
    let id: UUID = UUID()
    let type: PatternType
    let signature: String
    let confidence: Double
    let context: [String: String]
    let firstSeen: Date = Date()
    var lastSeen: Date = Date()
    var occurrences: Int = 1
}

struct UserPreferenceProfile {
    let category: PreferenceCategory
    var likes: Set<String> = []
    var dislikes: Set<String> = []
    var preferredStyle: String?
    var strength: Double = 0.5
    
    mutating func update(with signal: PreferenceSignal) {
        switch signal.sentiment {
        case .positive:
            likes.insert(signal.item)
            strength = min(1.0, strength + signal.strength * 0.1)
        case .negative:
            dislikes.insert(signal.item)
        case .neutral:
            break
        }
    }
}

struct PreferenceSignal {
    let category: PreferenceCategory
    let item: String
    let sentiment: Sentiment
    let strength: Double
    
    enum Sentiment {
        case positive, negative, neutral
    }
}

enum PreferenceCategory: String, Codable {
    case food, activities, work, communication, environment, general
}

struct UserBehavior: Identifiable {
    let id: UUID
    let type: BehaviorType
    let action: InteractionAction
    let context: ConversationContext
    let timestamp: Date
    let duration: TimeInterval
    let outcome: ConversationOutcome?
}

enum BehaviorType: String, Codable {
    case informationSeeking = "informationSeeking"
    case taskExecution = "taskExecution"
    case socialInteraction = "socialInteraction"
    case feedbackProvision = "feedbackProvision"
    case general = "general"
}

struct BehaviorTrend: Identifiable {
    let id: UUID
    let type: BehaviorType
    let metric: TrendMetric
    let value: Double
    let direction: TrendDirection
    let confidence: Double
}

enum TrendMetric: String, Codable {
    case frequency = "frequency"
    case timing = "timing"
    case duration = "duration"
    case success = "success"
}

enum TrendDirection: String, Codable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

struct UserFeedback: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let isPositive: Bool
    let rating: Double?
    let comment: String?
    let context: ConversationContext
    
    init(from dto: UserFeedbackData) {
        self.timestamp = dto.timestamp
        self.isPositive = dto.isPositive
        self.rating = dto.rating
        self.comment = dto.comment
        self.context = dto.context
    }
}

struct FeedbackPattern {
    let context: ConversationContext
    let positiveRate: Double
    let sampleSize: Int
    let insights: [String]
}

struct Adaptation: Identifiable {
    let id: UUID
    let type: AdaptationType
    let parameters: [String: Any]
    let timestamp: Date
    let impact: Double
}

enum AdaptationType: String, Codable {
    case responseStyle = "responseStyle"
    case personality = "personality"
    case behaviorPrediction = "behaviorPrediction"
    case knowledgeExpansion = "knowledgeExpansion"
}

// MARK: - Pattern Recognizer
class PatternRecognizer {
    private var patterns: [LearningPattern] = []
    private var patternStrength: [UUID: Double] = [:]
    private let maxPatterns = 500
    
    func process(_ features: InteractionFeatures) {
        // Look for patterns in features
        let newPatterns = detectPatterns(in: features)
        
        for pattern in newPatterns {
            if let existingIndex = patterns.firstIndex(where: { $0.signature == pattern.signature }) {
                // Strengthen existing pattern
                patterns[existingIndex].occurrences += 1
                patterns[existingIndex].lastSeen = Date()
                patternStrength[patterns[existingIndex].id] = min(1.0, (patternStrength[patterns[existingIndex].id] ?? 0.5) + 0.1)
            } else {
                // Add new pattern
                patterns.append(pattern)
                patternStrength[pattern.id] = 0.5
            }
        }
        
        // Maintain pattern limit
        if patterns.count > maxPatterns {
            cleanupPatterns()
        }
    }
    
    func getTopPatterns(count: Int = 10) -> [LearningPattern] {
        patterns.sorted { pattern1, pattern2 in
            let strength1 = patternStrength[pattern1.id] ?? 0
            let strength2 = patternStrength[pattern2.id] ?? 0
            return strength1 > strength2
        }.prefix(count).map { $0 }
    }
    
    func getLastPattern() -> LearningPattern? {
        patterns.max { $0.lastSeen < $1.lastSeen }
    }
    
    func reinforce(_ pattern: LearningPattern) {
        patternStrength[pattern.id] = min(1.0, (patternStrength[pattern.id] ?? 0.5) + 0.2)
    }
    
    func weaken(_ pattern: LearningPattern) {
        patternStrength[pattern.id] = max(0.0, (patternStrength[pattern.id] ?? 0.5) - 0.3)
    }
    
    func updatePatterns(_ memoryPatterns: [MemoryPatternData]) {
        // Convert memory patterns to learning patterns
        for memPattern in memoryPatterns {
            let learningPattern = LearningPattern(
                type: mapPatternType(memPattern.type),
                signature: memPattern.description,
                confidence: memPattern.confidence,
                context: [:]
            )
            
            if !patterns.contains(where: { $0.signature == learningPattern.signature }) {
                patterns.append(learningPattern)
                patternStrength[learningPattern.id] = memPattern.confidence
            }
        }
    }
    
    func getPatternCount() -> Int {
        patterns.count
    }
    
    func getRecentPatternCount() -> Int {
        let recentDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // Last 7 days
        return patterns.filter { $0.firstSeen > recentDate }.count
    }
    
    private func detectPatterns(in features: InteractionFeatures) -> [LearningPattern] {
        var detectedPatterns: [LearningPattern] = []
        
        // Time-based patterns
        if let timePattern = detectTimePattern(features.timestamp) {
            detectedPatterns.append(timePattern)
        }
        
        // Intent patterns
        if let intentPattern = detectIntentPattern(features.intent, context: features.context) {
            detectedPatterns.append(intentPattern)
        }
        
        // Topic patterns
        for topic in features.topics {
            if let topicPattern = detectTopicPattern(topic, timestamp: features.timestamp) {
                detectedPatterns.append(topicPattern)
            }
        }
        
        return detectedPatterns
    }
    
    private func detectTimePattern(_ timestamp: Date) -> LearningPattern? {
        let hour = Calendar.current.component(.hour, from: timestamp)
        let dayOfWeek = Calendar.current.component(.weekday, from: timestamp)
        
        let signature = "Active at \(hour):00 on day \(dayOfWeek)"
        
        return LearningPattern(
            type: .daily,
            signature: signature,
            confidence: 0.6,
            context: ["hour": String(hour), "dayOfWeek": String(dayOfWeek)]
        )
    }
    
    private func detectIntentPattern(_ intent: MessageIntent, context: ConversationContext) -> LearningPattern? {
        let signature = "\(intent.rawValue) in \(context.rawValue) context"
        
        return LearningPattern(
            type: .behavioral,
            signature: signature,
            confidence: 0.7,
            context: ["intent": intent.rawValue, "context": context.rawValue]
        )
    }
    
    private func detectTopicPattern(_ topic: String, timestamp: Date) -> LearningPattern? {
        let hour = Calendar.current.component(.hour, from: timestamp)
        let timeOfDay = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        
        let signature = "Discusses \(topic) in \(timeOfDay)"
        
        return LearningPattern(
            type: .communication,
            signature: signature,
            confidence: 0.5,
            context: ["topic": topic, "timeOfDay": timeOfDay]
        )
    }
    
    private func cleanupPatterns() {
        // Remove weak and old patterns
        let cutoffDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days
        
        patterns = patterns.filter { pattern in
            let strength = patternStrength[pattern.id] ?? 0
            return strength > 0.3 && pattern.lastSeen > cutoffDate
        }
    }
    
    private func mapPatternType(_ memoryType: MemoryPatternType) -> PatternType {
        switch memoryType {
        case .behavioral: return .behavioral
        case .temporal: return .daily
        case .emotional: return .emotional
        case .knowledge: return .communication
        case .association: return .productivity
        }
    }
}

// MARK: - Preference Tracker
class PreferenceTracker {
    private var preferences: [PreferenceCategory: UserPreferenceProfile] = [:]
    
    func update(with interaction: Interaction) {
        // Extract preference signals from interaction
        let signals = extractPreferenceSignals(from: interaction)
        
        for signal in signals {
            updatePreference(signal)
        }
    }
    
    func getCurrentPreferences() -> [PreferenceCategory: UserPreferenceProfile] {
        preferences
    }
    
    private func extractPreferenceSignals(from interaction: Interaction) -> [PreferenceSignal] {
        var signals: [PreferenceSignal] = []
        
        // Analyze message for preference indicators
        let message = interaction.message.lowercased()
        
        // Positive signals
        let positiveIndicators = ["love", "like", "enjoy", "prefer", "favorite", "great", "awesome", "amazing"]
        for indicator in positiveIndicators {
            if message.contains(indicator) {
                if let object = extractObject(from: message, after: indicator) {
                    signals.append(PreferenceSignal(
                        category: categorizeObject(object),
                        item: object,
                        sentiment: .positive,
                        strength: 0.8
                    ))
                }
            }
        }
        
        // Negative signals
        let negativeIndicators = ["hate", "dislike", "don't like", "avoid", "terrible", "awful"]
        for indicator in negativeIndicators {
            if message.contains(indicator) {
                if let object = extractObject(from: message, after: indicator) {
                    signals.append(PreferenceSignal(
                        category: categorizeObject(object),
                        item: object,
                        sentiment: .negative,
                        strength: 0.8
                    ))
                }
            }
        }
        
        return signals
    }
    
    private func updatePreference(_ signal: PreferenceSignal) {
        if preferences[signal.category] == nil {
            preferences[signal.category] = UserPreferenceProfile(category: signal.category)
        }
        
        preferences[signal.category]?.update(with: signal)
    }
    
    private func extractObject(from message: String, after indicator: String) -> String? {
        // Simple extraction - in production, use NLP
        let components = message.components(separatedBy: indicator)
        guard components.count > 1 else { return nil }
        
        let afterIndicator = components[1].trimmingCharacters(in: .whitespaces)
        let words = afterIndicator.split(separator: " ")
        
        // Take next 1-3 words as the object
        let objectWords = words.prefix(3)
        guard !objectWords.isEmpty else { return nil }
        
        return objectWords.joined(separator: " ")
    }
    
    private func categorizeObject(_ object: String) -> PreferenceCategory {
        // Simple categorization - in production, use classification
        let foodWords = ["food", "eat", "drink", "meal", "coffee", "tea"]
        let activityWords = ["run", "walk", "exercise", "read", "watch", "play"]
        let workWords = ["work", "meeting", "project", "deadline", "office"]
        
        if foodWords.contains(where: { object.contains($0) }) {
            return .food
        } else if activityWords.contains(where: { object.contains($0) }) {
            return .activities
        } else if workWords.contains(where: { object.contains($0) }) {
            return .work
        } else {
            return .general
        }
    }
}

// MARK: - Behavior Analyzer
class BehaviorAnalyzer {
    private var behaviors: [UserBehavior] = []
    private var behaviorTrends: [BehaviorTrend] = []
    
    func analyze(_ interaction: Interaction) {
        let behavior = UserBehavior(
            id: UUID(),
            type: detectBehaviorType(interaction),
            action: interaction.action,
            context: interaction.context,
            timestamp: interaction.timestamp,
            duration: interaction.responseTime,
            outcome: interaction.outcome
        )
        
        behaviors.append(behavior)
        
        // Keep only recent behaviors
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days
        behaviors = behaviors.filter { $0.timestamp > cutoff }
    }
    
    func analyzeTrends() {
        behaviorTrends.removeAll()
        
        // Analyze frequency trends
        let frequencyTrends = analyzeFrequencyTrends()
        behaviorTrends.append(contentsOf: frequencyTrends)
        
        // Analyze timing trends
        let timingTrends = analyzeTimingTrends()
        behaviorTrends.append(contentsOf: timingTrends)
        
        // Analyze outcome trends
        let outcomeTrends = analyzeOutcomeTrends()
        behaviorTrends.append(contentsOf: outcomeTrends)
    }
    
    func getKeyBehaviors() -> [UserBehavior] {
        // Return most impactful behaviors
        behaviors.sorted { $0.timestamp > $1.timestamp }.prefix(20).map { $0 }
    }
    
    private func detectBehaviorType(_ interaction: Interaction) -> BehaviorType {
        switch interaction.action {
        case .query:
            return .informationSeeking
        case .command:
            return .taskExecution
        case .feedback:
            return .feedbackProvision
        case .conversation:
            return .socialInteraction
        default:
            return .general
        }
    }
    
    private func analyzeFrequencyTrends() -> [BehaviorTrend] {
        var trends: [BehaviorTrend] = []
        
        // Group behaviors by type
        let behaviorsByType = Dictionary(grouping: behaviors) { $0.type }
        
        for (type, behaviors) in behaviorsByType {
            let frequency = Double(behaviors.count) / 30.0 // Per day average
            
            let trend = BehaviorTrend(
                id: UUID(),
                type: type,
                metric: .frequency,
                value: frequency,
                direction: calculateTrendDirection(for: behaviors),
                confidence: min(1.0, Double(behaviors.count) / 100.0)
            )
            trends.append(trend)
        }
        
        return trends
    }
    
    private func analyzeTimingTrends() -> [BehaviorTrend] {
        var trends: [BehaviorTrend] = []
        
        // Analyze by hour of day
        var hourlyActivity: [Int: Int] = [:]
        for behavior in behaviors {
            let hour = Calendar.current.component(.hour, from: behavior.timestamp)
            hourlyActivity[hour, default: 0] += 1
        }
        
        // Find peak hours
        if let peakHour = hourlyActivity.max(by: { $0.value < $1.value }) {
            let trend = BehaviorTrend(
                id: UUID(),
                type: .general,
                metric: .timing,
                value: Double(peakHour.key),
                direction: .stable,
                confidence: 0.8
            )
            trends.append(trend)
        }
        
        return trends
    }
    
    private func analyzeOutcomeTrends() -> [BehaviorTrend] {
        var trends: [BehaviorTrend] = []
        
        let successfulBehaviors = behaviors.filter { $0.outcome == .successful }
        let successRate = Double(successfulBehaviors.count) / Double(max(behaviors.count, 1))
        
        let trend = BehaviorTrend(
            id: UUID(),
            type: .general,
            metric: .success,
            value: successRate,
            direction: successRate > 0.7 ? .increasing : .decreasing,
            confidence: 0.9
        )
        trends.append(trend)
        
        return trends
    }
    
    private func calculateTrendDirection(for behaviors: [UserBehavior]) -> TrendDirection {
        guard behaviors.count > 10 else { return .stable }
        
        let sorted = behaviors.sorted { $0.timestamp < $1.timestamp }
        let midPoint = sorted.count / 2
        let firstHalf = sorted.prefix(midPoint)
        let secondHalf = sorted.suffix(sorted.count - midPoint)
        
        let firstHalfAvg = Double(firstHalf.count) / Double(max(1, midPoint))
        let secondHalfAvg = Double(secondHalf.count) / Double(max(1, sorted.count - midPoint))
        
        if secondHalfAvg > firstHalfAvg * 1.2 {
            return .increasing
        } else if secondHalfAvg < firstHalfAvg * 0.8 {
            return .decreasing
        } else {
            return .stable
        }
    }
}

// MARK: - Feedback Processor
class FeedbackProcessor {
    private var feedbackHistory: [UserFeedback] = []
    private var feedbackPatterns: [FeedbackPattern] = []
    
    func process(_ feedback: UserFeedback) {
        feedbackHistory.append(feedback)
        
        // Analyze feedback patterns
        analyzeFeedbackPatterns()
        
        // Keep only recent feedback
        let cutoff = Date().addingTimeInterval(-60 * 24 * 60 * 60) // 60 days
        feedbackHistory = feedbackHistory.filter { $0.timestamp > cutoff }
    }
    
    func getAverageRating() -> Double {
        guard !feedbackHistory.isEmpty else { return 0.5 }
        
        let ratings = feedbackHistory.compactMap { $0.rating }
        guard !ratings.isEmpty else { return 0.5 }
        
        return ratings.reduce(0.0, +) / Double(ratings.count)
    }
    
    func getRecentSentiment() -> Double {
        let recentFeedback = feedbackHistory.suffix(10)
        let positiveFeedback = recentFeedback.filter { $0.isPositive }.count
        
        return Double(positiveFeedback) / Double(max(recentFeedback.count, 1))
    }
    
    private func analyzeFeedbackPatterns() {
        feedbackPatterns.removeAll()
        
        // Group feedback by context
        let feedbackByContext = Dictionary(grouping: feedbackHistory) { $0.context }
        
        for (context, feedbacks) in feedbackByContext {
            let positiveCount = feedbacks.filter { $0.isPositive }.count
            let totalCount = feedbacks.count
            
            if totalCount > 5 {
                let pattern = FeedbackPattern(
                    context: context,
                    positiveRate: Double(positiveCount) / Double(totalCount),
                    sampleSize: totalCount,
                    insights: generateInsights(for: feedbacks)
                )
                feedbackPatterns.append(pattern)
            }
        }
    }
    
    private func generateInsights(for feedbacks: [UserFeedback]) -> [String] {
        var insights: [String] = []
        
        // Analyze common positive feedback
        let positiveFeedback = feedbacks.filter { $0.isPositive }
        if positiveFeedback.count > feedbacks.count / 2 {
            insights.append("Users respond well in this context")
        }
        
        // Analyze common issues
        let negativeFeedback = feedbacks.filter { !$0.isPositive }
        if negativeFeedback.count > 3 {
            let commonIssues = extractCommonIssues(from: negativeFeedback)
            insights.append(contentsOf: commonIssues)
        }
        
        return insights
    }
    
    private func extractCommonIssues(from feedbacks: [UserFeedback]) -> [String] {
        // In production, use NLP to extract themes
        return ["Consider adjusting response style", "Users may need more clarity"]
    }
}

// MARK: - Adaptation Engine
class AdaptationEngine {
    private var adaptations: [Adaptation] = []
    private var currentAdaptationLevel: Double = 0.5
    
    func adapt(patterns: [MemoryPatternData], insights: LearningInsightsData, currentState: LearningState) {
        // Analyze what needs adaptation
        let requiredAdaptations = analyzeAdaptationNeeds(
            patterns: patterns,
            insights: insights,
            currentState: currentState
        )
        
        // Apply adaptations
        for adaptationType in requiredAdaptations {
            let adaptation = createAdaptation(type: adaptationType, insights: insights)
            apply(adaptation)
            adaptations.append(adaptation)
        }
        
        // Update adaptation level
        updateAdaptationLevel()
    }
    
    func getAdaptationLevel() -> Double {
        currentAdaptationLevel
    }
    
    func getRecentAdaptations() -> [Adaptation] {
        adaptations.suffix(10)
    }
    
    private func analyzeAdaptationNeeds(
        patterns: [MemoryPatternData],
        insights: LearningInsightsData,
        currentState: LearningState
    ) -> [AdaptationType] {
        var needs: [AdaptationType] = []
        
        // Check if response style needs adjustment
        if insights.preferenceCount > 5 {
            needs.append(.responseStyle)
        }
        
        // Check if personality needs adjustment
        if let successRate = currentState.successRate, successRate < 0.7 {
            needs.append(.personality)
        }
        
        // Check if behavior predictions need update
        if insights.behaviorCount > 10 {
            needs.append(.behaviorPrediction)
        }
        
        // Check if knowledge gaps exist
        if patterns.contains(where: { $0.type == .knowledge && $0.confidence < 0.5 }) {
            needs.append(.knowledgeExpansion)
        }
        
        return needs
    }
    
    private func createAdaptation(type: AdaptationType, insights: LearningInsightsData) -> Adaptation {
        let parameters: [String: Any]
        
        switch type {
        case .responseStyle:
            parameters = [
                "newStyle": determineOptimalResponseStyle(insights),
                "confidence": 0.8
            ]
        case .personality:
            parameters = [
                "adjustments": determinePersonalityAdjustments(insights),
                "strength": 0.5
            ]
        case .behaviorPrediction:
            parameters = [
                "patterns": ["behavioral", "temporal"],
                "accuracy": 0.7
            ]
        case .knowledgeExpansion:
            parameters = [
                "areas": identifyKnowledgeGaps(insights),
                "priority": 0.9
            ]
        }
        
        return Adaptation(
            id: UUID(),
            type: type,
            parameters: parameters,
            timestamp: Date(),
            impact: estimateImpact(type)
        )
    }
    
    private func apply(_ adaptation: Adaptation) {
        // In a real implementation, this would modify AI behavior
        // For now, we'll just track the adaptation
        
        switch adaptation.type {
        case .responseStyle:
            print("Adapting response style")
        case .personality:
            print("Adjusting personality traits")
        case .behaviorPrediction:
            print("Updating behavior predictions")
        case .knowledgeExpansion:
            print("Expanding knowledge base")
        }
    }
    
    private func updateAdaptationLevel() {
        // Calculate based on number and success of adaptations
        let recentAdaptations = adaptations.suffix(20)
        let averageImpact = recentAdaptations.map { $0.impact }.reduce(0.0, +) / Double(max(recentAdaptations.count, 1))
        
        currentAdaptationLevel = min(1.0, currentAdaptationLevel + averageImpact * 0.1)
    }
    
    private func determineOptimalResponseStyle(_ insights: LearningInsightsData) -> String {
        // Analyze insights to determine best style
        if insights.confidence > 0.8 {
            return "detailed"
        } else if insights.patternCount > 20 {
            return "concise"
        } else {
            return "balanced"
        }
    }
    
    private func determinePersonalityAdjustments(_ insights: LearningInsightsData) -> [String: Double] {
        var adjustments: [String: Double] = [:]
        
        // Adjust based on user engagement patterns
        if insights.behaviorCount > 15 {
            adjustments["humor"] = 0.2
        }
        
        if insights.confidence < 0.6 {
            adjustments["formality"] = 0.3
        }
        
        return adjustments
    }
    
    private func identifyKnowledgeGaps(_ insights: LearningInsightsData) -> [String] {
        // Identify areas where more learning is needed
        var gaps: [String] = []
        
        if insights.patternCount < 10 {
            gaps.append("behavioral patterns")
        }
        
        if insights.preferenceCount < 5 {
            gaps.append("user preferences")
        }
        
        return gaps
    }
    
    private func estimateImpact(_ type: AdaptationType) -> Double {
        switch type {
        case .responseStyle:
            return 0.3
        case .personality:
            return 0.4
        case .behaviorPrediction:
            return 0.5
        case .knowledgeExpansion:
            return 0.6
        }
    }
}

// MARK: - Helper Functions

private func mapToMemoryCategory(_ intent: MessageIntent) -> MemoryCategory {
    switch intent {
    case .question:
        return .fact
    case .command:
        return .goal
    case .emotion:
        return .experience
    default:
        return .personal
    }
}
