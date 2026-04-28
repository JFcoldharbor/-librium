import SwiftUI

struct PipelineSettingsView: View {
    @ObservedObject private var service = PipelineService.shared
    @State private var editingDeal: PipelineDeal?
    @State private var showAddForm = false

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard

                    Button(action: { showAddForm = true }) {
                        Label("Add deal", systemImage: "plus.circle")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(EquilibriumColor.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(EquilibriumColor.primaryText)
                    }

                    if service.deals.isEmpty {
                        emptyState
                    } else {
                        ForEach(service.deals.sorted { $0.weightedValue > $1.weightedValue }) { deal in
                            dealRow(deal)
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Sales Pipeline")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddForm) {
            PipelineDealFormView(deal: nil)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingDeal) { deal in
            PipelineDealFormView(deal: deal)
                .preferredColorScheme(.dark)
        }
    }

    private var summaryCard: some View {
        HStack {
            statBlock(value: "$\(formatThousands(service.totalActiveValue))", label: "active value")
            Spacer()
            statBlock(value: "$\(formatThousands(service.totalWeightedValue))", label: "weighted")
            Spacer()
            statBlock(value: "\(service.activeDeals.count)", label: "active")
        }
        .padding(16)
        .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(EquilibriumColor.tertiaryText)
        }
    }

    private func dealRow(_ deal: PipelineDeal) -> some View {
        Button(action: { editingDeal = deal }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(deal.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Text("$\(formatThousands(deal.dealValue))")
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                HStack(spacing: 8) {
                    stageBadge(deal.stage)
                    Text("\(Int(deal.probability * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(EquilibriumColor.secondaryText)
                    Text("·")
                        .foregroundColor(EquilibriumColor.tertiaryText)
                    Text(deal.contactName)
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.secondaryText)
                        .lineLimit(1)
                }
                if let action = deal.nextAction, !action.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 10))
                        Text(action)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundColor(EquilibriumColor.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func stageBadge(_ stage: PipelineDeal.Stage) -> some View {
        Text(stage.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(stageColor(stage).opacity(0.2), in: Capsule())
            .foregroundColor(stageColor(stage))
    }

    private func stageColor(_ stage: PipelineDeal.Stage) -> Color {
        switch stage {
        case .lead: return EquilibriumColor.tertiaryText
        case .qualified: return Color.yellow
        case .proposal: return Color.orange
        case .negotiation: return EquilibriumColor.accent
        case .closedWon: return Color.green
        case .closedLost: return Color.red.opacity(0.7)
        }
    }

    private func formatThousands(_ value: Double) -> String {
        if value >= 1000 {
            let k = value / 1000
            return String(format: "%.1fk", k)
        }
        return String(format: "%.0f", value)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No deals yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add prospects and clients so Maria can route you to who's ready to close.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

private struct PipelineDealFormView: View {
    let deal: PipelineDeal?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = PipelineService.shared

    @State private var name: String = ""
    @State private var contactName: String = ""
    @State private var contactEmail: String = ""
    @State private var stage: PipelineDeal.Stage = .lead
    @State private var dealValueText: String = ""
    @State private var probabilityText: String = "50"
    @State private var nextAction: String = ""
    @State private var hasNextActionDate: Bool = false
    @State private var nextActionDate: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                Form {
                    Section("Deal") {
                        TextField("Name (e.g. Acme - Q3 contract)", text: $name)
                        TextField("Contact name", text: $contactName)
                        TextField("Contact email (optional)", text: $contactEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    Section("Stage") {
                        Picker("Stage", selection: $stage) {
                            ForEach(PipelineDeal.Stage.allCases, id: \.self) { s in
                                Text(s.label).tag(s)
                            }
                        }
                    }

                    Section("Value") {
                        TextField("Deal value ($)", text: $dealValueText)
                            .keyboardType(.decimalPad)
                        TextField("Probability of close (%)", text: $probabilityText)
                            .keyboardType(.decimalPad)
                    }

                    Section("Next action") {
                        TextField("e.g. Send revised proposal", text: $nextAction)
                        Toggle("Has due date", isOn: $hasNextActionDate)
                        if hasNextActionDate {
                            DatePicker("Due", selection: $nextActionDate, displayedComponents: .date)
                        }
                    }

                    Section("Notes") {
                        TextField("Anything Maria should know", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if deal != nil {
                        Section {
                            Button("Delete deal", role: .destructive) {
                                if let id = deal?.id {
                                    service.delete(id: id)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(deal == nil ? "Add deal" : "Edit deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(EquilibriumColor.primaryText)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || contactName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let d = deal else { return }
        name = d.name
        contactName = d.contactName
        contactEmail = d.contactEmail ?? ""
        stage = d.stage
        dealValueText = String(format: "%.0f", d.dealValue)
        probabilityText = String(Int(d.probability * 100))
        nextAction = d.nextAction ?? ""
        if let date = d.nextActionDate {
            hasNextActionDate = true
            nextActionDate = date
        }
        notes = d.notes ?? ""
    }

    private func save() {
        let value = Double(dealValueText.replacingOccurrences(of: ",", with: "")) ?? 0
        let probPct = Double(probabilityText) ?? 50
        let probability = max(0, min(1, probPct / 100))
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = nextAction.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        let item = PipelineDeal(
            id: deal?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            contactName: contactName.trimmingCharacters(in: .whitespaces),
            contactEmail: trimmedEmail.isEmpty ? nil : trimmedEmail.lowercased(),
            stage: stage,
            dealValue: value,
            probability: probability,
            nextAction: trimmedAction.isEmpty ? nil : trimmedAction,
            nextActionDate: hasNextActionDate ? nextActionDate : nil,
            lastContact: deal?.lastContact,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            createdAt: deal?.createdAt ?? Date()
        )
        service.upsert(item)
        dismiss()
    }
}
