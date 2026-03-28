//
//  EditStockValuationView.swift
//  financeplan
//
//  Created by Fernando Correia on 11.03.26.
//

import StockPlanShared
import SwiftUI

struct EditStockValuationView: View {
  private enum Field: Hashable {
    case bearLow, bearHigh, baseLow, baseHigh, bullLow, bullHigh, targetDate, rationale
  }

  let symbol: String
  let existing: StockValuationRequest?
  let onSave: @MainActor (StockValuationDraft) async -> String?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
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
  @State private var successFeedbackTrigger = 0

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
    VStack(spacing: 0) {
      FormSheetHeader(
        title: "Edit Valuation",
        subtitle: symbol,
        onDismiss: { dismiss() }
      )

      ScrollView {
        VStack(spacing: 16) {
          // Symbol tag
          HStack {
            FormInfoTag(text: symbol, icon: "chart.line.uptrend.xyaxis")
            Spacer()
          }

          // MARK: - Bear Case
          scenarioCard(
            title: "Bear Case",
            icon: "arrow.down.right",
            color: AppTheme.Colors.danger,
            lowText: $bearLow,
            highText: $bearHigh,
            lowField: .bearLow,
            highField: .bearHigh
          )

          // MARK: - Base Case
          scenarioCard(
            title: "Base Case",
            icon: "arrow.right",
            color: AppTheme.Colors.tint(for: colorScheme),
            lowText: $baseLow,
            highText: $baseHigh,
            lowField: .baseLow,
            highField: .baseHigh
          )

          // MARK: - Bull Case
          scenarioCard(
            title: "Bull Case",
            icon: "arrow.up.right",
            color: AppTheme.Colors.success,
            lowText: $bullLow,
            highText: $bullHigh,
            lowField: .bullLow,
            highField: .bullHigh
          )

          // MARK: - Extra
          FormCard(title: "Extra") {
            FormTextField(
              icon: "calendar",
              iconColor: .orange,
              placeholder: "Target date (YYYY-MM-DD)",
              text: $targetDate,
              autocapitalization: .never
            )
            .focused($focusedField, equals: .targetDate)

            FormDivider()

            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 12) {
                Image(systemName: "text.quote")
                  .font(.subheadline.weight(.medium))
                  .foregroundStyle(.secondary)
                  .frame(width: 24, alignment: .center)

                Text("Rationale")
                  .typography(.caption)
                  .foregroundStyle(.secondary)
              }
              .padding(.horizontal, 16)
              .padding(.top, 13)

              TextEditor(text: $rationale)
                .frame(minHeight: 80)
                .padding(.horizontal, 16)
                .padding(.bottom, 13)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .rationale)
            }
          }

          // MARK: - Error
          if let saveErrorMessage {
            FormErrorBanner(message: saveErrorMessage)
          }

          Spacer(minLength: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)

      FormActionBar(
        primaryLabel: isSaving ? "Saving…" : "Save Valuation",
        isLoading: isSaving,
        isDisabled: !isValid || isSaving
      ) {
        focusedField = nil
        Task { @MainActor in
          await save()
        }
      }
    }
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .appSensoryFeedback(success: successFeedbackTrigger)
  }

  // MARK: - Scenario Card

  private func scenarioCard(
    title: String,
    icon: String,
    color: Color,
    lowText: Binding<String>,
    highText: Binding<String>,
    lowField: Field,
    highField: Field
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // Card header label
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption.weight(.bold))
          .foregroundStyle(color)
        Text(title.uppercased())
          .typography(.caption, weight: .semibold)
          .foregroundStyle(color)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 8)

      FormCard {
        HStack(spacing: 12) {
          Image(systemName: "arrow.down")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color.opacity(0.7))
            .frame(width: 24, alignment: .center)

          TextField("Low price", text: lowText)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: lowField)
            .typography(.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)

        FormDivider()

        HStack(spacing: 12) {
          Image(systemName: "arrow.up")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color.opacity(0.7))
            .frame(width: 24, alignment: .center)

          TextField("High price", text: highText)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: highField)
            .typography(.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
      }
    }
  }

  // MARK: - Validation & Save

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
    guard let bearCase, let baseCase, let bullCase else { return }

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

    if let message = await onSave(draft) {
      saveErrorMessage = message
    } else {
      successFeedbackTrigger += 1
      dismiss()
    }
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
