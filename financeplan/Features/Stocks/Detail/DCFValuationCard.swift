import StockPlanShared
import SwiftUI

struct DCFValuationCard: View {
    let basePrice: Double
    let bearPrice: Double
    let bullPrice: Double
    let currentPrice: Double
    var onEdit: (() -> Void)? = nil
    var onApplyToValuation: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Intrinsic valuation (DCF)")
                            .typography(.small, weight: .semibold)

                        Text("Discounted cash flow (DCF) fair value estimates based on the projected explicit cash flows and the Gordon Growth terminal value.")
                            .typography(.nano)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        if let onApplyToValuation {
                            Button(action: onApplyToValuation) {
                                Text("Apply")
                                    .typography(.caption, weight: .semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                            .accessibilityLabel("Apply DCF values to valuation")
                        }

                        if let onEdit {
                            Button(action: onEdit) {
                                Text("Edit")
                                    .typography(.caption, weight: .semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    dcfBlock(title: "Bear case", value: bearPrice)
                    dcfBlock(title: "Base case", value: basePrice)
                    dcfBlock(title: "Bull case", value: bullPrice)
                }
            }
        }
    }

    private func dcfBlock(title: String, value: Double) -> some View {
        let isUpside = value > currentPrice
        let color: Color = isUpside ? .green : .red

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .typography(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

            Text(value.currency)
                .typography(.label, weight: .bold)

            HStack(spacing: 2) {
                Image(systemName: isUpside ? "arrow.up.right" : "arrow.down.right")
                Text(StockMetricFormatter.percentText((value - currentPrice) / currentPrice))
            }
            .typography(.caption, weight: .semibold)
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
