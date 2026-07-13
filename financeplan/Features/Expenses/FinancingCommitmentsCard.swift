import Observation
import StockPlanShared
import SwiftUI

@MainActor
@Observable
private final class FinancingCommitmentsModel {
  var projections: [FinancingProjectionResponse] = []
  var didLoad = false
  private let service: any ExpensesServicing

  init(service: (any ExpensesServicing)? = nil) {
    self.service = service ?? Container.shared.expensesService()
  }

  func load() async {
    guard !didLoad else { return }
    didLoad = true
    projections = (try? await service.getFinancingProjections(from: Self.today, to: nil)) ?? []
  }

  private static var today: String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
  }
}

struct FinancingCommitmentsCard: View {
  let onPlanPurchase: () -> Void
  @State private var model = FinancingCommitmentsModel()

  private var upcoming: [FinancingProjectionResponse] {
    Array(model.projections.filter { $0.status != .cancelled && $0.status != .completed }.prefix(4))
  }

  var body: some View {
    GlassCard(cornerRadius: 20) {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("Upcoming commitments").font(.headline)
            Text("Financed purchases projected into future months").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Button("Plan") { onPlanPurchase() }.buttonStyle(.bordered)
        }
        if upcoming.isEmpty {
          Text("No financed purchases are being tracked.").font(.subheadline).foregroundStyle(.secondary)
        } else {
          ForEach(upcoming) { projection in
            HStack {
              Image(systemName: projection.status == .matched ? "checkmark.circle.fill" : "calendar")
                .foregroundStyle(projection.status == .matched ? .green : .blue)
              VStack(alignment: .leading) {
                Text("Payment \(projection.installmentNumber)").font(.subheadline.weight(.semibold))
                Text(projection.dueDate).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Text(projection.totalAmount.formatted(.currency(code: projection.currency))).font(.subheadline.weight(.semibold))
            }
          }
        }
      }
    }
    .task { await model.load() }
    .accessibilityIdentifier("expenses.financingCommitments")
  }
}
