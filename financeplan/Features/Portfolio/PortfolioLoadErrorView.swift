import StockPlanShared
import SwiftUI

struct PortfolioLoadErrorView: View {
  let error: String
  let onRetry: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("Unable to Load Portfolio", systemImage: "exclamationmark.triangle")
    } description: {
      Text(error)
    } actions: {
      Button("Retry", action: onRetry)
        .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
