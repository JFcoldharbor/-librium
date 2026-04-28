import Foundation

struct FocusSession: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let durationSeconds: Int
    let completed: Bool

    var endedAt: Date {
        startedAt.addingTimeInterval(TimeInterval(durationSeconds))
    }

    var minutes: Int {
        durationSeconds / 60
    }
}
