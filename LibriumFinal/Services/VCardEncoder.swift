import Contacts
import Foundation

enum VCardEncoder {
    struct ParsedContact: Equatable {
        var fullName: String
        var jobTitle: String?
        var organization: String?
        var email: String?
        var phone: String?
        var website: String?
        var imageData: Data?
    }

    // MARK: - Encode

    static func encode(_ profile: UserProfile, meetingNote: String? = nil, imageData: Data? = nil) -> String {
        let nameParts = splitFullName(profile.fullName)
        var lines: [String] = []
        lines.append("BEGIN:VCARD")
        lines.append("VERSION:3.0")
        lines.append("FN:\(escape(profile.fullName))")
        lines.append("N:\(escape(nameParts.last));\(escape(nameParts.first));;;")
        if let org = profile.organization, !org.isEmpty {
            lines.append("ORG:\(escape(org))")
        }
        if let title = profile.jobTitle, !title.isEmpty {
            lines.append("TITLE:\(escape(title))")
        }
        if !profile.email.isEmpty {
            lines.append("EMAIL;TYPE=INTERNET:\(profile.email)")
        }
        if let phone = profile.phone, !phone.isEmpty {
            lines.append("TEL;TYPE=CELL:\(phone)")
        }
        if let website = profile.website, !website.isEmpty {
            lines.append("URL:\(website)")
        }
        if let imageData, !imageData.isEmpty {
            let base64 = imageData.base64EncodedString()
            lines.append("PHOTO;ENCODING=b;TYPE=JPEG:\(base64)")
        }
        if let note = meetingNote, !note.isEmpty {
            lines.append("NOTE:\(escape(note))")
        }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    // MARK: - Decode

    static func decode(_ raw: String) -> ParsedContact? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased().contains("BEGIN:VCARD") else { return nil }

        let unfolded = unfold(trimmed)
        let lines = unfolded.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        var contact = ParsedContact(
            fullName: "",
            jobTitle: nil,
            organization: nil,
            email: nil,
            phone: nil,
            website: nil,
            imageData: nil
        )

        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("FN:") {
                contact.fullName = unescape(String(line.dropFirst(3)))
            } else if upper.hasPrefix("N:") {
                let parts = String(line.dropFirst(2)).split(separator: ";", omittingEmptySubsequences: false).map(String.init)
                if parts.count >= 2, contact.fullName.isEmpty {
                    let last = unescape(parts[0])
                    let first = unescape(parts[1])
                    contact.fullName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                }
            } else if upper.hasPrefix("ORG:") {
                contact.organization = unescape(String(line.dropFirst(4)))
            } else if upper.hasPrefix("TITLE:") {
                contact.jobTitle = unescape(String(line.dropFirst(6)))
            } else if upper.hasPrefix("URL:") {
                contact.website = unescape(String(line.dropFirst(4)))
            } else if upper.hasPrefix("PHOTO") {
                contact.imageData = parsePhoto(line)
            } else if upper.contains("EMAIL") {
                if let value = valueAfterColon(line) { contact.email = value }
            } else if upper.contains("TEL") {
                if let value = valueAfterColon(line) { contact.phone = value }
            }
        }

        guard !contact.fullName.isEmpty else { return nil }
        return contact
    }

    private static func unfold(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        // RFC 2425: lines that start with a space or tab are continuations
        return normalized
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    private static func parsePhoto(_ line: String) -> Data? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colon)...])
        let cleaned = value.replacingOccurrences(of: " ", with: "")
        return Data(base64Encoded: cleaned)
    }

    // MARK: - Save to Contacts

    static func saveToContacts(
        parsed: ParsedContact,
        meetingNote: String?,
        store: CNContactStore = CNContactStore()
    ) -> String? {
        let nameParts = splitFullName(parsed.fullName)
        let mutable = CNMutableContact()
        mutable.givenName = nameParts.first
        mutable.familyName = nameParts.last
        if let job = parsed.jobTitle { mutable.jobTitle = job }
        if let org = parsed.organization { mutable.organizationName = org }
        if let email = parsed.email {
            mutable.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = parsed.phone {
            mutable.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))
            ]
        }
        if let website = parsed.website {
            mutable.urlAddresses = [CNLabeledValue(label: CNLabelHome, value: website as NSString)]
        }
        if let imageData = parsed.imageData, !imageData.isEmpty {
            mutable.imageData = imageData
        }
        if let note = meetingNote, EquilibriumConfig.contactsNotesEnabled {
            mutable.note = note
        }

        let request = CNSaveRequest()
        request.add(mutable, toContainerWithIdentifier: nil)

        do {
            try store.execute(request)
            return mutable.identifier
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func splitFullName(_ name: String) -> (first: String, last: String) {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count <= 1 {
            return (name, "")
        }
        let first = parts[0]
        let last = parts.dropFirst().joined(separator: " ")
        return (first, last)
    }

    private static func valueAfterColon(_ line: String) -> String? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colonIndex)...])
        return unescape(value)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func unescape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
