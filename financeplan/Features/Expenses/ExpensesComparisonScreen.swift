import Charts
import SwiftUI
import StockPlanShared

struct ExpensesComparisonScreen: View {
  @Binding var isSettingsPresented: Bool
  @ObservedObject var viewModel: BudgetPlannerViewModel

  @Environment(\.colorScheme) private var colorScheme
  @State private var isProfilePresented = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          NetWorthCard()
          CashFlowCard()
          AssetAllocationCard()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
      }
      .background(Color(uiColor: .systemBackground).ignoresSafeArea())
      .navigationTitle("Financial Insights & Reports")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button {
            isSettingsPresented = true
          } label: {
            Image(systemName: "gearshape")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              .padding(6)
              .appGlassEffect(.capsule)
          }
          .accessibilityLabel("Open settings")

          AppTopBarProfileButton(
            isUserMenuPresented: isProfilePresented,
            onTap: { isProfilePresented = true }
          )
          .accessibilityLabel("Open profile")
        }
      }
      .sheet(isPresented: $isProfilePresented) {
        UserProfileView()
      }
    }
  }
}

// MARK: - Net Worth Card

private struct NetWorthCard: View {
  var body: some View {
    GlassCard(cornerRadius: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Net Worth")
            .font(.headline)
          Text("$124,830.42")
            .font(.system(size: 34, weight: .bold, design: .rounded))
        }
        Spacer()
        HStack(spacing: 4) {
          Image(systemName: "arrow.up.right")
          Text("+2.31%")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.green)
      }
    }
  }
}

// MARK: - Cash Flow Card

private struct CashFlowData: Identifiable {
  let id = UUID()
  let month: String
  let income: Double
  let expenses: Double
}

private struct CashFlowCard: View {
  let data: [CashFlowData] = [
    .init(month: "Nov", income: 5000, expenses: 3100),
    .init(month: "Dec", income: 6500, expenses: 4000),
    .init(month: "Jan", income: 5400, expenses: 3800),
    .init(month: "Feb", income: 6200, expenses: 4200),
    .init(month: "Mar", income: 6800, expenses: 4700),
    .init(month: "Apr", income: 7400, expenses: 5000)
  ]
  
  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 16) {
        Text("Cash Flow (Last 6 Months)")
          .font(.headline)
        
        Chart {
          ForEach(data) { item in
            BarMark(
              x: .value("Month", item.month),
              y: .value("Amount", item.income)
            )
            .foregroundStyle(Color.green)
            .position(by: .value("Type", "Income"))
            
            BarMark(
              x: .value("Month", item.month),
              y: .value("Amount", item.expenses)
            )
            .foregroundStyle(Color.red)
            .position(by: .value("Type", "Expenses"))
          }
        }
        .frame(height: 200)
        .chartYAxis {
          AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Color.white.opacity(0.1))
            AxisValueLabel {
              if let doubleValue = value.as(Double.self) {
                Text("\(Int(doubleValue / 1000))k")
                  .foregroundStyle(Color.secondary)
                  .font(.caption2)
              }
            }
          }
        }
        .chartXAxis {
          AxisMarks(values: .automatic) { _ in
            AxisValueLabel().foregroundStyle(Color.secondary).font(.caption2)
          }
        }
        
        HStack(spacing: 16) {
          Spacer()
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
              .fill(Color.green)
              .frame(width: 12, height: 12)
            Text("Income (Green)")
              .font(.caption)
          }
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
              .fill(Color.red)
              .frame(width: 12, height: 12)
            Text("Expenses (Red)")
              .font(.caption)
          }
          Spacer()
        }
      }
    }
  }
}

// MARK: - Asset Allocation Card

private struct AssetAllocationData: Identifiable {
  let id = UUID()
  let category: String
  let percentage: Double
  let color: Color
}

private struct AssetAllocationCard: View {
  let data: [AssetAllocationData] = [
    .init(category: "Stocks", percentage: 55, color: .blue),
    .init(category: "Bonds", percentage: 25, color: .orange),
    .init(category: "Crypto", percentage: 10, color: .purple),
    .init(category: "Cash", percentage: 10, color: .green)
  ]
  
  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 20) {
        Text("Diversification (Asset Allocation)")
          .font(.headline)
        
        HStack(spacing: 20) {
          if #available(iOS 17.0, *) {
            Chart(data) { item in
              SectorMark(
                angle: .value("Percentage", item.percentage),
                innerRadius: .ratio(0.0),
                angularInset: 1.0
              )
              .foregroundStyle(item.color)
              .annotation(position: .overlay) {
                VStack(spacing: 2) {
                  Text(item.category)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                  Text("\(Int(item.percentage))%")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                }
              }
            }
            .frame(height: 180)
            .chartLegend(.hidden)
          } else {
             Circle()
                 .fill(Color.blue)
                 .frame(height: 180)
          }
          
          VStack(alignment: .leading, spacing: 12) {
            ForEach(data) { item in
              HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                  .fill(item.color)
                  .frame(width: 12, height: 12)
                Text(item.category)
                  .font(.subheadline)
              }
            }
          }
        }
      }
    }
  }
}
