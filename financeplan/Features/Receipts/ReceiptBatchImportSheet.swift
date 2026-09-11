import PhotosUI
import StockPlanShared
import SwiftUI

/// Turns photographed receipts into expenses.
///
/// Photograph or pick up to five receipts, check what was read, then add.
/// Every amount is editable and every line has a toggle: OCR is a guess and
/// these become the month's spending, so nothing is written until the user
/// confirms it.
@MainActor
struct ReceiptBatchImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel = ReceiptBatchImportViewModel()
  @State private var isCameraPresented = false

  let onImportCompleted: @MainActor () async -> Void

  var body: some View {
    NavigationStack {
      List {
        if viewModel.entries.isEmpty, !viewModel.didCommit {
          sourceSection
        }
        if viewModel.isScanning {
          Section {
            HStack(spacing: 12) {
              ProgressView()
              Text("Reading your receipts…").foregroundStyle(.secondary)
            }
          }
        }
        if let message = viewModel.errorMessage {
          Section { Text(message).foregroundStyle(.red) }
        }
        if !viewModel.warnings.isEmpty {
          Section("Notes") {
            ForEach(viewModel.warnings, id: \.self) { warning in
              Text(warning).font(.footnote).foregroundStyle(.secondary)
            }
          }
        }
        if viewModel.didCommit {
          committedSection
        } else {
          ForEach($viewModel.entries) { $entry in
            receiptSection(entry: $entry)
          }
          if !viewModel.entries.isEmpty, viewModel.entries.count < ReceiptBatchImportViewModel.maxImages {
            Section { addAnotherButton }
          }
        }
      }
      .navigationTitle("Scan receipts")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
        if !viewModel.entries.isEmpty, !viewModel.didCommit {
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
              Task {
                await viewModel.commit()
                if viewModel.didCommit { await onImportCompleted() }
              }
            }
            .disabled(viewModel.isCommitting || viewModel.selectedLineCount == 0)
            .accessibilityIdentifier("receiptBatch.commit")
          }
        }
      }
      .sheet(isPresented: $isCameraPresented) {
        CameraCaptureView { data in
          isCameraPresented = false
          guard let data else { return }
          Task { await viewModel.scanCaptured(data) }
        }
        .ignoresSafeArea()
      }
    }
  }

  private var sourceSection: some View {
    Section {
      if CameraCaptureView.isAvailable {
        Button {
          isCameraPresented = true
        } label: {
          Label("Take a photo", systemImage: "camera")
        }
        .accessibilityIdentifier("receiptBatch.camera")
      }
      PhotosPicker(
        selection: $viewModel.pickedItems,
        maxSelectionCount: ReceiptBatchImportViewModel.maxImages,
        matching: .images,
        photoLibrary: .shared()
      ) {
        Label("Choose from library", systemImage: "photo.on.rectangle.angled")
      }
      .accessibilityIdentifier("receiptBatch.pick")
    } header: {
      Text("Receipts")
    } footer: {
      Text(
        """
        Up to \(ReceiptBatchImportViewModel.maxImages) receipts. Itemised receipts become one \
        expense per article. Photos are read and discarded — they are never stored.
        """
      )
    }
  }

  private var addAnotherButton: some View {
    Group {
      if CameraCaptureView.isAvailable {
        Button {
          isCameraPresented = true
        } label: {
          Label("Scan another receipt", systemImage: "camera")
        }
      }
    }
  }

  private func receiptSection(entry: Binding<ReceiptBatchEntry>) -> some View {
    Section {
      if let warning = entry.wrappedValue.reconciliationWarning {
        Label(warning, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      }
      ForEach(entry.lines) { $line in
        ReceiptLineEditor(line: $line)
      }
    } header: {
      HStack {
        Text(entry.wrappedValue.merchant)
        Spacer()
        if let date = entry.wrappedValue.date {
          Text(date).foregroundStyle(.secondary)
        }
      }
    } footer: {
      let selected = entry.wrappedValue.includedTotal
      let currency = entry.wrappedValue.currency ?? ""
      if entry.wrappedValue.isSingleLine {
        Text("Read as one expense — no itemised lines were legible.")
      } else {
        Text(String(format: "%d of %d items selected · %.2f %@",
                    entry.wrappedValue.lines.filter(\.isIncluded).count,
                    entry.wrappedValue.lines.count,
                    selected,
                    currency))
      }
    }
  }

  private var committedSection: some View {
    Section {
      Label(viewModel.commitSummary, systemImage: "checkmark.circle")
        .foregroundStyle(.green)
      Button("Done") { dismiss() }
    }
  }
}

/// One editable expense line from a receipt.
private struct ReceiptLineEditor: View {
  @Binding var line: ReceiptExpenseLine

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        Toggle("Include", isOn: $line.isIncluded)
          .toggleStyle(.switch)
          .labelsHidden()

        TextField("Description", text: $line.title)
          .textFieldStyle(.plain)

        TextField("0.00", text: $line.amount)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .frame(width: 90)
      }
      PillarPicker(label: "Pillar", icon: nil, iconColor: nil, selectedPillar: $line.pillar)
    }
    .padding(.vertical, 2)
    .opacity(line.isIncluded ? 1 : 0.45)
  }
}
