import StockPlanShared
import SwiftUI

/// The dashboard's market brief: the morning pre-market brief or the evening
/// close recap, shared by every user and written in the app's language.
/// Renders nothing until there is a brief to show; `MarketBriefLifecycle`
/// does the loading.
struct MarketBriefCard: View {
  static let scrollID = "dashboard.marketBrief"

  @Bindable var viewModel: MarketBriefViewModel

  var body: some View {
    if case let .loaded(brief, _) = viewModel.state {
      GlassCard {
        VStack(alignment: .leading, spacing: 16) {
          MarketBriefHeader(brief: brief, isFetching: viewModel.isFetching)

          if viewModel.showsSelector {
            selector
          }

          if let greeting = brief.greeting, !greeting.isEmpty {
            Text(verbatim: greeting)
              .typography(.small)
              .fixedSize(horizontal: false, vertical: true)
          }

          if !brief.groups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              ForEach(brief.groups, id: \.id) { group in
                MarketBriefQuoteGroupView(group: group)
              }
            }
          }

          if !brief.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              ForEach(numberedItems(brief.items), id: \.offset) { entry in
                MarketBriefItemRow(item: entry.item, number: entry.number)
              }
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .id(Self.scrollID)
    }
  }

  private var selector: some View {
    Picker("Brief", selection: $viewModel.selection) {
      Text("Latest").tag(MarketBriefViewModel.Selection.latest)
      Text("Previous").tag(MarketBriefViewModel.Selection.previous)
    }
    .pickerStyle(.segmented)
    .onChange(of: viewModel.selection) { _, selection in
      Task { await viewModel.select(selection) }
    }
  }

  /// Evening stories are numbered 1, 2, 3 among themselves.
  private func numberedItems(_ items: [MarketBriefItem]) -> [NumberedItem] {
    var storyCount = 0
    return items.enumerated().map { offset, item in
      if item.kind == .story { storyCount += 1 }
      return NumberedItem(offset: offset, item: item, number: storyCount)
    }
  }

  private struct NumberedItem {
    let offset: Int
    let item: MarketBriefItem
    let number: Int
  }
}
