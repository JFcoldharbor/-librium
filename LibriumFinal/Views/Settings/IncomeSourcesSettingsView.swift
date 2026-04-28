import SwiftUI

struct IncomeSourcesSettingsView: View {
    @ObservedObject private var service = IncomeSourcesService.shared
    @State private var editingSource: IncomeSource?
    @State private var showAddForm = false

    var body: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { showAddForm = true }) {
                        Label("Add income source", systemImage: "plus.circle")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(EquilibriumColor.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(EquilibriumColor.primaryText)
                    }

                    if service.sources.isEmpty {
                        emptyState
                    } else {
                        ForEach(service.sources) { source in
                            sourceRow(source)
                        }
                    }

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Income Sources")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddForm) {
            IncomeSourceFormView(source: nil)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $editingSource) { source in
            IncomeSourceFormView(source: source)
                .preferredColorScheme(.dark)
        }
    }

    private func sourceRow(_ source: IncomeSource) -> some View {
        Button(action: { editingSource = source }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(source.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                    Spacer()
                    Text(rateLabel(for: source))
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                HStack(spacing: 8) {
                    typeBadge(source.type.label)
                    Text(source.reliability.label)
                        .font(.system(size: 11))
                        .foregroundColor(EquilibriumColor.secondaryText)
                    Spacer()
                    Text(source.monthlyEstimateLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(EquilibriumColor.CardTint.financial)
                }
                if let notes = source.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                        .italic()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EquilibriumColor.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func rateLabel(for source: IncomeSource) -> String {
        let formatted: String
        if source.typicalRate >= 1000 {
            formatted = "$\(Int(source.typicalRate))"
        } else {
            formatted = String(format: "$%.0f", source.typicalRate)
        }
        return "\(formatted) \(source.rateUnit.label)"
    }

    private func typeBadge(_ label: String) -> some View {
        Text(label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(EquilibriumColor.accent.opacity(0.2), in: Capsule())
            .foregroundColor(EquilibriumColor.accent)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 40))
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text("No income sources yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Add every way you make money so Maria can route you to the right one when bills are tight.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
}

private struct IncomeSourceFormView: View {
    let source: IncomeSource?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = IncomeSourcesService.shared

    @State private var title: String = ""
    @State private var type: IncomeSource.IncomeType = .gig
    @State private var rateText: String = ""
    @State private var rateUnit: IncomeSource.RateUnit = .hourly
    @State private var reliability: IncomeSource.Reliability = .immediate
    @State private var monthlyFrequencyText: String = ""
    @State private var notes: String = ""

    private var needsFrequency: Bool {
        rateUnit == .hourly || rateUnit == .perGig
    }

    private var frequencyLabel: String {
        switch rateUnit {
        case .hourly: return "Hours/month"
        case .perGig: return "Times/month"
        default: return ""
        }
    }

    private var monthlyEstimate: Double {
        let rate = Double(rateText.replacingOccurrences(of: ",", with: "")) ?? 0
        let freq = Int(monthlyFrequencyText) ?? 0
        switch rateUnit {
        case .hourly, .perGig: return rate * Double(freq)
        case .monthly: return rate
        case .biweekly: return rate * 2.17
        case .oneTime: return 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EquilibriumColor.background.ignoresSafeArea()

                Form {
                    Section("Source") {
                        TextField("Title (e.g. DoorDash, Acme Corp)", text: $title)
                        Picker("Type", selection: $type) {
                            ForEach(IncomeSource.IncomeType.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                    }

                    Section("Rate") {
                        TextField("Amount", text: $rateText)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $rateUnit) {
                            ForEach(IncomeSource.RateUnit.allCases, id: \.self) { u in
                                Text(u.label).tag(u)
                            }
                        }
                    }

                    if needsFrequency {
                        Section(footer: Text(monthlyEstimate > 0 ? "Monthly tally: $\(Int(monthlyEstimate))" : "Adds up to a monthly total Maria can use.")) {
                            TextField(frequencyLabel, text: $monthlyFrequencyText)
                                .keyboardType(.numberPad)
                        }
                    }

                    Section("Cash flow") {
                        Picker("How fast does it pay?", selection: $reliability) {
                            ForEach(IncomeSource.Reliability.allCases, id: \.self) { r in
                                Text(r.label).tag(r)
                            }
                        }
                    }

                    Section("Notes (optional)") {
                        TextField("Anything Maria should know", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    if source != nil {
                        Section {
                            Button("Delete", role: .destructive) {
                                if let id = source?.id {
                                    service.delete(id: id)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(source == nil ? "Add source" : "Edit source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(EquilibriumColor.primaryText)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || rateText.isEmpty)
                }
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        guard let s = source else { return }
        title = s.title
        type = s.type
        rateText = String(format: "%.2f", s.typicalRate)
        rateUnit = s.rateUnit
        reliability = s.reliability
        if let freq = s.monthlyFrequency, freq > 0 {
            monthlyFrequencyText = String(freq)
        }
        notes = s.notes ?? ""
    }

    private func save() {
        let rate = Double(rateText.replacingOccurrences(of: ",", with: "")) ?? 0
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let frequency = needsFrequency ? Int(monthlyFrequencyText) : nil
        let item = IncomeSource(
            id: source?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            type: type,
            typicalRate: rate,
            rateUnit: rateUnit,
            reliability: reliability,
            monthlyFrequency: frequency,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        service.upsert(item)
        dismiss()
    }
}
