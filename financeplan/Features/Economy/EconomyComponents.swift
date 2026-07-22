import StockPlanShared
import SwiftUI

// MARK: - Coverage chips

struct EconomyCoverageChips: View {
  let coverage: [String]

  var body: some View {
    if !coverage.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(coverage, id: \.self) { tag in
            Text(tag.replacingOccurrences(of: "_", with: " ").capitalized)
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(Color.primary.opacity(0.08), in: Capsule())
              .foregroundStyle(.secondary)
          }
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Coverage: \(coverage.joined(separator: ", "))")
    }
  }
}

// MARK: - Indicator gauge row

struct EconomyIndicatorRow: View {
  let indicator: MacroIndicatorDTO

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(indicator.name)
          .font(.callout)
        Text("As of \(indicator.asOf)")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 1) {
        Text(Self.formatValue(indicator))
          .font(.callout.weight(.semibold).monospacedDigit())
        if let change = indicator.changeFromPrevious {
          Text(Self.formatChange(change, unit: indicator.unit))
            .font(.caption2)
            .foregroundStyle(change >= 0 ? Color.red : Color.green)
        }
      }
    }
  }

  static func formatValue(_ indicator: MacroIndicatorDTO) -> String {
    switch indicator.unit.lowercased() {
    case "percent", "%", "pp", "percentage_points":
      return String(format: "%.2f%%", indicator.value)
    case "thousands":
      return indicator.value.formatted(.number.precision(.fractionLength(0))) + "k"
    case "index", "count", "persons", "claims":
      return indicator.value.formatted(.number.precision(.fractionLength(indicator.value.rounded() == indicator.value ? 0 : 1)))
    default:
      return String(format: "%.2f", indicator.value)
    }
  }

  static func formatChange(_ change: Double, unit: String) -> String {
    let prefix = change > 0 ? "+" : ""
    switch unit.lowercased() {
    case "percent", "%", "pp", "percentage_points":
      return "\(prefix)\(String(format: "%.2f", change))pp"
    default:
      return "\(prefix)\(String(format: "%.2f", change))"
    }
  }
}

// MARK: - Material card chrome (matches MacroScreen)

struct EconomyMaterialCard<Content: View>: View {
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      content()
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

struct EconomyMetaFooter: View {
  let asOf: String
  let source: String
  var currency: String? = nil

  var body: some View {
    Group {
      if let currency {
        Text("As of \(asOf) • \(source) • \(currency)")
      } else {
        Text("As of \(asOf) • \(source)")
      }
    }
    .font(.caption2)
    .foregroundStyle(.tertiary)
  }
}
