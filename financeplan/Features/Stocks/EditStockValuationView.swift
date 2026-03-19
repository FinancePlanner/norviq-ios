//
//  EditStockValuationView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.03.26.
//

import SwiftUI
import StockPlanShared

struct EditStockValuationView: View {
    private enum Field: Hashable {
        case bearLow
        case bearHigh
        case baseLow
        case baseHigh
        case bullLow
        case bullHigh
        case targetDate
        case rationale
    }

    let symbol: String
    let existing: StockValuationRequest?
    let onSave: @MainActor (StockValuationDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var bearLow: String
    @State private var bearHigh: String
    @State private var baseLow: String
    @State private var baseHigh: String
    @State private var bullLow: String
    @State private var bullHigh: String
    @State private var targetDate: String
    @State private var rationale: String
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    init(
        symbol: String,
        existing: StockValuationRequest? = nil,
        onSave: @escaping @MainActor (StockValuationDraft) async -> String?
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
                    priceField("Low price", text: $bearLow, field: .bearLow)
                    priceField("High price", text: $bearHigh, field: .bearHigh)
                }

                Section("Base case") {
                    priceField("Low price", text: $baseLow, field: .baseLow)
                    priceField("High price", text: $baseHigh, field: .baseHigh)
                }

                Section("Bull case") {
                    priceField("Low price", text: $bullLow, field: .bullLow)
                    priceField("High price", text: $bullHigh, field: .bullHigh)
                }

                Section("Extra") {
                    TextField("Target date (YYYY-MM-DD)", text: $targetDate)
                        .focused($focusedField, equals: .targetDate)
                        .textInputAutocapitalization(.never)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rationale")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $rationale)
                            .frame(minHeight: 96)
                            .focused($focusedField, equals: .rationale)
                    }
                }
            }
            .navigationTitle("Edit valuation")
            .scrollDismissesKeyboard(.interactively)
            .alert("Unable to Save Valuation", isPresented: saveErrorIsPresented) {
                Button("OK", role: .cancel) {
                    saveErrorMessage = nil
                }
            } message: {
                Text(saveErrorMessage ?? "Something went wrong while saving this valuation.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        focusedField = nil
                        Task { @MainActor in
                            await save()
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
        }
    }

    private var bearCase: (low: Double, high: Double)? {
        priceRange(lowText: bearLow, highText: bearHigh)
    }

    private var baseCase: (low: Double, high: Double)? {
        priceRange(lowText: baseLow, highText: baseHigh)
    }

    private var bullCase: (low: Double, high: Double)? {
        priceRange(lowText: bullLow, highText: bullHigh)
    }

    private var isValid: Bool {
        bearCase != nil && baseCase != nil && bullCase != nil
    }

    private func priceField(_ title: String, text: Binding<String>, field: Field) -> some View {
        TextField(title, text: text)
            .focused($focusedField, equals: field)
            .keyboardType(.decimalPad)
    }

    private func priceRange(lowText: String, highText: String) -> (low: Double, high: Double)? {
        guard
            let low = Double(lowText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let high = Double(highText.trimmingCharacters(in: .whitespacesAndNewlines)),
            low <= high
        else {
            return nil
        }

        return (low: low, high: high)
    }

    @MainActor
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

        let draft = StockValuationDraft(
            bearLow: bearCase.low,
            bearHigh: bearCase.high,
            baseLow: baseCase.low,
            baseHigh: baseCase.high,
            bullLow: bullCase.low,
            bullHigh: bullCase.high,
            rationale: normalizedOptional(rationale),
            targetDate: normalizedOptional(targetDate)
        )

        print(
            """
            Valuation draft \
            bearLow=\(draft.bearLow) bearHigh=\(draft.bearHigh) \
            baseLow=\(draft.baseLow) baseHigh=\(draft.baseHigh) \
            bullLow=\(draft.bullLow) bullHigh=\(draft.bullHigh) \
            rationale=\(draft.rationale ?? "<nil>") \
            targetDate=\(draft.targetDate ?? "<nil>")
            """
        )

        if let message = await onSave(draft) {
            saveErrorMessage = message
        } else {
            dismiss()
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    saveErrorMessage = nil
                }
            }
        )
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
