import Foundation

enum NetworkEventEncoder {
    static let prefix = "EQUEVENT::"
    static let webHost = "librium-f1a78.web.app"

    static func shareURL(for event: NetworkEvent) -> URL {
        URL(string: "https://\(webHost)/e/\(event.id.uuidString)")!
    }

    static func parseEventId(from url: URL) -> UUID? {
        let isOurHost = (url.host ?? "").lowercased() == webHost
        guard isOurHost else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0].lowercased() == "e" else { return nil }
        return UUID(uuidString: parts[1])
    }

    static func parseEventId(fromString string: String) -> UUID? {
        guard let url = URL(string: string) else { return nil }
        return parseEventId(from: url)
    }

    private struct Payload: Codable {
        let id: String?
        let name: String
        let venue: String?
        let lat: Double?
        let lng: Double?
        let start: String
        let end: String
        let host: String?
        let host_email: String?
        let attendees: [PayloadAttendee]?
    }

    private struct PayloadAttendee: Codable {
        let name: String
        let email: String?
        let role: String?
        let org: String?
    }

    // MARK: - Detect

    static func looksLikeEvent(_ payload: String) -> Bool {
        payload.hasPrefix(prefix)
    }

    // MARK: - Decode

    static func decode(_ raw: String) -> NetworkEvent? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(prefix) else { return nil }
        let jsonPart = String(trimmed.dropFirst(prefix.count))
        guard let data = jsonPart.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let startDate = isoFormatter.date(from: payload.start) ?? Date()
        let endDate = isoFormatter.date(from: payload.end) ?? startDate.addingTimeInterval(2 * 3600)

        let attendees = (payload.attendees ?? []).map { att in
            NetworkEvent.Attendee(
                id: UUID(),
                name: att.name,
                email: att.email?.lowercased(),
                role: att.role,
                organization: att.org,
                contactId: nil
            )
        }

        let id = (payload.id.flatMap { UUID(uuidString: $0) }) ?? UUID()
        return NetworkEvent(
            id: id,
            name: payload.name,
            venue: payload.venue,
            latitude: payload.lat,
            longitude: payload.lng,
            startDate: startDate,
            endDate: endDate,
            host: payload.host,
            hostEmail: payload.host_email?.lowercased(),
            hostUserId: nil,
            attendees: attendees,
            addedAt: Date()
        )
    }

    // MARK: - Encode (for hosts later)

    static func encode(_ event: NetworkEvent) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let payload = Payload(
            id: event.id.uuidString,
            name: event.name,
            venue: event.venue,
            lat: event.latitude,
            lng: event.longitude,
            start: isoFormatter.string(from: event.startDate),
            end: isoFormatter.string(from: event.endDate),
            host: event.host,
            host_email: event.hostEmail,
            attendees: event.attendees.map { att in
                PayloadAttendee(
                    name: att.name,
                    email: att.email,
                    role: att.role,
                    org: att.organization
                )
            }
        )
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return prefix + "{}"
        }
        return prefix + json
    }
}
