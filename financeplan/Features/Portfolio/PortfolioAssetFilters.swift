import StockPlanShared
import SwiftUI

struct PortfolioAssetFilters: View {
  let colorScheme: ColorScheme
  let selectedAssetFilter: PortfolioScreen.AssetFilter
  let onSelectFilter: (PortfolioScreen.AssetFilter) -> Void

  var body: some View {
    GlassEffectContainer(spacing: 8) {
      HStack(spacing: 8) {
        ForEach(Array(PortfolioScreen.AssetFilter.allCases), id: \.self) { filter in
          PortfolioFilterButton(
            title: filter.rawValue,
            isSelected: selectedAssetFilter == filter,
            tint: AppTheme.Colors.tint(for: colorScheme),
            action: { onSelectFilter(filter) }
          )
        }
      }
    }
  }
}
