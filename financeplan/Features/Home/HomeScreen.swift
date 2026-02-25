import SwiftUI

private enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case watchlist
  case settings
}

struct HomeScreen: View {
  let onLogout: () async -> Void
  @State private var selectedTab: HomeTab = .dashboard

  var body: some View {
    TabView(selection: $selectedTab) {
      DashboardTab()
        .tabItem {
          Label("Home", systemImage: "house.fill")
        }
        .tag(HomeTab.dashboard)

      PortfolioTab()
        .tabItem {
          Label("Portfolio", systemImage: "briefcase.fill")
        }
        .tag(HomeTab.portfolio)

      WatchlistTab()
        .tabItem {
          Label("Watchlist", systemImage: "star.fill")
        }
        .tag(HomeTab.watchlist)

      SettingsTab(onLogout: onLogout)
        .tabItem {
          Label("Settings", systemImage: "gearshape.fill")
        }
        .tag(HomeTab.settings)
    }
  }
}

private struct DashboardTab: View {
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          PortfolioSummaryWidget()
          DailyPerformanceWidget()
          TopMoversWidget()
          AllocationWidget()
        }
        .padding(16)
      }
      .navigationTitle("Dashboard")
      .background(Color(.systemGroupedBackground))
    }
  }
}

private struct PortfolioTab: View {
  private let positions: [PortfolioPosition] = [
    .init(symbol: "AAPL", quantity: 18, averageCost: 168.20, marketPrice: 191.70),
    .init(symbol: "MSFT", quantity: 7, averageCost: 352.00, marketPrice: 418.30),
    .init(symbol: "NVDA", quantity: 12, averageCost: 98.40, marketPrice: 125.60),
    .init(symbol: "AMZN", quantity: 10, averageCost: 157.15, marketPrice: 177.10),
  ]

  var body: some View {
    NavigationStack {
      List(positions) { position in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(position.symbol)
              .font(.headline)
            Spacer()
            Text(position.marketValue.currency)
              .font(.subheadline.weight(.semibold))
          }

          HStack(spacing: 10) {
            Text("Qty \(Int(position.quantity))")
            Text("Avg \(position.averageCost.currency)")
            Text("Now \(position.marketPrice.currency)")
          }
          .font(.footnote)
          .foregroundStyle(.secondary)

          Text(position.unrealizedPnLString)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(position.unrealizedPnL >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
      }
      .navigationTitle("Portfolio")
    }
  }
}

private struct WatchlistTab: View {
  private let watchlist: [WatchlistItem] = [
    .init(symbol: "TSLA", price: 241.80, changePercent: 1.92),
    .init(symbol: "META", price: 502.40, changePercent: -0.64),
    .init(symbol: "AMD", price: 176.25, changePercent: 2.15),
    .init(symbol: "GOOGL", price: 186.91, changePercent: 0.43),
  ]

  var body: some View {
    NavigationStack {
      List(watchlist) { item in
        HStack {
          Text(item.symbol)
            .font(.headline)
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(item.price.currency)
              .font(.subheadline.weight(.semibold))
            Text(item.changePercentString)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(item.changePercent >= 0 ? .green : .red)
          }
        }
        .padding(.vertical, 2)
      }
      .navigationTitle("Watchlist")
    }
  }
}

private struct SettingsTab: View {
  let onLogout: () async -> Void
  @State private var isLoggingOut = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Account")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text("Signed in to FinPlanner")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))

        Button {
          Task {
            guard !isLoggingOut else { return }
            isLoggingOut = true
            await onLogout()
            isLoggingOut = false
          }
        } label: {
          HStack(spacing: 8) {
            if isLoggingOut {
              ProgressView()
                .tint(.white)
            }
            Text("Log out")
              .fontWeight(.semibold)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .foregroundStyle(.white)
          .background(Color.red)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoggingOut)

        Spacer()
      }
      .padding(16)
      .navigationTitle("Settings")
      .background(Color(.systemGroupedBackground))
    }
  }
}

private struct PortfolioSummaryWidget: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Portfolio Value")
        .font(.footnote)
        .foregroundStyle(.secondary)

      Text("$124,830.42")
        .font(.system(size: 32, weight: .bold, design: .rounded))

      HStack(spacing: 8) {
        Label("+$2,814.11", systemImage: "arrow.up.right")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.green)

        Text("(+2.31%) today")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(
      LinearGradient(
        colors: [Color.blue.opacity(0.18), Color.cyan.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 16)
    )
  }
}

private struct DailyPerformanceWidget: View {
  private let points: [Double] = [112, 118, 121, 119, 124, 127, 125, 129, 132]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Daily Performance")
        .font(.headline)

      HStack(alignment: .bottom, spacing: 6) {
        ForEach(points.indices, id: \.self) { index in
          let value = points[index]
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.blue.opacity(index == points.indices.last ? 0.9 : 0.55))
            .frame(height: CGFloat(value - 100))
            .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 90)

      Text("Intraday trend (mock)")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
  }
}

private struct TopMoversWidget: View {
  private let movers: [Mover] = [
    .init(symbol: "NVDA", changePercent: 4.12),
    .init(symbol: "TSLA", changePercent: 2.84),
    .init(symbol: "META", changePercent: -1.21),
    .init(symbol: "AMD", changePercent: 3.17),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Top Movers")
        .font(.headline)

      ForEach(movers) { mover in
        HStack {
          Text(mover.symbol)
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text(mover.changeString)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(mover.changePercent >= 0 ? .green : .red)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
  }
}

private struct AllocationWidget: View {
  private let buckets: [AllocationBucket] = [
    .init(name: "Tech", percent: 52, color: .blue),
    .init(name: "Index ETFs", percent: 23, color: .indigo),
    .init(name: "Finance", percent: 15, color: .teal),
    .init(name: "Cash", percent: 10, color: .orange),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Allocation")
        .font(.headline)

      ForEach(buckets) { bucket in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(bucket.name)
              .font(.footnote.weight(.semibold))
            Spacer()
            Text("\(bucket.percent)%")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }

          GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.tertiarySystemFill))
              .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                  .fill(bucket.color)
                  .frame(width: proxy.size.width * CGFloat(bucket.percent) / 100)
              }
          }
          .frame(height: 8)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
  }
}

private struct PortfolioPosition: Identifiable {
  let id = UUID()
  let symbol: String
  let quantity: Double
  let averageCost: Double
  let marketPrice: Double

  var marketValue: Double {
    quantity * marketPrice
  }

  var unrealizedPnL: Double {
    quantity * (marketPrice - averageCost)
  }

  var unrealizedPnLString: String {
    let sign = unrealizedPnL >= 0 ? "+" : ""
    return "\(sign)\(unrealizedPnL.currency)"
  }
}

private struct WatchlistItem: Identifiable {
  let id = UUID()
  let symbol: String
  let price: Double
  let changePercent: Double

  var changePercentString: String {
    let sign = changePercent >= 0 ? "+" : ""
    return "\(sign)\(String(format: "%.2f", changePercent))%"
  }
}

private struct Mover: Identifiable {
  let id = UUID()
  let symbol: String
  let changePercent: Double

  var changeString: String {
    let sign = changePercent >= 0 ? "+" : ""
    return "\(sign)\(String(format: "%.2f", changePercent))%"
  }
}

private struct AllocationBucket: Identifiable {
  let id = UUID()
  let name: String
  let percent: Int
  let color: Color
}

private extension Double {
  var currency: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
  }
}
