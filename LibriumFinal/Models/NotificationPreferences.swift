import Foundation

struct NotificationPreferences: Codable, Equatable {
    var morningIntention: Bool
    var eveningReflection: Bool
    var hydrationReminders: Bool
    var breathingReminder: Bool
    var meetingHeadsUp: Bool
    var billReminders: Bool
    var followUpReminders: Bool

    static let `default` = NotificationPreferences(
        morningIntention: false,
        eveningReflection: false,
        hydrationReminders: false,
        breathingReminder: false,
        meetingHeadsUp: false,
        billReminders: false,
        followUpReminders: false
    )

    enum CodingKeys: String, CodingKey {
        case morningIntention, eveningReflection, hydrationReminders, breathingReminder
        case meetingHeadsUp, billReminders, followUpReminders
    }

    init(
        morningIntention: Bool,
        eveningReflection: Bool,
        hydrationReminders: Bool,
        breathingReminder: Bool,
        meetingHeadsUp: Bool = false,
        billReminders: Bool = false,
        followUpReminders: Bool = false
    ) {
        self.morningIntention = morningIntention
        self.eveningReflection = eveningReflection
        self.hydrationReminders = hydrationReminders
        self.breathingReminder = breathingReminder
        self.meetingHeadsUp = meetingHeadsUp
        self.billReminders = billReminders
        self.followUpReminders = followUpReminders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        morningIntention = try c.decode(Bool.self, forKey: .morningIntention)
        eveningReflection = try c.decode(Bool.self, forKey: .eveningReflection)
        hydrationReminders = try c.decode(Bool.self, forKey: .hydrationReminders)
        breathingReminder = try c.decode(Bool.self, forKey: .breathingReminder)
        meetingHeadsUp = (try? c.decode(Bool.self, forKey: .meetingHeadsUp)) ?? false
        billReminders = (try? c.decode(Bool.self, forKey: .billReminders)) ?? false
        followUpReminders = (try? c.decode(Bool.self, forKey: .followUpReminders)) ?? false
    }
}
