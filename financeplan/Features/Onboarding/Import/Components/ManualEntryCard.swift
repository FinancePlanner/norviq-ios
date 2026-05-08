//
//  ManualEntryCard.swift
//  financeplan
//
import StockPlanShared
import SwiftUI

struct ManualEntryCard: View {
  @Binding var entry: ManualEntry
  let index: Int
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var focusedField: EntryField?

  private enum EntryField { case symbol, quantity, price }

  var body: some View {
    VStack(spacing: 0) {
      // Header row
      HStack {
        Text("Position \(index)")
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)

        Spacer()

        Button(action: onDelete) {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary.opacity(0.5))
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 10)

      // Symbol
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("Symbol (e.g. AAPL)", text: $entry.symbol)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled(true)
          .focused($focusedField, equals: .symbol)
          .submitLabel(.next)
          .onSubmit { focusedField = .quantity }
          .typography(.label, weight: .semibold)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        AppTheme.Colors.elevatedCardBackground(for: colorScheme)
          .opacity(0.6)
      )

      Divider().padding(.leading, 16).opacity(0.3)

      // Quantity & Price row
      HStack(spacing: 0) {
        HStack(spacing: 8) {
          Text("Qty")
            .typography(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 28, alignment: .leading)

          TextField("0", text: $entry.quantity)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .quantity)
            .typography(.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider().frame(height: 28).opacity(0.3)

        HStack(spacing: 8) {
          Text("Price")
            .typography(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 36, alignment: .leading)

          TextField("0.00", text: $entry.price)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .price)
            .typography(.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .background(
        AppTheme.Colors.elevatedCardBackground(for: colorScheme)
          .opacity(0.6)
      )
    }
    .appGlassEffect(.rect(cornerRadius: 18))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}
