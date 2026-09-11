import Factory
import PhotosUI
import StockPlanShared
import SwiftUI

/// Imports positions from broker screenshots.
///
/// Three steps, in one sheet: pick images, review what was read, commit. The
/// review step is not optional — extraction is a guess, and these numbers
/// become the user's financial records, so every value stays editable and
/// every row can be dropped before anything is written.
@MainActor
struct PortfolioScreenshotImportSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel: ScreenshotImportViewModel

  let onImportCompleted: @MainActor () async -> Void

  init(
    portfolioListId: String?,
    onImportCompleted: @escaping @MainActor () async -> Void
  ) {
    _viewModel = State(wrappedValue: ScreenshotImportViewModel(portfolioListId: portfolioListId))
    self.onImportCompleted = onImportCompleted
  }

  var body: some View {
    NavigationStack {
      List {
        if viewModel.rows.isEmpty, !viewModel.didCommit {
          pickerSection
        }
        if viewModel.isExtracting {
          Section {
            HStack(spacing: 12) {
              ProgressView()
              Text("Reading your screenshots…")
                .foregroundStyle(.secondary)
            }
          }
        }
        if let message = viewModel.errorMessage {
          Section {
            Text(message)
              .foregroundStyle(.red)
          }
        }
        if !viewModel.warnings.isEmpty {
          Section("Could not read") {
            ForEach(viewModel.warnings, id: \.self) { warning in
              Text(warning)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
        }
        if viewModel.didCommit {
          committedSection
        } else if !viewModel.rows.isEmpty {
          kindSection
          reviewSection
        }
      }
      .navigationTitle("Import from screenshots")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") { dismiss() }
        }
        if !viewModel.rows.isEmpty, !viewModel.didCommit {
          ToolbarItem(placement: .confirmationAction) {
            Button("Import") {
              Task {
                await viewModel.commit()
                if viewModel.didCommit {
                  await onImportCompleted()
                }
              }
            }
            .disabled(viewModel.isCommitting || viewModel.selectedRowCount == 0)
            .accessibilityIdentifier("portfolioScreenshotImport.commit")
          }
        }
      }
    }
  }

  private var pickerSection: some View {
    Section {
      PhotosPicker(
        selection: $viewModel.pickedItems,
        maxSelectionCount: ScreenshotImportViewModel.maxImages,
        matching: .images,
        photoLibrary: .shared()
      ) {
        Label("Choose screenshots", systemImage: "photo.on.rectangle.angled")
      }
      .accessibilityIdentifier("portfolioScreenshotImport.pick")
    } header: {
      Text("Screenshots")
    } footer: {
      Text(
        """
        Up to \(ScreenshotImportViewModel.maxImages) screenshots of your broker's holdings \
        or trade history. Everything read from them is shown for you to check before \
        anything is saved. Images are read and discarded — they are never stored.
        """
      )
    }
  }

  private var kindSection: some View {
    Section {
      LabeledContent("Read as", value: viewModel.kindLabel)
      if !viewModel.hasCostBasis {
        Text(
          """
          A holdings screen shows what you own now, not what you paid. Purchase prices \
          were left blank rather than guessed — fill them in for accurate gains.
          """
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var reviewSection: some View {
    Section {
      ForEach($viewModel.rows) { $row in
        ScreenshotImportRowEditor(row: $row)
      }
    } header: {
      Text("Review \(viewModel.rows.count) position(s)")
    } footer: {
      Text("Uncheck anything you don't want. Correct any figure that was misread.")
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

/// One editable extracted position.
private struct ScreenshotImportRowEditor: View {
  @Binding var row: ScreenshotImportRow

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Toggle(isOn: $row.isIncluded) {
          TextField("Symbol", text: $row.symbol)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .font(.headline)
        }
        .toggleStyle(.switch)
      }

      HStack(spacing: 12) {
        LabeledTextField(label: "Shares", text: $row.shares)
        LabeledTextField(label: "Buy price", text: $row.buyPrice)
      }

      if row.needsAttention {
        Label(row.attentionMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
    .padding(.vertical, 4)
    .opacity(row.isIncluded ? 1 : 0.45)
  }
}

private struct LabeledTextField: View {
  let label: String
  @Binding var text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      TextField(label, text: $text)
        .keyboardType(.decimalPad)
        .textFieldStyle(.roundedBorder)
    }
  }
}
