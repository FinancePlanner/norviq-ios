import StockPlanShared
import SwiftUI

struct HomeQuickExpenseDraft: Equatable {
  let title: String
  let amount: Double
  let pillar: BudgetPillar
  let occurredOn: Date
  let splitMode: ExpenseSplitMode
  let userSharePercent: Double
}

struct HomeQuickExpenseSheet: View {
  let onSave: @MainActor (HomeQuickExpenseDraft) async -> String?

  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var amountText = ""
  @State private var pillar: BudgetPillar = .fundamentals
  @State private var occurredOn = Date()
  @State private var splitMode: ExpenseSplitMode = .personal
  @State private var userSharePercent: Double = 100
  @State private var isSaving = false
  @State private var errorMessage: String?
  @State private var isScannerPresented = false

  private var canSave: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && parsedAmount != nil
      && (parsedAmount ?? 0) > 0
      && !isSaving
  }

  private var parsedAmount: Double? {
    MoneyInputParser.parse(amountText)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Button {
            isScannerPresented = true
          } label: {
            Label("Scan Receipt", systemImage: "qrcode.viewfinder")
          }
          .accessibilityIdentifier("quickExpense.scanReceipt")
        }

        Section("Record Spend") {
          TextField("Title", text: $title)
            .textInputAutocapitalization(.words)

          TextField("Amount", text: $amountText)
            .keyboardType(.decimalPad)

          DatePicker("Date", selection: $occurredOn, displayedComponents: .date)

          Picker("Pillar", selection: $pillar) {
            ForEach(BudgetPillar.allCases, id: \.self) { entry in
              Text(pillarTitle(entry)).tag(entry)
            }
          }

          Picker("Split Mode", selection: $splitMode) {
            ForEach(ExpenseSplitMode.allCases, id: \.self) { mode in
              Text(mode == .personal ? "Personal" : "Shared").tag(mode)
            }
          }

          if splitMode == .shared {
            HStack {
              Text("Your Share")
              Spacer()
              Text("\(Int(userSharePercent.rounded()))%")
                .foregroundStyle(.secondary)
            }
            Slider(value: $userSharePercent, in: 0...100, step: 1)
          }
        }

        if let errorMessage {
          Section {
            Text(errorMessage)
              .font(.footnote)
              .foregroundStyle(AppTheme.Colors.danger)
          }
        }
      }
      .navigationTitle("Quick Add")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if #available(iOS 26, *) {
            Button("Cancel") {
              dismiss()
            }
            .buttonStyle(.bordered)
            .disabled(isSaving)
          } else {
            Button("Cancel") {
              dismiss()
            }
            .disabled(isSaving)
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          if #available(iOS 26, *) {
            Button {
              Task { await submit() }
            } label: {
              if isSaving {
                ProgressView()
              } else {
                Text("Save")
              }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
          } else {
            Button {
              Task { await submit() }
            } label: {
              if isSaving {
                ProgressView()
              } else {
                Text("Save")
              }
            }
            .disabled(!canSave)
          }
        }
      }
      .sheet(isPresented: $isScannerPresented) {
        ReceiptScannerView(onDraft: applyReceiptDraft)
      }
    }
  }

  private func applyReceiptDraft(_ draft: ReceiptDraft) {
    if let total = draft.total {
      amountText = String(format: "%.2f", total)
    }
    if let merchant = draft.merchant, !merchant.isEmpty {
      title = merchant
    } else if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      // Fiscal QR codes carry only a tax id, not a name — seed a label the user can edit.
      title = draft.taxId.map { "Receipt · \($0)" } ?? "Receipt"
    }
    if let date = draft.date, let parsed = Self.receiptDateFormatter.date(from: date) {
      occurredOn = parsed
    }
    errorMessage = nil
  }

  private static let receiptDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  private func submit() async {
    guard let amount = parsedAmount, amount > 0 else {
      errorMessage = "Enter a valid amount."
      return
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      errorMessage = "Spend entry needs a title."
      return
    }

    isSaving = true
    defer { isSaving = false }

    let draft = HomeQuickExpenseDraft(
      title: trimmedTitle,
      amount: amount,
      pillar: pillar,
      occurredOn: occurredOn,
      splitMode: splitMode,
      userSharePercent: splitMode == .shared ? userSharePercent : 100
    )
    let saveError = await onSave(draft)
    if let saveError {
      errorMessage = saveError
      return
    }
    dismiss()
  }

  private func pillarTitle(_ pillar: BudgetPillar) -> String {
    pillar.title
  }
}
