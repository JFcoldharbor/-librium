//
//  ContextEngine.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


//
//  ContextEngine.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation
import CoreLocation

// MARK: - Context Engine (Implements ContextProvider)
class ContextEngine: ObservableObject, ContextProvider {
    @Published private(set) var currentContext: AIContext
    private let memoryProvider: MemoryProvider
    private let learningProvider: LearningProvider
    
    // Context components
    private let temporalContext: TemporalContextManager
    private let environmentalContext: EnvironmentalContextManager
    private let conversationalContext: ConversationalContextManager
    private let emotionalContext: EmotionalContextManager
    private let situationalContext: SituationalContextManager
    
    init(memoryProvider: MemoryProvider, learningProvider: LearningProvider) {
        self.memoryProvider = memoryProvider
        self.learningProvider = learningProvider
        self.currentContext = AIContext()
        
        self.temporalContext = TemporalContextManager()
        self.environmentalContext = EnvironmentalContextManager()
        self.conversationalContext = ConversationalContextManager()
        self.emotionalContext = EmotionalContextManager()
        self.situationalContext = SituationalContextManager()
        
        setupContextUpdates()
    }
    
    // MARK: - ContextProvider Protocol Implementation
    
    func updateContext(with input: ContextInputData) {
        // Update individual context managers
        temporalContext.update(with: input.timestamp)
        
        if let location = input.location {
            let clLocation = CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            )
            environmentalContext.update(with: clLocation)
        }
        
        if let conversation = input.conversation {
            conversationalContext.update(with: conversation)
            emotionalContext.analyze(conversation)
        }
        
        // Analyze situation
        let situation = situationalContext.analyze(
            temporal: temporalContext.getContext(),
            environmental: environmentalContext.getContext(),
            conversational: conversationalContext.getContext(),
            emotional: emotionalContext.getContext()
        )
        
        // Update current context
        currentContext = AIContext(
            temporal: temporalContext.getContext(),
            environmental: environmentalContext.getContext(),
            conversational: conversationalContext.getContext(),
            emotional: emotionalContext.getContext(),
            situational: situation,
            confidence: calculateContextConfidence()
        )
        
        // Store context in memory
        storeContextInMemory()
    }
    
    func getRelevantContext(for query: String) -> RelevantContextData {
        // Get current context components
        let temporal = temporalContext.getRelevantAspects(for: query)
        let environmental = environmentalContext.getRelevantAspects(for: query)
        let conversational = conversationalContext.getRelevantHistory(for: query)
        let emotional = emotionalContext.getCurrentState()
        
        // Get historical context from memory
        let memoryContext = currentContext.toMemoryContext()
        let historicalContext = memoryProvider.retrieve(query: query, context: memoryContext)
        
        // Get learned patterns relevant to query
        let insights = learningProvider.getInsights()
        let relevantPatterns = insights.patternCount // Using count since we only have interface
        
        return RelevantContextData(
            current: currentContext.toDTO(),
            temporal: temporal,
            environmental: environmental,
            conversational: conversational.map { $0.toDTO() },
            emotional: emotional.toDTO(),
            historicalCount: historicalContext.count,
            patternCount: relevantPatterns
        )
    }
    
    func predictNextContext() -> PredictedContextData {
        // Use patterns to predict what might happen next
        let timeBasedPrediction = temporalContext.predictNext()
        let behaviorPrediction = situationalContext.predictNextSituation()
        
        return PredictedContextData(
            likelyActivities: behaviorPrediction.activities,
            likelyMood: behaviorPrediction.mood,
            likelyNeeds: behaviorPrediction.needs,
            timeframe: timeBasedPrediction.timeframe,
            confidence: behaviorPrediction.confidence
        )
    }
    
    func getCurrentContext() -> AIContextData {
        return currentContext.toDTO()
    }
    
    // MARK: - Private Methods
    private func setupContextUpdates() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateTemporalContext()
        }
    }
    
    private func updateTemporalContext() {
        temporalContext.update(with: Date())
        
        if temporalContext.hasSignificantChange() {
            let input = ContextInputData(
                timestamp: Date(),
                location: nil,
                conversation: nil,
                userActivity: nil
            )
            updateContext(with: input)
        }
    }
    
    private func calculateContextConfidence() -> Double {
        var confidence = 0.0
        var weights = 0.0
        
        confidence += temporalContext.getConfidence() * 0.3
        weights += 0.3
        
        if environmentalContext.hasData() {
            confidence += environmentalContext.getConfidence() * 0.2
            weights += 0.2
        }
        
        if conversationalContext.hasRecentActivity() {
            confidence += conversationalContext.getConfidence() * 0.3
            weights += 0.3
        }
        
        if emotionalContext.hasData() {
            confidence += emotionalContext.getConfidence() * 0.2
            weights += 0.2
        }
        
        return weights > 0 ? confidence / weights : 0.5
    }
    
    private func storeContextInMemory() {
        let contextMemory = MemoryItemData(
            id: UUID(),
            type: .experience,
            content: "Context: \(currentContext.situational.description)",
            timestamp: Date(),
            source: .observation,
            category: .experience,
            tags: [],
            importance: currentContext.situational.importance,
            emotions: [],
            context: currentContext.toMemoryContext()
        )
        
        memoryProvider.store(contextMemory)
    }
}

// MARK: - Internal Context Models (Business Logic)

class AIContext {
    var temporal: TemporalContext
    var environmental: EnvironmentalContext?
    var conversational: ConversationalContext
    var emotional: EmotionalContext
    var situational: Situation
    var confidence: Double
    
    init() {
        self.temporal = TemporalContext(timestamp: Date())
        self.environmental = nil
        self.conversational = ConversationalContext()
        self.emotional = EmotionalContext()
        self.situational = Situation(type: .unknown, description: "", importance: 0.5, suggestedActions: [], timestamp: Date())
        self.confidence = 0.5
    }
    
    init(temporal: TemporalContext, environmental: EnvironmentalContext?, conversational: ConversationalContext, emotional: EmotionalContext, situational: Situation, confidence: Double) {
        self.temporal = temporal
        self.environmental = environmental
        self.conversational = conversational
        self.emotional = emotional
        self.situational = situational
        self.confidence = confidence
    }
    
    func toDTO() -> AIContextData {
        AIContextData(
            temporal: temporal.toDTO(),
            environmental: environmental?.toDTO(),
            conversational: conversational.toDTO(),
            emotional: emotional.toDTO(),
            situational: situational.toDTO(),
            confidence: confidence
        )
    }
    
    func toMemoryContext() -> MemoryContextData {
        MemoryContextData(
            timestamp: Date(),
            location: environmental?.type.rawValue,
            participants: [],
            relatedCategories: [mapSituationToCategory(situational.type)],
            relatedTags: [temporal.partOfDay.rawValue, situational.type.rawValue]
        )
    }
}

class TemporalContext {
    let timestamp: Date
    let partOfDay: PartOfDay
    let dayOfWeek: Int
    let weekOfYear: Int
    let isWeekend: Bool
    let isWeekday: Bool
    let timeString: String
    
    init(timestamp: Date) {
        self.timestamp = timestamp
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        
        switch hour {
        case 5..<8:
            self.partOfDay = .earlyMorning
        case 8..<12:
            self.partOfDay = .morning
        case 12..<14:
            self.partOfDay = .midday
        case 14..<17:
            self.partOfDay = .afternoon
        case 17..<21:
            self.partOfDay = .evening
        case 21..<24:
            self.partOfDay = .night
        default:
            self.partOfDay = .lateNight
        }
        
        self.dayOfWeek = calendar.component(.weekday, from: timestamp)
        self.weekOfYear = calendar.component(.weekOfYear, from: timestamp)
        self.isWeekend = [1, 7].contains(dayOfWeek)
        self.isWeekday = !isWeekend
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        self.timeString = formatter.string(from: timestamp)
    }
    
    func toDTO() -> TemporalContextData {
        TemporalContextData(
            timestamp: timestamp,
            partOfDay: partOfDay,
            dayOfWeek: dayOfWeek,
            isWeekend: isWeekend,
            timeString: timeString
        )
    }
}

class EnvironmentalContext {
    let location: LocationData
    let type: EnvironmentType
    let characteristics: [String]
    
    init(location: LocationData, type: EnvironmentType, characteristics: [String]) {
        self.location = location
        self.type = type
        self.characteristics = characteristics
    }
    
    func toDTO() -> EnvironmentalContextData {
        EnvironmentalContextData(
            location: location,
            type: type,
            characteristics: characteristics
        )
    }
}

class ConversationalContext {
    var currentTopic: String?
    var recentTopics: [String]
    var turnCount: Int
    var lastIntent: MessageIntent?
    var conversationMood: ConversationMood
    
    init() {
        self.recentTopics = []
        self.turnCount = 0
        self.conversationMood = .neutral
    }
    
    func toDTO() -> ConversationalContextData {
        ConversationalContextData(
            currentTopic: currentTopic,
            recentTopics: recentTopics,
            turnCount: turnCount,
            lastIntent: lastIntent,
            conversationMood: conversationMood
        )
    }
}

class EmotionalContext {
    var currentEmotion: EmotionType
    var emotionIntensity: Double
    var emotionTrend: EmotionTrend
    var emotionalNeeds: [String]
    
    init() {
        self.currentEmotion = .trust
        self.emotionIntensity = 0.5
        self.emotionTrend = .stable
        self.emotionalNeeds = []
    }
    
    func toDTO() -> EmotionalContextData {
        EmotionalContextData(
            currentEmotion: currentEmotion,
            emotionIntensity: emotionIntensity,
            emotionTrend: emotionTrend,
            emotionalNeeds: emotionalNeeds
        )
    }
}

class Situation {
    let type: SituationType
    let description: String
    let importance: Double
    let suggestedActions: [String]
    let timestamp: Date
    
    init(type: SituationType, description: String, importance: Double, suggestedActions: [String], timestamp: Date) {
        self.type = type
        self.description = description
        self.importance = importance
        self.suggestedActions = suggestedActions
        self.timestamp = timestamp
    }
    
    func toDTO() -> SituationData {
        SituationData(
            type: type,
            description: description,
            importance: importance,
            suggestedActions: suggestedActions,
            timestamp: timestamp
        )
    }
}

class EmotionalState {
    var dominantEmotion: EmotionType = .trust
    var intensity: Double = 0.5
    var trend: EmotionTrend = .stable
    
    func toDTO() -> EmotionalStateData {
        EmotionalStateData(
            dominantEmotion: dominantEmotion,
            intensity: intensity,
            trend: trend
        )
    }
}

class ConversationTurn {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let intent: MessageIntent?
    let emotion: EmotionType?
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), intent: MessageIntent? = nil, emotion: EmotionType? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.intent = intent
        self.emotion = emotion
    }
    
    func toDTO() -> ConversationTurnData {
        ConversationTurnData(
            id: id,
            role: role,
            content: content,
            timestamp: timestamp,
            intent: intent,
            emotion: emotion
        )
    }
}

// MARK: - Context Managers

class TemporalContextManager {
    private var currentTemporal: TemporalContext
    
    init() {
        self.currentTemporal = TemporalContext(timestamp: Date())
    }
    
    func update(with timestamp: Date) {
        currentTemporal = TemporalContext(timestamp: timestamp)
    }
    
    func getContext() -> TemporalContext {
        currentTemporal
    }
    
    func getConfidence() -> Double {
        return 0.95
    }
    
    func hasSignificantChange() -> Bool {
        let lastPartOfDay = currentTemporal.partOfDay
        update(with: Date())
        return lastPartOfDay != currentTemporal.partOfDay
    }
    
    func getRelevantAspects(for query: String) -> [String: String] {
        var aspects: [String: String] = [:]
        
        let timeKeywords = ["today", "yesterday", "tomorrow", "morning", "evening", "night", "weekend"]
        let queryLower = query.lowercased()
        
        if timeKeywords.contains(where: { queryLower.contains($0) }) {
            aspects["currentTime"] = currentTemporal.timeString
            aspects["partOfDay"] = currentTemporal.partOfDay.rawValue
            aspects["dayType"] = currentTemporal.isWeekend ? "weekend" : "weekday"
        }
        
        return aspects
    }
    
    func predictNext() -> (timeframe: String, activities: [String]) {
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let nextPartOfDay = TemporalContext(timestamp: nextHour).partOfDay
        
        var activities: [String] = []
        
        switch nextPartOfDay {
        case .earlyMorning:
            activities = ["wake up routine", "morning exercise", "breakfast preparation"]
        case .morning:
            activities = ["work start", "morning meetings", "focus time"]
        case .midday:
            activities = ["lunch break", "midday walk", "quick tasks"]
        case .afternoon:
            activities = ["afternoon work", "meetings", "project time"]
        case .evening:
            activities = ["dinner preparation", "family time", "relaxation"]
        case .night:
            activities = ["evening routine", "entertainment", "wind down"]
        case .lateNight:
            activities = ["sleep preparation", "reading", "reflection"]
        }
        
        return (timeframe: nextPartOfDay.rawValue, activities: activities)
    }
}

class EnvironmentalContextManager {
    private var currentEnvironment: EnvironmentalContext?
    private var locationHistory: [LocationData] = []
    
    func update(with location: CLLocation) {
        let locationData = LocationData(
            coordinate: CoordinateData(from: location.coordinate),
            timestamp: location.timestamp,
            accuracy: location.horizontalAccuracy
        )
        
        locationHistory.append(locationData)
        
        if locationHistory.count > 100 {
            locationHistory = Array(locationHistory.suffix(100))
        }
        
        let environmentType = determineEnvironmentType(from: location)
        
        currentEnvironment = EnvironmentalContext(
            location: locationData,
            type: environmentType,
            characteristics: analyzeEnvironmentCharacteristics(environmentType)
        )
    }
    
    func getContext() -> EnvironmentalContext? {
        currentEnvironment
    }
    
    func hasData() -> Bool {
        currentEnvironment != nil
    }
    
    func getConfidence() -> Double {
        guard let env = currentEnvironment else { return 0.0 }
        let accuracyConfidence = max(0, 1.0 - (env.location.accuracy / 100.0))
        return min(1.0, accuracyConfidence)
    }
    
    func getRelevantAspects(for query: String) -> [String: String] {
        guard let env = currentEnvironment else { return [:] }
        
        var aspects: [String: String] = [:]
        
        let locationKeywords = ["where", "location", "place", "here", "nearby"]
        if locationKeywords.contains(where: { query.lowercased().contains($0) }) {
            aspects["environmentType"] = env.type.rawValue
            aspects["characteristics"] = env.characteristics.joined(separator: ", ")
        }
        
        return aspects
    }
    
    private func determineEnvironmentType(from location: CLLocation) -> EnvironmentType {
        let recentLocations = locationHistory.suffix(5)
        guard recentLocations.count >= 2 else { return .unknown }
        
        let totalDistance = zip(recentLocations, recentLocations.dropFirst()).reduce(0.0) { sum, pair in
            let loc1 = CLLocation(latitude: pair.0.coordinate.latitude, longitude: pair.0.coordinate.longitude)
            let loc2 = CLLocation(latitude: pair.1.coordinate.latitude, longitude: pair.1.coordinate.longitude)
            return sum + loc1.distance(from: loc2)
        }
        
        let avgSpeed = totalDistance / (5 * 60)
        
        if avgSpeed < 0.5 {
            return .stationary
        } else if avgSpeed < 2.0 {
            return .walking
        } else if avgSpeed < 10.0 {
            return .transit
        } else {
            return .driving
        }
    }
    
    private func analyzeEnvironmentCharacteristics(_ type: EnvironmentType) -> [String] {
        switch type {
        case .home:
            return ["comfortable", "private", "relaxed", "familiar"]
        case .work:
            return ["professional", "focused", "structured", "productive"]
        case .social:
            return ["interactive", "dynamic", "engaging", "public"]
        case .transit:
            return ["mobile", "temporary", "transitional", "limited"]
        case .outdoor:
            return ["open", "natural", "active", "refreshing"]
        case .stationary:
            return ["stable", "settled", "consistent"]
        case .walking:
            return ["active", "mobile", "healthy", "exploring"]
        case .driving:
            return ["focused", "mobile", "enclosed", "navigating"]
        case .unknown:
            return ["uncertain", "general"]
        }
    }
}

class ConversationalContextManager {
    private var conversationHistory: [ConversationTurn] = []
    private var currentTopic: String?
    private var topicHistory: [(topic: String, startTime: Date)] = []
    private let maxHistorySize = 50
    
    func update(with conversation: ConversationData) {
        for message in conversation.messages {
            let turn = ConversationTurn(
                id: message.id,
                role: message.role,
                content: message.content,
                timestamp: message.timestamp,
                intent: message.intent,
                emotion: message.emotion
            )
            conversationHistory.append(turn)
        }
        
        if conversationHistory.count > maxHistorySize {
            conversationHistory = Array(conversationHistory.suffix(maxHistorySize))
        }
        
        if let newTopic = extractTopic(from: conversation) {
            if newTopic != currentTopic {
                if let current = currentTopic {
                    topicHistory.append((topic: current, startTime: Date()))
                }
                currentTopic = newTopic
            }
        }
    }
    
    func getContext() -> ConversationalContext {
        let context = ConversationalContext()
        context.currentTopic = currentTopic
        context.recentTopics = topicHistory.suffix(5).map { $0.topic }
        context.turnCount = conversationHistory.count
        context.lastIntent = conversationHistory.last?.intent
        context.conversationMood = analyzeConversationMood()
        return context
    }
    
    func hasRecentActivity() -> Bool {
        guard let lastTurn = conversationHistory.last else { return false }
        return Date().timeIntervalSince(lastTurn.timestamp) < 300
    }
    
    func getConfidence() -> Double {
        guard hasRecentActivity() else { return 0.3 }
        
        let topicConsistency = calculateTopicConsistency()
        let recencyFactor = min(1.0, 1.0 - (Date().timeIntervalSince(conversationHistory.last!.timestamp) / 300))
        
        return (topicConsistency + recencyFactor) / 2
    }
    
    func getRelevantHistory(for query: String) -> [ConversationTurn] {
        let queryWords = Set(query.lowercased().split(separator: " ").map { String($0) })
        
        return conversationHistory.filter { turn in
            let turnWords = Set(turn.content.lowercased().split(separator: " ").map { String($0) })
            return !queryWords.intersection(turnWords).isEmpty
        }.suffix(10)
    }
    
    private func extractTopic(from conversation: ConversationData) -> String? {
        let allContent = conversation.messages.map { $0.content }.joined(separator: " ")
        let words = allContent.split(separator: " ")
            .filter { $0.count > 4 }
            .map { String($0).lowercased() }
        
        let wordFrequency = words.reduce(into: [:]) { counts, word in
            counts[word, default: 0] += 1
        }
        
        return wordFrequency.max { $0.value < $1.value }?.key
    }
    
    private func analyzeConversationMood() -> ConversationMood {
        let recentEmotions = conversationHistory.suffix(10).compactMap { $0.emotion }
        
        guard !recentEmotions.isEmpty else { return .neutral }
        
        let positiveEmotions: Set<EmotionType> = [.joy, .trust, .anticipation]
        let negativeEmotions: Set<EmotionType> = [.sadness, .anger, .fear, .disgust]
        
        let positiveCount = recentEmotions.filter { positiveEmotions.contains($0) }.count
        let negativeCount = recentEmotions.filter { negativeEmotions.contains($0) }.count
        
        if positiveCount > negativeCount * 2 {
            return .positive
        } else if negativeCount > positiveCount * 2 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    private func calculateTopicConsistency() -> Double {
        guard topicHistory.count > 1 else { return 0.8 }
        
        let recentTopics = topicHistory.suffix(5).map { $0.topic }
        let uniqueTopics = Set(recentTopics)
        
        return 1.0 - (Double(uniqueTopics.count) / Double(recentTopics.count))
    }
}

class EmotionalContextManager {
    private var emotionalState: EmotionalState
    private var emotionHistory: [(emotion: EmotionType, intensity: Double, timestamp: Date)] = []
    
    init() {
        self.emotionalState = EmotionalState()
    }
    
    func analyze(_ conversation: ConversationData) {
        for message in conversation.messages {
            if let emotion = message.emotion ?? detectEmotion(from: message.content) {
                let intensity = calculateEmotionIntensity(message.content)
                emotionHistory.append((emotion: emotion, intensity: intensity, timestamp: message.timestamp))
            }
        }
        
        updateEmotionalState()
    }
    
    func getContext() -> EmotionalContext {
        let context = EmotionalContext()
        context.currentEmotion = emotionalState.dominantEmotion
        context.emotionIntensity = emotionalState.intensity
        context.emotionTrend = emotionalState.trend
        context.emotionalNeeds = identifyEmotionalNeeds()
        return context
    }
    
    func getCurrentState() -> EmotionalState {
        emotionalState
    }
    
    func hasData() -> Bool {
        !emotionHistory.isEmpty
    }
    
    func getConfidence() -> Double {
        guard !emotionHistory.isEmpty else { return 0.0 }
        
        let recentEmotions = emotionHistory.suffix(5)
        let uniqueEmotions = Set(recentEmotions.map { $0.emotion })
        let consistency = 1.0 - (Double(uniqueEmotions.count - 1) / 5.0)
        
        let recency = emotionHistory.last.map { emotion in
            min(1.0, 1.0 - (Date().timeIntervalSince(emotion.timestamp) / 3600))
        } ?? 0.0
        
        return (consistency + recency) / 2
    }
    
    private func updateEmotionalState() {
        guard !emotionHistory.isEmpty else { return }
        
        let recentEmotions = emotionHistory.suffix(10)
        let emotionCounts = recentEmotions.reduce(into: [:]) { counts, item in
            counts[item.emotion, default: 0] += item.intensity
        }
        
        if let dominant = emotionCounts.max(by: { $0.value < $1.value }) {
            emotionalState.dominantEmotion = dominant.key
            emotionalState.intensity = min(1.0, dominant.value / Double(recentEmotions.count))
        }
        
        emotionalState.trend = calculateEmotionTrend()
    }
    
    private func calculateEmotionIntensity(_ text: String) -> Double {
        let exclamationCount = text.filter { $0 == "!" }.count
        let capsRatio = Double(text.filter { $0.isUppercase }.count) / Double(max(text.count, 1))
        
        return min(1.0, 0.5 + Double(exclamationCount) * 0.1 + capsRatio * 0.3)
    }
    
    private func calculateEmotionTrend() -> EmotionTrend {
        guard emotionHistory.count > 5 else { return .stable }
        
        let older = emotionHistory.suffix(10).prefix(5)
        let newer = emotionHistory.suffix(5)
        
        let olderAvg = older.map { $0.intensity }.reduce(0, +) / Double(older.count)
        let newerAvg = newer.map { $0.intensity }.reduce(0, +) / Double(newer.count)
        
        if newerAvg > olderAvg * 1.2 {
            return .escalating
        } else if newerAvg < olderAvg * 0.8 {
            return .deescalating
        } else {
            return .stable
        }
    }
    
    private func identifyEmotionalNeeds() -> [String] {
        var needs: [String] = []
        
        switch emotionalState.dominantEmotion {
        case .sadness:
            needs = ["comfort", "understanding", "support"]
        case .anger:
            needs = ["validation", "solution", "calm"]
        case .fear:
            needs = ["reassurance", "safety", "information"]
        case .joy:
            needs = ["celebration", "sharing", "continuation"]
        case .trust:
            needs = ["reliability", "consistency", "openness"]
        case .anticipation:
            needs = ["planning", "preparation", "excitement"]
        default:
            needs = ["engagement", "connection", "balance"]
        }
        
        return needs
    }
}

class SituationalContextManager {
    private var currentSituation: Situation?
    private var situationHistory: [Situation] = []
    
    func analyze(
        temporal: TemporalContext,
        environmental: EnvironmentalContext?,
        conversational: ConversationalContext,
        emotional: EmotionalContext
    ) -> Situation {
        let situationType = determineSituationType(
            temporal: temporal,
            environmental: environmental,
            conversational: conversational,
            emotional: emotional
        )
        
        let importance = calculateSituationImportance(
            type: situationType,
            emotional: emotional
        )
        
        let situation = Situation(
            type: situationType,
            description: generateSituationDescription(situationType),
            importance: importance,
            suggestedActions: generateSuggestedActions(situationType, emotional: emotional),
            timestamp: Date()
        )
        
        currentSituation = situation
        situationHistory.append(situation)
        
        if situationHistory.count > 100 {
            situationHistory = Array(situationHistory.suffix(100))
        }
        
        return situation
    }
    
    func predictNextSituation() -> (activities: [String], mood: EmotionType?, needs: [String], confidence: Double) {
        guard let current = currentSituation else {
            return (activities: [], mood: nil, needs: [], confidence: 0.0)
        }
        
        let similarSituations = situationHistory.filter { $0.type == current.type }
        
        var nextActivities: [String] = []
        var nextMood: EmotionType?
        var nextNeeds: [String] = []
        
        switch current.type {
        case .workFocus:
            nextActivities = ["break", "meeting", "lunch"]
            nextNeeds = ["rest", "social interaction", "nourishment"]
        case .socializing:
            nextActivities = ["continued conversation", "activity change", "departure"]
            nextMood = .joy
            nextNeeds = ["connection", "engagement", "fun"]
        case .resting:
            nextActivities = ["wake up", "light activity", "meal"]
            nextNeeds = ["gentle transition", "energy", "motivation"]
        case .exercising:
            nextActivities = ["cool down", "hydration", "shower"]
            nextNeeds = ["recovery", "refreshment", "accomplishment"]
        case .learning:
            nextActivities = ["practice", "break", "review"]
            nextNeeds = ["consolidation", "rest", "application"]
        case .problemSolving:
            nextActivities = ["solution implementation", "collaboration", "break"]
            nextNeeds = ["clarity", "support", "progress"]
        case .mealTime:
            nextActivities = ["cleanup", "rest", "next activity"]
            nextMood = .trust
            nextNeeds = ["digestion", "satisfaction", "transition"]
        case .planning:
            nextActivities = ["execution", "preparation", "communication"]
            nextNeeds = ["clarity", "resources", "commitment"]
        case .crisis:
            nextActivities = ["resolution", "support seeking", "recovery"]
            nextNeeds = ["immediate help", "calm", "solution"]
        case .celebration:
            nextActivities = ["continued joy", "sharing", "wind down"]
            nextMood = .joy
            nextNeeds = ["expression", "connection", "memory making"]
        case .transition:
            nextActivities = ["arrival", "settling", "new activity"]
            nextNeeds = ["orientation", "comfort", "purpose"]
        case .unknown:
            nextActivities = ["exploration", "clarification", "decision"]
            nextNeeds = ["information", "direction", "confidence"]
        }
        
        let confidence = Double(similarSituations.count) / 20.0
        
        return (activities: nextActivities, mood: nextMood, needs: nextNeeds, confidence: min(1.0, confidence))
    }
    
    private func determineSituationType(
        temporal: TemporalContext,
        environmental: EnvironmentalContext?,
        conversational: ConversationalContext,
        emotional: EmotionalContext
    ) -> SituationType {
        // Crisis detection first
        if emotional.emotionIntensity > 0.8 &&
           [.anger, .fear, .sadness].contains(emotional.currentEmotion) {
            return .crisis
        }
        
        // Check for celebration
        if emotional.currentEmotion == .joy && emotional.emotionIntensity > 0.7 {
            return .celebration
        }
        
        // Time-based situations
        switch temporal.partOfDay {
        case .earlyMorning, .morning:
            if temporal.isWeekday {
                return .workFocus
            } else {
                return .resting
            }
        case .midday:
            return .mealTime
        case .afternoon:
            if temporal.isWeekday && conversational.currentTopic != nil {
                return .problemSolving
            } else {
                return .learning
            }
        case .evening:
            if environmental?.type == .social {
                return .socializing
            } else {
                return .planning
            }
        case .night, .lateNight:
            return .resting
        }
    }
    
    private func generateSituationDescription(_ type: SituationType) -> String {
        switch type {
        case .workFocus:
            return "Focused work time - high productivity potential"
        case .socializing:
            return "Social interaction - building connections"
        case .resting:
            return "Rest and recovery period"
        case .exercising:
            return "Physical activity and health focus"
        case .learning:
            return "Learning and skill development time"
        case .problemSolving:
            return "Active problem-solving mode"
        case .mealTime:
            return "Nutrition and meal break"
        case .planning:
            return "Planning and organizing activities"
        case .crisis:
            return "High-stress situation requiring immediate attention"
        case .celebration:
            return "Positive celebration or achievement"
        case .transition:
            return "Transitioning between activities or locations"
        case .unknown:
            return "Uncertain situation - gathering more context"
        }
    }
    
    private func calculateSituationImportance(type: SituationType, emotional: EmotionalContext) -> Double {
        var baseImportance: Double
        
        switch type {
        case .crisis:
            baseImportance = 1.0
        case .problemSolving, .workFocus:
            baseImportance = 0.8
        case .celebration, .learning:
            baseImportance = 0.7
        case .socializing, .planning:
            baseImportance = 0.6
        case .mealTime, .exercising:
            baseImportance = 0.5
        case .resting, .transition:
            baseImportance = 0.4
        case .unknown:
            baseImportance = 0.3
        }
        
        return min(1.0, baseImportance + emotional.emotionIntensity * 0.2)
    }
    
    private func generateSuggestedActions(_ type: SituationType, emotional: EmotionalContext) -> [String] {
        var actions: [String] = []
        
        switch type {
        case .workFocus:
            actions = ["Minimize distractions", "Set clear goals", "Take regular breaks"]
        case .socializing:
            actions = ["Be present", "Listen actively", "Share experiences"]
        case .resting:
            actions = ["Relax fully", "Avoid screens", "Practice mindfulness"]
        case .exercising:
            actions = ["Stay hydrated", "Monitor intensity", "Focus on form"]
        case .learning:
            actions = ["Take notes", "Ask questions", "Apply knowledge"]
        case .problemSolving:
            actions = ["Break down the problem", "Consider alternatives", "Seek input"]
        case .mealTime:
            actions = ["Eat mindfully", "Enjoy the moment", "Nourish your body"]
        case .planning:
            actions = ["Set priorities", "Be realistic", "Build in flexibility"]
        case .crisis:
            actions = ["Stay calm", "Seek support", "Focus on immediate needs"]
        case .celebration:
            actions = ["Savor the moment", "Share joy", "Express gratitude"]
        case .transition:
            actions = ["Stay organized", "Prepare for next activity", "Maintain energy"]
        case .unknown:
            actions = ["Observe situation", "Gather information", "Stay flexible"]
        }
        
        if emotional.emotionIntensity > 0.7 {
            switch emotional.currentEmotion {
            case .anger:
                actions.append("Take deep breaths")
            case .sadness:
                actions.append("Reach out for support")
            case .fear:
                actions.append("Focus on what you can control")
            default:
                break
            }
        }
        
        return actions
    }
}

// MARK: - Helper Functions

private func mapSituationToCategory(_ situation: SituationType) -> MemoryCategory {
    switch situation {
    case .workFocus, .problemSolving:
        return .work
    case .socializing, .celebration:
        return .relationship
    case .exercising, .mealTime, .resting:
        return .health
    case .learning:
        return .skill
    case .planning:
        return .goal
    default:
        return .experience
    }
}