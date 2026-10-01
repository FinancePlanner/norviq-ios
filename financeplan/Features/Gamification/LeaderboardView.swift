import SwiftUI

/// Friends-only leaderboards inside the Friends tab: pick a metric and a
/// period; the server ranks the caller and friends who opted in.
struct LeaderboardView: View {
  var onInvite: () -> Void
  @State private var viewModel = LeaderboardViewModel()

  var body: some View {
    List {
      Section {
        Picker("Metric", selection: $viewModel.metric) {
          ForEach(LeaderboardMetric.allCases) { metric in
            Text(metric.title).tag(metric)
          }
        }
        .pickerStyle(.segmented)
        Picker("Period", selection: $viewModel.period) {
          ForEach(LeaderboardPeriod.allCases) { period in
            Text(period.title).tag(period)
          }
        }
        .pickerStyle(.segmented)
      } footer: {
        if viewModel.showsReturnPercentNote {
          Text("Only friends who chose to share their return appear here, and only percentages are shown, never amounts.")
        }
      }

      rankings
    }
    .refreshable { await viewModel.load() }
    .task(id: viewModel.selectionKey) { await viewModel.load() }
  }

  @ViewBuilder
  private var rankings: some View {
    if viewModel.entries.isEmpty, viewModel.isLoading {
      Section {
        ProgressView().frame(maxWidth: .infinity)
      }
    } else if viewModel.entries.isEmpty, let message = viewModel.errorMessage {
      Section {
        ContentUnavailableView {
          Label("Couldn't load the leaderboard", systemImage: "exclamationmark.triangle")
        } description: {
          Text(message)
        } actions: {
          Button("Try again") { Task { await viewModel.load() } }
        }
      }
    } else {
      if !viewModel.entries.isEmpty {
        Section(viewModel.period.title) {
          ForEach(viewModel.entries) { entry in
            if entry.isMe {
              LeaderboardRow(entry: entry, metric: viewModel.metric)
                .listRowBackground(AppTheme.Colors.tint.opacity(0.12))
            } else {
              NavigationLink(value: entry.user) {
                LeaderboardRow(entry: entry, metric: viewModel.metric)
              }
            }
          }
        }
      }
      if viewModel.isAlone {
        Section {
          ContentUnavailableView {
            Label("No friends to compare with yet", systemImage: "trophy")
          } description: {
            Text("Leaderboards only show you and your friends. Invite someone to see how you rank.")
          } actions: {
            Button("Invite friends", action: onInvite)
              .buttonStyle(.borderedProminent)
          }
        }
      }
    }
  }
}

private struct LeaderboardRow: View {
  let entry: LeaderboardEntry
  let metric: LeaderboardMetric

  var body: some View {
    HStack(spacing: 12) {
      Text(entry.rank, format: .number)
        .typography(.label, weight: .bold)
        .monospacedDigit()
        .foregroundStyle(entry.rank <= 3 ? AppTheme.Colors.tint : .secondary)
        .frame(minWidth: 24)
      SocialUserRow(user: entry.user) {
        VStack(alignment: .trailing, spacing: 2) {
          Text(LeaderboardViewModel.formattedValue(entry.value, metric: metric))
            .typography(.label, weight: .semibold)
            .monospacedDigit()
          if entry.isMe {
            Text("You")
              .typography(.caption, weight: .semibold)
              .foregroundStyle(AppTheme.Colors.tint)
          }
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}
