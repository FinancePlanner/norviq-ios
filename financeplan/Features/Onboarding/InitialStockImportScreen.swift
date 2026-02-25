import SwiftUI

enum StockImportMethod: String, CaseIterable, Identifiable {
  case csv
  case manual
  case api

  var id: String { rawValue }

  var title: String {
    switch self {
    case .csv:
      return "Import CSV"
    case .manual:
      return "Enter Manually"
    case .api:
      return "Connect API"
    }
  }

  var subtitle: String {
    switch self {
    case .csv:
      return "Upload your broker/exported CSV file."
    case .manual:
      return "Add your positions one by one."
    case .api:
      return "Sync holdings from a broker/integration API."
    }
  }
}

struct InitialStockImportScreen: View {
  let onImportCompleted: (StockImportMethod) -> Void

  @State private var selectedMethod: StockImportMethod?
  @State private var isSubmitting = false
  @State private var message: String?

  var body: some View {
    VStack(spacing: 20) {
      Spacer(minLength: 0)

      Image(systemName: "tray.and.arrow.down.fill")
        .font(.system(size: 40, weight: .bold))
        .foregroundStyle(.blue)

      Text("Import Your Stocks")
        .font(.title2)
        .fontWeight(.bold)

      Text("This step is required the first time you sign in. Choose one import method to continue.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)

      VStack(spacing: 10) {
        ForEach(StockImportMethod.allCases) { method in
          Button {
            selectedMethod = method
            message = nil
          } label: {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: selectedMethod == method ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedMethod == method ? .blue : .secondary)

              VStack(alignment: .leading, spacing: 4) {
                Text(method.title)
                  .font(.headline)
                  .foregroundStyle(.primary)

                Text(method.subtitle)
                  .font(.footnote)
                  .foregroundStyle(.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(selectedMethod == method ? Color.blue.opacity(0.10) : Color(.secondarySystemBackground))
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("stockImportMethod.\(method.rawValue)")
        }
      }

      if let message {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.green)
      }

      Button {
        Task { await completeImport() }
      } label: {
        HStack(spacing: 8) {
          if isSubmitting {
            ProgressView()
              .tint(.white)
          }
          Text(buttonTitle)
            .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .background(selectedMethod == nil || isSubmitting ? Color.gray : Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .disabled(selectedMethod == nil || isSubmitting)
      .accessibilityIdentifier("stockImportContinueButton")

      Spacer(minLength: 0)
    }
    .accessibilityIdentifier("initialStockImportScreen")
    .padding(16)
    .frame(maxWidth: 520, maxHeight: .infinity)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground).ignoresSafeArea())
  }

  private var buttonTitle: String {
    guard let selectedMethod else {
      return "Select a Method"
    }
    return "Continue with \(selectedMethod.title)"
  }

  @MainActor
  private func completeImport() async {
    guard let selectedMethod else {
      return
    }

    isSubmitting = true
    defer { isSubmitting = false }

    // Placeholder completion. Replace with real import flows.
    try? await Task.sleep(nanoseconds: 300_000_000)
    message = "\(selectedMethod.title) selected."
    onImportCompleted(selectedMethod)
  }
}
