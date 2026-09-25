import Charts
import SwiftUI

/// The image people post. Reads only percentages from the model — never
/// `marketValue` — so it is safe to share by construction.
struct PortfolioShareCard: View {
  enum Style: String, CaseIterable, Identifiable {
    case list
    case pie
    var id: String { rawValue }
  }

  /// One wedge of the pie: a listed holding, or everything past them as Other.
  struct PieSlice: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let weight: Double
    let color: Color
  }

  let model: PortfolioOnePageModel
  let totalReturnPercent: Double?
  let dayChangePercent: Double?
  var style: Style = .list

  var body: some View {
    VStack(alignment: .leading, spacing: 28) {
      Text("My portfolio")
        .font(.system(size: 64, weight: .bold))
      HStack(spacing: 48) {
        stat("Total return", totalReturnPercent)
        stat("Today", dayChangePercent)
      }
      switch style {
      case .list: list
      case .pie: pie
      }
      Spacer(minLength: 0)
      Text("norviq.org").font(.system(size: 30, weight: .medium)).foregroundStyle(.secondary)
    }
    .padding(72)
    .frame(width: 1080, height: 1350, alignment: .topLeading)
    .background(Color(.systemBackground))
  }

  private var list: some View {
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
  }

  private var pie: some View {
    let slices = Self.pieSlices(for: model)
    return VStack(alignment: .leading, spacing: 36) {
      Chart(slices) { slice in
        SectorMark(
          angle: .value("Weight", slice.weight),
          innerRadius: .ratio(0.56),
          angularInset: 1.5
        )
        .foregroundStyle(slice.color)
      }
      .chartLegend(.hidden)
      .frame(width: 560, height: 560)
      .frame(maxWidth: .infinity)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 32), GridItem(.flexible())], alignment: .leading, spacing: 14) {
        ForEach(slices) { slice in
          HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4).fill(slice.color).frame(width: 24, height: 24)
            Text(slice.label).font(.system(size: 30, weight: .semibold))
            Spacer(minLength: 8)
            Text(String(format: "%.1f%%", slice.weight)).font(.system(size: 30).monospacedDigit())
          }
        }
      }
    }
  }

  /// The listed holdings plus a neutral Other wedge, in list order. Colors are
  /// fixed by position so the legend and wedges always agree.
  static func pieSlices(for model: PortfolioOnePageModel) -> [PieSlice] {
    var slices = model.rows.enumerated().map { index, row in
      PieSlice(label: row.symbol, weight: row.weightPercent, color: palette[index % palette.count])
    }
    if let other = model.otherWeightPercent {
      slices.append(PieSlice(label: "Other", weight: other, color: .gray.opacity(0.55)))
    }
    return slices
  }

  /// Twelve evenly spaced hues, one per listed holding, stepped by 5/12 of the
  /// wheel so neighbouring wedges never sit next to a similar color.
  private static let palette: [Color] = (0..<12).map { index in
    Color(hue: Double(index * 5 % 12) / 12, saturation: 0.62, brightness: 0.88)
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
