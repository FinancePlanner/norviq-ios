import SwiftUI

/// The image people post. Reads only percentages from the model — never
/// `marketValue` — so it is safe to share by construction.
struct PortfolioShareCard: View {
  let model: PortfolioOnePageModel
  let totalReturnPercent: Double?
  let dayChangePercent: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      Text("My portfolio")
        .font(.system(size: 64, weight: .bold))
      HStack(spacing: 48) {
        stat("Total return", totalReturnPercent)
        stat("Today", dayChangePercent)
      }
      VStack(spacing: 14) {
        ForEach(model.rows) { row in
          HStack {
            Text(row.symbol).font(.system(size: 36, weight: .semibold))
            Spacer()
            Text(String(format: "%.1f%%", row.weightPercent))
              .font(.system(size: 36).monospacedDigit())
            Text(Self.signed(row.unrealizedPnlPercent))
              .font(.system(size: 32).monospacedDigit())
              .foregroundStyle(Self.color(row.unrealizedPnlPercent))
              .frame(width: 220, alignment: .trailing)
          }
        }
        if let other = model.otherWeightPercent {
          HStack {
            Text("Other").font(.system(size: 32)).foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.1f%%", other)).font(.system(size: 32)).foregroundStyle(.secondary)
          }
        }
      }
      Spacer(minLength: 0)
      Text("norviq.org").font(.system(size: 30, weight: .medium)).foregroundStyle(.secondary)
    }
    .padding(72)
    .frame(width: 1080, height: 1350, alignment: .topLeading)
    .background(Color(.systemBackground))
  }

  private func stat(_ label: String, _ value: Double?) -> some View {
    VStack(alignment: .leading) {
      Text(label).font(.system(size: 28)).foregroundStyle(.secondary)
      Text(Self.signed(value))
        .font(.system(size: 52, weight: .bold).monospacedDigit())
        .foregroundStyle(Self.color(value))
    }
  }

  static func signed(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%+.2f%%", value)
  }

  static func color(_ value: Double?) -> Color {
    guard let value else { return .secondary }
    return value >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger
  }
}
