import Foundation

struct UserProfile: Codable, Equatable {
    var fullName: String
    var jobTitle: String?
    var organization: String?
    var email: String
    var phone: String?
    var website: String?

    static let empty = UserProfile(
        fullName: "",
        jobTitle: nil,
        organization: nil,
        email: "",
        phone: nil,
        website: nil
    )

    var hasMinimumFields: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var displaySubtitle: String? {
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
