import SwiftUI

struct ProjectsSettingsView: View {
    @ObservedObject private var service = ProjectsService.shared
    @State private var editingProject: Project?
    @State private var showAddForm = false

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { showAddForm = true }) {
                        Label("Add project", systemImage: "plus.circle")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(EquilibriumColor.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(EquilibriumColor.primaryText)
                    }

                    if service.projects.isEmpty {
                        emptyState
                    } else {
                        ForEach(service.projects) { project in
                            projectRow(project)
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddForm) {
            ProjectFormView(project: nil)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingProject) { project in
            ProjectFormView(project: project)
                .preferredColorScheme(.dark)
        }
    }

    private func projectRow(_ project: Project) -> some View {
        Button(action: { editingProject = project }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Spacer()
                    statusBadge(project.status)
                }
                HStack(spacing: 12) {
                    if let deadline = project.deadline {
                        Label(deadlineLabel(deadline), systemImage: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(deadlineColor(deadline))
                    }
                    if !project.milestones.isEmpty {
                        Label("\(project.completedMilestones)/\(project.milestones.count)", systemImage: "checklist")
                            .font(.system(size: 12))
                            .foregroundColor(EquilibriumColor.secondaryText)
                    }
                }
                if let detail = project.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .italic()
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func statusBadge(_ status: Project.Status) -> some View {
        Text(status.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor(status).opacity(0.2), in: Capsule())
            .foregroundColor(statusColor(status))
    }

    private func statusColor(_ status: Project.Status) -> Color {
        switch status {
        case .active: return EquilibriumColor.accent
        case .paused: return Color.yellow
        case .completed: return Color.green
        case .dropped: return EquilibriumColor.tertiaryText
        }
    }

    private func deadlineLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        if days < 0 { return "OVERDUE · \(f.string(from: date))" }
        if days == 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days)d · \(f.string(from: date))"
    }

    private func deadlineColor(_ date: Date) -> Color {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days < 0 { return .red.opacity(0.85) }
        if days <= 7 { return .orange }
        return EquilibriumColor.secondaryText
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No projects yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add long-term goals so Maria knows what you're building toward.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

private struct ProjectFormView: View {
    let project: Project?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = ProjectsService.shared

    @State private var name: String = ""
    @State private var detail: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date()
    @State private var status: Project.Status = .active
    @State private var milestones: [Project.Milestone] = []
    @State private var newMilestoneName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                Form {
                    Section("Project") {
                        TextField("Name", text: $name)
                        TextField("Description (optional)", text: $detail, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section("Status & deadline") {
                        Picker("Status", selection: $status) {
                            ForEach(Project.Status.allCases, id: \.self) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        Toggle("Has deadline", isOn: $hasDeadline)
                        if hasDeadline {
                            DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                        }
                    }

                    Section("Milestones") {
                        ForEach($milestones) { $milestone in
                            HStack {
                                Button(action: { milestone.isCompleted.toggle() }) {
                                    Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(milestone.isCompleted ? .green : EquilibriumColor.tertiaryText)
                                }
                                .buttonStyle(.plain)
                                TextField("Milestone", text: $milestone.name)
                            }
                        }
                        .onDelete { indices in
                            milestones.remove(atOffsets: indices)
                        }

                        HStack {
                            TextField("Add milestone", text: $newMilestoneName)
                            Button(action: addMilestone) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .disabled(newMilestoneName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    if project != nil {
                        Section {
                            Button("Delete project", role: .destructive) {
                                if let id = project?.id {
                                    service.delete(id: id)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(project == nil ? "Add project" : "Edit project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(EquilibriumColor.primaryText)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { populate() }
    }

    private func addMilestone() {
        let trimmed = newMilestoneName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        milestones.append(Project.Milestone(id: UUID(), name: trimmed, dueDate: nil, isCompleted: false))
        newMilestoneName = ""
    }

    private func populate() {
        guard let p = project else { return }
        name = p.name
        detail = p.detail ?? ""
        if let d = p.deadline {
            hasDeadline = true
            deadline = d
        }
        status = p.status
        milestones = p.milestones
    }

    private func save() {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = Project(
            id: project?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            detail: trimmedDetail.isEmpty ? nil : trimmedDetail,
            deadline: hasDeadline ? deadline : nil,
            status: status,
            milestones: milestones,
            createdAt: project?.createdAt ?? Date()
        )
        service.upsert(item)
        dismiss()
    }
}
