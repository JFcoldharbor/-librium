//
//  SharedTypes.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation
import CoreLocation

// MARK: - Core Protocols (Interfaces)

protocol MemoryProvider {
    func store(_ item: MemoryItemData)
    func retrieve(query: String, context: MemoryContextData?) -> [MemoryItemData]
    func consolidate()
    func findPatterns() -> [MemoryPatternData]
}

protocol ContextProvider {
    func updateContext(with input: ContextInputData)
    func getRelevantContext(for query: String) -> RelevantContextData
    func predictNextContext() -> PredictedContextData
    func getCurrentContext() -> AIContextData
}

protocol LearningProvider {
    func learn(from interaction: InteractionData)
    func processFeedback(_ feedback: UserFeedbackData)
    func getInsights() -> LearningInsightsData
}

protocol ResponseProvider {
    func generateResponse(to input: UserInputData) async -> AIResponseData
    func generateProactiveMessage(context: AIContextData) async -> ProactiveMessageData?
}

// MARK: - Basic Data Transfer Objects (DTOs)

struct MemoryItemData: Codable, Identifiable, Hashable {
    let id: UUID
    let type: MemoryType
    let content: String
    let timestamp: Date
    let source: MemorySource
    let category: MemoryCategory
    let tags: [String]
    let importance: Double
    let emotions: [EmotionType]
    let context: MemoryContextData?
    
    static func == (lhs: MemoryItemData, rhs: MemoryItemData) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MemoryContextData: Codable {
    let timestamp: Date
    let location: String?
    let participants: [String]
    let relatedCategories: [MemoryCategory]
    let relatedTags: [String]
}

struct MemoryPatternData: Codable, Identifiable {
    let id: UUID
    let type: MemoryPatternType
    let description: String
    let confidence: Double
    let relatedMemories: [String]
    let discoveredAt: Date
}

struct AIContextData: Codable {
    let temporal: TemporalContextData
    let environmental: EnvironmentalContextData?
    let conversational: ConversationalContextData
    let emotional: EmotionalContextData
    let situational: SituationData
    let confidence: Double
}

struct TemporalContextData: Codable {
    let timestamp: Date
    let partOfDay: PartOfDay
    let dayOfWeek: Int
    let isWeekend: Bool
    let timeString: String
}

struct EnvironmentalContextData: Codable {
    let location: LocationData
    let type: EnvironmentType
    let characteristics: [String]
}

struct ConversationalContextData: Codable {
    let currentTopic: String?
    let recentTopics: [String]
    let turnCount: Int
    let lastIntent: MessageIntent?
    let conversationMood: ConversationMood
}

struct EmotionalContextData: Codable {
    let currentEmotion: EmotionType
    let emotionIntensity: Double
    let emotionTrend: EmotionTrend
    let emotionalNeeds: [String]
}

struct SituationData: Codable {
    let type: SituationType
    let description: String
    let importance: Double
    let suggestedActions: [String]
    let timestamp: Date
}

struct RelevantContextData: Codable {
    let current: AIContextData
    let temporal: [String: String]
    let environmental: [String: String]
    let conversational: [ConversationTurnData]
    let emotional: EmotionalStateData
    let historicalCount: Int
    let patternCount: Int
}

struct PredictedContextData: Codable {
    let likelyActivities: [String]
    let likelyMood: EmotionType?
    let likelyNeeds: [String]
    let timeframe: String
    let confidence: Double
}

struct ContextInputData: Codable {
    let timestamp: Date
    let location: CoordinateData?
    let conversation: ConversationData?
    let userActivity: String?
}

struct InteractionData: Codable {
    let id: UUID
    let message: String
    let action: InteractionAction
    let context: ConversationContext
    let timestamp: Date
    let responseTime: TimeInterval
    let wasSuccessful: Bool
    let outcome: ConversationOutcome?
}

struct UserFeedbackData: Codable {
    let id: UUID
    let timestamp: Date
    let isPositive: Bool
    let rating: Double?
    let comment: String?
    let context: ConversationContext
}

struct LearningInsightsData: Codable {
    let patternCount: Int
    let preferenceCount: Int
    let behaviorCount: Int
    let adaptationCount: Int
    let confidence: Double
}

struct UserInputData: Codable {
    let message: String
    let timestamp: Date
    let context: ConversationContext?
}

struct AIResponseData: Codable {
    let message: String
    let emotion: EmotionType?
    let confidence: Double
    let suggestedActions: [String]
    let followUpQuestions: [String]
    let processingTime: TimeInterval
}

struct ProactiveMessageData: Codable {
    let content: String
    let trigger: ProactiveTrigger
    let priority: MessagePriority
    let suggestedActions: [String]
}

struct ConversationData: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let messages: [MessageData]
    let context: ConversationContext
    let mood: UserMood?
    let outcome: ConversationOutcome?
}

struct MessageData: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let intent: MessageIntent?
    let emotion: EmotionType?
    let confidence: Double?
}

struct ConversationTurnData: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let intent: MessageIntent?
    let emotion: EmotionType?
}

struct EmotionalStateData: Codable {
    let dominantEmotion: EmotionType
    let intensity: Double
    let trend: EmotionTrend
    
    // Computed property for compatibility
    var emotionIntensity: Double {
        return intensity
    }
}

// MARK: - Basic Location Data

struct LocationData: Codable {
    let coordinate: CoordinateData
    let timestamp: Date
    let accuracy: Double
}

struct CoordinateData: Codable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from clCoordinate: CLLocationCoordinate2D) {
        self.latitude = clCoordinate.latitude
        self.longitude = clCoordinate.longitude
    }
    
    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct TimeRange: Codable {
    let start: String // "HH:mm" format
    let end: String
}

struct Milestone: Codable, Identifiable {
    let id: UUID
    let title: String
    let targetDate: Date?
    let completed: Bool
    let completedDate: Date?
}

// MARK: - Core Enums

enum EmotionType: String, Codable, CaseIterable {
    case joy = "joy"
    case sadness = "sadness"
    case anger = "anger"
    case fear = "fear"
    case surprise = "surprise"
    case disgust = "disgust"
    case trust = "trust"
    case anticipation = "anticipation"
}

enum MemoryType: String, Codable {
    case event = "event"
    case fact = "fact"
    case emotion = "emotion"
    case experience = "experience"
    case achievement = "achievement"
    case lesson = "lesson"
    case quote = "quote"
}

enum MemoryCategory: String, Codable {
    case personal = "personal"
    case work = "work"
    case health = "health"
    case relationship = "relationship"
    case goal = "goal"
    case preference = "preference"
    case fact = "fact"
    case experience = "experience"
    case skill = "skill"
    case routine = "routine"
}

enum MemorySource: String, Codable {
    case userInput = "userInput"
    case observation = "observation"
    case inference = "inference"
    case external = "external"
    case system = "system"
}

enum MemoryPatternType: String, Codable {
    case behavioral = "behavioral"
    case temporal = "temporal"
    case emotional = "emotional"
    case knowledge = "knowledge"
    case association = "association"
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

enum MessageIntent: String, Codable {
    case question = "question"
    case command = "command"
    case statement = "statement"
    case greeting = "greeting"
    case farewell = "farewell"
    case gratitude = "gratitude"
    case feedback = "feedback"
    case clarification = "clarification"
    case confirmation = "confirmation"
    case emotion = "emotion"
}

enum ConversationContext: String, Codable {
    case general = "general"
    case health = "health"
    case work = "work"
    case personal = "personal"
    case learning = "learning"
    case planning = "planning"
    case reflection = "reflection"
    case emergency = "emergency"
}

enum ConversationOutcome: String, Codable {
    case successful = "successful"
    case needsFollowUp = "needsFollowUp"
    case unresolved = "unresolved"
    case redirected = "redirected"
}

enum UserMood: String, Codable {
    case happy = "happy"
    case sad = "sad"
    case stressed = "stressed"
    case anxious = "anxious"
    case excited = "excited"
    case calm = "calm"
    case frustrated = "frustrated"
    case motivated = "motivated"
    case tired = "tired"
    case energetic = "energetic"
}

enum PartOfDay: String, Codable {
    case earlyMorning = "early morning"
    case morning = "morning"
    case midday = "midday"
    case afternoon = "afternoon"
    case evening = "evening"
    case night = "night"
    case lateNight = "late night"
}

enum EnvironmentType: String, Codable {
    case home = "home"
    case work = "work"
    case social = "social"
    case transit = "transit"
    case outdoor = "outdoor"
    case stationary = "stationary"
    case walking = "walking"
    case driving = "driving"
    case unknown = "unknown"
}

enum ConversationMood: String, Codable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
}

enum EmotionTrend: String, Codable {
    case escalating = "escalating"
    case deescalating = "deescalating"
    case stable = "stable"
}

enum SituationType: String, Codable {
    case workFocus = "work_focus"
    case socializing = "socializing"
    case resting = "resting"
    case exercising = "exercising"
    case learning = "learning"
    case problemSolving = "problem_solving"
    case mealTime = "meal_time"
    case planning = "planning"
    case crisis = "crisis"
    case celebration = "celebration"
    case transition = "transition"
    case unknown = "unknown"
}

enum InteractionAction: String, Codable {
    case query = "query"
    case command = "command"
    case feedback = "feedback"
    case conversation = "conversation"
    case unknown = "unknown"
}

enum ProactiveTrigger: String, Codable {
    case timeBased = "timeBased"
    case contextBased = "contextBased"
    case patternBased = "patternBased"
    case eventBased = "eventBased"
}

enum MessagePriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

// AI-related enums
enum AIGender: String, Codable {
    case masculine = "masculine"
    case feminine = "feminine"
    case neutral = "neutral"
    case custom = "custom"
}

enum AIResponseStyle: String, Codable {
    case concise = "concise"
    case detailed = "detailed"
    case creative = "creative"
    case balanced = "balanced"
}

enum AIPersonalityTrait: String, Codable, CaseIterable {
    case friendly = "friendly"
    case helpful = "helpful"
    case encouraging = "encouraging"
    case empathetic = "empathetic"
    case curious = "curious"
    case professional = "professional"
    case humorous = "humorous"
    case patient = "patient"
    case creative = "creative"
    case analytical = "analytical"
}

enum AICapability: String, Codable, CaseIterable {
    case conversation = "conversation"
    case analysis = "analysis"
    case recommendations = "recommendations"
    case scheduling = "scheduling"
    case reminders = "reminders"
    case healthTracking = "healthTracking"
    case emotionalSupport = "emotionalSupport"
    case learning = "learning"
    case creativity = "creativity"
    case problemSolving = "problemSolving"
    
    static var defaultSet: Set<AICapability> {
        Set(Self.allCases)
    }
}

enum AISpecialization: String, Codable {
    case health = "health"
    case productivity = "productivity"
    case finance = "finance"
    case relationships = "relationships"
    case career = "career"
    case education = "education"
    case creativity = "creativity"
    case mindfulness = "mindfulness"
}

// Goal and task related enums
enum GoalCategory: String, Codable {
    case health = "health"
    case career = "career"
    case personal = "personal"
    case financial = "financial"
    case educational = "educational"
    case relationship = "relationship"
    case spiritual = "spiritual"
}

enum GoalStatus: String, Codable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case abandoned = "abandoned"
}

enum Priority: String, Codable {
    case urgent = "urgent"
    case high = "high"
    case medium = "medium"
    case low = "low"
}

enum RoutineType: String, Codable {
    case morning = "morning"
    case evening = "evening"
    case workout = "workout"
    case work = "work"
    case meal = "meal"
    case selfCare = "selfCare"
    case custom = "custom"
}

enum RoutineSchedule: String, Codable {
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case custom = "custom"
}

enum RelationshipType: String, Codable {
    case family = "family"
    case friend = "friend"
    case colleague = "colleague"
    case mentor = "mentor"
    case partner = "partner"
    case acquaintance = "acquaintance"
}

enum FactCategory: String, Codable {
    case personal = "personal"
    case family = "family"
    case work = "work"
    case health = "health"
    case preferences = "preferences"
    case goals = "goals"
    case history = "history"
    case skills = "skills"
}

enum PatternType: String, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case behavioral = "behavioral"
    case emotional = "emotional"
    case productivity = "productivity"
    case health = "health"
    case communication = "communication"
}

enum PatternFrequency: String, Codable {
    case always = "always"
    case often = "often"
    case sometimes = "sometimes"
    case rarely = "rarely"
}

// MARK: - Utility Functions

func detectEmotion(from message: String) -> EmotionType? {
    let lowercased = message.lowercased()
    
    if lowercased.contains("happy") || lowercased.contains("great") || lowercased.contains("awesome") {
        return .joy
    } else if lowercased.contains("sad") || lowercased.contains("disappointed") {
        return .sadness
    } else if lowercased.contains("angry") || lowercased.contains("frustrated") {
        return .anger
    } else if lowercased.contains("worried") || lowercased.contains("anxious") {
        return .fear
    } else {
        return nil
    }
}

func detectIntent(from message: String) -> MessageIntent {
    let lowercased = message.lowercased()
    
    if lowercased.contains("?") || lowercased.starts(with: "what") || lowercased.starts(with: "how") {
        return .question
    } else if lowercased.starts(with: "please") || lowercased.contains("can you") {
        return .command
    } else if lowercased.contains("thanks") || lowercased.contains("thank you") {
        return .gratitude
    } else if lowercased.contains("hi") || lowercased.contains("hello") {
        return .greeting
    } else {
        return .statement
    }
}

func extractTopics(from message: String) -> [String] {
    let words = message.lowercased().split(separator: " ")
    let stopWords = Set(["the", "is", "at", "which", "on", "a", "an", "and", "or", "but"])
    
    return words
        .filter { $0.count > 3 && !stopWords.contains(String($0)) }
        .map { String($0) }
}

func extractEntities(from message: String) -> [String] {
    let words = message.split(separator: " ")
    return words
        .filter { $0.first?.isUppercase == true }
        .map { String($0) }
}

// MARK: - String Similarity Extension

extension String {
    func similarity(to other: String) -> Double {
        let selfSet = Set(self.lowercased().split(separator: " "))
        let otherSet = Set(other.lowercased().split(separator: " "))
        
        let intersection = selfSet.intersection(otherSet)
        let union = selfSet.union(otherSet)
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
}
