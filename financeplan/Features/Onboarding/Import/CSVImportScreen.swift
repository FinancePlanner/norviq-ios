//
//  CSVImportScreen.swift
//  financeplan
//
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

struct CSVImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isImporterPresented = false
  @StateObject private var viewModel = CsvImportFlowViewModel()
  var headerNamespace: Namespace.ID?

  let onBack: () -> Void
  let onDone: ([ImportedPosition]) -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Custom nav bar
      OnboardingNavBar(
        title: "CSV Import",
        icon: "doc.text.fill",
        namespace: headerNamespace,
        onBack: onBack
      )

      ScrollView {
        VStack(spacing: 20) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Broker")
              .typography(.small, weight: .semibold)
              .foregroundStyle(.secondary)

            Picker("Provider", selection: $viewModel.selectedProvider) {
              ForEach(viewModel.availableProviders, id: \.self) { provider in
                Text(provider.uppercased()).tag(provider)
              }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.isLoadingProviders)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .appGlassEffect(.rect(cornerRadius: 16))

            if viewModel.isLoadingProviders {
              ProgressView("Loading broker connections...")
                .typography(.caption)
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 20)

          CSVImportFormatHint()
            .padding(.horizontal, 20)

          // Upload area
          Button {
            isImporterPresented = true
          } label: {
            VStack(spacing: 16) {
              ZStack {
                Circle()
                  .fill(
                    AppTheme.Colors.secondaryTint(for: colorScheme).opacity(
                      colorScheme == .dark ? 0.12 : 0.08)
                  )
                  .frame(width: 72, height: 72)

                Image(systemName: "arrow.up.doc.fill")
                  .font(.largeTitle.bold())
                  .foregroundStyle(AppTheme.Colors.secondaryTint(for: colorScheme))
              }

              VStack(spacing: 6) {
                Text("Select CSV File")
                  .typography(.label, weight: .semibold)
                  .foregroundStyle(.primary)

                Text("Tap to browse for a broker export or CSV file")
                  .typography(.nano)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .appGlassEffect(.rect(cornerRadius: 20))
          }
          .buttonStyle(PressEffectStyle())
          .padding(.horizontal, 20)

          if let selectedFileName = viewModel.selectedFileName {
            Text(selectedFileName)
              .typography(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 20)
              .frame(maxWidth: .infinity, alignment: .leading)
          }

          if let errorMessage = viewModel.errorMessage {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.Colors.danger)
              Text(errorMessage)
                .typography(.small)
                .foregroundStyle(AppTheme.Colors.danger)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.danger.opacity(0.08))
            )
            .padding(.horizontal, 20)
          }

          // Preview
          if let preview = viewModel.previewResponse, !preview.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text("Preview")
                  .typography(.small, weight: .semibold)

                Spacer()

                Text("\(preview.items.count) positions found")
                  .typography(.caption)
                  .foregroundStyle(AppTheme.Colors.success)
              }
              .padding(.horizontal, 4)

              ForEach(preview.items, id: \.line) { row in
                HStack {
                  Text(row.symbol)
                    .typography(.label, weight: .bold)

                  Spacer()

                  VStack(alignment: .trailing, spacing: 2) {
                    Text("Qty: \(row.shares?.formatted(.number.precision(.fractionLength(0...6))) ?? "-")")
                      .typography(.small)
                    Text((row.buyPrice ?? 0).currency)
                      .typography(.nano)
                      .foregroundStyle(.secondary)
                  }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .appGlassEffect(.rect(cornerRadius: 14))
              }
            }
            .padding(.horizontal, 20)

            if !preview.errors.isEmpty {
              VStack(alignment: .leading, spacing: 10) {
                Text("Preview Errors")
                  .typography(.small, weight: .semibold)

                ForEach(preview.errors, id: \.line) { error in
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Line \(error.line)")
                      .typography(.caption)
                      .foregroundStyle(.secondary)
                    Text(error.message)
                      .typography(.small)
                      .foregroundStyle(AppTheme.Colors.danger)
                  }
                  .padding(14)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .fill(AppTheme.Colors.danger.opacity(0.08))
                  )
                }
              }
              .padding(.horizontal, 20)
            }
          } else if viewModel.errorMessage == nil {
            VStack(spacing: 8) {
              Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.5))

              Text("No preview yet")
                .typography(.small)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 32)
          }

          Spacer(minLength: 100)
        }
      }

      // Bottom bar
      VStack(spacing: 0) {
        Divider().opacity(0.3)

        HStack(spacing: 12) {
          if let preview = viewModel.previewResponse, !preview.items.isEmpty {
            Text("\(preview.items.count) positions")
              .typography(.small)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button {
            Task {
              let didImport = await viewModel.commitImport()
              guard didImport, let preview = viewModel.previewResponse else { return }
              let imported = preview.items.map {
                ImportedPosition(
                  symbol: $0.symbol,
                  quantity: $0.shares ?? 0,
                  price: $0.buyPrice ?? 0
                )
              }
              onDone(imported)
            }
          } label: {
            HStack(spacing: 6) {
              if viewModel.isImporting {
                ProgressView()
                  .tint(.white)
              }

              Text(viewModel.isImporting ? "Importing" : "Continue")
                .font(.headline)
                .fontWeight(.bold)
              if !viewModel.isImporting {
                Image(systemName: "arrow.right")
                  .font(.subheadline.weight(.bold))
              }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
              Capsule()
                .fill(AppTheme.Colors.tint(for: colorScheme))
            )
            .shadow(
              color: AppTheme.Colors.tint(for: colorScheme).opacity(0.25),
              radius: 8, x: 0, y: 4
            )
          }
          .disabled(!viewModel.canImport)
          .opacity(viewModel.canImport ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .appGlassEffect(.rect(cornerRadius: 0))
        .ignoresSafeArea(edges: .bottom)
      }
    }
    .background(MeshGradientBackground().ignoresSafeArea())
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: [UTType.commaSeparatedText, .plainText],
      allowsMultipleSelection: false
      ) { result in
        do {
          let urls = try result.get()
          guard let url = urls.first else { return }
          Task {
            await viewModel.loadCSV(from: url)
          }
        } catch {
          viewModel.errorMessage = "Failed to read CSV: \(error.localizedDescription)"
        }
      }
    .task {
      await viewModel.loadProvidersIfNeeded()
    }
    .onChange(of: viewModel.selectedProvider) { _, _ in
      guard viewModel.previewResponse != nil else { return }
      Task {
        await viewModel.previewCSV()
      }
    }
  }
}
