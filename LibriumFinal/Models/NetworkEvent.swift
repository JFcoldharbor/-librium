import Foundation

struct NetworkEvent: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var venue: String?
    var latitude: Double?
    var longitude: Double?
    var startDate: Date
    var endDate: Date
    var host: String?
    var hostEmail: String?
    var hostUserId: String?
    var attendees: [Attendee]
    var addedAt: Date

    struct Attendee: Codable, Equatable, Identifiable {
        let id: UUID
        var name: String
        var email: String?
        var role: String?
        var organization: String?
        var contactId: String?

        init(
            id: UUID = UUID(),
            name: String,
            email: String? = nil,
            role: String? = nil,
            organization: String? = nil,
            contactId: String? = nil
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.role = role
            self.organization = organization
            self.contactId = contactId
        }
    }

    var isLive: Bool {
        let now = Date()
        return startDate <= now && now <= endDate
    }

    var isUpcoming: Bool {
        Date() < startDate
    }

    var isPast: Bool {
        Date() > endDate
    }

    var statusLabel: String {
        if isLive { return "LIVE" }
        if isUpcoming {
            let interval = startDate.timeIntervalSinceNow
            let hours = Int(interval / 3600)
            if hours < 1 { return "STARTING SOON" }
            if hours < 24 { return "IN \(hours)H" }
            let days = Int(interval / 86400)
            return "IN \(days)D"
        }
        return "PAST"
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}
