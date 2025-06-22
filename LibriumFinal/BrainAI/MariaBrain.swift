//
//  MariaBrain.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation

// MARK: - Maria's Complete Brain with Chat History
class MariaBrain: ObservableObject {
    // Published properties for UI binding
    @Published var isReady = false
    @Published var currentUser: UserData?
    @Published var currentAssistant: AIAssistantData?
    @Published var lastResponse: AIResponseData?
    @Published var chatHistory: [ChatMessage] = []
    @Published var isSearchingHistory = false
    @Published var searchResults: [ChatMessage] = []
    
    // Core components
    private let dataManager: DataManager
    private let memorySystem: MemorySystem
    private let learningEngine: LearningEngine
    private let contextEngine: ContextEngine
    private let responseGenerator: ResponseGenerator
    private let chatHistoryManager: ChatHistoryManager
    let commandSystem: AICommandSystem // Made public for extension access
    
    // Singleton instance
    static let shared = MariaBrain()
    
    private init() {
        // Initialize data layer
        self.dataManager = DataManager.shared
        
        // Initialize memory system
        self.memorySystem = MemorySystem()
        
        // Initialize learning engine with memory system
        self.learningEngine = LearningEngine(memoryProvider: memorySystem)
        
        // Initialize context engine with dependencies
        self.contextEngine = ContextEngine(
            memoryProvider: memorySystem,
            learningProvider: learningEngine
        )
        
        // Initialize response generator with all dependencies
        self.responseGenerator = ResponseGenerator(
            contextProvider: contextEngine,
            memoryProvider: memorySystem,
            learningProvider: learningEngine,
            dataProvider: dataManager
        )
        
        // Initialize chat history manager
        self.chatHistoryManager = ChatHistoryManager(dataManager: dataManager)
        
        // Initialize command system
        self.commandSystem = AICommandSystem()
        
        setupBrain()
    }
    
    // MARK: - Public Interface
    
    /// Process user input and generate response
    func processInput(_ message: String) async -> String {
        // Check if message contains a command
        if let command = CommandParser.parse(message) {
            // Execute command
            let commandResult = await commandSystem.execute(command)
            
            // Store command interaction in chat history
            let userMessage = ChatMessage(
                id: UUID(),
                role: .user,
                content: message,
                timestamp: Date(),
                estimatedTokens: estimateTokenCount(message),
                hasAttachments: false,
                metadata: MessageMetadata(
                    intent: .command,
                    emotion: nil,
                    topics: ["command"],
                    context: .general
                )
            )
            
            let assistantMessage = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: commandResult.message,
                timestamp: Date(),
                estimatedTokens: estimateTokenCount(commandResult.message),
                hasAttachments: false,
                metadata: MessageMetadata(
                    intent: nil,
                    emotion: commandResult.success ? .trust : .surprise,
                    topics: ["command_response"],
                    context: .general
                )
            )
            
            // Store both messages
            await chatHistoryManager.storeMessage(userMessage)
            await chatHistoryManager.storeMessage(assistantMessage)
            
            // Update UI
            await MainActor.run {
                self.chatHistory.append(userMessage)
                self.chatHistory.append(assistantMessage)
            }
            
            return commandResult.message
        }
        
        // Continue with normal chat processing if not a command
        // Create and store user message in chat history
        let userMessage = ChatMessage(
            id: UUID(),
            role: .user,
            content: message,
            timestamp: Date(),
            estimatedTokens: estimateTokenCount(message),
            hasAttachments: false,
            metadata: MessageMetadata(
                intent: detectIntent(from: message),
                emotion: detectEmotion(from: message),
                topics: extractTopics(from: message),
                context: determineContext(from: message)
            )
        )
        
        // Store user message
        await chatHistoryManager.storeMessage(userMessage)
        
        // Add to local chat history for UI
        await MainActor.run {
            self.chatHistory.append(userMessage)
        }
        
        // Create input data
        let input = UserInputData(
            message: message,
            timestamp: Date(),
            context: userMessage.metadata.context
        )
        
        // Update context with the new input
        contextEngine.updateContext(with: ContextInputData(
            timestamp: Date(),
            location: nil, // Could get from device
            conversation: ConversationData(
                id: UUID(),
                timestamp: Date(),
                messages: [
                    MessageData(
                        id: userMessage.id,
                        role: .user,
                        content: message,
                        timestamp: Date(),
                        intent: userMessage.metadata.intent,
                        emotion: userMessage.metadata.emotion,
                        confidence: 1.0
                    )
                ],
                context: input.context ?? .general,
                mood: nil,
                outcome: nil
            ),
            userActivity: nil
        ))
        
        // Generate response
        let response = await responseGenerator.generateResponse(to: input)
        
        // Store response for UI
        await MainActor.run {
            self.lastResponse = response
        }
        
        // Create and store assistant message in chat history
        let assistantMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: response.message,
            timestamp: Date(),
            estimatedTokens: estimateTokenCount(response.message),
            hasAttachments: false,
            metadata: MessageMetadata(
                intent: nil,
                emotion: response.emotion,
                topics: extractTopics(from: response.message),
                context: input.context
            )
        )
        
        // Store assistant message
        do {
            try await chatHistoryManager.storeMessage(assistantMessage)
        } catch {
            print("Error storing assistant message: \(error)")
        }
        
        // Add to local chat history for UI
        await MainActor.run {
            self.chatHistory.append(assistantMessage)
        }
        
        // Update context with assistant's response
        contextEngine.updateContext(with: ContextInputData(
            timestamp: Date(),
            location: nil,
            conversation: ConversationData(
                id: UUID(),
                timestamp: Date(),
                messages: [
                    MessageData(
                        id: assistantMessage.id,
                        role: .assistant,
                        content: response.message,
                        timestamp: Date(),
                        intent: nil,
                        emotion: response.emotion,
                        confidence: response.confidence
                    )
                ],
                context: input.context ?? .general,
                mood: nil,
                outcome: nil
            ),
            userActivity: nil
        ))
        
        return response.message
    }
    
    /// Search chat history
    func searchChatHistory(query: String, dateRange: DateRange? = nil, limit: Int = 50) async -> [ChatMessage] {
        await MainActor.run {
            self.isSearchingHistory = true
        }
        
        do {
            let results = try await chatHistoryManager.search(
                query: query,
                dateRange: dateRange,
                limit: limit
            )
            
            await MainActor.run {
                self.searchResults = results
                self.isSearchingHistory = false
            }
            
            return results
        } catch {
            print("Error searching chat history: \(error)")
            await MainActor.run {
                self.isSearchingHistory = false
            }
            return []
        }
    }
    
    /// Get conversation for a specific date
    func getConversation(for date: Date) async -> [ChatMessage] {
        do {
            return try await chatHistoryManager.getConversation(for: date)
        } catch {
            print("Error getting conversation: \(error)")
            return []
        }
    }
    
    /// Export chat history
    func exportChatHistory(from startDate: Date, to endDate: Date) async -> URL? {
        do {
            return try await chatHistoryManager.exportChatHistory(from: startDate, to: endDate)
        } catch {
            print("Error exporting chat history: \(error)")
            return nil
        }
    }
    
    /// Get chat storage statistics
    func getChatStorageStats() async -> ChatStorageStats? {
        do {
            return try await chatHistoryManager.getStorageStats()
        } catch {
            print("Error getting storage stats: \(error)")
            return nil
        }
    }
    
    /// Load recent chat history for UI
    func loadRecentChatHistory(limit: Int = 100) async {
        do {
            let recent = try await chatHistoryManager.search(
                query: "",
                dateRange: nil,
                limit: limit
            )
            
            await MainActor.run {
                self.chatHistory = recent.reversed() // Show oldest first
            }
        } catch {
            print("Error loading recent chat history: \(error)")
        }
    }
    
    /// Get proactive message if appropriate
    func getProactiveMessage() async -> ProactiveMessageData? {
        let currentContext = contextEngine.getCurrentContext()
        return await responseGenerator.generateProactiveMessage(context: currentContext)
    }
    
    /// Create or load user
    func setupUser(firstName: String, lastName: String, email: String) async {
        do {
            let userData = UserData(
                id: UUID(),
                firstName: firstName,
                lastName: lastName,
                email: email,
                phoneNumber: nil,
                preferences: UserPreferencesData(),
                privacySettings: PrivacySettingsData(),
                enabledHubs: Set([.life]),
                createdAt: Date(),
                lastActiveAt: Date()
            )
            
            let user = try await dataManager.createUser(userData)
            
            await MainActor.run {
                self.currentUser = user
            }
            
            // Create AI assistant for user
            await setupAssistant(for: user)
            
            // Load recent chat history
            await loadRecentChatHistory()
            
        } catch {
            print("Error setting up user: \(error)")
        }
    }
    
    /// Load existing user
    func loadUser(id: UUID) async {
        do {
            if let user = try await dataManager.loadUser(id: id) {
                await MainActor.run {
                    self.currentUser = user
                }
                
                // Load recent chat history
                await loadRecentChatHistory()
                
                await MainActor.run {
                    self.isReady = true
                }
            }
        } catch {
            print("Error loading user: \(error)")
        }
    }
    
    /// Provide feedback on last response
    func provideFeedback(isPositive: Bool, comment: String? = nil) {
        guard let lastResponse = lastResponse else { return }
        
        let feedback = UserFeedbackData(
            id: UUID(),
            timestamp: Date(),
            isPositive: isPositive,
            rating: isPositive ? 5.0 : 2.0,
            comment: comment,
            context: .general
        )
        
        learningEngine.processFeedback(feedback)
    }
    
    /// Consolidate memories and learn patterns
    func performMaintenance() {
        memorySystem.consolidate()
        
        // Also perform chat history maintenance
        Task {
            // This could archive old messages, build search indices, etc.
           try await chatHistoryManager.buildSearchIndex()
        }
    }
    
    /// Get current context
    func getCurrentContext() -> AIContextData {
        contextEngine.getCurrentContext()
    }
    
    /// Get learning insights
    func getLearningInsights() -> LearningInsightsData {
        learningEngine.getInsights()
    }
    
    /// Save a memory directly
    func saveMemory(_ content: String, category: MemoryCategory, importance: Double = 0.5) {
        let memory = MemoryItemData(
            id: UUID(),
            type: .fact,
            content: content,
            timestamp: Date(),
            source: .userInput,
            category: category,
            tags: extractTopics(from: content),
            importance: importance,
            emotions: [],
            context: nil
        )
        
        memorySystem.store(memory)
    }
    
    /// Search memories
    func searchMemories(_ query: String) -> [MemoryItemData] {
        memorySystem.retrieve(query: query)
    }
    
    // MARK: - Private Methods
    
    private func setupBrain() {
        // Check if we have a saved user
        Task {
            // In a real app, we'd load from UserDefaults or Keychain
            // For now, mark as ready after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                self.isReady = true
            }
        }
        
        // Start periodic maintenance
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.performMaintenance()
        }
    }
    
    private func setupAssistant(for user: UserData) async {
        do {
            let assistantData = AIAssistantData(
                id: UUID(),
                name: "Maria",
                gender: .feminine,
                personality: AIPersonalityData(
                    friendliness: user.preferences.aiPersonality.friendliness,
                    formality: user.preferences.aiPersonality.formality,
                    humor: user.preferences.aiPersonality.humor,
                    enthusiasm: 0.7,
                    empathy: 0.9,
                    curiosity: 0.6,
                    proactiveness: user.preferences.aiPersonality.proactiveness,
                    creativity: 0.6,
                    analyticalThinking: 0.7,
                    patience: 0.8,
                    useEmojis: true,
                    useQuestions: true
                ),
                responseStyle: .balanced,
                capabilities: AICapability.defaultSet,
                specializations: [],
                traits: AIPersonalityTrait.allCases,
                createdAt: Date(),
                lastInteractionAt: Date()
            )
            
            let assistant = try await dataManager.createAIAssistant(assistantData)
            
            await MainActor.run {
                self.currentAssistant = assistant
                self.isReady = true
            }
            
        } catch {
            print("Error setting up assistant: \(error)")
        }
    }
    
    private func determineContext(from message: String) -> ConversationContext {
        let lowercased = message.lowercased()
        
        if lowercased.contains("health") || lowercased.contains("feel") || lowercased.contains("sick") {
            return .health
        } else if lowercased.contains("work") || lowercased.contains("job") || lowercased.contains("meeting") {
            return .work
        } else if lowercased.contains("personal") || lowercased.contains("family") || lowercased.contains("friend") {
            return .personal
        } else if lowercased.contains("learn") || lowercased.contains("study") || lowercased.contains("understand") {
            return .learning
        } else if lowercased.contains("plan") || lowercased.contains("schedule") || lowercased.contains("organize") {
            return .planning
        } else {
            return .general
        }
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimate: 1 token ≈ 4 characters
        return text.count / 4
    }
}

// MARK: - Convenience Methods for SwiftUI

extension MariaBrain {
    /// Simple chat interface for UI
    func chat(_ message: String) async -> String {
        return await processInput(message)
    }
    
    /// Check if brain is initialized and ready
    var isInitialized: Bool {
        isReady && currentUser != nil
    }
    
    /// Get user's first name for personalization
    var userName: String {
        currentUser?.firstName ?? "Friend"
    }
    
    /// Get assistant's name
    var assistantName: String {
        currentAssistant?.name ?? "Maria"
    }
    
    /// Clear search results
    func clearSearchResults() {
        searchResults = []
    }
    
    /// Get chat history grouped by date
    func getChatHistoryGroupedByDate() -> [(date: Date, messages: [ChatMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: chatHistory) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, messages: $0.value.sorted { $0.timestamp < $1.timestamp }) }
    }
    
    // MARK: - Command System Access
    
    /// Check if sleep mode is active
    var isSleepModeActive: Bool {
        commandSystem.sleepModeActive
    }
    
    /// Check if DND is active
    var isDNDActive: Bool {
        commandSystem.isDNDActive
    }
    
    /// Get current AI mode
    var currentMode: AIMode {
        commandSystem.currentMode
    }
    
    /// Get command history
    var commandHistory: [ExecutedCommand] {
        commandSystem.commandHistory
    }
    
    /// Quick command execution
    func executeQuickCommand(_ type: AICommandType, parameters: [String: Any] = [:]) async -> String {
        let command = AICommand(type: type, parameters: parameters)
        let result = await commandSystem.execute(command)
        
        // Store in chat as system message
        let systemMessage = ChatMessage(
            id: UUID(),
            role: .system,
            content: result.message,
            timestamp: Date(),
            estimatedTokens: estimateTokenCount(result.message),
            hasAttachments: false,
            metadata: MessageMetadata(
                intent: .command,
                emotion: nil,
                topics: ["quick_command"],
                context: .general
            )
        )
        
        do {
            try await chatHistoryManager.storeMessage(systemMessage)
        } catch {
            print("Error storing system message: \(error)")
        }
        
        await MainActor.run {
            self.chatHistory.append(systemMessage)
        }
        
        return result.message
    }
    
    /// Disable all active modes
    func disableAllModes() async {
        await commandSystem.execute(AICommand(type: .modeSwitch, parameters: ["mode": "active"]))
    }
}
