import Factory
import StockPlanShared
import SwiftUI

/// Pilots the viewer follows, then every politician and fund they can follow.
struct PilotsBrowseScreen: View {
  @InjectedObservable(\Container.pilotsStore) private var store

  var body: some View {
    List {
      Section {
        VigilPageHeader(
          watch: .wealth,
          title: "Pilots",
          subtitle: "Mirror a member of Congress or a 13F fund in a simulation. No real money moves."
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
      }

      if !store.follows.isEmpty {
        Section("Following") {
          ForEach(store.follows) { follow in
            NavigationLink {
              PilotFollowDetailScreen(follow: follow)
            } label: {
              PilotFollowRow(follow: follow)
            }
          }
        }
      }

      PilotListSection(title: "Politicians", pilots: store.pilots.filter { $0.kind == .politician })
      PilotListSection(title: "Funds", pilots: store.pilots.filter { $0.kind == .fund })
    }
    .overlay {
      if store.availability == .unavailable {
        ContentUnavailableView(
          "Pilots aren't available",
          systemImage: "person.2.slash",
          description: Text("Following pilots isn't switched on yet.")
        )
      } else if store.isLoading, store.pilots.isEmpty {
        ProgressView()
      }
    }
    .vigilListChrome()
    .vigilNavigationTitle("Pilots")
    .vigilInlineNavigationBar()
    .task { await store.load() }
    .refreshable { await store.load() }
    .alert("Something went wrong", isPresented: errorBinding) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(store.errorMessage ?? "")
    }
  }

  private var errorBinding: Binding<Bool> {
    Binding(
      get: { store.errorMessage != nil },
      set: { if !$0 { store.errorMessage = nil } }
    )
  }
}

private struct PilotListSection: View {
  let title: LocalizedStringKey
  let pilots: [PilotSummary]

  var body: some View {
    if !pilots.isEmpty {
      Section(title) {
        ForEach(pilots) { pilot in
          NavigationLink {
            PilotDetailScreen(pilot: pilot)
          } label: {
            PilotRow(pilot: pilot)
          }
          .accessibilityIdentifier("pilots.pilot.\(pilot.slug)")
        }
      }
    }
  }
}

private struct PilotRow: View {
  let pilot: PilotSummary

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: pilot.kind == .politician ? "building.columns" : "chart.pie")
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(pilot.displayName).font(.headline)
        Text(PilotFormatting.subtitle(for: pilot))
          .font(.caption)
          .foregroundStyle(pilot.holdingsCount == 0 ? Color.orange : Color.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
