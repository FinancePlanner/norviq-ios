import Factory
import SwiftUI

struct ChartBuilderStandaloneScreen: View {
  @Environment(\.colorScheme) private var colorScheme
  @InjectedObservable(\Container.billingManager) private var billingManager
  @State private var searchViewModel = AssetSearchViewModel()
  @State private var selectedAsset: AssetSearchResult?

  var body: some View {
    Group {
      if trimmedQuery.isEmpty {
        emptyStateContent
      } else if searchViewModel.isLoading {
        loadingContent
      } else if let errorMessage = searchViewModel.errorMessage {
        errorContent(errorMessage)
      } else if searchViewModel.results.isEmpty {
        emptyResultsContent
      } else {
        resultsList
      }
    }
    .vigilNavigationTitle("Chart Builder")
    .vigilInlineNavigationBar()
    .vigilScreenBackground()
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
        .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
        .vigilScreenBackground()
        .vigilNavigationTitle(asset.symbol)
        .vigilInlineNavigationBar()
      }
    }
  }

  private var chartBuilderHeader: some View {
    VigilPageHeader(
      watch: .wealth,
      title: "Chart Builder",
      subtitle: "Search for a stock, then combine up to 20 financial metrics with peer tickers"
    )
  }

  private var emptyStateContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        chartBuilderHeader
        ContentUnavailableView(
          "Choose a stock",
          systemImage: "magnifyingglass",
          description: Text("Search by company name or ticker to open its chart builder.")
        )
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
  }

  private var loadingContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        chartBuilderHeader
        ProgressView("Searching...")
          .frame(maxWidth: .infinity)
          .padding(.top, 40)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
  }

  private func errorContent(_ message: String) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        chartBuilderHeader
        ContentUnavailableView(
          "Search unavailable",
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
  }

  private var emptyResultsContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        chartBuilderHeader
        ContentUnavailableView.search
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 20)
    }
  }

  private var resultsList: some View {
    List {
      Section {
        chartBuilderHeader
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
          .listRowBackground(Color.clear)
      }

      ForEach(searchViewModel.results) { result in
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
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(AppTheme.Colors.pageBackground(for: colorScheme).ignoresSafeArea())
  }

  private var trimmedQuery: String {
    searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func submitSearch() {
    Task { await searchViewModel.searchNow() }
  }
}
