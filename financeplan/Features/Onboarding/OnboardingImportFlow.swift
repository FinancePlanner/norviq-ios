//
//  OnboardingImportFlow.swift
//  financeplan
//
//  Created by Fernando Correia on 27.02.26.
//
import Combine
import Factory
import StockPlanShared
import StoreKit
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingImportFlow: View {
  @StateObject private var viewModel = OnboardingImportViewModel()
  @Namespace private var headerNS
  let onFinished: () -> Void
  let onSignOut: () async -> Void

  var body: some View {
    Group {
      switch viewModel.step {
      case .mainMenu:
        OnboardingMainMenu(
          onSelectStocks: { viewModel.startStockImport() },
          onSelectExpenses: { viewModel.startExpenseImport() },
          onSignOut: {
            Task { await onSignOut() }
          },
          onSkip: onFinished
        )
      case .chooseStockMethod:
        InitialStockImportScreen(
          onImportCompleted: { method in viewModel.selectStockMethod(method) },
          onSignOut: {
            Task { await onSignOut() }
          },
          onBack: { viewModel.backToMain() },
          headerNamespace: headerNS
        )
      case .csv:
        CSVImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChooseStock() },
          onDone: { _ in viewModel.finish() }
        )
      case .manual:
        ManualImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChooseStock() },
          onDone: { _ in viewModel.finish() }
        )
      case .api:
        APIKeyImportScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToChooseStock() },
          onDone: { viewModel.finish() }
        )
      case .expenseBudgetSetup:
        ExpenseBudgetSetupScreen(
          headerNamespace: headerNS,
          onBack: { viewModel.backToMain() },
          onDone: { viewModel.finish() }
        )
      case .success:
        SuccessImportScreen(
          onDone: { viewModel.complete() }
        )
      case .done:
        Color.clear.onAppear(perform: onFinished)
      }
    }
    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: viewModel.step)
  }
}

// MARK: - MAIN MENU

struct OnboardingMainMenu: View {
  @Environment(\.requestReview) private var requestReview
  @Environment(\.colorScheme) private var colorScheme
  
  let onSelectStocks: () -> Void
  let onSelectExpenses: () -> Void
  let onSignOut: () -> Void
  let onSkip: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      VStack(spacing: 12) {
        Text("Welcome to Norviqa")
          .typography(.hero, weight: .bold)
        
        Text("How would you like to start building your workspace?")
          .typography(.label)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
      }
      .padding(.top, 60)

      VStack(spacing: 16) {
        OnboardingMenuButton(
          title: "Import Stocks",
          subtitle: "Connect accounts or upload CSVs",
          icon: "chart.line.uptrend.xyaxis",
          color: .blue,
          action: onSelectStocks
        )

        OnboardingMenuButton(
          title: "Import Expenses",
          subtitle: "Track your spending and budget",
          icon: "creditcard.fill",
          color: .orange,
          action: onSelectExpenses
        )

        OnboardingMenuButton(
          title: "Crypto Assets",
          subtitle: "Sync wallets and exchange data",
          icon: "bitcoinsign.circle.fill",
          color: .red,
          isDisabled: true,
          showSoonBadge: true,
          action: { /* Soon */ }
        )
      }
      .padding(.horizontal, 24)

      Spacer()

      VStack(spacing: 20) {
        Button {
          requestReview()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "star.fill")
            Text("Enjoying the app? Leave a review")
          }
          .typography(.caption, weight: .semibold)
          .foregroundStyle(.secondary)
        }

        HStack(spacing: 24) {
          Button("Sign Out", action: onSignOut)
            .typography(.caption, weight: .medium)
            .foregroundStyle(.red)

          Button("Skip for Now", action: onSkip)
            .typography(.caption, weight: .medium)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.bottom, 40)
    }
    .background(MeshGradientBackground().ignoresSafeArea())
  }
}

private struct OnboardingMenuButton: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  var isDisabled: Bool = false
  var showSoonBadge: Bool = false
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(color.opacity(0.15))
            .frame(width: 48, height: 48)
          
          Image(systemName: icon)
            .font(.title3.weight(.bold))
            .foregroundStyle(color)
        }

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(title)
              .typography(.label, weight: .bold)
              .foregroundStyle(isDisabled ? .secondary : .primary)
            
            if showSoonBadge {
              Text("Soon")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red, in: Capsule())
            }
          }
          
          Text(subtitle)
            .typography(.nano)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.secondary.opacity(0.5))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .appGlassEffect(.rect(cornerRadius: 20))
      .opacity(isDisabled ? 0.6 : 1.0)
    }
    .buttonStyle(PressEffectStyle())
    .disabled(isDisabled)
  }
}

// MARK: - SUCCESS SCREEN

struct SuccessImportScreen: View {
  @Environment(\.requestReview) var requestReview
  @Environment(\.colorScheme) private var colorScheme
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      VStack(spacing: 24) {
        ZStack {
          Circle()
            .fill(AppTheme.Colors.success.opacity(0.12))
            .frame(width: 100, height: 100)

          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 48, weight: .bold))
            .foregroundStyle(AppTheme.Colors.success)
        }

        VStack(spacing: 12) {
          Text("All Set!")
            .typography(.hero, weight: .bold)

          Text("Your data has been imported. You can now explore your workspace insights.")
            .typography(.label)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
      }

      VStack(spacing: 16) {
        Button {
          requestReview()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "star.fill")
            Text("Leave a review")
          }
          .font(.headline)
          .fontWeight(.bold)
        }
        .buttonStyle(GlowingButtonStyle())
        .padding(.horizontal, 24)

        Button {
          onDone()
        } label: {
          Text("Go to Home")
            .typography(.label, weight: .semibold)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(MeshGradientBackground().ignoresSafeArea())
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
          .appGlassEffect(.rect(cornerRadius: 14), tint: AppTheme.Colors.tintSoft(for: colorScheme).opacity(0.4))
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
        .appGlassEffect(.rect(cornerRadius: 0))
        .ignoresSafeArea(edges: .bottom)
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
        let today = DateFormatter.yyyyMMdd.string(from: Date())

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
}

// MARK: - CSV Import

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
            .appGlassEffect(.rect(cornerRadius: 20))
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
                .appGlassEffect(.rect(cornerRadius: 14))
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
        viewModel.loadCSV(from: url)
      } catch {
        viewModel.errorMessage = "Failed to read CSV: \(error.localizedDescription)"
        viewModel.previewRows = []
      }
    }
  }
}

// MARK: - Manual Entry Card

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

// MARK: - Onboarding Nav Bar

struct OnboardingNavBar: View {
  let title: String
  let icon: String
  var namespace: Namespace.ID? = nil
  let onBack: () -> Void

  init(title: String, icon: String, namespace: Namespace.ID? = nil, onBack: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.namespace = namespace
    self.onBack = onBack
  }
    
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
    .padding(.top, 8)
    .padding(.vertical, 12)
    .appGlassEffect(.rect(cornerRadius: 0))
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

// MARK: - Expense Budget Setup

struct ExpenseBudgetSetupScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = ExpenseBudgetSetupViewModel()
  @State private var errorMessage: String?
  var headerNamespace: Namespace.ID? = nil

  let onBack: () -> Void
  let onDone: () -> Void

  private var totalPercent: Double {
    viewModel.pillars.values.reduce(0, +)
  }

  private var isValid: Bool {
    !viewModel.monthlyIncome.isEmpty && totalPercent == 100
  }
    
  var body: some View {
    VStack(spacing: 0) {
      // Custom nav bar
      OnboardingNavBar(
        title: "Budget Setup",
        icon: "dollarsign.circle.fill",
        namespace: headerNamespace,
        onBack: onBack
      )

      ScrollView {
        VStack(spacing: 24) {
          // Instructions
          HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
              .font(.title3)
              .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

            Text(
              "Set up your monthly budget by defining your income and allocating it across spending pillars."
            )
            .typography(.small)
            .foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .appGlassEffect(.rect(cornerRadius: 14), tint: AppTheme.Colors.tintSoft(for: colorScheme).opacity(0.4))
          .padding(.horizontal, 20)
          .padding(.top, 16)

          // Monthly Income
          VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Income")
              .typography(.label, weight: .semibold)
              .padding(.horizontal, 4)

            HStack(spacing: 12) {
              Image(systemName: "banknote.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.success)
                .frame(width: 32)

              TextField("Enter your net monthly income", text: $viewModel.monthlyIncome)
                .keyboardType(.decimalPad)
                .typography(.label, weight: .semibold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .appGlassEffect(.rect(cornerRadius: 16))
          }
          .padding(.horizontal, 20)

          // Budget Pillars
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text("Budget Pillars")
                .typography(.label, weight: .semibold)
              
              Spacer()
              
              Text("\(Int(totalPercent))%")
                .typography(.label, weight: .bold)
                .foregroundStyle(totalPercent == 100 ? AppTheme.Colors.success : AppTheme.Colors.warning)
            }
            .padding(.horizontal, 4)

            ForEach(BudgetPillar.allCases, id: \.self) { pillar in
              PillarAllocationCard(
                pillar: pillar,
                percentage: Binding(
                  get: { viewModel.pillars[pillar] ?? 0 },
                  set: { viewModel.pillars[pillar] = $0 }
                ),
                monthlyIncome: viewModel.monthlyIncomeValue
              )
            }
          }
          .padding(.horizontal, 20)

          // Initial Expenses (Optional)
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text("Add Initial Expenses (Optional)")
                .typography(.label, weight: .semibold)
              
              Spacer()
              
              Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                  viewModel.addExpense()
                }
              } label: {
                Image(systemName: "plus.circle.fill")
                  .font(.title3)
                  .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
              }
            }
            .padding(.horizontal, 4)

            if viewModel.expenses.isEmpty {
              Text("You can add expenses later from the Expenses tab")
                .typography(.nano)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            } else {
                ForEach(Array(viewModel.expenses.enumerated()), id: \.element.id) { (index, _) in
                    ExpenseEntryCard(
                        expense: $viewModel.expenses[index],
                        index: index + 1,
                        onDelete: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.expenses.remove(at: index)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
          }
          .padding(.horizontal, 20)

          Spacer(minLength: 100)
        }
      }
      .scrollDismissesKeyboard(.interactively)

      // Bottom bar
      VStack(spacing: 0) {
        Divider().opacity(0.3)

        HStack(spacing: 12) {
          if !isValid {
            Text(totalPercent != 100 ? "Pillars must total 100%" : "Enter income")
              .typography(.small)
              .foregroundStyle(AppTheme.Colors.warning)
          }

          Spacer()

          Button {
            submitBudgetSetup()
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
          .disabled(!isValid)
          .opacity(isValid ? 1 : 0.5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .appGlassEffect(.rect(cornerRadius: 0))
        .ignoresSafeArea(edges: .bottom)
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

  private func submitBudgetSetup() {
    errorMessage = nil
    Task {
      do {
        try await viewModel.createBudgetSnapshot()
        onDone()
      } catch {
        errorMessage =
          (error as? LocalizedError)?.errorDescription
          ?? "Could not create budget. Please try again."
      }
    }
  }
}

// MARK: - Pillar Allocation Card

private struct PillarAllocationCard: View {
  let pillar: BudgetPillar
  @Binding var percentage: Double
  let monthlyIncome: Double
  @Environment(\.colorScheme) private var colorScheme

  private var allocatedAmount: Double {
    monthlyIncome * (percentage / 100)
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        HStack(spacing: 10) {
          Image(systemName: pillar.symbol)
            .font(.title3)
            .foregroundStyle(pillar.color(for: colorScheme))
            .frame(width: 28)

          VStack(alignment: .leading, spacing: 2) {
            Text(pillar.title)
              .typography(.label, weight: .semibold)
            
            if monthlyIncome > 0 {
              Text(allocatedAmount.formatted(.currency(code: "USD")))
                .typography(.nano)
                .foregroundStyle(.secondary)
            }
          }
        }

        Spacer()

        HStack(spacing: 4) {
          TextField("0", value: $percentage, format: .number.precision(.fractionLength(0)))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .typography(.label, weight: .bold)
            .frame(width: 40)
          
          Text("%")
            .typography(.label)
            .foregroundStyle(.secondary)
        }
      }

      // Slider
      Slider(value: $percentage, in: 0...100, step: 5)
        .tint(pillar.color(for: colorScheme))
    }
    .padding(16)
    .appGlassEffect(.rect(cornerRadius: 16))
  }
}

// MARK: - Expense Entry Card

private struct ExpenseEntryCard: View {
  @Binding var expense: ExpenseEntry
  let index: Int
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var focusedField: ExpenseField?

  private enum ExpenseField { case title, amount }

  var body: some View {
    VStack(spacing: 0) {
      // Header row
      HStack {
        Text("Expense \(index)")
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

      // Title
      HStack(spacing: 10) {
        Image(systemName: "text.alignleft")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        TextField("Expense name (e.g. Groceries)", text: $expense.title)
          .focused($focusedField, equals: .title)
          .submitLabel(.next)
          .onSubmit { focusedField = .amount }
          .typography(.label, weight: .semibold)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        AppTheme.Colors.elevatedCardBackground(for: colorScheme)
          .opacity(0.6)
      )

      Divider().padding(.leading, 16).opacity(0.3)

      // Amount & Pillar row
      HStack(spacing: 0) {
        HStack(spacing: 8) {
          Text("$")
            .typography(.label)
            .foregroundStyle(.secondary)

          TextField("0.00", text: $expense.amount)
            .keyboardType(.decimalPad)
            .focused($focusedField, equals: .amount)
            .typography(.label)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider().frame(height: 28).opacity(0.3)

        Menu {
          ForEach(BudgetPillar.allCases, id: \.self) { pillar in
            Button {
              expense.pillar = pillar
            } label: {
              Label(pillar.title, systemImage: pillar.symbol)
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: expense.pillar.symbol)
              .font(.subheadline)
            Text(expense.pillar.title)
              .typography(.small, weight: .medium)
            Image(systemName: "chevron.down")
              .font(.caption2.weight(.bold))
          }
          .foregroundStyle(expense.pillar.color(for: colorScheme))
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
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

// MARK: - View Model

@MainActor
final class ExpenseBudgetSetupViewModel: ObservableObject {
  @Published var monthlyIncome: String = ""
  @Published var pillars: [BudgetPillar: Double] = [
    .fundamentals: 50,
    .futureYou: 30,
    .fun: 20
  ]
  @Published var expenses: [ExpenseEntry] = []

  var monthlyIncomeValue: Double {
    Double(monthlyIncome) ?? 0
  }

  func addExpense() {
    expenses.append(ExpenseEntry())
  }

  func createBudgetSnapshot() async throws {
    let expensesService = Container.shared.expensesService()
    
    // Create budget snapshot
    let calendar = Calendar.current
    let now = Date()
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    var targetShares: [String: Double] = [:]
    for (pillar, percentage) in pillars {
      targetShares[pillar.rawValue] = percentage / 100
    }
    
    let snapshotRequest = BudgetSnapshotRequest(
      monthStart: dateFormatter.string(from: monthStart),
      netSalary: monthlyIncomeValue,
      targetShares: targetShares
    )
    
    _ = try await expensesService.createBudgetSnapshot(request: snapshotRequest)
    
    // Create expenses if any
    for expense in expenses where !expense.title.isEmpty {
      guard let amount = Double(expense.amount), amount > 0 else { continue }
      
      let expenseRequest = ExpenseRequest(
        title: expense.title,
        amount: amount,
        pillar: expense.pillar,
        occurredOn: dateFormatter.string(from: now),
        linkedPlanItemId: nil
      )
      
      try await expensesService.createExpense(request: expenseRequest)
    }
  }
}

struct ExpenseEntry: Identifiable {
  let id = UUID()
  var title: String = ""
  var amount: String = ""
  var pillar: BudgetPillar = .fundamentals
}

