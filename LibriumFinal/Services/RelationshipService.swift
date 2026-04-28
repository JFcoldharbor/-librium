import Foundation

@MainActor
final class RelationshipService {
    static let shared = RelationshipService()

    private let calendarService: CalendarService
    private let contactsService: ContactsService

    init(
        calendarService: CalendarService = .shared,
        contactsService: ContactsService = .shared
    ) {
        self.calendarService = calendarService
        self.contactsService = contactsService
    }

    func loadSnapshot(now: Date = Date(), lookbackDays: Int? = nil, topK: Int = 25) async -> RelationshipSnapshot {
        guard calendarService.accessState == .authorized,
              contactsService.accessState == .authorized else {
            return .empty
        }

        let days = lookbackDays ?? EquilibriumConfig.relationshipLookbackDays
        let events = await calendarService.eventsInPast(days: days, now: now)

        var datesByEmail: [String: [Date]] = [:]
        for event in events {
            for email in event.attendeeEmails where !email.isEmpty {
                datesByEmail[email, default: []].append(event.startDate)
            }
        }

        var relationships: [Relationship] = []
        for (email, dates) in datesByEmail {
            guard let lastDate = dates.max(),
                  let firstDate = dates.min() else { continue }
            let count = dates.count

            let contact = await contactsService.findContact(byEmail: email)
            let displayName = contact?.displayName ?? email

            let stalenessDays = max(0, now.timeIntervalSince(lastDate) / 86_400)
            let importance = log(Double(count) + 1)
            let decay = stalenessDays * importance

            relationships.append(Relationship(
                id: contact?.id ?? email,
                displayName: displayName,
                email: email,
                lastInteraction: lastDate,
                firstInteraction: firstDate,
                interactionCount: count,
                decayScore: decay,
                role: contact?.role,
                contactNote: contact?.note,
                imageData: contact?.imageData
            ))
        }

        let topRelationships = relationships
            .sorted { $0.decayScore > $1.decayScore }
            .prefix(topK)

        return RelationshipSnapshot(
            relationships: Array(topRelationships),
            asOf: now
        )
    }
}
