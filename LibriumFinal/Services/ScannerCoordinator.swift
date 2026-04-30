import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class ScannerCoordinator: ObservableObject {
    static let shared = ScannerCoordinator()

    @Published private(set) var latest: ScannerOutput?
    @Published private(set) var recent: [ScannerOutput] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    func startListening() {
        listener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        listener = db.collection("users").document(uid)
            .collection("scannerOutputs")
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let outputs = docs.compactMap { doc -> ScannerOutput? in
                    Self.decode(data: doc.data())
                }
                Task { @MainActor in
                    self?.recent = outputs
                    self?.latest = outputs.first
                }
            }
    }

    /// Short text suitable for inclusion in Maria's chat baseline. Picks the
    /// most recent scanner output and condenses it to summary + the top
    /// surfacing note titles. Returns nil if no recent output.
    var summaryForChat: String? {
        guard let output = latest else { return nil }
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        guard output.createdAt >= cutoff else { return nil }

        var lines: [String] = []
        lines.append("[\(output.kind.rawValue)] \(output.summary)")
        for note in output.surfacingNotes.prefix(3) {
            lines.append("- (\(note.kind.rawValue)) \(note.title)")
        }
        return lines.joined(separator: "\n")
    }

    private static func decode(data: [String: Any]) -> ScannerOutput? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let kindRaw = data["kind"] as? String,
              let kind = ScannerOutput.Kind(rawValue: kindRaw),
              let summary = data["summary"] as? String,
              let createdTs = data["createdAt"] as? Timestamp else {
            return nil
        }

        let notes = (data["surfacingNotes"] as? [[String: Any]] ?? [])
            .compactMap(decodeNote)
        let actions = (data["suggestedActions"] as? [[String: Any]] ?? [])
            .compactMap(decodeAction)

        return ScannerOutput(
            id: id,
            kind: kind,
            createdAt: createdTs.dateValue(),
            summary: summary,
            surfacingNotes: notes,
            suggestedActions: actions,
            trigger: data["trigger"] as? String
        )
    }

    private static func decodeNote(_ data: [String: Any]) -> SurfacingNote? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let kindRaw = data["kind"] as? String,
              let kind = SurfacingNote.NoteKind(rawValue: kindRaw),
              let title = data["title"] as? String,
              let body = data["body"] as? String else {
            return nil
        }
        let priorityRaw = data["priority"] as? Int ?? 3
        return SurfacingNote(
            id: id,
            kind: kind,
            title: title,
            body: body,
            relatedEntityId: data["relatedEntityId"] as? String,
            priority: max(1, min(5, priorityRaw))
        )
    }

    private static func decodeAction(_ data: [String: Any]) -> SuggestedAction? {
        guard let idStr = data["id"] as? String,
              let id = UUID(uuidString: idStr),
              let label = data["label"] as? String,
              let toolName = data["toolName"] as? String else {
            return nil
        }
        return SuggestedAction(
            id: id,
            label: label,
            toolName: toolName,
            argumentsJSON: data["argumentsJSON"] as? String ?? "{}"
        )
    }
}
