//
//  ChatHistoryManager.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//

import Foundation
import CoreData

// MARK: - Chat History Manager
class ChatHistoryManager: ObservableObject {
    @Published var isSearching = false
    @Published var searchResults: [ChatMessage] = []
    
    private let dataManager: DataManager
    private let compressionManager = CompressionManager()
    
    init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
    }
    
    // MARK: - Public Methods
    
    /// Store a new chat message
    func storeMessage(_ message: ChatMessage) async {
        let context = dataManager.context
        
        do {
            try await context.perform {
                let entity = ChatMessageEntity(context: context)
                entity.id = message.id
                entity.role = message.role.rawValue
                entity.content = self.compressionManager.compress(message.content)
                entity.timestamp = message.timestamp
                entity.tokens = Int32(message.estimatedTokens)
                entity.hasAttachments = message.hasAttachments
                entity.metadata = try? JSONEncoder().encode(message.metadata)
                
                // Add to daily batch
                let batchKey = self.getBatchKey(for: message.timestamp)
                entity.batchKey = batchKey
                
                try context.save()
            }
            
            // Archive old messages periodically
            await archiveOldMessagesIfNeeded()
        } catch {
            print("Error storing chat message: \(error)")
        }
    }
    
    /// Search through chat history
    func search(query: String, dateRange: DateRange? = nil, limit: Int = 50) async throws -> [ChatMessage] {
        let context = dataManager.context
        
        return try await context.perform {
            let request: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
            
            // Build predicate
            var predicates: [NSPredicate] = []
            
            // Text search (encrypted content requires special handling)
            predicates.append(NSPredicate(format: "content CONTAINS[cd] %@", query))
            
            // Date range filter
            if let dateRange = dateRange {
                predicates.append(NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                    dateRange.start as NSDate, dateRange.end as NSDate))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = limit
            
            let entities = try context.fetch(request)
            
            return entities.compactMap { entity in
                guard let id = entity.id,
                      let roleString = entity.role,
                      let role = MessageRole(rawValue: roleString),
                      let compressedContent = entity.content else { return nil }
                
                let content = self.compressionManager.decompress(compressedContent)
                
                return ChatMessage(
                    id: id,
                    role: role,
                    content: content,
                    timestamp: entity.timestamp ?? Date(),
                    estimatedTokens: Int(entity.tokens),
                    hasAttachments: entity.hasAttachments,
                    metadata: (try? JSONDecoder().decode(MessageMetadata.self, from: entity.metadata ?? Data())) ?? MessageMetadata()
                )
            }
        }
    }
    
    /// Get conversation for a specific date
    func getConversation(for date: Date) async throws -> [ChatMessage] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try await search(
            query: "",
            dateRange: DateRange(start: startOfDay, end: endOfDay),
            limit: 1000
        )
    }
    
    /// Export chat history
    func exportChatHistory(from startDate: Date, to endDate: Date) async throws -> URL {
        let messages = try await search(
            query: "",
            dateRange: DateRange(start: startDate, end: endDate),
            limit: Int.max
        )
        
        // Create JSON export
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(messages)
        
        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat_export_\(Date().timeIntervalSince1970).json")
        
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    /// Get storage statistics
    func getStorageStats() async throws -> ChatStorageStats {
        let context = dataManager.context
        
        return try await context.perform {
            let request: NSFetchRequest<ChatMessageEntity> = ChatMessageEntity.fetchRequest()
            
            // Total messages
            let totalCount = try context.count(for: request)
            
            // Calculate approximate storage
            let avgMessageSize = 500 // bytes (compressed)
            let estimatedStorage = totalCount * avgMessageSize
            
            // Get date range
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            request.fetchLimit = 1
            let oldest = try context.fetch(request).first?.timestamp ?? Date()
            
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            let newest = try context.fetch(request).first?.timestamp ?? Date()
            
            return ChatStorageStats(
                totalMessages: totalCount,
                estimatedStorageBytes: estimatedStorage,
                oldestMessage: oldest,
                newestMessage: newest,
                averageMessagesPerDay: self.calculateAverageMessagesPerDay(totalCount, from: oldest)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func archiveOldMessagesIfNeeded() async {
        // Archive messages older than 1 year to compressed format
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        
        // This would batch compress old messages and store them more efficiently
        // Implementation depends on your specific needs
    }
    
    private func getBatchKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func calculateAverageMessagesPerDay(_ total: Int, from startDate: Date) -> Double {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 1
        return Double(total) / Double(max(days, 1))
    }
}

// MARK: - Compression Manager
class CompressionManager {
    func compress(_ text: String) -> Data {
        // Use compression algorithm (zlib, lz4, etc.)
        // For now, just convert to data
        // In production, use proper compression
        return text.data(using: .utf8) ?? Data()
    }
    
    func decompress(_ data: Data) -> String {
        // Decompress the data
        // For now, just convert back to string
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - Data Models
struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let estimatedTokens: Int
    let hasAttachments: Bool
    let metadata: MessageMetadata
}

struct MessageMetadata: Codable {
    var intent: MessageIntent?
    var emotion: EmotionType?
    var topics: [String] = []
    var context: ConversationContext?
}

struct DateRange {
    let start: Date
    let end: Date
}

struct ChatStorageStats {
    let totalMessages: Int
    let estimatedStorageBytes: Int
    let oldestMessage: Date
    let newestMessage: Date
    let averageMessagesPerDay: Double
    
    var estimatedStorageMB: Double {
        Double(estimatedStorageBytes) / (1024 * 1024)
    }
    
    var estimatedStorageGB: Double {
        estimatedStorageMB / 1024
    }
}

// MARK: - Core Data Entity
@objc(ChatMessageEntity)
public class ChatMessageEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var role: String?
    @NSManaged public var content: Data? // Compressed
    @NSManaged public var timestamp: Date?
    @NSManaged public var tokens: Int32
    @NSManaged public var hasAttachments: Bool
    @NSManaged public var metadata: Data?
    @NSManaged public var batchKey: String? // For efficient batch operations
}

extension ChatMessageEntity {
    static func fetchRequest() -> NSFetchRequest<ChatMessageEntity> {
        return NSFetchRequest<ChatMessageEntity>(entityName: "ChatMessageEntity")
    }
}

// MARK: - Storage Estimation
/*
 STORAGE CALCULATION FOR 5 YEARS:
 
 Assumptions:
 - Average message length: 100 words ≈ 500 characters
 - Average messages per day: 50 (25 from user, 25 from AI)
 - Compression ratio: 70% (text compresses well)
 
 Raw Calculation:
 - Messages per year: 50 × 365 = 18,250
 - Messages in 5 years: 91,250
 - Uncompressed size: 91,250 × 500 bytes = 45.6 MB
 - Compressed size: 45.6 MB × 0.3 = 13.7 MB
 - With metadata: ~20 MB
 
 For heavy users (200 messages/day):
 - 5 years compressed: ~80 MB
 
 For very heavy users (1000 messages/day):
 - 5 years compressed: ~400 MB
 
 OPTIMIZATION STRATEGIES:
 1. Archive messages older than 1 year to even more compressed format
 2. Store only summaries for very old conversations
 3. Use incremental search indices
 4. Implement message pruning policies
 */

// MARK: - Search Optimization
extension ChatHistoryManager {
    /// Build search index for faster queries
    func buildSearchIndex() async throws {
        // This would create an inverted index for full-text search
        // Using Core Data's built-in indexing or a separate search engine
    }
    
    /// Advanced search with multiple filters
    func advancedSearch(
        query: String? = nil,
        role: MessageRole? = nil,
        emotions: [EmotionType]? = nil,
        topics: [String]? = nil,
        dateRange: DateRange? = nil,
        limit: Int = 50
    ) async throws -> [ChatMessage] {
        // Implementation for complex multi-filter search
        // Would build complex NSPredicate based on all parameters
        return []
    }
}
