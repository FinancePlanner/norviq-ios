import Factory
import StockPlanShared
import SwiftUI

/// One follow: what Norviq simulated for it, its value, and the controls to
/// pause, resume or stop it.
struct PilotFollowDetailScreen: View {
  @Environment(\.dismiss) private var dismiss
  @State private var model: PilotFollowDetailModel
  @State private var isConfirmingStop = false

  init(follow: PilotFollowResponse) {
    _model = State(initialValue: PilotFollowDetailModel(follow: follow))
  }

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .wealth,
          title: LocalizedStringKey(model.follow.pilot.displayName),
          subtitle: LocalizedStringKey(PilotFormatting.followSubtitle(model.follow))
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      Section {
        PilotFollowSummary(follow: model.follow, latestValue: model.latestValue, performance: model.performance)
      }

      if model.isPortfolio {
        Section("Simulated value") {
          PilotFollowValueChart(points: model.valuePoints, currency: model.follow.currency)
        }
      }

      PilotFollowEventsSection(
        events: model.events,
        isLoading: model.isLoading,
        isPortfolio: model.isPortfolio,
        isWaitingForFirstTrades: model.follow.appliedVersion == 0,
        currency: model.follow.currency
      )

      Section {
        if model.isPaused {
          Button("Resume following", systemImage: "play.fill") {
            Task { await model.setPaused(false) }
          }
          .disabled(model.isSaving)
        } else {
          Button("Pause following", systemImage: "pause.fill") {
            Task { await model.setPaused(true) }
          }
          .disabled(model.isSaving)
        }
        Button("Stop following", systemImage: "xmark.circle", role: .destructive) {
          isConfirmingStop = true
        }
        .disabled(model.isSaving)
        .accessibilityIdentifier("pilots.follow.stop")
      } footer: {
        if model.isPortfolio {
          Text("Stopping keeps the portfolio and its simulated trades. Norviq stops updating it.")
        } else {
          Text("Stopping keeps the watchlist. Norviq stops updating it.")
        }
      }
    }
    .vigilListChrome()
    .vigilNavigationTitle(model.follow.pilot.displayName)
    .vigilInlineNavigationBar()
    .task { await model.load() }
    .refreshable { await model.load() }
    .confirmationDialog(
      "Stop following \(model.follow.pilot.displayName)?",
      isPresented: $isConfirmingStop,
      titleVisibility: .visible
    ) {
      Button("Stop following", role: .destructive) { Task { await stop() } }
    }
    .alert("Something went wrong", isPresented: boardsErrorBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {
        // The follow no longer exists: once the user has read why, drop it
        // everywhere and leave its screen.
        if model.isGone {
          model.acknowledgeGone()
          dismiss()
        }
      }
    } message: {
      Text(model.errorMessage ?? "")
    }
  }

  private func stop() async {
    if await model.stop() {
      dismiss()
    }
  }
}

/// A follow in a list: pilot, target, paused state.
struct PilotFollowRow: View {
  let follow: PilotFollowResponse

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: follow.targetKind == .portfolio ? "flask" : "eye")
        .foregroundStyle(Color.orange)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(follow.pilot.displayName).font(.headline)
        Text(PilotFormatting.followSubtitle(follow)).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      if follow.status == .paused {
        Text("Paused").font(.caption2).foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct PilotFollowSummary: View {
  let follow: PilotFollowResponse
  let latestValue: Double?
  let performance: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let latestValue {
        Text(PilotFormatting.money(latestValue, currency: follow.currency))
          .font(.title.weight(.bold))
          .monospacedDigit()
      }
      if let performance {
        Text("\(PilotFormatting.signedPercent(performance)) since you started")
          .font(.subheadline)
          .foregroundStyle(performance < 0 ? Color.red : Color.green)
      }
      if follow.status == .paused {
        Label("Paused. Norviq isn't copying new disclosures.", systemImage: "pause.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text("Simulated. No real money is invested.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct PilotFollowEventsSection: View {
  let events: [PilotFollowEventResponse]
  let isLoading: Bool
  let isPortfolio: Bool
  let isWaitingForFirstTrades: Bool
  let currency: String

  var body: some View {
    Section {
      if events.isEmpty, !isLoading {
        if isWaitingForFirstTrades {
          Text("Norviq is placing the first simulated trades. Check back shortly.").foregroundStyle(.secondary)
        } else {
          Text("No changes yet.").foregroundStyle(.secondary)
        }
      }
      ForEach(events) { event in
        PilotFollowEventRow(event: event, currency: currency)
      }
    } header: {
      if isPortfolio {
        Text("Simulated trades")
      } else {
        Text("Watchlist feed")
      }
    } footer: {
      Text("Each trade is priced when Norviq sees the disclosure, not on the pilot's trade date.")
    }
  }
}

private struct PilotFollowEventRow: View {
  let event: PilotFollowEventResponse
  let currency: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: PilotFormatting.eventSymbolName(event.kind))
        .foregroundStyle(.secondary)
        .frame(width: 22)
      VStack(alignment: .leading, spacing: 3) {
        Text(PilotFormatting.eventTitle(event)).font(.subheadline.weight(.semibold))
        Text(PilotFormatting.eventDetail(event, currency: currency)).font(.caption).foregroundStyle(.secondary)
        if let note = event.note, !note.isEmpty {
          Text(note).font(.caption2).foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}
