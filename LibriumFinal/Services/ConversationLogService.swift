import Foundation

@MainActor
final class ConversationLogService: ObservableObject {
    static let shared = ConversationLogService()

    @Published private(set) var turns: [ConversationTurn] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.debug.conversationLog"
    private static let cap = 100

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        turns = store.load([ConversationTurn].self, key: Self.storageKey) ?? []
    }

    func record(_ turn: ConversationTurn) {
        turns.append(turn)
        if turns.count > Self.cap {
            turns = Array(turns.suffix(Self.cap))
        }
        persist()
    }

    func clear() {
        turns = []
        store.remove(key: Self.storageKey)
    }

    func exportAll() -> String {
        guard !turns.isEmpty else { return "(no turns logged)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var out = ""
        for (idx, turn) in turns.enumerated().reversed() {
            out += "═══ Turn \(idx + 1) [\(formatter.string(from: turn.timestamp))]"
            out += turn.isProactive ? " · PROACTIVE\n" : " · REACTIVE\n"
            out += "USER: \(turn.userMessage.isEmpty ? "(no input — auto-brief)" : turn.userMessage)\n"
            out += "MARIA: \(turn.mariaResponse)\n"
            out += "MODEL: \(turn.model)"
            if let tokens = turn.tokensUsed {
                out += " · \(tokens) tokens"
            }
            out += "\n"
            if !turn.memoriesUsed.isEmpty {
                out += "MEMORIES PASSED (\(turn.memoriesUsed.count)):\n"
                for m in turn.memoriesUsed {
                    out += "  - \(m)\n"
                }
            }
            out += "─── SYSTEM CONTEXT ───\n"
            out += turn.systemContext
            out += "\n\n"
        }
        return out
    }

    func exportTurn(_ turn: ConversationTurn) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        var out = "[\(formatter.string(from: turn.timestamp))]"
        out += turn.isProactive ? " · PROACTIVE\n" : " · REACTIVE\n"
        out += "USER: \(turn.userMessage.isEmpty ? "(no input — auto-brief)" : turn.userMessage)\n"
        out += "MARIA: \(turn.mariaResponse)\n"
        out += "MODEL: \(turn.model)"
        if let tokens = turn.tokensUsed {
            out += " · \(tokens) tokens"
        }
        out += "\n"
        if !turn.memoriesUsed.isEmpty {
            out += "MEMORIES PASSED:\n"
            for m in turn.memoriesUsed {
                out += "  - \(m)\n"
            }
        }
        out += "─── SYSTEM CONTEXT ───\n"
        out += turn.systemContext
        return out
    }

    private func persist() {
        store.save(turns, key: Self.storageKey)
    }
}
