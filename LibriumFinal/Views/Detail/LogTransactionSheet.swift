import SwiftUI

struct LogTransactionSheet: View {
    let prefilledDirection: MoneyTransaction.Direction?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = TransactionsService.shared

    @State private var direction: MoneyTransaction.Direction = .expense
    @State private var amountText: String = ""
    @State private var category: String = ""
    @State private var source: String = ""
    @State private var note: String = ""
    @State private var occurredAt: Date = Date()

    private let expenseCategories = ["Food", "Transport", "Subscription", "Healthcare", "Housing", "Entertainment", "Shopping", "Other"]
    private let incomeCategories = ["Gig", "Client", "Salary", "Refund", "Other"]

    init(prefilledDirection: MoneyTransaction.Direction? = nil) {
        self.prefilledDirection = prefilledDirection
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                Form {
                    Section {
                        Picker("Type", selection: $direction) {
                            Text("Expense").tag(MoneyTransaction.Direction.expense)
                            Text("Income").tag(MoneyTransaction.Direction.income)
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Amount") {
                        TextField("$", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .heavy))
                    }

                    Section(direction == .income ? "Source" : "Category") {
                        TextField(direction == .income ? "e.g. DoorDash, Acme Corp" : "e.g. Food, Transport", text: direction == .income ? $source : $category)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(direction == .income ? incomeCategories : expenseCategories, id: \.self) { suggestion in
                                    Button {
                                        if direction == .income {
                                            source = suggestion
                                        } else {
                                            category = suggestion
                                        }
                                    } label: {
                                        Text(suggestion)
                                            .font(.system(size: 11, weight: .semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Capsule().fill(EquilibriumColor.CardTint.financial.opacity(0.18)))
                                            .foregroundColor(EquilibriumColor.CardTint.financial)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Section("Note (optional)") {
                        TextField("What for?", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section("When") {
                        DatePicker("Date", selection: $occurredAt)
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
                    Text("Log transaction")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.heavy)
                        .foregroundColor(EquilibriumColor.CardTint.financial)
                        .disabled(parsedAmount == nil)
                }
            }
            .onAppear {
                if let prefilled = prefilledDirection {
                    direction = prefilled
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.financial.opacity(0.20),
                    EquilibriumColor.CardTint.financial.opacity(0.05),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var parsedAmount: Double? {
        let cleaned = amountText.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let tx = MoneyTransaction(
            id: UUID(),
            amount: amount,
            direction: direction,
            category: trimmedCategory.isEmpty ? nil : trimmedCategory,
            source: trimmedSource.isEmpty ? nil : trimmedSource,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            occurredAt: occurredAt,
            createdAt: Date()
        )
        service.upsert(tx)
        dismiss()
    }
}
