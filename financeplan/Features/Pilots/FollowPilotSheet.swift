import Factory
import StockPlanShared
import SwiftUI

/// Where to mirror a pilot, with how much, and what "simulated" means here.
struct FollowPilotSheet: View {
  @Environment(\.dismiss) private var dismiss
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var model: FollowPilotModel
  @State private var isPaywallPresented = false
  let lagNote: String

  init(pilot: PilotSummary, lagNote: String, isPro: Bool) {
    _model = State(initialValue: FollowPilotModel(pilot: pilot, isPro: isPro))
    self.lagNote = lagNote
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Mirror into", selection: $model.target) {
            Text("Simulated portfolio").tag(PilotFollowTargetKind.portfolio)
            Text("Watchlist").tag(PilotFollowTargetKind.watchlist)
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("pilots.follow.target")
        }

        switch model.target {
        case .portfolio:
          FollowPortfolioTargetSection(model: model, isPro: billingManager.isPro)
        case .watchlist:
          FollowWatchlistTargetSection(model: model)
        }

        PilotFollowDisclaimer(lagNote: lagNote)

        if let message = model.failureMessage {
          Section { FormErrorBanner(message: message) }
        }
      }
      .navigationTitle("Follow \(model.pilot.displayName)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          if model.requiresPro(isPro: billingManager.isPro) {
            Button("Unlock Pro") { isPaywallPresented = true }
              .accessibilityIdentifier("pilots.follow.unlock")
          } else {
            Button("Follow") { Task { await follow() } }
              .disabled(model.isSubmitting || model.formProblem != nil)
              .accessibilityIdentifier("pilots.follow.submit")
          }
        }
      }
      .onChange(of: model.target) { model.failure = nil }
      .sheet(isPresented: $isPaywallPresented) {
        PaywallView(billingManager: billingManager)
      }
    }
  }

  private func follow() async {
    if await model.submit(isPro: billingManager.isPro) != nil {
      dismiss()
    } else if model.failure == .needsPro {
      isPaywallPresented = true
    }
  }
}

private struct FollowPortfolioTargetSection: View {
  @Bindable var model: FollowPilotModel
  let isPro: Bool

  var body: some View {
    Section {
      TextField("Starting amount (USD)", text: $model.capitalText)
        .keyboardType(.decimalPad)
        .accessibilityIdentifier("pilots.follow.capital")
      if let problem = model.formProblem, !model.capitalText.isEmpty {
        Text(problem).font(.footnote).foregroundStyle(.red)
      }
    } header: {
      Text("Starting amount")
    } footer: {
      if isPro {
        Text("Norviq creates a new simulated portfolio, puts this amount in as cash, and buys the pilot's current holdings at their weights. It rebalances on each new disclosure.")
      } else {
        Text("Simulated portfolios are part of Norviq Pro. Free accounts can follow one pilot into a watchlist.")
      }
    }
  }
}

private struct FollowWatchlistTargetSection: View {
  @Bindable var model: FollowPilotModel

  var body: some View {
    Section {
      Picker("Watchlist", selection: $model.watchlistListId) {
        Text("New watchlist").tag(String?.none)
        ForEach(model.watchlists) { list in
          Text(list.name).tag(Optional(list.id))
        }
      }
    } footer: {
      Text("Norviq adds each symbol the pilot buys and marks it exited when they sell. An existing watchlist must be empty.")
    }
    .task { await model.loadWatchlists() }
  }
}

private struct PilotFollowDisclaimer: View {
  let lagNote: String

  var body: some View {
    Section("Before you follow") {
      Label("This is a simulation. No real money is invested and no orders are placed.", systemImage: "flask")
      Label("Disclosures arrive late: up to 45 days for members of Congress and up to 135 days for 13F funds.", systemImage: "clock.arrow.circlepath")
      Label("Each trade is priced when Norviq sees the disclosure, not at the pilot's original price.", systemImage: "tag")
      if !lagNote.isEmpty {
        Text(lagNote).font(.footnote).foregroundStyle(.secondary)
      }
    }
  }
}
