import StockPlanShared
import SwiftUI

struct EarningsFlowVisualizer: View {
    let symbol: String
    let statements: [IncomeStatementResponse]
    var isLoading: Bool = false

    @State private var selectedDate: String?

    private var selectedStatement: IncomeStatementResponse? {
        if let selectedDate,
           let statement = statements.first(where: { $0.date == selectedDate }) {
            return statement
        }
        return statements.first
    }

    private var selectedDateBinding: Binding<String> {
        Binding(
            get: { selectedDate ?? statements.first?.date ?? "" },
            set: { selectedDate = $0 }
        )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isLoading && statements.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else if let selectedStatement, let model = EarningsFlowModel(statement: selectedStatement) {
                    summary(model)
                    flow(model)
                    expenseBreakdown(model)
                } else {
                    ResearchPlaceholderCard(
                        title: "Income statement unavailable",
                        bodyText: "Revenue, expense, and net income flow will appear here when statement data is available for \(symbol)."
                    )
                }
            }
        }
        .onChange(of: statements) { _, updated in
            guard let selectedDate else { return }
            if !updated.contains(where: { $0.date == selectedDate }) {
                self.selectedDate = updated.first?.date
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Earnings visualizer")
                    .typography(.label, weight: .bold)
                Text("Income statement flow from revenue to net income.")
                    .typography(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if statements.count > 1 {
                Picker("Filing", selection: selectedDateBinding) {
                    ForEach(statements, id: \.date) { statement in
                        Text(filingLabel(statement))
                            .tag(statement.date)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func summary(_ model: EarningsFlowModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.symbol)
                    .typography(.title, weight: .bold)
                Text(model.filingLabel)
                    .typography(.nano)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let eps = model.eps {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("EPS")
                        .typography(.nano, weight: .semibold)
                        .foregroundStyle(.secondary)
                    Text("\(model.currency) \(eps.formatted(.number.precision(.fractionLength(2))))")
                        .typography(.label, weight: .bold)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }

    private func flow(_ model: EarningsFlowModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 10) {
                FlowNode(metric: model.revenue, maxValue: model.revenue.rawValue)
                FlowConnector()
                VStack(spacing: 8) {
                    FlowNode(metric: model.grossProfit, maxValue: model.revenue.rawValue)
                    FlowNode(metric: model.costOfRevenue, maxValue: model.revenue.rawValue)
                }
                FlowConnector()
                VStack(spacing: 8) {
                    FlowNode(metric: model.operatingIncome, maxValue: model.revenue.rawValue)
                    FlowNode(metric: model.operatingExpenses, maxValue: model.revenue.rawValue)
                }
                FlowConnector()
                VStack(spacing: 8) {
                    FlowNode(metric: model.netIncome, maxValue: model.revenue.rawValue)
                    if let tax = model.tax {
                        FlowNode(metric: tax, maxValue: model.revenue.rawValue)
                    }
                    if let other = model.other {
                        FlowNode(metric: other, maxValue: model.revenue.rawValue)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func expenseBreakdown(_ model: EarningsFlowModel) -> some View {
        if !model.expenseBreakdown.isEmpty {
            HStack(spacing: 8) {
                ForEach(model.expenseBreakdown) { metric in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric.title)
                            .typography(.nano, weight: .semibold)
                            .foregroundStyle(.secondary)
                        Text(metric.formattedValue(currency: model.currency))
                            .typography(.caption, weight: .bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: .rect(cornerRadius: 12))
                }
            }
        }
    }

    private func filingLabel(_ statement: IncomeStatementResponse) -> String {
        var parts: [String] = []
        if let period = statement.period, !period.isEmpty {
            parts.append(period)
        }
        if let fiscalYear = statement.fiscalYear, !fiscalYear.isEmpty {
            parts.append("FY \(fiscalYear)")
        }
        let prefix = parts.isEmpty ? statement.symbol : parts.joined(separator: " ")
        return "\(prefix) · \(formatDisplayDate(statement.date))"
    }

    private func formatDisplayDate(_ rawDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: String(rawDate.prefix(10))) else { return rawDate }
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

private struct FlowNode: View {
    let metric: EarningsFlowMetric
    let maxValue: Double

    private var minHeight: CGFloat {
        let ratio = abs(metric.rawValue) / max(maxValue, 1)
        return 58 + min(CGFloat(ratio) * 120, 120)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.title)
                .typography(.nano, weight: .semibold)
                .foregroundStyle(.secondary)
            Text(metric.formattedValue(currency: metric.currency))
                .typography(.label, weight: .bold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let subtitle = metric.subtitle {
                Text(subtitle)
                    .typography(.nano)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 128)
        .frame(minHeight: minHeight, alignment: .center)
        .padding(12)
        .background(metric.tint.opacity(0.12), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(metric.tint.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct FlowConnector: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .frame(width: 22)
    }
}

private struct EarningsFlowModel {
    let symbol: String
    let currency: String
    let filingLabel: String
    let eps: Double?
    let revenue: EarningsFlowMetric
    let grossProfit: EarningsFlowMetric
    let costOfRevenue: EarningsFlowMetric
    let operatingIncome: EarningsFlowMetric
    let operatingExpenses: EarningsFlowMetric
    let netIncome: EarningsFlowMetric
    let tax: EarningsFlowMetric?
    let other: EarningsFlowMetric?
    let expenseBreakdown: [EarningsFlowMetric]

    init?(statement: IncomeStatementResponse) {
        guard let revenueValue = statement.revenue, revenueValue > 0 else { return nil }

        let currency = if let reportedCurrency = statement.reportedCurrency, !reportedCurrency.isEmpty {
            reportedCurrency
        } else {
            "USD"
        }
        let grossProfit = statement.grossProfit ?? subtract(statement.revenue, statement.costOfRevenue)
        let costOfRevenue = statement.costOfRevenue ?? subtract(statement.revenue, grossProfit)
        let operatingIncome = statement.operatingIncome ?? statement.ebit
        let operatingExpenses = statement.operatingExpenses ?? subtract(grossProfit, operatingIncome)
        let netIncome = statement.netIncome ?? statement.bottomLineNetIncome ?? statement.netIncomeFromContinuingOperations
        let other = statement.totalOtherIncomeExpensesNet ?? subtract(operatingIncome, netIncome)

        guard
            let grossProfit,
            let costOfRevenue,
            let operatingIncome,
            let operatingExpenses,
            let netIncome
        else { return nil }

        self.symbol = statement.symbol
        self.currency = currency
        self.filingLabel = Self.filingLabel(statement)
        self.eps = statement.eps
        self.revenue = EarningsFlowMetric(title: "Revenue", rawValue: revenueValue, subtitle: nil, tint: .blue, currency: currency)
        self.grossProfit = EarningsFlowMetric(title: "Gross profit", rawValue: grossProfit, subtitle: margin(grossProfit, revenueValue), tint: .green, currency: currency)
        self.costOfRevenue = EarningsFlowMetric(title: "Cost of revenue", rawValue: costOfRevenue, subtitle: margin(costOfRevenue, revenueValue), tint: .red, currency: currency)
        self.operatingIncome = EarningsFlowMetric(title: "Operating income", rawValue: operatingIncome, subtitle: margin(operatingIncome, revenueValue), tint: .green, currency: currency)
        self.operatingExpenses = EarningsFlowMetric(title: "Operating expenses", rawValue: operatingExpenses, subtitle: margin(operatingExpenses, revenueValue), tint: .red, currency: currency)
        self.netIncome = EarningsFlowMetric(title: "Net income", rawValue: netIncome, subtitle: margin(netIncome, revenueValue), tint: .green, currency: currency)
        tax = statement.incomeTaxExpense.map {
            EarningsFlowMetric(title: "Tax", rawValue: $0, subtitle: margin($0, revenueValue), tint: .orange, currency: currency)
        }
        self.other = other.map {
            EarningsFlowMetric(title: "Other", rawValue: $0, subtitle: margin($0, revenueValue), tint: .secondary, currency: currency)
        }

        let sga = statement.sellingGeneralAndAdministrativeExpenses
            ?? statement.generalAndAdministrativeExpenses
            ?? statement.sellingAndMarketingExpenses
        expenseBreakdown = [
            statement.researchAndDevelopmentExpenses.map {
                EarningsFlowMetric(title: "R&D", rawValue: $0, subtitle: nil, tint: .purple, currency: currency)
            },
            sga.map {
                EarningsFlowMetric(title: "SG&A", rawValue: $0, subtitle: nil, tint: .teal, currency: currency)
            }
        ].compactMap { $0 }
    }

    private static func filingLabel(_ statement: IncomeStatementResponse) -> String {
        var parts: [String] = []
        if let period = statement.period, !period.isEmpty {
            parts.append(period)
        }
        if let fiscalYear = statement.fiscalYear, !fiscalYear.isEmpty {
            parts.append("FY \(fiscalYear)")
        }
        let prefix = parts.isEmpty ? statement.symbol : parts.joined(separator: " ")
        return "\(prefix) · \(statement.date)"
    }
}

private struct EarningsFlowMetric: Identifiable {
    let id = UUID()
    let title: String
    let rawValue: Double
    let subtitle: String?
    let tint: Color
    let currency: String

    func formattedValue(currency: String) -> String {
        "\(currency) \(compactNumber(abs(rawValue)))"
    }
}

private func compactNumber(_ value: Double) -> String {
    let divisor: Double
    let suffix: String
    switch value {
    case 1_000_000_000...:
        divisor = 1_000_000_000
        suffix = "B"
    case 1_000_000...:
        divisor = 1_000_000
        suffix = "M"
    case 1_000...:
        divisor = 1_000
        suffix = "K"
    default:
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
    return (value / divisor).formatted(.number.precision(.fractionLength(2))) + suffix
}

private func subtract(_ lhs: Double?, _ rhs: Double?) -> Double? {
    guard let lhs, let rhs else { return nil }
    return lhs - rhs
}

private func margin(_ value: Double, _ revenue: Double) -> String? {
    guard revenue > 0 else { return nil }
    let formatted = ((value / revenue) * 100).formatted(.number.precision(.fractionLength(1)))
    return "\(formatted)% margin"
}
