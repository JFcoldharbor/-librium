import Foundation
#if !os(macOS) && canImport(CoreNFC)
import CoreNFC
#endif

@MainActor
final class NFCService: NSObject {
    static let shared = NFCService()

    enum NFCError: LocalizedError {
        case unavailable
        case sessionFailed(String)
        case writeFailed(String)
        case readOnly
        case tooLarge
        case noPayload

        var errorDescription: String? {
            switch self {
            case .unavailable: return "NFC isn't available on this device."
            case .sessionFailed(let m): return m
            case .writeFailed(let m): return m
            case .readOnly: return "That tag is read-only."
            case .tooLarge: return "Card is too large for this tag."
            case .noPayload: return "Tag was empty."
            }
        }
    }

    static var isAvailable: Bool {
        #if !os(macOS) && canImport(CoreNFC)
        return NFCNDEFReaderSession.readingAvailable
        #else
        return false
        #endif
    }

    #if !os(macOS) && canImport(CoreNFC)
    private var session: NFCNDEFReaderSession?
    private var mode: Mode = .read
    private var readContinuation: CheckedContinuation<Result<String, NFCError>, Never>?
    private var writeContinuation: CheckedContinuation<Result<Void, NFCError>, Never>?

    private enum Mode {
        case read
        case write(String)
    }
    #endif

    private override init() {
        super.init()
    }

    // MARK: - Public

    func readVCard() async -> Result<String, NFCError> {
        #if !os(macOS) && canImport(CoreNFC)
        guard NFCNDEFReaderSession.readingAvailable else {
            return .failure(.unavailable)
        }
        return await withCheckedContinuation { continuation in
            self.readContinuation = continuation
            self.mode = .read
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = "Hold your iPhone near a tag."
            self.session = session
            session.begin()
        }
        #else
        return .failure(.unavailable)
        #endif
    }

    func writeVCard(_ payload: String) async -> Result<Void, NFCError> {
        #if !os(macOS) && canImport(CoreNFC)
        guard NFCNDEFReaderSession.readingAvailable else {
            return .failure(.unavailable)
        }
        return await withCheckedContinuation { continuation in
            self.writeContinuation = continuation
            self.mode = .write(payload)
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            session.alertMessage = "Hold your iPhone near a writable tag."
            self.session = session
            session.begin()
        }
        #else
        return .failure(.unavailable)
        #endif
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

#if !os(macOS) && canImport(CoreNFC)
extension NFCService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {}

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.session = nil
            let message = (error as NSError).localizedDescription
            self.readContinuation?.resume(returning: .failure(.sessionFailed(message)))
            self.readContinuation = nil
            self.writeContinuation?.resume(returning: .failure(.sessionFailed(message)))
            self.writeContinuation = nil
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Used in legacy read-only path. Modern path uses didDetect tags.
        let payload = Self.extractFirstPayload(from: messages)
        Task { @MainActor in
            if let payload = payload {
                session.alertMessage = "Card read."
                self.readContinuation?.resume(returning: .success(payload))
            } else {
                self.readContinuation?.resume(returning: .failure(.noPayload))
            }
            self.readContinuation = nil
            self.session = nil
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }

        Task { @MainActor in
            session.connect(to: tag) { connectError in
                if let connectError = connectError {
                    session.invalidate(errorMessage: connectError.localizedDescription)
                    return
                }

                tag.queryNDEFStatus { status, capacity, queryError in
                    if let queryError = queryError {
                        session.invalidate(errorMessage: queryError.localizedDescription)
                        return
                    }

                    Task { @MainActor in
                        switch self.mode {
                        case .read:
                            self.handleRead(tag: tag, session: session)
                        case .write(let payload):
                            self.handleWrite(tag: tag, payload: payload, status: status, capacity: capacity, session: session)
                        }
                    }
                }
            }
        }
    }

    private func handleRead(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { message, error in
            if let error = error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }
            let messages = message.map { [$0] } ?? []
            let payload = Self.extractFirstPayload(from: messages)
            Task { @MainActor in
                if let payload = payload {
                    session.alertMessage = "Card read."
                    session.invalidate()
                    self.readContinuation?.resume(returning: .success(payload))
                    self.readContinuation = nil
                } else {
                    session.invalidate(errorMessage: "Tag was empty.")
                    self.readContinuation?.resume(returning: .failure(.noPayload))
                    self.readContinuation = nil
                }
                self.session = nil
            }
        }
    }

    private func handleWrite(
        tag: NFCNDEFTag,
        payload: String,
        status: NFCNDEFStatus,
        capacity: Int,
        session: NFCNDEFReaderSession
    ) {
        switch status {
        case .notSupported:
            session.invalidate(errorMessage: "Tag isn't NDEF.")
            self.writeContinuation?.resume(returning: .failure(.writeFailed("Tag is not NDEF-formatted.")))
            self.writeContinuation = nil
            self.session = nil
            return
        case .readOnly:
            session.invalidate(errorMessage: "Tag is read-only.")
            self.writeContinuation?.resume(returning: .failure(.readOnly))
            self.writeContinuation = nil
            self.session = nil
            return
        case .readWrite:
            break
        @unknown default:
            session.invalidate(errorMessage: "Unknown tag status.")
            self.writeContinuation?.resume(returning: .failure(.writeFailed("Unknown tag status.")))
            self.writeContinuation = nil
            self.session = nil
            return
        }

        let message = Self.makeNDEFMessage(payload: payload)
        let messageBytes = message.length
        if messageBytes > capacity {
            session.invalidate(errorMessage: "Card too large for this tag (\(messageBytes) > \(capacity) bytes).")
            self.writeContinuation?.resume(returning: .failure(.tooLarge))
            self.writeContinuation = nil
            self.session = nil
            return
        }

        tag.writeNDEF(message) { error in
            Task { @MainActor in
                if let error = error {
                    session.invalidate(errorMessage: error.localizedDescription)
                    self.writeContinuation?.resume(returning: .failure(.writeFailed(error.localizedDescription)))
                } else {
                    session.alertMessage = "Card written."
                    session.invalidate()
                    self.writeContinuation?.resume(returning: .success(()))
                }
                self.writeContinuation = nil
                self.session = nil
            }
        }
    }

    // MARK: - NDEF helpers

    private nonisolated static func makeNDEFMessage(payload: String) -> NFCNDEFMessage {
        let payloadData = Data(payload.utf8)
        let textRecord = NFCNDEFPayload(
            format: .nfcWellKnown,
            type: Data("T".utf8),
            identifier: Data(),
            payload: encodeTextPayload(payloadData)
        )
        let mimeRecord = NFCNDEFPayload(
            format: .media,
            type: Data("text/vcard".utf8),
            identifier: Data(),
            payload: payloadData
        )
        return NFCNDEFMessage(records: [mimeRecord, textRecord])
    }

    private nonisolated static func encodeTextPayload(_ payload: Data) -> Data {
        // RFC: Status byte + language code + text
        let langCode = "en".data(using: .utf8) ?? Data()
        var data = Data()
        let statusByte = UInt8(langCode.count & 0x3F)
        data.append(statusByte)
        data.append(langCode)
        data.append(payload)
        return data
    }

    private nonisolated static func extractFirstPayload(from messages: [NFCNDEFMessage]) -> String? {
        for message in messages {
            for record in message.records {
                if let text = decodeRecord(record) {
                    if text.uppercased().contains("BEGIN:VCARD") {
                        return text
                    }
                }
            }
        }
        // Fallback: return first non-empty text we find
        for message in messages {
            for record in message.records {
                if let text = decodeRecord(record), !text.isEmpty {
                    return text
                }
            }
        }
        return nil
    }

    private nonisolated static func decodeRecord(_ record: NFCNDEFPayload) -> String? {
        let typeString = String(data: record.type, encoding: .utf8) ?? ""

        if record.typeNameFormat == .nfcWellKnown && typeString == "T" {
            // text record: skip status byte + language code
            let bytes = record.payload
            guard !bytes.isEmpty else { return nil }
            let statusByte = bytes[0]
            let langLen = Int(statusByte & 0x3F)
            guard bytes.count > 1 + langLen else { return nil }
            let textData = bytes.subdata(in: (1 + langLen)..<bytes.count)
            return String(data: textData, encoding: .utf8)
        }

        if record.typeNameFormat == .media {
            return String(data: record.payload, encoding: .utf8)
        }

        return String(data: record.payload, encoding: .utf8)
    }
}
#endif
