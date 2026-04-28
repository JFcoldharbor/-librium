import AVFoundation
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @State private var showResetConfirm = false
    @State private var errorMessage: String?
    @State private var selectedOpenAIVoice: OpenAITTSService.Voice = .coral

    private var openAIAvailable: Bool { !Secrets.openAIAPIKey.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        operatorSection
                        accountSection
                        voiceSection
                        notificationsSection
                        debugSection
                        aboutSection
                        dataSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.85))
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(EquilibriumColor.primaryText)
                }
            }
            .task {
                await notificationService.refreshAuthStatus()
                selectedOpenAIVoice = OpenAITTSService.shared.selectedVoice
            }
            .alert("Reset all data?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) { resetAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deletes journal entries, breathing sessions, wellness logs, focus sessions, and Maria's memories. Cannot be undone.")
            }
        }
    }

    private var operatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("OPERATOR")

            NavigationLink(destination: ObligationsSettingsView()) {
                operatorRow(
                    title: "Bills & obligations",
                    subtitle: obligationsSubtitle,
                    systemImage: "list.bullet.rectangle"
                )
            }

            NavigationLink(destination: IncomeSourcesSettingsView()) {
                operatorRow(
                    title: "Income sources",
                    subtitle: incomeSubtitle,
                    systemImage: "dollarsign.circle"
                )
            }

            NavigationLink(destination: PipelineSettingsView()) {
                operatorRow(
                    title: "Sales pipeline",
                    subtitle: pipelineSubtitle,
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }

            NavigationLink(destination: ProjectsSettingsView()) {
                operatorRow(
                    title: "Projects",
                    subtitle: projectsSubtitle,
                    systemImage: "folder"
                )
            }
        }
    }

    private var pipelineSubtitle: String {
        let active = PipelineService.shared.activeDeals.count
        let weighted = PipelineService.shared.totalWeightedValue
        if active == 0 { return "Add prospects & clients" }
        return "\(active) active · $\(formatThousands(weighted)) weighted"
    }

    private var projectsSubtitle: String {
        let active = ProjectsService.shared.activeProjects.count
        if active == 0 { return "Add long-term goals" }
        return "\(active) active"
    }

    private func formatThousands(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private var obligationsSubtitle: String {
        let count = ObligationsService.shared.obligations.count
        let due7 = ObligationsService.shared.totalDue(within: 7)
        if count == 0 { return "Add your bills" }
        return "\(count) total · $\(Int(due7)) due in 7d"
    }

    private var incomeSubtitle: String {
        let count = IncomeSourcesService.shared.sources.count
        if count == 0 { return "Add how you make money" }
        return "\(count) source\(count == 1 ? "" : "s")"
    }

    private func operatorRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .frame(width: 24)
                .foregroundColor(EquilibriumColor.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
        .padding(12)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ACCOUNT")

            if EquilibriumConfig.bypassAuth {
                Text("Auth bypassed for development.")
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .padding(.vertical, 4)
            } else if let user = authService.currentUser {
                row(label: "Email", value: user.email ?? "(none)")
                row(label: "User ID", value: String(user.uid.prefix(8)) + "…")

                Button(action: signOut) {
                    Text("Sign Out")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(EquilibriumColor.primaryText.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                .padding(.top, 8)
            } else {
                Text("Not signed in.")
                    .font(.system(size: 14))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MARIA'S VOICE")

            if openAIAvailable {
                openAIVoicePicker
                Text("Premium OpenAI voices. Falls back to iOS if the network fails.")
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.tertiaryText)
                    .padding(.top, 4)
            } else {
                Text("Add your OpenAI API key in Secrets.swift to unlock natural voices.")
                    .font(.system(size: 13))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
        }
    }

    private var openAIVoicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Voice", selection: Binding(
                get: { selectedOpenAIVoice },
                set: { newValue in
                    selectedOpenAIVoice = newValue
                    OpenAITTSService.shared.setSelectedVoice(newValue)
                }
            )) {
                ForEach(OpenAITTSService.Voice.allCases, id: \.self) { voice in
                    Text("\(voice.displayName) · \(voice.description)").tag(voice)
                }
            }
            .pickerStyle(.menu)
            .tint(EquilibriumColor.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EquilibriumColor.primaryText.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            Button(action: { SpeechSynthesizerService.shared.previewOpenAI(selectedOpenAIVoice) }) {
                Label("Preview voice", systemImage: "play.circle")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(EquilibriumColor.primaryText.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .foregroundColor(EquilibriumColor.primaryText)
            }
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("NOTIFICATIONS")

            if notificationService.authStatus == .denied {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications disabled.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Text("Enable in Settings → Equilibrium → Notifications.")
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                .padding(.vertical, 4)
            } else {
                toggleRow(
                    title: "Morning intention",
                    subtitle: "8:00 AM daily",
                    isOn: notificationService.preferences.morningIntention
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setMorningIntention(enabled: $0)
                    } }
                }

                toggleRow(
                    title: "Evening reflection",
                    subtitle: "8:00 PM daily",
                    isOn: notificationService.preferences.eveningReflection
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setEveningReflection(enabled: $0)
                    } }
                }

                toggleRow(
                    title: "Hydration",
                    subtitle: "Every 2 hours, 9 AM – 7 PM",
                    isOn: notificationService.preferences.hydrationReminders
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setHydrationReminders(enabled: $0)
                    } }
                }

                toggleRow(
                    title: "Breathing",
                    subtitle: "3:00 PM daily",
                    isOn: notificationService.preferences.breathingReminder
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setBreathingReminder(enabled: $0)
                    } }
                }

                toggleRow(
                    title: "Meeting heads-up",
                    subtitle: "5 min before each calendar event",
                    isOn: notificationService.preferences.meetingHeadsUp
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setMeetingHeadsUp(enabled: $0)
                    } }
                }

                toggleRow(
                    title: "Bill reminders",
                    subtitle: "24h before each unpaid bill",
                    isOn: notificationService.preferences.billReminders
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setBillReminders(enabled: $0)
                    } }
                }

                toggleRow(
                    title: "Follow-up reminders",
                    subtitle: "When a contact's follow-up is due",
                    isOn: notificationService.preferences.followUpReminders
                ) { enabled in
                    Task { await applyToggle(enabled: enabled) {
                        await notificationService.setFollowUpReminders(enabled: $0)
                    } }
                }
            }
        }
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DEBUG")

            NavigationLink(destination: ConversationLogView()) {
                operatorRow(
                    title: "Conversation log",
                    subtitle: "\(ConversationLogService.shared.turns.count) turns captured",
                    systemImage: "bubble.left.and.bubble.right"
                )
            }

            Button(action: resetMemories) {
                operatorRow(
                    title: "Reset Maria's memories",
                    subtitle: "Wipe \(MemoryService.shared.loadAll().count) stored memories",
                    systemImage: "brain"
                )
            }
            .buttonStyle(.plain)

            Button(action: resetConversationContext) {
                operatorRow(
                    title: "Reset conversation context",
                    subtitle: "Clear short-term turn buffer (use if Maria gets confused)",
                    systemImage: "arrow.counterclockwise"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func resetMemories() {
        MemoryService.shared.deleteAll()
    }

    private func resetConversationContext() {
        MariaService.shared.clearRecentTurns()
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ABOUT")
            row(label: "App", value: "Equilibrium")
            row(label: "Version", value: appVersion)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DATA")
            Button(action: { showResetConfirm = true }) {
                Text("Reset all data")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(Color.red.opacity(0.9))
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundColor(EquilibriumColor.tertiaryText)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(EquilibriumColor.primaryText)
        }
        .padding(.vertical, 6)
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Bool,
        action: @escaping (Bool) -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(EquilibriumColor.primaryText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(EquilibriumColor.secondaryText)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: action))
                .labelsHidden()
                .tint(EquilibriumColor.accent)
        }
        .padding(.vertical, 6)
    }

    private func applyToggle(enabled: Bool, apply: @escaping (Bool) async -> Void) async {
        if enabled && notificationService.authStatus == .notDetermined {
            let granted = await notificationService.requestAuthorization()
            if !granted { return }
        }
        await apply(enabled)
    }

    private func signOut() {
        do {
            try authService.signOut()
            SpeechSynthesizerService.shared.stop()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetAll() {
        let keys = [
            "equilibrium.life.journal.entries",
            "equilibrium.life.breathing.sessions",
            "equilibrium.life.wellness.logs",
            "equilibrium.work.focus.sessions",
            "equilibrium.maria.memories",
            "equilibrium.notifications.preferences",
            "equilibrium.voice.identifier",
            "equilibrium.openai.voice",
            "equilibrium.nav.lifeCardIndex",
            "equilibrium.nav.workCardIndex"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        dismiss()
    }
}
