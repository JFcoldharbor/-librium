import SwiftUI

struct ObligationsSettingsView: View {
    @ObservedObject private var service = ObligationsService.shared
    @State private var editingObligation: Obligation?
    @State private var showAddForm = false

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard

                    Button(action: { showAddForm = true }) {
                        Label("Add bill", systemImage: "plus.circle")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(EquilibriumColor.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(EquilibriumColor.primaryText)
                    }

                    if service.obligations.isEmpty {
                        emptyState
                    } else {
                        ForEach(service.obligations.sorted { $0.dueDate < $1.dueDate }) { obligation in
                            obligationRow(obligation)
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Bills & Obligations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddForm) {
            ObligationFormView(obligation: nil)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingObligation) { obligation in
            ObligationFormView(obligation: obligation)
                .preferredColorScheme(.dark)
        }
    }

    private var summaryCard: some View {
        let due7 = service.totalDue(within: 7)
        let due30 = service.totalDue(within: 30)
        return HStack {
            statBlock(value: "$\(Int(due7))", label: "due in 7d")
            Spacer()
            statBlock(value: "$\(Int(due30))", label: "due in 30d")
            Spacer()
            statBlock(value: "\(service.obligations.count)", label: "total")
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

    private func obligationRow(_ obligation: Obligation) -> some View {
        Button(action: { editingObligation = obligation }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(obligation.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                        .lineLimit(1)
                    Text(dueLabel(for: obligation))
                        .font(.system(size: 12))
                        .foregroundColor(dueColor(for: obligation))
                }
                Spacer()
                Text("$\(formatAmount(obligation.amount))")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(EquilibriumColor.primaryText)

                if obligation.isPaidThisCycle {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green.opacity(0.85))
                } else {
                    Button(action: { service.markPaid(id: obligation.id) }) {
                        Image(systemName: "circle")
                            .font(.system(size: 22))
                            .foregroundColor(EquilibriumColor.primaryText.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func dueLabel(for obligation: Obligation) -> String {
        let days = obligation.daysUntilDue()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: obligation.dueDate)

        if obligation.isPaidThisCycle {
            return "Paid · next \(dateStr)"
        }
        if days < 0 {
            return "OVERDUE · \(abs(days))d ago"
        }
        if days == 0 { return "Due today · \(dateStr)" }
        if days == 1 { return "Due tomorrow · \(dateStr)" }
        return "Due in \(days)d · \(dateStr)"
    }

    private func dueColor(for obligation: Obligation) -> Color {
        if obligation.isPaidThisCycle { return EquilibriumColor.tertiaryText }
        if obligation.isOverdue { return .red.opacity(0.85) }
        let days = obligation.daysUntilDue()
        if days <= 3 { return .orange }
        if days <= 7 { return .yellow }
        return EquilibriumColor.secondaryText
    }

    private func formatAmount(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.2f", amount)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No bills yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add your recurring bills so Maria knows what's due and when.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

private struct ObligationFormView: View {
    let obligation: Obligation?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = ObligationsService.shared

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var dueDate: Date = Date()
    @State private var recurrence: Obligation.Recurrence = .monthly
    @State private var category: Obligation.Category = .other
    @State private var consequences: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                Form {
                    Section("Bill") {
                        TextField("Title (e.g. Rent, Verizon)", text: $title)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }

                    Section("Schedule") {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                        Picker("Recurrence", selection: $recurrence) {
                            ForEach(Obligation.Recurrence.allCases, id: \.self) { r in
                                Text(r.label).tag(r)
                            }
                        }
                    }

                    Section("Category") {
                        Picker("Category", selection: $category) {
                            ForEach(Obligation.Category.allCases, id: \.self) { c in
                                Text(c.label).tag(c)
                            }
                        }
                    }

                    Section("If missed (optional)") {
                        TextField("Consequences if late or skipped", text: $consequences, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if obligation != nil {
                        Section {
                            Button("Delete bill", role: .destructive) {
                                if let id = obligation?.id {
                                    service.delete(id: id)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(obligation == nil ? "Add bill" : "Edit bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(EquilibriumColor.primaryText)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amountText.isEmpty)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let o = obligation else { return }
        title = o.title
        amountText = String(format: "%.2f", o.amount)
        dueDate = o.dueDate
        recurrence = o.recurrence
        category = o.category
        consequences = o.consequencesIfMissed ?? ""
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        let trimmedConsequences = consequences.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = Obligation(
            id: obligation?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            amount: amount,
            dueDate: dueDate,
            recurrence: recurrence,
            category: category,
            consequencesIfMissed: trimmedConsequences.isEmpty ? nil : trimmedConsequences,
            isPaidThisCycle: obligation?.isPaidThisCycle ?? false
        )
        service.upsert(item)
        dismiss()
    }
}
