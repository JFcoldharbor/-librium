import Contacts
import Foundation

@MainActor
final class ImportantDatesService: ObservableObject {
    static let shared = ImportantDatesService()

    @Published private(set) var customDates: [ImportantDate] = []

    private let store: JSONStore
    private static let storageKey = "equilibrium.life.importantDates.custom"

    init(store: JSONStore = .shared) {
        self.store = store
        load()
    }

    func load() {
        customDates = store.load([ImportantDate].self, key: Self.storageKey) ?? []
    }

    func upsert(_ date: ImportantDate) {
        if let idx = customDates.firstIndex(where: { $0.id == date.id }) {
            customDates[idx] = date
        } else {
            customDates.append(date)
        }
        persist()
    }

    func delete(id: String) {
        customDates.removeAll { $0.id == id }
        persist()
    }

    func loadUpcoming(within days: Int = 90, now: Date = Date()) async -> [ImportantDate] {
        var dates: [ImportantDate] = customDates

        if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
            let contactsDates = await Self.loadContactDates()
            dates.append(contentsOf: contactsDates)
        }

        for project in ProjectsService.shared.activeProjects where project.deadline != nil {
            dates.append(ImportantDate(
                id: "project-\(project.id.uuidString)",
                title: "\(project.name) deadline",
                date: project.deadline!,
                recurrence: .once,
                source: .projectDeadline,
                relatedContactName: nil,
                relatedContactId: nil,
                icon: "📁",
                note: project.detail
            ))
        }

        return dates
            .filter { date in
                let until = date.daysUntil(now: now)
                return until >= 0 && until <= days
            }
            .sorted { $0.daysUntil(now: now) < $1.daysUntil(now: now) }
    }

    private static func loadContactDates() async -> [ImportantDate] {
        await Task.detached { () -> [ImportantDate] in
            var result: [ImportantDate] = []
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactBirthdayKey as CNKeyDescriptor,
                CNContactDatesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)

            try? store.enumerateContacts(with: request) { contact, _ in
                let name = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard !name.isEmpty else { return }

                if var bday = contact.birthday {
                    if bday.year == nil { bday.year = 2000 }
                    if let date = Calendar.current.date(from: bday) {
                        result.append(ImportantDate(
                            id: "contact-bday-\(contact.identifier)",
                            title: "\(name)'s birthday",
                            date: date,
                            recurrence: .yearly,
                            source: .contactBirthday,
                            relatedContactName: name,
                            relatedContactId: contact.identifier,
                            icon: "🎂",
                            note: nil
                        ))
                    }
                }

                for labeledDate in contact.dates {
                    let comps = labeledDate.value as DateComponents
                    var fullComps = comps
                    if fullComps.year == nil { fullComps.year = 2000 }
                    guard let date = Calendar.current.date(from: fullComps) else { continue }

                    let labelRaw = labeledDate.label ?? ""
                    let isAnniversary = labelRaw == CNLabelDateAnniversary
                    let displayLabel: String = isAnniversary
                        ? "anniversary"
                        : CNLabeledValue<NSDateComponents>.localizedString(forLabel: labelRaw).lowercased()

                    result.append(ImportantDate(
                        id: "contact-date-\(contact.identifier)-\(labelRaw)",
                        title: "\(name)'s \(displayLabel)",
                        date: date,
                        recurrence: .yearly,
                        source: isAnniversary ? .contactAnniversary : .contactCustomDate,
                        relatedContactName: name,
                        relatedContactId: contact.identifier,
                        icon: isAnniversary ? "💍" : "🎉",
                        note: nil
                    ))
                }
            }
            return result
        }.value
    }

    private func persist() {
        store.save(customDates, key: Self.storageKey)
    }
}
