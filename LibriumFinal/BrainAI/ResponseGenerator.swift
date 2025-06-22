//
//  ResponseGenerator.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation

// MARK: - Response Generator (Implements ResponseProvider)
class ResponseGenerator: ObservableObject, ResponseProvider {
    private let contextProvider: ContextProvider
    private let memoryProvider: MemoryProvider
    private let learningProvider: LearningProvider
    private let dataProvider: DataProvider
    
    // Response components
    private let contentBuilder: ContentBuilder
    private let personalityEngine: PersonalityEngine
    private let emotionalIntelligence: EmotionalIntelligence
    private let languageProcessor: LanguageProcessor
    
    // Current AI configuration
    private var currentAIPersonality: AIPersonalityData?
    private var currentResponseStyle: AIResponseStyle = .balanced
    
    init(
        contextProvider: ContextProvider,
        memoryProvider: MemoryProvider,
        learningProvider: LearningProvider,
        dataProvider: DataProvider
    ) {
        self.contextProvider = contextProvider
        self.memoryProvider = memoryProvider
        self.learningProvider = learningProvider
        self.dataProvider = dataProvider
        
        self.contentBuilder = ContentBuilder()
        self.personalityEngine = PersonalityEngine()
        self.emotionalIntelligence = EmotionalIntelligence()
        self.languageProcessor = LanguageProcessor()
        
        // Load AI configuration
        Task {
            await loadAIConfiguration()
        }
    }
    
    // MARK: - ResponseProvider Protocol Implementation
    
    func generateResponse(to input: UserInputData) async -> AIResponseData {
        let startTime = Date()
        
        // 1. Analyze input
        let analysis = analyzeInput(input)
        
        // 2. Get relevant context
        let context = contextProvider.getRelevantContext(for: input.message)
        
        // 3. Retrieve relevant memories
        let memories = memoryProvider.retrieve(
            query: input.message,
            context: MemoryContextData(
                timestamp: Date(),
                location: nil,
                participants: [],
                relatedCategories: [],
                relatedTags: []
            )
        )
        
        // 4. Generate base content
        let content = await generateContent(
            analysis: analysis,
            context: context,
            memories: memories
        )
        
        // 5. Apply personality
        let personalizedContent = personalityEngine.applyPersonality(
            to: content,
            personality: currentAIPersonality ?? AIPersonalityData(),
            context: context.current
        )
        
        // 6. Add emotional intelligence
        let emotionallyAwareContent = emotionalIntelligence.enhance(
            content: personalizedContent,
            userEmotion: analysis.emotion,
            emotionalState: context.emotional
        )
        
        // 7. Format and finalize
        let finalResponse = formatResponse(
            content: emotionallyAwareContent,
            analysis: analysis,
            context: context,
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        // 8. Learn from this interaction
        recordInteraction(input: input, response: finalResponse, analysis: analysis)
        
        return finalResponse
    }
    
    func generateProactiveMessage(context: AIContextData) async -> ProactiveMessageData? {
        // Check if proactive message is appropriate
        guard shouldGenerateProactiveMessage(context) else { return nil }
        
        // Predict user needs
        let predictedContext = contextProvider.predictNextContext()
        
        // Generate helpful message
        let content = await generateProactiveContent(
            current: context,
            predicted: predictedContext
        )
        
        // Apply personality
        let personalizedContent = personalityEngine.applyPersonality(
            to: content,
            personality: currentAIPersonality ?? AIPersonalityData(),
            context: context
        )
        
        return ProactiveMessageData(
            content: personalizedContent.mainMessage,
            trigger: determineTrigger(context),
            priority: calculatePriority(context),
            suggestedActions: predictedContext.likelyActivities
        )
    }
    
    // MARK: - Private Methods
    
    private func loadAIConfiguration() async {
        // Load AI assistant data if available
        // This would normally load from saved configuration
        currentAIPersonality = AIPersonalityData()
        currentResponseStyle = .balanced
    }
    
    private func analyzeInput(_ input: UserInputData) -> InputAnalysis {
        let intent = detectIntent(from: input.message)
        let emotion = detectEmotion(from: input.message)
        let entities = extractEntities(from: input.message)
        let topics = extractTopics(from: input.message)
        let urgency = calculateUrgency(input.message, emotion: emotion)
        let questions = extractQuestions(from: input.message)
        
        return InputAnalysis(
            intent: intent,
            emotion: emotion,
            entities: entities,
            topics: topics,
            urgency: urgency,
            questions: questions,
            timestamp: input.timestamp
        )
    }
    
    private func generateContent(
        analysis: InputAnalysis,
        context: RelevantContextData,
        memories: [MemoryItemData]
    ) async -> ResponseContent {
        var content = ResponseContent()
        
        // Handle different intents
        switch analysis.intent {
        case .question:
            content = await handleQuestion(
                questions: analysis.questions,
                context: context,
                memories: memories
            )
            
        case .command:
            content = await handleCommand(
                entities: analysis.entities,
                context: context
            )
            
        case .emotion:
            content = handleEmotionalExpression(
                emotion: analysis.emotion ?? .trust,
                context: context
            )
            
        case .greeting:
            content = generateGreeting(context: context)
            
        case .farewell:
            content = generateFarewell(context: context)
            
        case .gratitude:
            content = handleGratitude(context: context)
            
        case .feedback:
            content = handleFeedback(context: context)
            
        default:
            content = generateConversationalResponse(
                topics: analysis.topics,
                context: context,
                memories: memories
            )
        }
        
        // Add contextual enhancements
        content = enhanceWithContext(content, context: context)
        
        // Add memory-based insights
        if !memories.isEmpty {
            content = enhanceWithMemories(content, memories: memories)
        }
        
        return content
    }
    
    private func handleQuestion(
        questions: [String],
        context: RelevantContextData,
        memories: [MemoryItemData]
    ) async -> ResponseContent {
        var content = ResponseContent()
        
        for question in questions {
            // Search for answer in memories
            let relevantMemories = memories.filter { memory in
                memory.content.lowercased().contains(question.lowercased()) ||
                memory.tags.contains { $0.lowercased().contains(question.lowercased()) }
            }
            
            if !relevantMemories.isEmpty {
                // Found relevant information
                let answer = synthesizeAnswer(
                    from: relevantMemories,
                    question: question
                )
                content.mainMessage += answer + " "
            } else {
                // Generate thoughtful response
                let response = await generateThoughtfulAnswer(
                    question: question,
                    context: context
                )
                content.mainMessage += response + " "
            }
        }
        
        // Add follow-up questions if appropriate
        if shouldAskFollowUp(context: context) {
            content.followUpQuestions = generateFollowUpQuestions(
                originalQuestions: questions,
                context: context
            )
        }
        
        return content
    }
    
    private func handleCommand(
        entities: [String],
        context: RelevantContextData
    ) async -> ResponseContent {
        var content = ResponseContent()
        
        // Process command based on entities
        let commandType = identifyCommandType(entities)
        
        switch commandType {
        case .reminder:
            content.mainMessage = "I'll help you remember that. "
            content.suggestedActions = ["Set specific time", "Add details", "Create recurring reminder"]
            
        case .search:
            content.mainMessage = "Let me find that information for you. "
            content.suggestedActions = ["Refine search", "Show more results", "Save findings"]
            
        case .schedule:
            content.mainMessage = "I'll help you schedule that. "
            content.suggestedActions = ["Pick a time", "Check availability", "Set reminder"]
            
        default:
            content.mainMessage = "I'll help you with that. "
        }
        
        return content
    }
    
    private func handleEmotionalExpression(
        emotion: EmotionType,
        context: RelevantContextData
    ) -> ResponseContent {
        var content = ResponseContent()
        
        // Generate empathetic response
        content.mainMessage = emotionalIntelligence.generateEmpathicResponse(
            userEmotion: emotion,
            emotionalState: context.emotional
        )
        
        // Offer appropriate support
        content.suggestedActions = emotionalIntelligence.getSupportiveSuggestions(
            for: emotion
        )
        
        content.tone = emotionalIntelligence.getAppropiateTone(for: emotion)
        
        return content
    }
    
    private func generateGreeting(context: RelevantContextData) -> ResponseContent {
        var content = ResponseContent()
        
        // Time-appropriate greeting
        let greeting = getTimeBasedGreeting(context.current.temporal.partOfDay)
        content.mainMessage = greeting + " "
        
        // Add personalized touch based on history
        if context.historicalCount > 0 {
            content.mainMessage += "It's good to see you again! "
        }
        
        // Add contextual observation
        if context.current.situational.type != .unknown {
            content.mainMessage += generateSituationalComment(context.current.situational.type)
        }
        
        content.tone = .friendly
        content.suggestedActions = ["How are you feeling?", "What's on your mind?", "Any plans for today?"]
        
        return content
    }
    
    private func generateFarewell(context: RelevantContextData) -> ResponseContent {
        var content = ResponseContent()
        
        // Context-appropriate farewell
        let farewell = getContextualFarewell(context.current.temporal.partOfDay)
        content.mainMessage = farewell + " "
        
        // Add encouragement based on situation
        if context.current.situational.type == .workFocus {
            content.mainMessage += "Good luck with your work! "
        } else if context.current.temporal.partOfDay == .night {
            content.mainMessage += "Sweet dreams! "
        }
        
        content.tone = .warm
        
        return content
    }
    
    private func formatResponse(
        content: ResponseContent,
        analysis: InputAnalysis,
        context: RelevantContextData,
        processingTime: TimeInterval
    ) -> AIResponseData {
        // Apply language processing
        let processedMessage = languageProcessor.process(
            content.mainMessage,
            style: currentResponseStyle,
            tone: content.tone
        )
        
        // Build final response
        return AIResponseData(
            message: processedMessage,
            emotion: determineResponseEmotion(content.tone),
            confidence: calculateResponseConfidence(analysis, context),
            suggestedActions: content.suggestedActions,
            followUpQuestions: content.followUpQuestions,
            processingTime: processingTime
        )
    }
    
    private func shouldGenerateProactiveMessage(_ context: AIContextData) -> Bool {
        // Check personality setting for proactiveness
        guard let personality = currentAIPersonality,
              personality.proactiveness > 0.5 else { return false }
        
        // Check if situation warrants proactive message
        switch context.situational.type {
        case .crisis:
            return true
        case .transition:
            return true
        case .mealTime:
            return context.temporal.partOfDay == .midday
        case .resting:
            return context.temporal.partOfDay == .night
        default:
            return false
        }
    }
    
    private func recordInteraction(input: UserInputData, response: AIResponseData, analysis: InputAnalysis) {
        // Create interaction record
        let interaction = InteractionData(
            id: UUID(),
            message: input.message,
            action: mapIntentToAction(analysis.intent),
            context: input.context ?? .general,
            timestamp: Date(),
            responseTime: response.processingTime,
            wasSuccessful: response.confidence > 0.7,
            outcome: response.confidence > 0.7 ? .successful : .needsFollowUp
        )
        
        // Send to learning engine
        learningProvider.learn(from: interaction)
        
        // Store in memory
        let memoryItem = MemoryItemData(
            id: UUID(),
            type: .experience,
            content: "User: \(input.message)\nAssistant: \(response.message)",
            timestamp: Date(),
            source: .userInput,
            category: .personal,
            tags: analysis.topics,
            importance: analysis.urgency,
            emotions: [analysis.emotion].compactMap { $0 },
            context: nil
        )
        memoryProvider.store(memoryItem)
    }
}

// MARK: - Internal Models

struct InputAnalysis {
    let intent: MessageIntent
    let emotion: EmotionType?
    let entities: [String]
    let topics: [String]
    let urgency: Double
    let questions: [String]
    let timestamp: Date
}

struct ResponseContent {
    var mainMessage: String = ""
    var tone: ResponseTone = .friendly
    var suggestedActions: [String] = []
    var followUpQuestions: [String] = []
}

enum ResponseTone {
    case friendly
    case professional
    case enthusiastic
    case compassionate
    case encouraging
    case calm
    case playful
    case warm
    case supportive
    case reassuring
}

enum CommandType {
    case reminder
    case search
    case schedule
    case unknown
}

// MARK: - Content Builder

class ContentBuilder {
    func build(components: [ContentComponent]) -> String {
        var content = ""
        
        for component in components {
            switch component {
            case .text(let text):
                content += text + " "
            case .emoji(let emoji):
                content += emoji + " "
            case .link(let text, let url):
                content += "[\(text)](\(url)) "
            case .list(let items):
                content += "\n" + items.map { "• \($0)" }.joined(separator: "\n") + "\n"
            case .quote(let quote, let author):
                content += "\n\"\(quote)\"\(author.map { " - \($0)" } ?? "")\n"
            }
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ContentComponent {
    case text(String)
    case emoji(String)
    case link(String, URL)
    case list([String])
    case quote(String, String?)
}

// MARK: - Personality Engine

class PersonalityEngine {
    func applyPersonality(
        to content: ResponseContent,
        personality: AIPersonalityData,
        context: AIContextData
    ) -> ResponseContent {
        var modified = content
        
        // Apply friendliness
        if personality.friendliness > 0.7 {
            modified.mainMessage = addFriendlyTouches(to: modified.mainMessage)
        }
        
        // Apply formality
        if personality.formality > 0.7 {
            modified.mainMessage = increaseFormality(modified.mainMessage)
        } else if personality.formality < 0.3 {
            modified.mainMessage = decreaseFormality(modified.mainMessage)
        }
        
        // Apply humor
        if personality.humor > 0.6 && context.emotional.emotionIntensity < 0.7 {
            modified = addHumor(to: modified, context: context)
        }
        
        // Apply enthusiasm
        if personality.enthusiasm > 0.7 {
            modified.mainMessage = addEnthusiasm(to: modified.mainMessage)
        }
        
        // Apply emoji usage
        if personality.useEmojis {
            modified.mainMessage = addAppropriateEmojis(to: modified.mainMessage, tone: modified.tone)
        }
        
        // Apply question usage
        if personality.useQuestions && modified.followUpQuestions.isEmpty {
            modified.followUpQuestions = generatePersonalityQuestions(
                personality: personality,
                context: context
            )
        }
        
        return modified
    }
    
    private func addFriendlyTouches(to message: String) -> String {
        let friendlyPhrases = [
            "I hope", "I'd love to", "It would be great", "I'm here to help",
            "Feel free to", "I'm happy to", "That's wonderful"
        ]
        
        // Add friendly phrase if not already present
        if !friendlyPhrases.contains(where: { message.contains($0) }) {
            return "I'd love to help! " + message
        }
        
        return message
    }
    
    private func increaseFormality(_ message: String) -> String {
        var formal = message
        
        // Replace casual contractions
        formal = formal.replacingOccurrences(of: "I'm", with: "I am")
        formal = formal.replacingOccurrences(of: "you're", with: "you are")
        formal = formal.replacingOccurrences(of: "let's", with: "let us")
        formal = formal.replacingOccurrences(of: "won't", with: "will not")
        
        return formal
    }
    
    private func decreaseFormality(_ message: String) -> String {
        var casual = message
        
        // Use contractions
        casual = casual.replacingOccurrences(of: "I am", with: "I'm")
        casual = casual.replacingOccurrences(of: "you are", with: "you're")
        casual = casual.replacingOccurrences(of: "let us", with: "let's")
        
        return casual
    }
    
    private func addHumor(to content: ResponseContent, context: AIContextData) -> ResponseContent {
        var modified = content
        
        // Add light humor based on situation
        if context.situational.type == .mealTime {
            modified.mainMessage += " (No pressure, but I hear the early bird gets the best coffee! ☕)"
        } else if context.temporal.partOfDay == .lateNight {
            modified.mainMessage += " (Says the AI who never sleeps! 😄)"
        }
        
        return modified
    }
    
    private func addEnthusiasm(to message: String) -> String {
        // Add exclamation marks where appropriate
        if !message.contains("!") && !message.contains("?") {
            return message.replacingOccurrences(of: ".", with: "!", options: [], range: message.range(of: ".", options: .backwards))
        }
        
        return message
    }
    
    private func addAppropriateEmojis(to message: String, tone: ResponseTone) -> String {
        let emojiMap: [ResponseTone: [String]] = [
            .friendly: ["😊", "🙂", "👋"],
            .professional: ["💼", "📊", "✅"],
            .enthusiastic: ["🎉", "🌟", "✨"],
            .compassionate: ["💙", "🤗", "❤️"],
            .encouraging: ["💪", "🌈", "👍"],
            .calm: ["🌿", "☮️", "🧘"],
            .playful: ["😄", "🎈", "🌺"],
            .warm: ["☀️", "🌸", "😌"],
            .supportive: ["🤝", "💫", "🌻"],
            .reassuring: ["🛡️", "🌅", "💚"]
        ]
        
        if let emojis = emojiMap[tone], !emojis.isEmpty {
            let emoji = emojis.randomElement() ?? ""
            return message + " " + emoji
        }
        
        return message
    }
    
    private func generatePersonalityQuestions(
        personality: AIPersonalityData,
        context: AIContextData
    ) -> [String] {
        var questions: [String] = []
        
        if personality.curiosity > 0.6 {
            questions.append("What's been the highlight of your day so far?")
        }
        
        if personality.empathy > 0.7 {
            questions.append("How are you feeling about everything?")
        }
        
        return questions
    }
}

// MARK: - Emotional Intelligence

class EmotionalIntelligence {
    func enhance(
        content: ResponseContent,
        userEmotion: EmotionType?,
        emotionalState: EmotionalStateData
    ) -> ResponseContent {
        var enhanced = content
        
        // Adjust tone based on user emotion
        if let emotion = userEmotion {
            enhanced.tone = getAppropiateTone(for: emotion)
        }
        
        // Add emotional validation
        if emotionalState.intensity > 0.6 {
            enhanced.mainMessage = addEmotionalValidation(
                to: enhanced.mainMessage,
                emotion: emotionalState.dominantEmotion,
                intensity: emotionalState.intensity
            )
        }
        
        // Adjust response based on emotional trend
        switch emotionalState.trend {
        case .escalating:
            enhanced = addDeescalationTechniques(to: enhanced)
        case .deescalating:
            enhanced = addEncouragement(to: enhanced)
        case .stable:
            break
        }
        
        return enhanced
    }
    
    func generateEmpathicResponse(
        userEmotion: EmotionType,
        emotionalState: EmotionalStateData
    ) -> String {
        switch userEmotion {
        case .joy:
            return "That's wonderful! I'm so happy to hear you're feeling good. Your joy is contagious!"
        case .sadness:
            return "I can sense you're going through a difficult time. It's okay to feel this way, and I'm here to listen."
        case .anger:
            return "I understand you're feeling frustrated. Your feelings are valid, and it's important to express them."
        case .fear:
            return "I hear your concerns. It's natural to feel worried sometimes. Let's work through this together."
        case .surprise:
            return "That must have been unexpected! How are you processing this surprise?"
        case .disgust:
            return "That sounds really unpleasant. I understand why you'd feel that way."
        case .trust:
            return "Thank you for your trust. I'm here to support you however I can."
        case .anticipation:
            return "I can feel your excitement! It's great to have something to look forward to."
        }
    }
    
    func getSupportiveSuggestions(for emotion: EmotionType) -> [String] {
        switch emotion {
        case .sadness:
            return ["Talk about what's bothering you", "Try a mood-boosting activity", "Practice self-care"]
        case .anger:
            return ["Take deep breaths", "Go for a walk", "Express your feelings safely"]
        case .fear:
            return ["Focus on facts", "Practice grounding techniques", "Talk through your concerns"]
        case .joy:
            return ["Celebrate your happiness", "Share with others", "Capture this moment"]
        default:
            return ["I'm here to listen", "Take your time", "You're not alone"]
        }
    }
    
    func getAppropiateTone(for emotion: EmotionType) -> ResponseTone {
        switch emotion {
        case .joy, .anticipation:
            return .enthusiastic
        case .sadness:
            return .compassionate
        case .anger:
            return .calm
        case .fear:
            return .reassuring
        case .trust:
            return .warm
        default:
            return .supportive
        }
    }
    
    private func addEmotionalValidation(
        to message: String,
        emotion: EmotionType,
        intensity: Double
    ) -> String {
        let validation: String
        
        if intensity > 0.8 {
            validation = "I can really feel how strongly you're experiencing this. "
        } else if intensity > 0.5 {
            validation = "I understand you're feeling \(emotion.rawValue). "
        } else {
            validation = "I sense you might be feeling \(emotion.rawValue). "
        }
        
        return validation + message
    }
    
    private func addDeescalationTechniques(to content: ResponseContent) -> ResponseContent {
        var modified = content
        
        modified.suggestedActions.insert("Take a few deep breaths", at: 0)
        modified.suggestedActions.insert("Let's pause for a moment", at: 1)
        
        return modified
    }
    
    private func addEncouragement(to content: ResponseContent) -> ResponseContent {
        var modified = content
        
        modified.mainMessage += " You're making progress, and that's something to be proud of."
        
        return modified
    }
}

// MARK: - Language Processor

class LanguageProcessor {
    func process(_ message: String, style: AIResponseStyle, tone: ResponseTone) -> String {
        var processed = message
        
        // Apply style modifications
        switch style {
        case .concise:
            processed = makeConcise(processed)
        case .detailed:
            processed = makeDetailed(processed)
        case .creative:
            processed = makeCreative(processed, tone: tone)
        case .balanced:
            // Keep as is
            break
        }
        
        // Clean up formatting
        processed = cleanupFormatting(processed)
        
        return processed
    }
    
    private func makeConcise(_ message: String) -> String {
        // Remove filler words
        var concise = message
        let fillers = ["actually", "basically", "really", "very", "quite", "just", "simply"]
        
        for filler in fillers {
            concise = concise.replacingOccurrences(of: " \(filler) ", with: " ")
        }
        
        // Shorten sentences
        let sentences = concise.components(separatedBy: ". ")
        if sentences.count > 3 {
            concise = sentences.prefix(3).joined(separator: ". ") + "."
        }
        
        return concise
    }
    
    private func makeDetailed(_ message: String) -> String {
        // Add clarifying phrases
        var detailed = message
        
        if !detailed.contains("specifically") && !detailed.contains("particularly") {
            detailed = detailed.replacingOccurrences(
                of: "This ",
                with: "Specifically, this ",
                options: [],
                range: detailed.range(of: "This ")
            )
        }
        
        return detailed
    }
    
    private func makeCreative(_ message: String, tone: ResponseTone) -> String {
        // Add creative elements based on tone
        var creative = message
        
        switch tone {
        case .playful:
            creative = addPlayfulElements(to: creative)
        case .enthusiastic:
            creative = addEnthusiasticElements(to: creative)
        default:
            creative = addCreativeMetaphors(to: creative)
        }
        
        return creative
    }
    
    private func addPlayfulElements(to message: String) -> String {
        let playfulPhrases = [
            "Here's a fun thought:",
            "Picture this:",
            "Imagine if",
            "What if we"
        ]
        
        if let phrase = playfulPhrases.randomElement() {
            return phrase + " " + message.lowercased()
        }
        
        return message
    }
    
    private func addEnthusiasticElements(to message: String) -> String {
        let enthusiasticWords = [
            "amazing", "fantastic", "incredible", "wonderful", "brilliant"
        ]
        
        // Add enthusiastic word if not present
        if !enthusiasticWords.contains(where: { message.contains($0) }) {
            if let word = enthusiasticWords.randomElement() {
                return message.replacingOccurrences(
                    of: "good",
                    with: word,
                    options: [.caseInsensitive]
                )
            }
        }
        
        return message
    }
    
    private func addCreativeMetaphors(to message: String) -> String {
        // Simple metaphor addition
        if message.contains("progress") {
            return message.replacingOccurrences(
                of: "progress",
                with: "progress (like climbing a mountain, one step at a time)"
            )
        }
        
        return message
    }
    
    private func cleanupFormatting(_ message: String) -> String {
        var cleaned = message
        
        // Remove extra spaces
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        // Ensure proper sentence ending
        if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
            cleaned += "."
        }
        
        // Capitalize first letter
        if let first = cleaned.first, first.isLowercase {
            cleaned = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        }
        
        return cleaned
    }
}

// MARK: - Helper Functions

private func synthesizeAnswer(from memories: [MemoryItemData], question: String) -> String {
    // Combine relevant information from memories
    let relevantInfo = memories
        .sorted { $0.importance > $1.importance }
        .prefix(3)
        .map { $0.content }
        .joined(separator: " ")
    
    return "Based on what I remember, " + relevantInfo
}

private func generateThoughtfulAnswer(question: String, context: RelevantContextData) async -> String {
    // Generate answer based on context and patterns
    if question.lowercased().contains("how") {
        return "Here's how I would approach that: Consider your current situation and what's worked for you before."
    } else if question.lowercased().contains("why") {
        return "That's a thoughtful question. The reason might be related to your recent patterns and experiences."
    } else if question.lowercased().contains("what") {
        return "From what I understand about your situation, I'd suggest focusing on what matters most to you right now."
    } else {
        return "That's an interesting question. Let me think about that in the context of what I know about you."
    }
}

private func shouldAskFollowUp(context: RelevantContextData) -> Bool {
    // Ask follow-up if conversation is engaged and not overwhelming
    return context.conversational.count < 5 && context.emotional.intensity < 0.8
}

private func generateFollowUpQuestions(
    originalQuestions: [String],
    context: RelevantContextData
) -> [String] {
    var followUps: [String] = []
    
    for question in originalQuestions {
        if question.contains("feel") {
            followUps.append("What would help you feel better?")
        } else if question.contains("think") {
            followUps.append("What alternatives have you considered?")
        } else if question.contains("do") {
            followUps.append("What's your ideal outcome?")
        }
    }
    
    return Array(followUps.prefix(2))
}

private func identifyCommandType(_ entities: [String]) -> CommandType {
    let entityString = entities.joined(separator: " ").lowercased()
    
    if entityString.contains("remind") || entityString.contains("remember") {
        return .reminder
    } else if entityString.contains("find") || entityString.contains("search") {
        return .search
    } else if entityString.contains("schedule") || entityString.contains("calendar") {
        return .schedule
    } else {
        return .unknown
    }
}

private func extractQuestions(from message: String) -> [String] {
    // Split by question marks and filter
    let questions = message.components(separatedBy: "?")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { $0 + "?" }
    
    return questions
}

private func calculateUrgency(_ message: String, emotion: EmotionType?) -> Double {
    var urgency = 0.5
    
    // Check for urgent keywords
    let urgentWords = ["urgent", "emergency", "immediately", "asap", "now", "help", "crisis"]
    for word in urgentWords {
        if message.lowercased().contains(word) {
            urgency += 0.3
            break
        }
    }
    
    // Check emotion
    if let emotion = emotion {
        switch emotion {
        case .fear, .anger:
            urgency += 0.2
        case .sadness:
            urgency += 0.1
        default:
            break
        }
    }
    
    // Check punctuation
    if message.contains("!!!") || message.contains("???") {
        urgency += 0.1
    }
    
    return min(1.0, urgency)
}

private func enhanceWithContext(_ content: ResponseContent, context: RelevantContextData) -> ResponseContent {
    var enhanced = content
    
    // Add temporal context
    if context.current.temporal.partOfDay == .morning {
        enhanced.mainMessage = "Good morning! " + enhanced.mainMessage
    } else if context.current.temporal.partOfDay == .night {
        enhanced.mainMessage = enhanced.mainMessage + " Have a restful evening!"
    }
    
    // Add situational awareness
    if context.current.situational.type == .workFocus {
        enhanced.suggestedActions.append("Take a break when you need it")
    }
    
    return enhanced
}

private func enhanceWithMemories(_ content: ResponseContent, memories: [MemoryItemData]) -> ResponseContent {
    var enhanced = content
    
    // Add relevant memory reference
    if let relevantMemory = memories.first(where: { $0.importance > 0.7 }) {
        enhanced.mainMessage += " (This reminds me of when you mentioned something similar before.)"
    }
    
    return enhanced
}

private func getTimeBasedGreeting(_ partOfDay: PartOfDay) -> String {
    switch partOfDay {
    case .earlyMorning:
        return "Good early morning! You're up early"
    case .morning:
        return "Good morning! Hope you're having a great start to your day"
    case .midday:
        return "Good afternoon! How's your day going"
    case .afternoon:
        return "Good afternoon! Hope you're having a productive day"
    case .evening:
        return "Good evening! How was your day"
    case .night:
        return "Good evening! Winding down for the night"
    case .lateNight:
        return "Hi there! Burning the midnight oil"
    }
}

private func generateSituationalComment(_ situation: SituationType) -> String {
    switch situation {
    case .workFocus:
        return "I see you're in work mode. "
    case .socializing:
        return "Enjoying some social time? "
    case .resting:
        return "Taking some well-deserved rest. "
    case .exercising:
        return "Great job staying active! "
    case .learning:
        return "Love the dedication to learning! "
    case .mealTime:
        return "Hope you're enjoying your meal. "
    default:
        return ""
    }
}

private func getContextualFarewell(_ partOfDay: PartOfDay) -> String {
    switch partOfDay {
    case .earlyMorning, .morning:
        return "Have a wonderful day ahead!"
    case .midday, .afternoon:
        return "Enjoy the rest of your day!"
    case .evening:
        return "Have a lovely evening!"
    case .night, .lateNight:
        return "Sleep well and sweet dreams!"
    }
}

private func handleGratitude(context: RelevantContextData) -> ResponseContent {
    var content = ResponseContent()
    
    content.mainMessage = "You're very welcome! It's my pleasure to help you."
    content.tone = .warm
    
    // Add personalized touch based on relationship
    if context.emotional.intensity > 0.6 {
        content.mainMessage += " Your gratitude means a lot to me."
    }
    
    return content
}

private func handleFeedback(context: RelevantContextData) -> ResponseContent {
    var content = ResponseContent()
    
    content.mainMessage = "Thank you for your feedback! I'm always learning and improving."
    content.tone = .professional
    content.followUpQuestions = ["Is there anything specific I could do better?"]
    
    return content
}

private func generateConversationalResponse(
    topics: [String],
    context: RelevantContextData,
    memories: [MemoryItemData]
) -> ResponseContent {
    var content = ResponseContent()
    
    // Build response based on topics
    if !topics.isEmpty {
        content.mainMessage = "I understand you're interested in \(topics.joined(separator: " and ")). "
        
        // Add relevant insights from memories
        let relevantMemories = memories.filter { memory in
            topics.contains { topic in memory.content.lowercased().contains(topic.lowercased()) }
        }
        
        if !relevantMemories.isEmpty {
            content.mainMessage += "Based on our previous conversations, I know this is important to you."
        }
    } else {
        content.mainMessage = "I'm here and listening. Tell me more about what's on your mind."
    }
    
    content.tone = .supportive
    
    return content
}

private func determineResponseEmotion(_ tone: ResponseTone) -> EmotionType {
    switch tone {
    case .enthusiastic, .playful:
        return .joy
    case .compassionate:
        return .trust
    case .calm, .reassuring:
        return .trust
    default:
        return .trust
    }
}

private func calculateResponseConfidence(_ analysis: InputAnalysis, _ context: RelevantContextData) -> Double {
    var confidence = 0.7 // Base confidence
    
    // Increase confidence if we have relevant context
    if context.historicalCount > 0 {
        confidence += 0.1
    }
    
    // Increase confidence if intent is clear
    if analysis.intent != .statement {
        confidence += 0.1
    }
    
    // Decrease confidence if urgency is high (more careful)
    if analysis.urgency > 0.8 {
        confidence -= 0.1
    }
    
    return min(1.0, max(0.0, confidence))
}

private func mapIntentToAction(_ intent: MessageIntent) -> InteractionAction {
    switch intent {
    case .question:
        return .query
    case .command:
        return .command
    case .feedback:
        return .feedback
    default:
        return .conversation
    }
}

private func determineTrigger(_ context: AIContextData) -> ProactiveTrigger {
    if context.situational.type == .transition {
        return .contextBased
    } else if context.temporal.partOfDay == .morning {
        return .timeBased
    } else {
        return .patternBased
    }
}

private func calculatePriority(_ context: AIContextData) -> MessagePriority {
    if context.situational.importance > 0.8 {
        return .urgent
    } else if context.situational.importance > 0.6 {
        return .high
    } else if context.situational.importance > 0.4 {
        return .medium
    } else {
        return .low
    }
}

private func generateProactiveContent(
    current: AIContextData,
    predicted: PredictedContextData
) async -> ResponseContent {
    var content = ResponseContent()
    
    // Generate helpful proactive message
    switch current.situational.type {
    case .transition:
        content.mainMessage = "I noticed you're transitioning between activities. "
        content.mainMessage += "Based on your patterns, you might want to \(predicted.likelyActivities.first ?? "take a moment to plan")."
        content.suggestedActions = predicted.likelyActivities
        
    case .mealTime:
        content.mainMessage = "It's lunchtime! Don't forget to take a break and nourish yourself."
        content.suggestedActions = ["Set a lunch reminder", "Find nearby restaurants", "View healthy recipes"]
        
    case .crisis:
        content.mainMessage = "I'm here if you need support. Remember, it's okay to take things one step at a time."
        content.suggestedActions = ["Talk through what's happening", "Try a calming exercise", "Contact someone you trust"]
        content.tone = .compassionate
        
    default:
        content.mainMessage = "Just checking in! Hope everything is going well."
    }
    
    return content
}
