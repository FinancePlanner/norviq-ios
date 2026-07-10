import Factory
import SwiftUI

struct ChartBuilderStandaloneScreen: View {
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var searchViewModel = AssetSearchViewModel()
  @State private var selectedAsset: AssetSearchResult?

  var body: some View {
    Group {
      if trimmedQuery.isEmpty {
        ContentUnavailableView(
          "Choose a stock",
          systemImage: "magnifyingglass",
          description: Text("Search by company name or ticker to open its chart builder.")
        )
      } else if searchViewModel.isLoading {
        ProgressView("Searching...")
      } else if let errorMessage = searchViewModel.errorMessage {
        ContentUnavailableView(
          "Search unavailable",
          systemImage: "exclamationmark.triangle",
          description: Text(errorMessage)
        )
      } else if searchViewModel.results.isEmpty {
        ContentUnavailableView.search
      } else {
        List(searchViewModel.results) { result in
          Button {
            selectedAsset = result
          } label: {
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(result.symbol)
                  .font(.headline)
                Text(result.name)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }

              Spacer()

              if let exchange = result.exchange {
                Text(exchange)
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }

              Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Open chart builder for \(result.symbol), \(result.name)")
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle("Chart Builder")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(
      text: $searchViewModel.query,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search stocks"
    )
    .onChange(of: searchViewModel.query) { _, _ in
      searchViewModel.queryChanged()
    }
    .onSubmit(of: .search) {
      submitSearch()
    }
    .navigationDestination(item: $selectedAsset) { asset in
      ProGateView(billingManager: billingManager) {
        ScrollView {
          ChartBuilderScreen(symbol: asset.symbol, companyName: asset.name)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .maxContentWidth(regularSizeClass: ContentWidth.dense)
        }
        .background(MeshGradientBackground())
        .navigationTitle(asset.symbol)
        .navigationBarTitleDisplayMode(.inline)
      }
    }
  }

  private var trimmedQuery: String {
    searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func submitSearch() {
    Task { await searchViewModel.searchNow() }
  }
}
