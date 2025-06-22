//
//  DataManager.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation
import CoreData
import Security
import CryptoKit

// MARK: - Data Provider Protocol
protocol DataProvider {
    // User Management
    func createUser(_ userData: UserData) async throws -> UserData
    func loadUser(id: UUID) async throws -> UserData?
    func updateUser(_ userData: UserData) async throws
    func deleteUser(id: UUID) async throws
    
    // AI Assistant Management
    func createAIAssistant(_ assistantData: AIAssistantData) async throws -> AIAssistantData
    func loadAIAssistant(id: UUID) async throws -> AIAssistantData?
    func updateAIAssistant(_ assistantData: AIAssistantData) async throws
    
    // Memory Persistence
    func saveMemory(_ memory: MemoryItemData) async throws
    func loadMemories(category: MemoryCategory?) async throws -> [MemoryItemData]
    
    // Privacy & Export
    func exportUserData(userId: UUID) async throws -> Data
    func deleteAllUserData(userId: UUID) async throws
}

// MARK: - Data Manager (Implements DataProvider)
class DataManager: ObservableObject, DataProvider {
    static let shared = DataManager()
    
    @Published var currentUser: UserData?
    @Published var aiAssistant: AIAssistantData?
    @Published var isDataLoaded = false
    
    // Core Data
    private let persistentContainer: NSPersistentContainer
    private let encryptionManager: EncryptionManager
    private let privacyManager: PrivacyManager
    
    // Cache
    private var userCache: [UUID: UserData] = [:]
    private var memoryCache: [UUID: MemoryItemData] = [:]
    
    private init() {
        self.persistentContainer = NSPersistentContainer(name: "FINALE")
        self.encryptionManager = EncryptionManager()
        self.privacyManager = PrivacyManager()
        
        setupCoreData()
        loadInitialData()
    }
    
    // MARK: - Core Data Setup
    private func setupCoreData() {
        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                print("Core Data error: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.isDataLoaded = true
            }
        }
    }
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func save() async throws {
        guard context.hasChanges else { return }
        
        try await context.perform {
            try self.context.save()
        }
    }
    
    // MARK: - DataProvider Implementation
    
    func createUser(_ userData: UserData) async throws -> UserData {
        return try await context.perform {
            let userEntity = UserEntity(context: self.context)
            userEntity.id = userData.id
            userEntity.firstName = userData.firstName
            userEntity.lastName = userData.lastName
            userEntity.email = self.encryptionManager.encrypt(userData.email)
            userEntity.phoneNumber = userData.phoneNumber.map { self.encryptionManager.encrypt($0) }
            userEntity.preferences = try JSONEncoder().encode(userData.preferences)
            userEntity.privacySettings = try JSONEncoder().encode(userData.privacySettings)
            userEntity.enabledHubs = try JSONEncoder().encode(userData.enabledHubs)
            userEntity.createdAt = userData.createdAt
            userEntity.lastActiveAt = userData.lastActiveAt
            
            try self.context.save()
            
            self.userCache[userData.id] = userData
            
            DispatchQueue.main.async {
                self.currentUser = userData
            }
            
            return userData
        }
    }
    
    func loadUser(id: UUID) async throws -> UserData? {
        // Check cache first
        if let cachedUser = userCache[id] {
            return cachedUser
        }
        
        return try await context.perform {
            let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try self.context.fetch(request)
            guard let entity = entities.first else { return nil }
            
            let userData = UserData(
                id: entity.id ?? UUID(),
                firstName: entity.firstName ?? "",
                lastName: entity.lastName ?? "",
                email: self.encryptionManager.decrypt(entity.email ?? "") ?? "",
                phoneNumber: entity.phoneNumber.flatMap { self.encryptionManager.decrypt($0) },
                preferences: (try? JSONDecoder().decode(UserPreferencesData.self, from: entity.preferences ?? Data())) ?? UserPreferencesData(),
                privacySettings: (try? JSONDecoder().decode(PrivacySettingsData.self, from: entity.privacySettings ?? Data())) ?? PrivacySettingsData(),
                enabledHubs: (try? JSONDecoder().decode(Set<HubType>.self, from: entity.enabledHubs ?? Data())) ?? Set([.life]),
                createdAt: entity.createdAt ?? Date(),
                lastActiveAt: entity.lastActiveAt ?? Date()
            )
            
            self.userCache[id] = userData
            return userData
        }
    }
    
    func updateUser(_ userData: UserData) async throws {
        userCache[userData.id] = userData
        
        try await context.perform {
            let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", userData.id as CVarArg)
            
            let entities = try self.context.fetch(request)
            guard let entity = entities.first else { return }
            
            entity.firstName = userData.firstName
            entity.lastName = userData.lastName
            entity.email = self.encryptionManager.encrypt(userData.email)
            entity.phoneNumber = userData.phoneNumber.map { self.encryptionManager.encrypt($0) }
            entity.preferences = try JSONEncoder().encode(userData.preferences)
            entity.privacySettings = try JSONEncoder().encode(userData.privacySettings)
            entity.enabledHubs = try JSONEncoder().encode(userData.enabledHubs)
            entity.lastActiveAt = Date()
            
            try self.context.save()
        }
    }
    
    func deleteUser(id: UUID) async throws {
        userCache.removeValue(forKey: id)
        
        if currentUser?.id == id {
            DispatchQueue.main.async {
                self.currentUser = nil
            }
        }
        
        try await privacyManager.deleteAllUserData(userId: id, context: context)
    }
    
    func createAIAssistant(_ assistantData: AIAssistantData) async throws -> AIAssistantData {
        return try await context.perform {
            let entity = AIAssistantEntity(context: self.context)
            entity.id = assistantData.id
            entity.name = assistantData.name
            entity.gender = assistantData.gender.rawValue
            entity.personality = try JSONEncoder().encode(assistantData.personality)
            entity.responseStyle = assistantData.responseStyle.rawValue
            entity.capabilities = try JSONEncoder().encode(Array(assistantData.capabilities))
            entity.specializations = try JSONEncoder().encode(assistantData.specializations)
            entity.traits = try JSONEncoder().encode(assistantData.traits)
            entity.createdAt = assistantData.createdAt
            entity.lastInteractionAt = assistantData.lastInteractionAt
            
            try self.context.save()
            
            DispatchQueue.main.async {
                self.aiAssistant = assistantData
            }
            
            return assistantData
        }
    }
    
    func loadAIAssistant(id: UUID) async throws -> AIAssistantData? {
        return try await context.perform {
            let request: NSFetchRequest<AIAssistantEntity> = AIAssistantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            
            let entities = try self.context.fetch(request)
            guard let entity = entities.first else { return nil }
            
            let assistantData = AIAssistantData(
                id: entity.id ?? UUID(),
                name: entity.name ?? "Maria",
                gender: AIGender(rawValue: entity.gender ?? "feminine") ?? .feminine,
                personality: (try? JSONDecoder().decode(AIPersonalityData.self, from: entity.personality ?? Data())) ?? AIPersonalityData(),
                responseStyle: AIResponseStyle(rawValue: entity.responseStyle ?? "balanced") ?? .balanced,
                capabilities: Set((try? JSONDecoder().decode([AICapability].self, from: entity.capabilities ?? Data())) ?? Array(AICapability.defaultSet)),
                specializations: (try? JSONDecoder().decode([AISpecialization].self, from: entity.specializations ?? Data())) ?? [],
                traits: (try? JSONDecoder().decode([AIPersonalityTrait].self, from: entity.traits ?? Data())) ?? AIPersonalityTrait.allCases,
                createdAt: entity.createdAt ?? Date(),
                lastInteractionAt: entity.lastInteractionAt ?? Date()
            )
            
            return assistantData
        }
    }
    
    func updateAIAssistant(_ assistantData: AIAssistantData) async throws {
        try await context.perform {
            let request: NSFetchRequest<AIAssistantEntity> = AIAssistantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", assistantData.id as CVarArg)
            
            let entities = try self.context.fetch(request)
            guard let entity = entities.first else { return }
            
            entity.name = assistantData.name
            entity.gender = assistantData.gender.rawValue
            entity.personality = try JSONEncoder().encode(assistantData.personality)
            entity.responseStyle = assistantData.responseStyle.rawValue
            entity.capabilities = try JSONEncoder().encode(Array(assistantData.capabilities))
            entity.specializations = try JSONEncoder().encode(assistantData.specializations)
            entity.traits = try JSONEncoder().encode(assistantData.traits)
            entity.lastInteractionAt = Date()
            
            try self.context.save()
        }
    }
    
    func saveMemory(_ memory: MemoryItemData) async throws {
        try await context.perform {
            let entity = MemoryEntity(context: self.context)
            entity.id = memory.id
            entity.type = memory.type.rawValue
            entity.content = self.encryptionManager.encrypt(memory.content)
            entity.timestamp = memory.timestamp
            entity.source = memory.source.rawValue
            entity.category = memory.category.rawValue
            entity.importance = memory.importance
            entity.tags = try JSONEncoder().encode(memory.tags)
            entity.emotions = try JSONEncoder().encode(memory.emotions.map { $0.rawValue })
            
            try self.context.save()
            
            self.memoryCache[memory.id] = memory
        }
    }
    
    func loadMemories(category: MemoryCategory? = nil) async throws -> [MemoryItemData] {
        return try await context.perform {
            let request: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
            
            if let category = category {
                request.predicate = NSPredicate(format: "category == %@", category.rawValue)
            }
            
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let entities = try self.context.fetch(request)
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let typeString = entity.type,
                      let type = MemoryType(rawValue: typeString),
                      let encryptedContent = entity.content,
                      let content = self.encryptionManager.decrypt(encryptedContent),
                      let sourceString = entity.source,
                      let source = MemorySource(rawValue: sourceString),
                      let categoryString = entity.category,
                      let category = MemoryCategory(rawValue: categoryString) else {
                    return nil
                }
                
                let tags = (try? JSONDecoder().decode([String].self, from: entity.tags ?? Data())) ?? []
                let emotionStrings = (try? JSONDecoder().decode([String].self, from: entity.emotions ?? Data())) ?? []
                let emotions = emotionStrings.compactMap { EmotionType(rawValue: $0) }
                
                return MemoryItemData(
                    id: id,
                    type: type,
                    content: content,
                    timestamp: entity.timestamp ?? Date(),
                    source: source,
                    category: category,
                    tags: tags,
                    importance: entity.importance,
                    emotions: emotions,
                    context: nil
                )
            }
        }
    }
    
    func exportUserData(userId: UUID) async throws -> Data {
        return try await privacyManager.exportUserData(userId: userId, context: context)
    }
    
    func deleteAllUserData(userId: UUID) async throws {
        try await deleteUser(id: userId)
    }
    
    // MARK: - Private Methods
    private func loadInitialData() {
        // Load current user if exists
        // This would typically load the last active user
    }
}

// MARK: - Data Transfer Objects

struct UserData: Codable, Identifiable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String?
    var preferences: UserPreferencesData
    var privacySettings: PrivacySettingsData
    var enabledHubs: Set<HubType>
    let createdAt: Date
    var lastActiveAt: Date
}

struct UserPreferencesData: Codable {
    var theme: AppTheme = .adaptive
    var notifications: NotificationSettingsData = NotificationSettingsData()
    var language: String = "en"
    var timezone: String = TimeZone.current.identifier
    var aiPersonality: AIPersonalityPreferencesData = AIPersonalityPreferencesData()
}

struct PrivacySettingsData: Codable {
    var shareHealthData: Bool = false
    var shareLocationData: Bool = false
    var shareUsageAnalytics: Bool = false
    var encryptSensitiveData: Bool = true
    var dataRetentionDays: Int = 365
    var allowPersonalization: Bool = true
}

struct NotificationSettingsData: Codable {
    var enabled: Bool = true
    var healthReminders: Bool = true
    var goalProgress: Bool = true
    var aiSuggestions: Bool = true
    var quietHours: TimeRange? = nil
}

struct AIPersonalityPreferencesData: Codable {
    var friendliness: Double = 0.8
    var formality: Double = 0.5
    var humor: Double = 0.3
    var proactiveness: Double = 0.6
}

struct AIAssistantData: Codable, Identifiable {
    let id: UUID
    var name: String
    var gender: AIGender
    var personality: AIPersonalityData
    var responseStyle: AIResponseStyle
    var capabilities: Set<AICapability>
    var specializations: [AISpecialization]
    var traits: [AIPersonalityTrait]
    let createdAt: Date
    var lastInteractionAt: Date
}

struct AIPersonalityData: Codable {
    var friendliness: Double = 0.8
    var formality: Double = 0.5
    var humor: Double = 0.3
    var enthusiasm: Double = 0.7
    var empathy: Double = 0.9
    var curiosity: Double = 0.6
    var proactiveness: Double = 0.5
    var creativity: Double = 0.6
    var analyticalThinking: Double = 0.7
    var patience: Double = 0.8
    var useEmojis: Bool = true
    var useQuestions: Bool = true
}

// MARK: - Encryption Manager
class EncryptionManager {
    private let keychain = Keychain()
    
    func encrypt(_ text: String) -> String {
        // In production, use proper encryption
        // For now, simple base64 encoding as placeholder
        return Data(text.utf8).base64EncodedString()
    }
    
    func decrypt(_ encryptedText: String) -> String? {
        // In production, use proper decryption
        guard let data = Data(base64Encoded: encryptedText) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func encryptData(_ data: Data?) -> Data? {
        // In production, use proper data encryption
        return data
    }
    
    func decryptData(_ encryptedData: Data?) -> Data? {
        // In production, use proper data decryption
        return encryptedData
    }
}

// MARK: - Privacy Manager
class PrivacyManager {
    func deleteAllUserData(userId: UUID, context: NSManagedObjectContext) async throws {
        try await context.perform {
            // Delete user entity
            let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            let users = try context.fetch(userRequest)
            for user in users {
                context.delete(user)
            }
            
            // Delete all memories (in production, filter by user)
            let memoryRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
            let memories = try context.fetch(memoryRequest)
            for memory in memories {
                context.delete(memory)
            }
            
            // Delete AI assistant (in production, filter by user)
            let assistantRequest: NSFetchRequest<AIAssistantEntity> = AIAssistantEntity.fetchRequest()
            let assistants = try context.fetch(assistantRequest)
            for assistant in assistants {
                context.delete(assistant)
            }
            
            try context.save()
        }
    }
    
    func exportUserData(userId: UUID, context: NSManagedObjectContext) async throws -> Data {
        return try await context.perform {
            var exportData: [String: Any] = [:]
            
            // Export user data
            let userRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            userRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
            
            if let user = try context.fetch(userRequest).first {
                exportData["user"] = [
                    "id": user.id?.uuidString ?? "",
                    "firstName": user.firstName ?? "",
                    "lastName": user.lastName ?? "",
                    "email": user.email ?? "",
                    "createdAt": user.createdAt?.timeIntervalSince1970 ?? 0
                ]
            }
            
            // Export memories
            let memoryRequest: NSFetchRequest<MemoryEntity> = MemoryEntity.fetchRequest()
            let memories = try context.fetch(memoryRequest)
            
            exportData["memories"] = memories.map { memory in
                [
                    "id": memory.id?.uuidString ?? "",
                    "type": memory.type ?? "",
                    "category": memory.category ?? "",
                    "timestamp": memory.timestamp?.timeIntervalSince1970 ?? 0
                ]
            }
            
            return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        }
    }
}

// MARK: - Keychain Wrapper
class Keychain {
    func store(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Core Data Entity Extensions
extension UserEntity {
    static func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }
}

extension AIAssistantEntity {
    static func fetchRequest() -> NSFetchRequest<AIAssistantEntity> {
        return NSFetchRequest<AIAssistantEntity>(entityName: "AIAssistantEntity")
    }
}

extension MemoryEntity {
    static func fetchRequest() -> NSFetchRequest<MemoryEntity> {
        return NSFetchRequest<MemoryEntity>(entityName: "MemoryEntity")
    }
}

// MARK: - Data Manager Specific Enums
enum AppTheme: String, Codable {
    case light = "light"
    case dark = "dark"
    case adaptive = "adaptive"
}

enum HubType: String, Codable, CaseIterable {
    case life = "life"
    case work = "work"
    case health = "health"
    case finance = "finance"
    case learning = "learning"
}

// MARK: - Core Data Entity Protocols (Placeholder)
// These would be generated by Core Data model file

@objc(UserEntity)
public class UserEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var firstName: String?
    @NSManaged public var lastName: String?
    @NSManaged public var email: String?
    @NSManaged public var phoneNumber: String?
    @NSManaged public var preferences: Data?
    @NSManaged public var privacySettings: Data?
    @NSManaged public var enabledHubs: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastActiveAt: Date?
}

@objc(AIAssistantEntity)
public class AIAssistantEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var gender: String?
    @NSManaged public var personality: Data?
    @NSManaged public var responseStyle: String?
    @NSManaged public var capabilities: Data?
    @NSManaged public var specializations: Data?
    @NSManaged public var traits: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastInteractionAt: Date?
}

@objc(MemoryEntity)
public class MemoryEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var content: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var source: String?
    @NSManaged public var category: String?
    @NSManaged public var importance: Double
    @NSManaged public var tags: Data?
    @NSManaged public var emotions: Data?
}
