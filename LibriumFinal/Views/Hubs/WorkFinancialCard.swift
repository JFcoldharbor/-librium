import SwiftUI

struct WorkFinancialCard: View {
    @ObservedObject private var pipelineService = PipelineService.shared
    @ObservedObject private var obligationsService = ObligationsService.shared
    @ObservedObject private var incomeService = IncomeSourcesService.shared
    @ObservedObject private var txService = TransactionsService.shared

    @State private var showPipeline = false
    @State private var showObligations = false
    @State private var showIncome = false
    @State private var showTransactions = false
    @State private var loggingDirection: MoneyTransaction.Direction?

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 80)
                    .padding(.bottom, 18)

                ScrollView {
                    VStack(spacing: 18) {
                        heroStrip

                        plCard

                        sectionCard(
                            label: "PIPELINE",
                            count: pipelineService.activeDeals.count,
                            icon: "chart.line.uptrend.xyaxis",
                            tint: EquilibriumColor.CardTint.financial,
                            action: { showPipeline = true }
                        ) {
                            pipelineContent
                        }

                        sectionCard(
                            label: "BILLS",
                            count: dueSoon.count,
                            icon: "calendar.badge.exclamationmark",
                            tint: hasOverdue ? Color.red : EquilibriumColor.CardTint.financial,
                            action: { showObligations = true }
                        ) {
                            obligationsContent
                        }

                        sectionCard(
                            label: "INCOME PATHS",
                            count: incomeService.sources.count,
                            icon: "dollarsign.circle",
                            tint: EquilibriumColor.CardTint.financial,
                            action: { showIncome = true }
                        ) {
                            incomeContent
                        }

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showPipeline) {
            NavigationStack { PipelineSettingsView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showObligations) {
            NavigationStack { ObligationsSettingsView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showIncome) {
            NavigationStack { IncomeSourcesSettingsView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showTransactions) {
            TransactionsListSheet()
                .preferredColorScheme(.dark)
        }
        .sheet(item: $loggingDirection) { direction in
            LogTransactionSheet(prefilledDirection: direction)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Atmosphere

    private var background: some View {
        ZStack {
            EquilibriumColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [
                    EquilibriumColor.CardTint.financial.opacity(0.28),
                    EquilibriumColor.CardTint.financial.opacity(0.07),
                    EquilibriumColor.background
                ],
                center: .top,
                startRadius: 60,
                endRadius: 700
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FINANCIAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(EquilibriumColor.CardTint.financial)
                Spacer()
            }
            Text(headlineCopy)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(EquilibriumColor.primaryText)
        }
    }

    // MARK: - Hero strip

    private var heroStrip: some View {
        HStack(spacing: 12) {
            heroTile(
                label: "WEIGHTED",
                value: formatDollars(pipelineService.totalWeightedValue),
                sub: "pipeline",
                positive: true
            )
            heroTile(
                label: "DUE 7d",
                value: formatDollars(obligationsService.totalDue(within: 7)),
                sub: "\(obligationsService.dueSoon(within: 7).count) bills",
                positive: false
            )
            heroTile(
                label: "DUE 30d",
                value: formatDollars(obligationsService.totalDue(within: 30)),
                sub: "\(obligationsService.dueSoon(within: 30).count) bills",
                positive: false
            )
        }
    }

    private func heroTile(label: String, value: String, sub: String, positive: Bool) -> some View {
        let tint = positive ? EquilibriumColor.CardTint.financial : Color.red.opacity(0.85)
        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundColor(EquilibriumColor.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.system(size: 10))
                .foregroundColor(EquilibriumColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(tint.opacity(0.30), lineWidth: 0.5)
                )
        )
    }

    // MARK: - P/L card

    private var plCard: some View {
        let today = txService.plToday()
        let week = txService.plThisWeek()
        let month = txService.plThisMonth()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EquilibriumColor.CardTint.financial)
                Text("P/L")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(EquilibriumColor.CardTint.financial)
                Spacer()
                Button {
                    loggingDirection = .income
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .heavy))
                        Text("INCOME")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(EquilibriumColor.CardTint.health.opacity(0.18)))
                    .foregroundColor(EquilibriumColor.CardTint.health)
                }
                .buttonStyle(.plain)
                Button {
                    loggingDirection = .expense
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .heavy))
                        Text("EXPENSE")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.18)))
                    .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                plPill(label: "TODAY", income: today.income, expense: today.expense)
                plPill(label: "WEEK", income: week.income, expense: week.expense)
                plPill(label: "MONTH", income: month.income, expense: month.expense)
            }

            Button {
                showTransactions = true
            } label: {
                HStack {
                    Text("View ledger · \(txService.transactions.count) entries")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(EquilibriumColor.tertiaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(EquilibriumColor.CardTint.financial.opacity(0.18), lineWidth: 0.5)
                )
        )
    }

    private func plPill(label: String, income: Double, expense: Double) -> some View {
        let net = income - expense
        let netTint: Color = net >= 0 ? EquilibriumColor.CardTint.health : Color.red.opacity(0.85)
        return VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(EquilibriumColor.tertiaryText)
            Text(formatNet(net))
                .font(.system(size: 18, weight: .heavy))
                .monospacedDigit()
                .foregroundColor(netTint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: 6) {
                Text("+\(Int(income))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(EquilibriumColor.CardTint.health)
                Text("−\(Int(expense))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquilibriumColor.primaryText.opacity(0.04))
        )
    }

    private func formatNet(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "−"
        let abs = Swift.abs(value)
        if abs >= 1000 {
            return String(format: "%@$%.1fk", sign, abs / 1000)
        }
        return "\(sign)$\(Int(abs))"
    }

    // MARK: - Section card

    private func sectionCard<Content: View>(
        label: String,
        count: Int,
        icon: String,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(tint)
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(tint)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(EquilibriumColor.tertiaryText)
                }
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(EquilibriumColor.primaryText.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(tint.opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section content

    @ViewBuilder
    private var pipelineContent: some View {
        let hot = Array(pipelineService.activeDeals.prefix(3))
        if hot.isEmpty {
            inlineEmpty(text: "No active deals. Tell Maria when you get a lead.")
        } else {
            VStack(spacing: 8) {
                ForEach(hot) { deal in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stageColor(deal.stage))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(deal.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(EquilibriumColor.primaryText)
                                .lineLimit(1)
                            Text("\(deal.contactName) · \(deal.stage.label) · \(Int(deal.probability * 100))%")
                                .font(.system(size: 11))
                                .foregroundColor(EquilibriumColor.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(formatDollars(deal.dealValue))
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(EquilibriumColor.primaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var obligationsContent: some View {
        let bills = Array(obligationsService.dueSoon(within: 14).prefix(3))
        if bills.isEmpty {
            inlineEmpty(text: "Nothing due in the next two weeks.")
        } else {
            VStack(spacing: 8) {
                ForEach(bills) { bill in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(bill.isOverdue ? Color.red : Color.orange)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(EquilibriumColor.primaryText)
                                .lineLimit(1)
                            Text(billSubtitle(bill))
                                .font(.system(size: 11))
                                .foregroundColor(bill.isOverdue ? Color.red.opacity(0.85) : EquilibriumColor.secondaryText)
                        }
                        Spacer()
                        Text("$\(Int(bill.amount))")
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(EquilibriumColor.primaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var incomeContent: some View {
        let sources = Array(incomeService.sources.prefix(3))
        if sources.isEmpty {
            inlineEmpty(text: "No income paths logged. Tell Maria how you make money.")
        } else {
            VStack(spacing: 8) {
                ForEach(sources) { source in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(reliabilityColor(source.reliability))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(EquilibriumColor.primaryText)
                                .lineLimit(1)
                            Text("\(source.type.label) · \(source.reliability.label)")
                                .font(.system(size: 11))
                                .foregroundColor(EquilibriumColor.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("$\(Int(source.typicalRate))")
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(EquilibriumColor.primaryText)
                    }
                }
            }
        }
    }

    private func inlineEmpty(text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(EquilibriumColor.tertiaryText)
            .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var dueSoon: [Obligation] {
        obligationsService.dueSoon(within: 14)
    }

    private var hasOverdue: Bool {
        dueSoon.contains(where: { $0.isOverdue })
    }

    private var headlineCopy: String {
        let weighted = pipelineService.totalWeightedValue
        let due7 = obligationsService.totalDue(within: 7)
        if hasOverdue { return "Bills overdue" }
        if due7 > weighted && due7 > 0 { return "Coverage tight" }
        if weighted > 0 || due7 > 0 { return "Money in motion" }
        return "Track what's moving"
    }

    private func billSubtitle(_ bill: Obligation) -> String {
        let days = bill.daysUntilDue()
        if bill.isOverdue { return "OVERDUE · \(bill.recurrence.label)" }
        if days == 0 { return "due today · \(bill.recurrence.label)" }
        if days == 1 { return "due tomorrow · \(bill.recurrence.label)" }
        return "due in \(days)d · \(bill.recurrence.label)"
    }

    private func stageColor(_ stage: PipelineDeal.Stage) -> Color {
        switch stage {
        case .lead: return EquilibriumColor.tertiaryText
        case .qualified: return Color.yellow
        case .proposal: return Color.orange
        case .negotiation: return EquilibriumColor.CardTint.financial
        case .closedWon: return Color.green
        case .closedLost: return Color.red.opacity(0.7)
        }
    }

    private func reliabilityColor(_ reliability: IncomeSource.Reliability) -> Color {
        switch reliability {
        case .immediate: return Color.green
        case .daysOut: return Color.green.opacity(0.7)
        case .weekly, .biweekly: return Color.yellow
        case .monthly: return Color.orange
        case .projectBased: return Color.red.opacity(0.7)
        }
    }

    private func formatDollars(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        }
        if value >= 1000 {
            return String(format: "$%.1fk", value / 1000)
        }
        return "$\(Int(value))"
    }
}
