//
//  ManualImportScreen.swift
//  financeplan
//
import StockPlanShared
import SwiftUI

struct ManualImportScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = ManualImportViewModel()
  @State private var errorToast: ToastData?
  @State private var entriesVisible = false
  var headerNamespace: Namespace.ID?

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
    .toastOverlay($errorToast)
  }

  private func submitManualImport() {
    errorToast = nil
    let positions = viewModel.buildPositions()
    Task {
      do {
        try await viewModel.importPositions(positions)
        onDone(positions)
      } catch {
        errorToast = .error(
          (error as? LocalizedError)?.errorDescription
            ?? "Could not import stocks. Please try again."
        )
      }
    }
  }
}
