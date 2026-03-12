//
//  EditStockValuationView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.03.26.
//

import SwiftUI
import StockPlanShared

struct EditStockValuationView: View {
    let symbol: String
    let existing: StockValuationRequest?
    let onSave: (StockValuationRequest) async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var bearLow: String
    @State private var bearHigh: String
    @State private var baseLow: String
    @State private var baseHigh: String
    @State private var bullLow: String
    @State private var bullHigh: String
    @State private var targetDate: String
    @State private var rationale: String
    @State private var isSaving = false

    init(
        symbol: String,
        existing: StockValuationRequest? = nil,
        onSave: @escaping (StockValuationRequest) async -> Void
    ) {
        self.symbol = symbol
        self.existing = existing
        self.onSave = onSave

        _bearLow = State(initialValue: Self.stringValue(existing?.bearCase.low))
        _bearHigh = State(initialValue: Self.stringValue(existing?.bearCase.high))
        _baseLow = State(initialValue: Self.stringValue(existing?.baseCase.low))
        _baseHigh = State(initialValue: Self.stringValue(existing?.baseCase.high))
        _bullLow = State(initialValue: Self.stringValue(existing?.bullCase.low))
        _bullHigh = State(initialValue: Self.stringValue(existing?.bullCase.high))
        _targetDate = State(initialValue: existing?.targetDate ?? "")
        _rationale = State(initialValue: existing?.rationale ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bear case") {
                    priceField("Low price", text: $bearLow)
                    priceField("High price", text: $bearHigh)
                }

                Section("Base case") {
                    priceField("Low price", text: $baseLow)
                    priceField("High price", text: $baseHigh)
                }

                Section("Bull case") {
                    priceField("Low price", text: $bullLow)
                    priceField("High price", text: $bullHigh)
                }

                Section("Extra") {
                    TextField("Target date (YYYY-MM-DD)", text: $targetDate)
                    TextField("Rationale", text: $rationale, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit valuation")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task {
                            await save()
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }

    private var bearCase: PriceRange? {
        priceRange(lowText: bearLow, highText: bearHigh)
    }

    private var baseCase: PriceRange? {
        priceRange(lowText: baseLow, highText: baseHigh)
    }

    private var bullCase: PriceRange? {
        priceRange(lowText: bullLow, highText: bullHigh)
    }

    private var isValid: Bool {
        bearCase != nil && baseCase != nil && bullCase != nil
    }

    private func priceField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
    }

    private func priceRange(lowText: String, highText: String) -> PriceRange? {
        guard
            let low = Double(lowText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let high = Double(highText.trimmingCharacters(in: .whitespacesAndNewlines)),
            low <= high
        else {
            return nil
        }

        return PriceRange(low: low, high: high)
    }

    private func save() async {
        guard
            let bearCase,
            let baseCase,
            let bullCase
        else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        let request = StockValuationRequest(
            symbol: symbol,
            bearCase: bearCase,
            baseCase: baseCase,
            bullCase: bullCase,
            rationale: normalizedOptional(rationale),
            targetDate: normalizedOptional(targetDate)
        )

        await onSave(request)
        dismiss()
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringValue(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(value)
    }
}
