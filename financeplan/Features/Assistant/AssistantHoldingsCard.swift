import StockPlanShared
import SwiftUI

// The review card for an `update_holdings` action: holdings Q read from an
// attached file. It follows the trades card: every value is editable, only
// ticked rows are saved, and all text from the backend renders verbatim.

/// Shown in place of the plain confirmation card for `update_holdings`.
struct AssistantHoldingsCard: View {
    @Binding var review: AssistantHoldingsReview
    let isBusy: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    /// "Replace existing" changed. Turning it on resends.
    let onReplaceChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let message = review.completedMessage {
                Label("Done", systemImage: "checkmark.circle").font(.subheadline.weight(.semibold))
                Text(verbatim: message).font(.subheadline)
            } else if let closed = review.closedMessage {
                if closed != AssistantHoldingsReview.maybeSavedCopy {
                    Label("Not applied", systemImage: "xmark.circle").font(.subheadline.weight(.semibold))
                }
                Text(verbatim: closed).font(.subheadline)
            } else {
                header
                ForEach($review.rows) { $row in
                    AssistantHoldingRowEditor(
                        row: $row,
                        problem: review.problem(at: row.id),
                        rowErrors: review.refusal?.byRow[row.id] ?? []
                    )
                }
                .disabled(isBusy)
                footer
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground, in: .rect(cornerRadius: AppTheme.Radius.card))
        .padding(.horizontal, 16)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Review holdings", systemImage: "list.bullet.rectangle").font(.subheadline.weight(.semibold))
            Text(verbatim: review.fromFileText)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            if let expiry = AssistantTradesCard.expiry(review.expiresAt) {
                Text("Expires \(expiry)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let refusal = review.refusal {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: refusal.message)
                    ForEach(Array(refusal.unplaced.enumerated()), id: \.offset) { Text(verbatim: $0.element) }
                }
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.danger)
            }
            if review.showsReplaceToggle {
                Toggle("Replace existing", isOn: Binding(
                    get: { review.replaceExisting },
                    set: { onReplaceChanged($0) }
                ))
                .disabled(isBusy)
            }
            HStack(spacing: 8) {
                Button(review.saveTitle, action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(!review.canSave || isBusy)
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .disabled(isBusy)
                if isBusy { ProgressView().controlSize(.small) }
            }
        }
    }
}

/// One editable row, with its badge.
private struct AssistantHoldingRowEditor: View {
    @Binding var row: AssistantHoldingRow
    let problem: String
    let rowErrors: [String]

    private enum Field: Hashable { case shares, avgPrice }
    @FocusState private var focus: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    row.keep.toggle()
                } label: {
                    Image(systemName: row.keep ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Save \(row.symbol)"))
                .accessibilityAddTraits(row.keep ? .isSelected : [])
                TextField("Symbol", text: $row.symbol)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body.weight(.semibold))
                Text(verbatim: row.badge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.Colors.secondaryText.opacity(0.12), in: .capsule)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    numberCell("Shares", text: $row.shares, stored: row.storedShares, field: .shares)
                    numberCell("Avg price", text: $row.avgPrice, stored: row.storedAvgPrice, field: .avgPrice)
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Buy date").font(.caption2).foregroundStyle(AppTheme.Colors.secondaryText)
                        TextField("YYYY-MM-DD", text: $row.buyDate)
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            notes
        }
        .padding(10)
        .background(
            rowErrors.isEmpty ? Color.clear : AppTheme.Colors.warning.opacity(0.08),
            in: .rect(cornerRadius: 10)
        )
        .onChange(of: focus) { old, _ in
            // Shows the number that will be sent: "1,5" becomes "1.5".
            switch old {
            case .shares: row.shares = TradeNumber.tidy(row.shares)
            case .avgPrice: row.avgPrice = TradeNumber.tidy(row.avgPrice)
            case nil: break
            }
        }
    }

    private func numberCell(_ label: LocalizedStringKey, text: Binding<String>, stored: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(AppTheme.Colors.secondaryText)
            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .focused($focus, equals: field)
            if let hint = TradeNumber.hint(for: text.wrappedValue, stored: stored) {
                Text(verbatim: hint.text)
                    .font(.caption2)
                    .foregroundStyle(hint.warns ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder private var notes: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !problem.isEmpty {
                Text(verbatim: problem).foregroundStyle(AppTheme.Colors.danger)
            }
            ForEach(Array(rowErrors.enumerated()), id: \.offset) { _, message in
                Text(verbatim: message).foregroundStyle(AppTheme.Colors.danger)
            }
        }
        .font(.caption)
    }
}
