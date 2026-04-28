import Foundation

struct ContactNote: Codable, Equatable, Identifiable {
    var id: String { contactId }
    let contactId: String
    var notes: String
    var nextFollowUp: Date?
    var followUpReason: String?
    var status: Status
    var lastTouchedAt: Date?
    var lastTouchChannel: String?
    var relationshipType: RelationshipType
    var personalScore: Int?          // 0-100, friend/family/personal warmth
    var businessScore: Int?          // 0-100, professional working relationship
    var relationshipContext: String? // free-text sentiment ("flaky, never follows up")
    var updatedAt: Date

    enum RelationshipType: String, Codable, CaseIterable {
        case unknown
        case personal
        case business
        case both

        var label: String {
            switch self {
            case .unknown: return "Not set"
            case .personal: return "Personal"
            case .business: return "Business"
            case .both: return "Both"
            }
        }
    }

    enum Status: String, Codable, CaseIterable {
        case active, deadLead, archived

        var label: String {
            switch self {
            case .active: return "Active"
            case .deadLead: return "Dead lead"
            case .archived: return "Archived"
            }
        }
    }

    static func empty(contactId: String) -> ContactNote {
        ContactNote(
            contactId: contactId,
            notes: "",
            nextFollowUp: nil,
            followUpReason: nil,
            status: .active,
            lastTouchedAt: nil,
            lastTouchChannel: nil,
            relationshipType: .unknown,
            personalScore: nil,
            businessScore: nil,
            relationshipContext: nil,
            updatedAt: Date()
        )
    }

    enum CodingKeys: String, CodingKey {
        case contactId, notes, nextFollowUp, followUpReason, status
        case lastTouchedAt, lastTouchChannel
        case relationshipType
        case personalScore, businessScore, relationshipContext
        case relationshipScore // legacy — read-only for one-time migration
        case updatedAt
    }

    init(
        contactId: String,
        notes: String,
        nextFollowUp: Date?,
        followUpReason: String?,
        status: Status = .active,
        lastTouchedAt: Date? = nil,
        lastTouchChannel: String? = nil,
        relationshipType: RelationshipType = .unknown,
        personalScore: Int? = nil,
        businessScore: Int? = nil,
        relationshipContext: String? = nil,
        updatedAt: Date
    ) {
        self.contactId = contactId
        self.notes = notes
        self.nextFollowUp = nextFollowUp
        self.followUpReason = followUpReason
        self.status = status
        self.lastTouchedAt = lastTouchedAt
        self.lastTouchChannel = lastTouchChannel
        self.relationshipType = relationshipType
        self.personalScore = personalScore
        self.businessScore = businessScore
        self.relationshipContext = relationshipContext
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contactId = try c.decode(String.self, forKey: .contactId)
        notes = try c.decode(String.self, forKey: .notes)
        nextFollowUp = try c.decodeIfPresent(Date.self, forKey: .nextFollowUp)
        followUpReason = try c.decodeIfPresent(String.self, forKey: .followUpReason)
        status = (try? c.decode(Status.self, forKey: .status)) ?? .active
        lastTouchedAt = try c.decodeIfPresent(Date.self, forKey: .lastTouchedAt)
        lastTouchChannel = try c.decodeIfPresent(String.self, forKey: .lastTouchChannel)

        relationshipType = try c.decodeIfPresent(RelationshipType.self, forKey: .relationshipType) ?? .unknown

        // Migrate legacy `relationshipScore` (single int) into `personalScore` if present.
        let legacy = try c.decodeIfPresent(Int.self, forKey: .relationshipScore)
        personalScore = try c.decodeIfPresent(Int.self, forKey: .personalScore) ?? legacy
        businessScore = try c.decodeIfPresent(Int.self, forKey: .businessScore)
        relationshipContext = try c.decodeIfPresent(String.self, forKey: .relationshipContext)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(contactId, forKey: .contactId)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(nextFollowUp, forKey: .nextFollowUp)
        try c.encodeIfPresent(followUpReason, forKey: .followUpReason)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(lastTouchedAt, forKey: .lastTouchedAt)
        try c.encodeIfPresent(lastTouchChannel, forKey: .lastTouchChannel)
        try c.encode(relationshipType, forKey: .relationshipType)
        try c.encodeIfPresent(personalScore, forKey: .personalScore)
        try c.encodeIfPresent(businessScore, forKey: .businessScore)
        try c.encodeIfPresent(relationshipContext, forKey: .relationshipContext)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}
