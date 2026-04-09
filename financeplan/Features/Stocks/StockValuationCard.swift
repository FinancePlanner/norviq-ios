//
//  StockValuationCard.swift
//  financeplan
//
//  Created by Fernando Correia on 11.03.26.
//

import SwiftUI
import StockPlanShared

struct StockValuationCard: View {
    let valuation: StockValuationRequest?

    let onEditTapped: () -> Void

    var body: some View {
        Section("Valuation") {
            VStack(alignment: .leading, spacing: 12) {
                valuationRow(title: "Bear", range: valuation?.bearCase)
                valuationRow(title: "Bull", range: valuation?.bullCase)
                valuationRow(title: "Base", range: valuation?.baseCase)

                if let targetDate = valuation?.targetDate, !targetDate.isEmpty {
                    LabeledContent("Target date", value: targetDate)
                }

                if let rationale = valuation?.rationale, !rationale.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rationale")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(rationale)
                    }
                }
                Button("Edit Valuation", action: onEditTapped)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@ViewBuilder
private func valuationRow(title: String, range: PriceRange?) -> some View {
    HStack {
        Text(title)
            .fontWeight(.semibold)

        Spacer()

        if let range {
            Text("$\(range.low, specifier: "%.2f") - $\(range.high, specifier: "%.2f")")
                            .monospacedDigit()
                    } else {
                        Text("Not set")
                            .foregroundStyle(.secondary)
                    }
    }
}
