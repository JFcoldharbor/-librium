import SwiftUI

struct TransactionsListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = TransactionsService.shared

    @State private var loggingDirection: MoneyTransaction.Direction?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if service.transactions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(EquilibriumColor.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Ledger")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(EquilibriumColor.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            loggingDirection = .income
                        } label: {
                            Label("Log income", systemImage: "plus.circle.fill")
                        }
                        Button {
                            loggingDirection = .expense
                        } label: {
                            Label("Log expense", systemImage: "minus.circle.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(EquilibriumColor.CardTint.financial)
                    }
                }
            }
            .sheet(item: $loggingDirection) { direction in
                LogTransactionSheet(prefilledDirection: direction)
                    .preferredColorScheme(.dark)
            }
        }
    }

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.financial.opacity(0.18),
                    EquilibriumColor.CardTint.financial.opacity(0.04),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }

    private var list: some View {
        List {
            ForEach(service.transactions) { tx in
                row(tx)
                    .listRowBackground(EquilibriumColor.primaryText.opacity(0.04))
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    service.delete(id: service.transactions[idx].id)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ tx: MoneyTransaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tx.direction == .income ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(tx.direction == .income ? EquilibriumColor.CardTint.health : Color.red.opacity(0.85))

            VStack(alignment: .leading, spacing: 2) {
                Text(primaryLabel(tx))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(EquilibriumColor.primaryText)
                    .lineLimit(1)
                Text(secondaryLabel(tx))
                    .font(.system(size: 11))
                    .foregroundColor(EquilibriumColor.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(tx.direction == .income ? "+" : "−")$\(Int(tx.amount))")
                .font(.system(size: 15, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(tx.direction == .income ? EquilibriumColor.CardTint.health : .red.opacity(0.85))
        }
        .padding(.vertical, 4)
    }

    private func primaryLabel(_ tx: MoneyTransaction) -> String {
        if tx.direction == .income {
            return tx.source ?? "Income"
        }
        return tx.category ?? "Expense"
    }

    private func secondaryLabel(_ tx: MoneyTransaction) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        let datePart = f.string(from: tx.occurredAt)
        if let note = tx.note, !note.isEmpty {
            return "\(datePart) · \(note)"
        }
        return datePart
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 80)
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 36))
                .foregroundColor(EquilibriumColor.CardTint.financial.opacity(0.6))
            Text("No transactions yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
            Text("Tap + to log income or expenses, or tell Maria.")
                .font(.system(size: 13))
                .foregroundColor(EquilibriumColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
