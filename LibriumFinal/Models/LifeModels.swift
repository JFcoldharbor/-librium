import Foundation

// MARK: - Breathing

enum BreathingPhaseKind: String, Codable, Equatable {
    case inhale, hold, exhale

    var label: String {
        switch self {
        case .inhale: return "Inhale"
        case .hold: return "Hold"
        case .exhale: return "Exhale"
        }
    }

    var scale: CGFloat {
        switch self {
        case .inhale: return 1.4
        case .hold: return 1.4
        case .exhale: return 0.7
        }
    }
}

struct BreathingPhaseStep: Equatable {
    let kind: BreathingPhaseKind
    let duration: Int
}

enum BreathingPattern: String, CaseIterable, Codable {
    case fourSevenEight, box, calm

    var label: String {
        switch self {
        case .fourSevenEight: return "4·7·8"
        case .box: return "Box"
        case .calm: return "Calm"
        }
    }

    var subtitle: String {
        switch self {
        case .fourSevenEight: return "Calm down"
        case .box: return "Focus"
        case .calm: return "Relax"
        }
    }

    var phases: [BreathingPhaseStep] {
        switch self {
        case .fourSevenEight: return [
            BreathingPhaseStep(kind: .inhale, duration: 4),
            BreathingPhaseStep(kind: .hold, duration: 7),
            BreathingPhaseStep(kind: .exhale, duration: 8)
        ]
        case .box: return [
            BreathingPhaseStep(kind: .inhale, duration: 4),
            BreathingPhaseStep(kind: .hold, duration: 4),
            BreathingPhaseStep(kind: .exhale, duration: 4),
            BreathingPhaseStep(kind: .hold, duration: 4)
        ]
        case .calm: return [
            BreathingPhaseStep(kind: .inhale, duration: 5),
            BreathingPhaseStep(kind: .exhale, duration: 7)
        ]
        }
    }

    var cycleSeconds: Int {
        phases.reduce(0) { $0 + $1.duration }
    }
}

struct BreathingSession: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let pattern: BreathingPattern
    let cyclesCompleted: Int

    var totalSeconds: Int {
        cyclesCompleted * pattern.cycleSeconds
    }
}

// MARK: - Journal

struct JournalEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var intention: String
    var gratitude: String
    var mood: Int

    static func makeForToday() -> JournalEntry {
        JournalEntry(
            id: UUID(),
            date: Calendar.current.startOfDay(for: Date()),
            intention: "",
            gratitude: "",
            mood: 0
        )
    }

    var hasContent: Bool {
        !intention.isEmpty || !gratitude.isEmpty || mood > 0
    }
}

// MARK: - Wellness

struct WellnessLog: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var sleepHours: Double
    var energyLevel: Int
    var waterGlasses: Int

    static func makeForToday() -> WellnessLog {
        WellnessLog(
            id: UUID(),
            date: Calendar.current.startOfDay(for: Date()),
            sleepHours: 0,
            energyLevel: 0,
            waterGlasses: 0
        )
    }
}
