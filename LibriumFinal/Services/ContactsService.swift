import Contacts
import Foundation

struct ContactSummary: Equatable, Identifiable {
    let id: String
    let displayName: String
    let jobTitle: String?
    let organization: String?
    let note: String?
    let primaryEmail: String?
    let primaryPhone: String?
    let imageData: Data?

    var role: String? {
        switch (jobTitle, organization) {
        case let (job?, org?) where !job.isEmpty && !org.isEmpty:
            return "\(job) at \(org)"
        case let (job?, _) where !job.isEmpty:
            return job
        case let (_, org?) where !org.isEmpty:
            return org
        default:
            return nil
        }
    }
}

@MainActor
final class ContactsService: ObservableObject {
    static let shared = ContactsService()

    enum AccessState {
        case unknown, denied, authorized
    }

    @Published private(set) var accessState: AccessState

    private let store = CNContactStore()
    private var emailIndex: [String: ContactSummary] = [:]
    private var allContacts: [ContactSummary] = []
    private var indexBuiltAt: Date?
    private let indexTTL: TimeInterval = 60

    private init() {
        accessState = Self.map(CNContactStore.authorizationStatus(for: .contacts))
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            accessState = granted ? .authorized : .denied
        } catch {
            accessState = .denied
        }
    }

    func invalidateIndex() {
        indexBuiltAt = nil
    }

    func findContact(byEmail email: String) async -> ContactSummary? {
        await ensureIndex()
        return emailIndex[email.lowercased()]
    }

    func loadAllContacts() async -> [ContactSummary] {
        await ensureIndex()
        return allContacts
    }

    func findContact(byId id: String) async -> ContactSummary? {
        await ensureIndex()
        return allContacts.first { $0.id == id }
    }

    private func ensureIndex() async {
        if let built = indexBuiltAt, Date().timeIntervalSince(built) < indexTTL {
            return
        }
        guard accessState == .authorized else { return }

        var keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactImageDataAvailableKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        if EquilibriumConfig.contactsNotesEnabled {
            keys.append(CNContactNoteKey as CNKeyDescriptor)
        }

        let request = CNContactFetchRequest(keysToFetch: keys)

        var index: [String: ContactSummary] = [:]
        var all: [ContactSummary] = []
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let fullName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let display: String = !fullName.isEmpty
                    ? fullName
                    : (contact.organizationName.isEmpty ? "Unknown" : contact.organizationName)

                var noteValue: String? = nil
                if EquilibriumConfig.contactsNotesEnabled {
                    let raw = contact.note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !raw.isEmpty {
                        noteValue = raw
                    }
                }

                let primaryEmail = (contact.emailAddresses.first?.value as String?)?.lowercased()
                let primaryPhone = contact.phoneNumbers.first?.value.stringValue
                let imageData: Data? = contact.imageDataAvailable ? contact.thumbnailImageData : nil

                let summary = ContactSummary(
                    id: contact.identifier,
                    displayName: display,
                    jobTitle: contact.jobTitle.isEmpty ? nil : contact.jobTitle,
                    organization: contact.organizationName.isEmpty ? nil : contact.organizationName,
                    note: noteValue,
                    primaryEmail: (primaryEmail?.isEmpty ?? true) ? nil : primaryEmail,
                    primaryPhone: (primaryPhone?.isEmpty ?? true) ? nil : primaryPhone,
                    imageData: imageData
                )
                all.append(summary)
                for emailAddr in contact.emailAddresses {
                    let email = (emailAddr.value as String).lowercased()
                    if !email.isEmpty {
                        index[email] = summary
                    }
                }
            }
            emailIndex = index
            allContacts = all.sorted { $0.displayName < $1.displayName }
            indexBuiltAt = Date()
        } catch {
            // Silent — accessState gates use; failures leave index empty
        }
    }

    private static func map(_ status: CNAuthorizationStatus) -> AccessState {
        switch status {
        case .authorized: return .authorized
        case .denied, .restricted: return .denied
        default: return .unknown
        }
    }
}
