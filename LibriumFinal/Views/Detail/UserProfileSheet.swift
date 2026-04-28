import SwiftUI

struct UserProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = UserProfileService.shared

    @State private var fullName: String = ""
    @State private var jobTitle: String = ""
    @State private var organization: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var website: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                background

                Form {
                    Section("Identity") {
                        TextField("Full name", text: $fullName)
                            .textInputAutocapitalization(.words)
                        TextField("Job title", text: $jobTitle)
                        TextField("Organization", text: $organization)
                    }
                    Section("Reach") {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Website / LinkedIn URL", text: $website)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Section(footer: Text("This is what you share when you swap cards. Stored on this device only.")) {
                        EmptyView()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("My card")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundColor(EquilibriumColor.CardTint.network)
                        .disabled(!isValid)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.network.opacity(0.18),
                    EquilibriumColor.CardTint.network.opacity(0.04),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func hydrate() {
        let p = service.profile
        fullName = p.fullName
        jobTitle = p.jobTitle ?? ""
        organization = p.organization ?? ""
        email = p.email
        phone = p.phone ?? ""
        website = p.website ?? ""
    }

    private func save() {
        let trimmedJob = jobTitle.trimmingCharacters(in: .whitespaces)
        let trimmedOrg = organization.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedSite = website.trimmingCharacters(in: .whitespaces)
        let profile = UserProfile(
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            jobTitle: trimmedJob.isEmpty ? nil : trimmedJob,
            organization: trimmedOrg.isEmpty ? nil : trimmedOrg,
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
            website: trimmedSite.isEmpty ? nil : trimmedSite
        )
        service.save(profile)
        dismiss()
    }
}
