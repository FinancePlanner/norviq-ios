import Factory
import StockPlanShared
import SwiftUI

/// One pilot: the book Norviq would mirror, recent disclosures, and the
/// reporting-lag note, with the Follow action.
struct PilotDetailScreen: View {
  @InjectedObservable(\Container.pilotsStore) private var store
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var model: PilotDetailModel
  @State private var isFollowSheetPresented = false
  @State private var isPaywallPresented = false
  let pilot: PilotSummary

  init(pilot: PilotSummary) {
    self.pilot = pilot
    _model = State(initialValue: PilotDetailModel(slug: pilot.slug))
  }

  private var shownPilot: PilotSummary { model.detail?.pilot ?? pilot }

  private var block: PilotFollowRules.Block? {
    PilotFollowRules.block(for: shownPilot, isPro: billingManager.isPro, followCount: store.follows.count)
  }

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .wealth,
          verbatimTitle: shownPilot.displayName,
          verbatimSubtitle: PilotFormatting.subtitle(for: shownPilot)
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      if let detail = model.detail {
        Section {
          PilotFollowAction(
            block: block,
            followCount: store.follows.count,
            onFollow: { isFollowSheetPresented = true },
            onUnlock: { isPaywallPresented = true }
          )
        }

        let following = store.follows(forPilot: pilot.slug)
        if !following.isEmpty {
          Section("You follow this pilot") {
            ForEach(following) { follow in
              NavigationLink(value: PilotRoute.follow(follow)) {
                PilotFollowRow(follow: follow)
              }
            }
          }
        }

        PilotWeightsSection(weights: detail.weights)
        PilotDisclosuresSection(items: detail.recentDisclosures, skippedPuts: detail.skippedPuts)

        Section("Reporting lag") {
          Text(detail.lagNote).font(.subheadline)
        }
      }
    }
    .overlay {
      if model.isLoading, model.detail == nil {
        ProgressView()
      }
    }
    .vigilListChrome()
    .vigilNavigationTitle(shownPilot.displayName)
    .vigilInlineNavigationBar()
    .task { await model.load() }
    .refreshable { await model.load() }
    .sheet(isPresented: $isFollowSheetPresented) {
      FollowPilotSheet(pilot: shownPilot, lagNote: model.detail?.lagNote ?? "", isPro: billingManager.isPro)
    }
    .sheet(isPresented: $isPaywallPresented) {
      PaywallView(billingManager: billingManager)
    }
    .alert("Something went wrong", isPresented: errorAlertBinding($model.errorMessage)) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }
}

private struct PilotFollowAction: View {
  let block: PilotFollowRules.Block?
  let followCount: Int
  let onFollow: () -> Void
  let onUnlock: () -> Void

  var body: some View {
    switch block {
    case nil:
      Button("Follow this pilot", systemImage: "person.crop.circle.badge.plus", action: onFollow)
        .accessibilityIdentifier("pilots.detail.follow")
    case .noTradesYet?:
      Label("No trades seen yet", systemImage: "hourglass")
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("pilots.detail.noTrades")
    case .needsPro?:
      Button("Follow more pilots with Pro", systemImage: "sparkles", action: onUnlock)
    case .atLimit?:
      // The real count, not the client's copy of the limit: the server
      // owns the limit and may not match `proFollowLimit`.
      Label(
        "You follow ^[\(followCount) pilot](inflect: true), the most your plan allows. Stop one to follow another.",
        systemImage: "exclamationmark.circle"
      )
      .foregroundStyle(.secondary)
    }
  }
}

private struct PilotWeightsSection: View {
  let weights: [PilotWeight]

  var body: some View {
    Section {
      if weights.isEmpty {
        Text("No trades seen yet").foregroundStyle(.secondary)
      }
      ForEach(weights, id: \.symbol) { weight in
        LabeledContent(weight.symbol, value: PilotFormatting.weight(weight.weight))
      }
    } header: {
      Text("Current weights")
    } footer: {
      Text("A simulated portfolio following this pilot holds these symbols at these weights.")
    }
  }
}

private struct PilotDisclosuresSection: View {
  let items: [PilotDisclosureItem]
  let skippedPuts: Int

  var body: some View {
    Section {
      if items.isEmpty {
        Text("No disclosures yet.").foregroundStyle(.secondary)
      }
      ForEach(IdentifiedDisclosure.identify(items)) { disclosure in
        PilotDisclosureRow(item: disclosure.item)
      }
    } header: {
      Text("Recent disclosures")
    } footer: {
      if let note = PilotFormatting.skippedPutsNote(skippedPuts) {
        Text(note)
      }
    }
  }
}

private struct PilotDisclosureRow: View {
  let item: PilotDisclosureItem

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(PilotFormatting.disclosureTitle(item)).font(.subheadline.weight(.semibold))
      if let detail = PilotFormatting.disclosureDetail(item) {
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
      if PilotFormatting.isSkippedPut(item) {
        Text("Not mirrored: copying a put would mean going short.")
          .font(.caption2)
          .foregroundStyle(.orange)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
