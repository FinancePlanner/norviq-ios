//
//  OnboardingImportFlow.swift
//  financeplan
//
//  Created by Fernando Correia on 27.02.26.
//
import Factory
import StockPlanShared
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingImportFlow: View {
  @StateObject private var viewModel = OnboardingImportViewModel()
  @Namespace private var headerNS
  let onFinished: () -> Void

  var body: some View {
    Group {
      switch viewModel.step {
      case .chooseMethod:
        InitialStockImportScreen(
          onImportCompleted: { method in viewModel.select(method) },
          headerNamespace: headerNS
        )
      case .csv:
        CSVImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChoose() },
          onDone: { _ in viewModel.finish() }
        )
      case .manual:
        ManualImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChoose() },
          onDone: { _ in viewModel.finish() }
        )
      case .api:
        APIKeyImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChoose() },
          onDone: { viewModel.finish() }
        )
      case .done:
        Color.clear.onAppear(perform: onFinished)
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.step)
  }
}

// MARK: - API KEY VIEW
// to fill from endpoint later

struct APIKeyImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  var headerNamespace: Namespace.ID? = nil

  let onBack: () -> Void
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Custom nav bar
      OnboardingNavBar(
        title: "API Import",
        icon: "link.circle.fill",
        namespace: headerNamespace,
        onBack: onBack
      )

      ScrollView {
        VStack(spacing: 24) {
          Spacer(minLength: 40)

          // Placeholder illustration
          VStack(spacing: 20) {
            ZStack {
              Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .frame(width: 100, height: 100)

              Image(systemName: "key.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.indigo)
            }

            Text("Coming Soon")
              .typography(.title, weight: .bold)

            Text(
              "Broker API integration is on the roadmap.\nYou'll be able to sync positions automatically."
            )
            .typography(.small)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 24)
          }

          Spacer(minLength: 40)

          Button {
            onDone()
          } label: {
            Text("Skip for Now")
              .font(.headline)
              .fontWeight(.bold)
          }
          .buttonStyle(GlowingButtonStyle())
          .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
      }
    }
    .background(MeshGradientBackground().ignoresSafeArea())
  }
}

// MARK: - MANUAL ENTRY

struct ManualEntry: Identifiable, Equatable {
  let id = UUID()
  var symbol: String = ""
  var quantity: String = ""
  var price: String = ""
}

struct ManualImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = ManualImportViewModel()
  @State private var errorMessage: String?
  @State private var entriesVisible = false
  var headerNamespace: Namespace.ID? = nil

  let onBack: () -> Void
  let onDone: ([ImportedPosition]) -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Custom nav bar
      OnboardingNavBar(
        title: "Manual Import",
        icon: "square.and.pencil",
        namespace: headerNamespace,
        onBack: onBack
      )

      ScrollView {
        VStack(spacing: 16) {
          // Instructions
          HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
              .font(.title3)
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

            Text(
              "Enter each position with its ticker symbol, quantity, and buy price."
            )
            .typography(.small)
            .foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(AppTheme.Colors.tintSoft(for: colorScheme).opacity(0.4))
          )
          .padding(.horizontal, 20)
          .padding(.top, 16)

          // Entry cards
          ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, _ in
            ManualEntryCard(entry: $viewModel.entries[index], index: index + 1) {
              if viewModel.entries.count > 1 {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                  viewModel.removeRows(at: IndexSet(integer: index))
                }
              }
            }
            .padding(.horizontal, 20)
            .transition(.asymmetric(
              insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
              removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
          }

          // Add row button
          Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
              viewModel.addRow()
            }
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "plus.circle.fill")
                .font(.title3)
              Text("Add Another Position")
                .typography(.small, weight: .semibold)
            }
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                  AppTheme.Colors.tint(for: colorScheme).opacity(0.3),
                  style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                )
            )
          }
          .padding(.horizontal, 20)
          .padding(.top, 4)

          Spacer(minLength: 100)
        }
      }
      .scrollDismissesKeyboard(.interactively)

      // Bottom bar
      VStack(spacing: 0) {
        Divider().opacity(0.3)

        HStack(spacing: 12) {
          // Position count
          let validCount = viewModel.buildPositions().count
          Text(
            "\(validCount) position\(validCount == 1 ? "" : "s") ready"
          )
          .typography(.small)
          .foregroundStyle(.secondary)

          Spacer()

          Button {
            submitManualImport()
          } label: {
            HStack(spacing: 6) {
              Text("Continue")
                .font(.headline)
                .fontWeight(.bold)
              Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
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
          .disabled(viewModel.entries.allSatisfy { $0.symbol.isEmpty })
          .opacity(viewModel.entries.allSatisfy { $0.symbol.isEmpty } ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
          AppTheme.Colors.cardBackground(for: colorScheme)
            .opacity(0.95)
            .ignoresSafeArea(edges: .bottom)
        )
      }
    }
    .background(MeshGradientBackground().ignoresSafeArea())
    .overlay(alignment: .top) {
      if let errorMessage {
        ToastBanner(message: errorMessage, style: .error)
          .padding(.horizontal, 16)
          .padding(.top, 60)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .task(id: errorMessage) {
      guard let current = errorMessage else { return }
      try? await Task.sleep(nanoseconds: 3_000_000_000)
      guard errorMessage == current else { return }
      withAnimation(.easeInOut(duration: 0.2)) {
        errorMessage = nil
      }
    }
  }

  private func submitManualImport() {
    errorMessage = nil
    let positions = viewModel.buildPositions()
    Task {
      do {
        let today = Self.dateOnlyFormatter.string(from: Date())
        let requests: [StockRequest] = positions.map { pos in
          StockRequest(
            symbol: pos.symbol,
            shares: pos.quantity,
            buyPrice: pos.price,
            buyDate: today,
            notes: ""
          )
        }
        let service = Container.shared.stockService()
        _ = try await service.bulkCreate(stocks: requests)
        onDone(positions)
      } catch {
        errorMessage =
          (error as? LocalizedError)?.errorDescription
          ?? "Could not import stocks. Please try again."
      }
    }
  }

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .init(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

// MARK: - Manual Entry Card

private struct ManualEntryCard: View {
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
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(AppTheme.Colors.cardBackground(for: colorScheme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(
          AppTheme.Colors.separator(for: colorScheme).opacity(colorScheme == .dark ? 0.3 : 0.14),
          lineWidth: 0.8
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .shadow(
      color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.04),
      radius: 8, x: 0, y: 4
    )
  }
}

// MARK: - CSV Import

struct ImportedPosition: Identifiable, Equatable {
  let id = UUID()
  let symbol: String
  let quantity: Double
  let price: Double
}

struct CSVImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var isImporterPresented = false
  @StateObject private var viewModel = CSVImportViewModel()
  var headerNamespace: Namespace.ID? = nil

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
                  .font(.system(size: 28, weight: .bold))
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
            .background(
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.Colors.cardBackground(for: colorScheme))
            )
            .overlay(
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                  AppTheme.Colors.secondaryTint(for: colorScheme).opacity(0.3),
                  style: StrokeStyle(lineWidth: 1.5, dash: [10, 6])
                )
            )
          }
          .buttonStyle(PressEffectStyle())
          .padding(.horizontal, 20)
          .padding(.top, 20)

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
          if !viewModel.previewRows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text("Preview")
                  .typography(.small, weight: .semibold)

                Spacer()

                Text("\(viewModel.previewRows.count) positions found")
                  .typography(.caption)
                  .foregroundStyle(AppTheme.Colors.success)
              }
              .padding(.horizontal, 4)

              ForEach(viewModel.previewRows) { row in
                HStack {
                  Text(row.symbol)
                    .typography(.label, weight: .bold)

                  Spacer()

                  VStack(alignment: .trailing, spacing: 2) {
                    Text("Qty: \(Int(row.quantity))")
                      .typography(.small)
                    Text(row.price.currency)
                      .typography(.nano)
                      .foregroundStyle(.secondary)
                  }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground(for: colorScheme))
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                      AppTheme.Colors.separator(for: colorScheme)
                        .opacity(colorScheme == .dark ? 0.25 : 0.12),
                      lineWidth: 0.8
                    )
                )
              }
            }
            .padding(.horizontal, 20)
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
          if !viewModel.previewRows.isEmpty {
            Text("\(viewModel.previewRows.count) positions")
              .typography(.small)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button {
            onDone(viewModel.previewRows)
          } label: {
            HStack(spacing: 6) {
              Text("Continue")
                .font(.headline)
                .fontWeight(.bold)
              Image(systemName: "arrow.right")
                .font(.subheadline.weight(.bold))
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
          .disabled(viewModel.previewRows.isEmpty)
          .opacity(viewModel.previewRows.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
          AppTheme.Colors.cardBackground(for: colorScheme)
            .opacity(0.95)
            .ignoresSafeArea(edges: .bottom)
        )
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
        viewModel.loadCSV(from: url)
      } catch {
        viewModel.errorMessage = "Failed to read CSV: \(error.localizedDescription)"
        viewModel.previewRows = []
      }
    }
  }
}

// MARK: - Onboarding Nav Bar

struct OnboardingNavBar: View {
  let title: String
  let icon: String
  var namespace: Namespace.ID? = nil
  let onBack: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onBack) {
        HStack(spacing: 4) {
          Image(systemName: "chevron.left")
            .font(.body.weight(.semibold))
          Text("Back")
            .typography(.label)
        }
        .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
      }

      Spacer()

      HStack(spacing: 8) {
        Image(systemName: icon)
          .imageScale(.medium)
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.icon", namespace: namespace))

        Text(title)
          .typography(.label, weight: .semibold)
          .modifier(
            MatchedGeometryIfAvailable(
              id: "onboarding.header.title", namespace: namespace))
      }

      Spacer()

      // Balance spacer for back button
      Color.clear
        .frame(width: 64, height: 1)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      AppTheme.Colors.topBarBackground(for: colorScheme)
        .opacity(0.85)
        .ignoresSafeArea(edges: .top)
    )
    .overlay(alignment: .bottom) {
      Divider().opacity(0.2)
    }
  }
}

struct MatchedGeometryIfAvailable: ViewModifier {
  let id: String
  let namespace: Namespace.ID?
  func body(content: Content) -> some View {
    if let ns = namespace {
      content.matchedGeometryEffect(id: id, in: ns)
    } else {
      content
    }
  }
}
