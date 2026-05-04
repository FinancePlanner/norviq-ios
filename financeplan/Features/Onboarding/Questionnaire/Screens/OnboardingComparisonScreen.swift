import SwiftUI

struct OnboardingComparisonScreen: View {
  let onContinue: () -> Void

  private static let rows: [ComparisonRow] = [
    ComparisonRow(label: "All wealth in one screen", norviq: true, without: false),
    ComparisonRow(label: "Spending → investing trade-offs", norviq: true, without: false),
    ComparisonRow(label: "Live allocation visuals", norviq: true, without: false),
    ComparisonRow(label: "10-year projections", norviq: true, without: false)
  ]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 20) {
          VStack(spacing: 10) {
            Text("Two in three Americans don't track their spending at all.")
              .typography(.title, weight: .bold)
              .multilineTextAlignment(.center)

            Text("It doesn't have to be that way.")
              .typography(.label)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .padding(.top, 28)

          comparisonTable
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }

      OnboardingActionBar(
        primaryTitle: "Show me how it works",
        showsArrow: true,
        onPrimary: onContinue
      )
    }
  }

  private var comparisonTable: some View {
    GlassCard(cornerRadius: 22) {
      VStack(spacing: 0) {
        headerRow
        ForEach(Array(Self.rows.enumerated()), id: \.element.id) { index, row in
          if index > 0 {
            Divider().opacity(0.2)
          }
          ComparisonRowView(row: row)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var headerRow: some View {
    HStack {
      Spacer().frame(width: 0)
      Text(" ")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("Norviq")
        .typography(.caption, weight: .bold)
        .frame(width: 64, alignment: .center)
      Text("Without")
        .typography(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 64, alignment: .center)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }
}

private struct ComparisonRow: Identifiable {
  let id = UUID()
  let label: String
  let norviq: Bool
  let without: Bool
}

private struct ComparisonRowView: View {
  let row: ComparisonRow

  var body: some View {
    HStack {
      Text(row.label)
        .typography(.small, weight: .medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

      checkmark(row.norviq, positive: true)
        .frame(width: 64, alignment: .center)

      checkmark(row.without, positive: false)
        .frame(width: 64, alignment: .center)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
  }

  @ViewBuilder
  private func checkmark(_ enabled: Bool, positive: Bool) -> some View {
    if enabled {
      Image(systemName: "checkmark.circle.fill")
        .font(.title3)
        .foregroundStyle(AppTheme.Colors.success)
    } else {
      Image(systemName: "xmark.circle.fill")
        .font(.title3)
        .foregroundStyle(AppTheme.Colors.danger.opacity(0.85))
    }
  }
}
