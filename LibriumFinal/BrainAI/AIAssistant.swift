//
//  AIAssistant.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation

// MARK: - AI Assistant Model
struct AIAssistant: Codable, Identifiable {
    let id: UUID
    var name: String
    var gender: AIGender
    var avatarEmoji: String
    var primaryColor: String // Hex color
    var voiceId: String?
    
    // Personality
    var personality: AIPersonality
    var traits: Set<AIPersonalityTrait>
    var responseStyle: AIResponseStyle
    
    // Learning State
    var knowledgeBase: AIKnowledgeBase
    var conversationHistory: [Conversation]
    var learningState: AILearningState
    
    // Capabilities
    var enabledCapabilities: Set<AICapability>
    var specializations: Set<AISpecialization>
    
    // Metadata
    let createdAt: Date
    var lastInteractionAt: Date
    var totalInteractions: Int
    var trustLevel: Double // 0.0 to 1.0
    
    init(name: String = "Maria", gender: AIGender = .feminine) {
        self.id = UUID()
        self.name = name
        self.gender = gender
        self.avatarEmoji = "🤖"
        self.primaryColor = "#FF5722"
        self.personality = AIPersonality()
        self.traits = [.friendly, .helpful, .encouraging]
        self.responseStyle = .balanced
        self.knowledgeBase = AIKnowledgeBase()
        self.conversationHistory = []
        self.learningState = AILearningState()
        self.enabledCapabilities = AICapability.defaultSet
        self.specializations = []
        self.createdAt = Date()
        self.lastInteractionAt = Date()
        self.totalInteractions = 0
        self.trustLevel = 0.5
    }
}

// MARK: - AI Personality
struct AIPersonality: Codable {
    var friendliness: Double = 0.8 // 0.0 to 1.0
    var formality: Double = 0.5
    var humor: Double = 0.3
    var empathy: Double = 0.9
    var enthusiasm: Double = 0.7
    var patience: Double = 0.9
    var curiosity: Double = 0.6
    var creativity: Double = 0.7
    
    // Response modifiers
    var useEmojis: Bool = true
    var useExclamations: Bool = true
    var useQuestions: Bool = true
    var usePersonalPronouns: Bool = true
    
    // Behavioral traits
    var proactiveness: Double = 0.6 // How often AI suggests things
    var assertiveness: Double = 0.4 // How strongly AI makes recommendations
    var adaptability: Double = 0.8 // How quickly AI adjusts to user preferences
}

// MARK: - AI Knowledge Base
struct AIKnowledgeBase: Codable {
    var userFacts: [String: UserFact] = [:]
    var preferences: [String: Preference] = [:]
    var patterns: [BehaviorPattern] = []
    var relationships: [Relationship] = []
    var goals: [Goal] = []
    var routines: [Routine] = []
    var memories: [Memory] = []
    
    mutating func addFact(_ fact: UserFact) {
        userFacts[fact.id.uuidString] = fact
    }
    
    mutating func addPreference(_ preference: Preference) {
        preferences[preference.category] = preference
    }
    
    mutating func addPattern(_ pattern: BehaviorPattern) {
        patterns.append(pattern)
        // Keep only most recent 100 patterns
        if patterns.count > 100 {
            patterns = Array(patterns.suffix(100))
        }
    }
}

// MARK: - User Fact
struct UserFact: Codable, Identifiable {
    let id: UUID
    let category: FactCategory
    let fact: String
    let confidence: Double // 0.0 to 1.0
    let source: String // Where this fact came from
    let createdAt: Date
    var lastConfirmedAt: Date
    var mentions: Int // How many times mentioned
    
    init(category: FactCategory, fact: String, source: String, confidence: Double = 0.8) {
        self.id = UUID()
        self.category = category
        self.fact = fact
        self.source = source
        self.confidence = confidence
        self.createdAt = Date()
        self.lastConfirmedAt = Date()
        self.mentions = 1
    }
}

// MARK: - Preference
struct Preference: Codable {
    let category: String
    var likes: Set<String> = []
    var dislikes: Set<String> = []
    var neutrals: Set<String> = []
    let createdAt: Date
    var lastUpdatedAt: Date
    
    init(category: String) {
        self.category = category
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
    }
}

// MARK: - Behavior Pattern
struct BehaviorPattern: Codable, Identifiable {
    let id: UUID
    let type: PatternType
    let description: String
    let frequency: PatternFrequency
    let timeOfDay: TimeRange?
    let dayOfWeek: Set<Int>? // 1 = Sunday, 7 = Saturday
    let triggers: [String]
    let confidence: Double
    let firstObserved: Date
    let lastObserved: Date
    var occurrences: Int
    
    init(type: PatternType, description: String, frequency: PatternFrequency) {
        self.id = UUID()
        self.type = type
        self.description = description
        self.frequency = frequency
        self.confidence = 0.5
        self.firstObserved = Date()
        self.lastObserved = Date()
        self.occurrences = 1
        self.triggers = []
        self.timeOfDay = nil
        self.dayOfWeek = nil
    }
}

// MARK: - Conversation
struct Conversation: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let messages: [Message]
    let context: ConversationContext
    let mood: UserMood?
    let outcome: ConversationOutcome?
    
    init(context: ConversationContext) {
        self.id = UUID()
        self.timestamp = Date()
        self.messages = []
        self.context = context
        self.mood = nil
        self.outcome = nil
    }
}

// MARK: - Message
struct Message: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let intent: MessageIntent?
    let emotion: EmotionType?
    let confidence: Double?
    
    init(role: MessageRole, content: String, intent: MessageIntent? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.intent = intent
        self.emotion = nil
        self.confidence = nil
    }
}

// MARK: - AI Learning State
struct AILearningState: Codable {
    var totalConversations: Int = 0
    var successfulInteractions: Int = 0
    var failedInteractions: Int = 0
    var averageResponseTime: Double = 0.0
    var averageSatisfaction: Double = 0.0
    var topTopics: [String: Int] = [:]
    var commonIntents: [MessageIntent: Int] = [:]
    var adaptationLevel: Double = 0.0 // How well AI has adapted to user
    var lastTrainingDate: Date?
    
    mutating func recordInteraction(successful: Bool, responseTime: Double) {
        totalConversations += 1
        if successful {
            successfulInteractions += 1
        } else {
            failedInteractions += 1
        }
        
        // Update average response time
        let totalResponseTime = averageResponseTime * Double(totalConversations - 1) + responseTime
        averageResponseTime = totalResponseTime / Double(totalConversations)
    }
}

// MARK: - Supporting Types
struct Memory: Codable, Identifiable {
    let id: UUID
    let type: MemoryType
    let content: String
    let emotionalWeight: Double // -1.0 (negative) to 1.0 (positive)
    let importance: Double // 0.0 to 1.0
    let createdAt: Date
    var accessCount: Int
    var lastAccessedAt: Date
    
    init(type: MemoryType, content: String, emotionalWeight: Double = 0.0, importance: Double = 0.5) {
        self.id = UUID()
        self.type = type
        self.content = content
        self.emotionalWeight = emotionalWeight
        self.importance = importance
        self.createdAt = Date()
        self.accessCount = 0
        self.lastAccessedAt = Date()
    }
}

struct Relationship: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: RelationshipType
    let importance: Double
    let notes: [String]
    let firstMentioned: Date
    var lastMentioned: Date
    var mentionCount: Int
    
    init(name: String, type: RelationshipType, importance: Double = 0.5) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.importance = importance
        self.notes = []
        self.firstMentioned = Date()
        self.lastMentioned = Date()
        self.mentionCount = 1
    }
}

struct Goal: Codable, Identifiable {
    let id: UUID
    let title: String
    let category: GoalCategory
    let priority: Priority
    let deadline: Date?
    let milestones: [Milestone]
    let createdAt: Date
    var progress: Double // 0.0 to 1.0
    var status: GoalStatus
    
    init(title: String, category: GoalCategory, priority: Priority = .medium, deadline: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.priority = priority
        self.deadline = deadline
        self.milestones = []
        self.createdAt = Date()
        self.progress = 0.0
        self.status = .active
    }
}

struct Routine: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: RoutineType
    let schedule: RoutineSchedule
    let activities: [String]
    let duration: TimeInterval
    let importance: Double
    var adherence: Double // 0.0 to 1.0
    
    init(name: String, type: RoutineType, schedule: RoutineSchedule, activities: [String], duration: TimeInterval, importance: Double = 0.5) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.schedule = schedule
        self.activities = activities
        self.duration = duration
        self.importance = importance
        self.adherence = 0.0
    }
}
