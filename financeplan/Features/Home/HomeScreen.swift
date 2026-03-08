import Charts
import Combine
import Factory
import Foundation
import StockPlanShared
import SwiftUI

private enum HomeTab: Hashable {
  case dashboard
  case portfolio
  case watchlist
  case more
}

struct HomeScreen: View {
  @EnvironmentObject private var sessionManager: SessionManager
  @Environment(\.colorScheme) private var colorScheme
  let onLogout: () async -> Void
  @State private var selectedTab: HomeTab = .dashboard
  @State private var isMoreSheetPresented = false
  @State private var showUserMenu = false
  @State private var isHelpPresented = false
  @State private var isProfilePresented = false

  var body: some View {
    ZStack {
      TabView(selection: $selectedTab) {
        NavigationStack {
          DashboardTab()
            .navigationBarHidden(true)
        }
        .tabItem {
          Label("Home", systemImage: "house.fill")
        }
        .tag(HomeTab.dashboard)

        NavigationStack {
          PortfolioTab()
            .navigationBarHidden(true)
        }
        .tabItem {
          Label("Portfolio", systemImage: "briefcase.fill")
        }
        .tag(HomeTab.portfolio)

        NavigationStack {
          WatchlistTab()
            .navigationBarHidden(true)
        }
        .tabItem {
          Label("Watchlist", systemImage: "star.fill")
        }
        .tag(HomeTab.watchlist)

        Color.clear
          .tabItem {
            Label("More", systemImage: "ellipsis")
          }
          .tag(HomeTab.more)
      }
      .tint(AppTheme.Colors.tint(for: colorScheme))
      .toolbarBackground(.visible, for: .tabBar)
      .toolbarBackground(AppTheme.Colors.tabBarBackground(for: colorScheme), for: .tabBar)
      .onChange(of: selectedTab) { newValue in
        if newValue == .more {
          isMoreSheetPresented = true
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            selectedTab = .dashboard
          }
        }
      }
      .ignoresSafeArea(.keyboard)
      .blur(radius: showUserMenu ? 6 : 0)
      .scaleEffect(showUserMenu ? 0.995 : 1)
      .animation(.spring(response: 0.28, dampingFraction: 0.9), value: showUserMenu)
      .allowsHitTesting(!showUserMenu)

      // TODO improve this Dim overlay
    
      if showUserMenu {
        Rectangle()
          .fill(.black.opacity(colorScheme == .dark ? 0.45 : 0.25))
          .ignoresSafeArea()
          .transition(.opacity)
          .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
              showUserMenu = false
            }
          }
          .zIndex(0.5)
      }

      if showUserMenu {
        UserMenuDrawer(
          isPresented: $showUserMenu,
          username: sessionManager.username,
          onProfile: {
            isProfilePresented = true
          },
          onHelp: {
            isHelpPresented = true
          }
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(1)
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      AppTopBar(
        username: sessionManager.username,
        isUserMenuPresented: showUserMenu,
        onUserTap: {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showUserMenu = true
          }
        }
      )
    }
    .sheet(isPresented: $isMoreSheetPresented) {
      MoreSheet(onLogout: onLogout)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $isHelpPresented) {
      NavigationStack {
        Text("Help & Support")
          .navigationTitle("Help")
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Done") { isHelpPresented = false }
            }
          }
      }
    }
    .sheet(isPresented: $isProfilePresented) {
      UserProfileView()
    }
  }
}



private struct MoreSheet: View {
  let onLogout: () async -> Void
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink {
            SettingsDetailView(onLogout: onLogout)
          } label: {
            Label("Settings", systemImage: "gearshape.fill")
          }
        }

        Section {
          NavigationLink {
            Text("Help & Support")
              .navigationTitle("Help")
          } label: {
            Label("Help & Support", systemImage: "questionmark.circle")
          }

          NavigationLink {
            Text("About FinPlanner")
              .navigationTitle("About")
          } label: {
            Label("About", systemImage: "info.circle")
          }
        }
      }
      .navigationTitle("More")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))
        }
      }
    }
  }
}

// MARK: - Settings Detail View

private struct SettingsDetailView: View {
  let onLogout: () async -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var isLoggingOut = false
  @AppStorage(AppAppearance.storageKey) private var appAppearanceRawValue = AppAppearance.system
    .rawValue

  var body: some View {
    List {
      Section("Account") {
        Text("Signed in to FinPlanner")
          .typography(.small)
          .foregroundStyle(.secondary)
      }

      Section("Appearance") {
        Picker("Appearance", selection: appAppearanceBinding) {
          ForEach(AppAppearance.allCases, id: \.self) { appearance in
            Text(appearance.title)
              .tag(appearance)
          }
        }
        .pickerStyle(.segmented)

        Text(selectedAppearance.subtitle)
          .typography(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
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
              .typography(.button, weight: .semibold)
          }
          .frame(maxWidth: .infinity)
          .foregroundStyle(AppTheme.Colors.danger)
        }
        .disabled(isLoggingOut)
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
  }

  private var appAppearanceBinding: Binding<AppAppearance> {
    Binding(
      get: { AppAppearance.from(appAppearanceRawValue) },
      set: { appAppearanceRawValue = $0.rawValue }
    )
  }

  private var selectedAppearance: AppAppearance {
    AppAppearance.from(appAppearanceRawValue)
  }
}

// MARK: - Tab Content Views

private struct DashboardTab: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        PortfolioSummaryWidget()
        DailyPerformanceWidget()
        TopMoversWidget()
        AllocationWidget()
      }
      .padding(16)
    }
    .background(MeshGradientBackground().ignoresSafeArea())
  }
}

private struct PortfolioTab: View {
  @Environment(\.colorScheme) private var colorScheme
  @StateObject private var viewModel = PortfolioViewModel()
  @State private var isManualImportPresented = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      Group {
        if viewModel.isLoading {
          ProgressView("Loading portfolio...")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let error = viewModel.errorMessage {
          VStack(spacing: 10) {
            Text(error)
              .foregroundStyle(AppTheme.Colors.danger)
              .typography(.small)
            Button("Retry") { Task { await viewModel.load() } }
              .buttonStyle(.bordered)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if viewModel.stocks.isEmpty {
          Text("No stocks yet.")
            .foregroundStyle(.secondary)
            .typography(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
          List(viewModel.stocks, id: \.id) { stock in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(stock.symbol)
                  .typography(.label, weight: .semibold)
                Spacer()
                Text((stock.shares * stock.buyPrice).currency)
                  .typography(.small, weight: .semibold)
              }

              HStack(spacing: 10) {
                Text("Qty \(Int(stock.shares))")
                Text("Avg \(stock.buyPrice.currency)")
                Text("Date \(stock.buyDate)")
              }
              .typography(.nano)
              .foregroundStyle(.secondary)

              if let notes = stock.notes, !notes.isEmpty {
                Text(notes)
                  .typography(.nano)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 4)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
              Button(role: .destructive) {
                Task { await viewModel.delete(id: stock.id) }
              } label: {
                Label("Delete", systemImage: "trash")
              }

              Button {
                viewModel.beginEdit(stock)
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
        }
      }
      .sheet(
        isPresented: Binding<Bool>(
          get: { viewModel.editingStock != nil },
          set: { if !$0 { viewModel.editingStock = nil } }
        )
      ) {
        if let stock = viewModel.editingStock {
          EditStockSheet(
            stock: stock,
            isSaving: viewModel.isSaving,
            onCancel: { viewModel.editingStock = nil },
            onSave: { updated in
              Task { await viewModel.saveEdit(updated) }
            }
          )
        } else {
          EmptyView()
        }
      }
      .background(AppTheme.Colors.pageBackground(for: colorScheme))
      .task { await viewModel.load() }
      .refreshable { await viewModel.load() }

      Button {
        isManualImportPresented = true
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 32, height: 32)
          .background(AppTheme.Colors.tint(for: colorScheme))
          .clipShape(Circle())
          .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
      }
      .accessibilityIdentifier("portfolio.fab")
      .padding(.trailing, 16)
      .padding(.bottom, 24)
    }
    .sheet(isPresented: $isManualImportPresented) {
      ManualImportScreen(
        headerNamespace: nil,
        onBack: { isManualImportPresented = false },
        onDone: { _ in
          isManualImportPresented = false
          Task { await viewModel.load() }
        }
      )
    }
  }

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .init(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()
}

private struct WatchlistTab: View {
  @Environment(\.colorScheme) private var colorScheme

  private let watchlist: [WatchlistItem] = [
    .init(symbol: "TSLA", price: 241.80, changePercent: 1.92),
    .init(symbol: "META", price: 502.40, changePercent: -0.64),
    .init(symbol: "AMD", price: 176.25, changePercent: 2.15),
    .init(symbol: "GOOGL", price: 186.91, changePercent: 0.43),
  ]

  var body: some View {
    List(watchlist) { item in
      HStack {
        Text(item.symbol)
          .typography(.label, weight: .semibold)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(item.price.currency)
            .typography(.small, weight: .semibold)
          Text(item.changePercentString)
            .typography(.nano, weight: .semibold)
            .foregroundStyle(
              item.changePercent >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
        }
      }
      .padding(.vertical, 2)
    }
    .scrollContentBackground(.hidden)
    .background(AppTheme.Colors.pageBackground(for: colorScheme))
  }
}

// MARK: - Dashboard Widgets

private struct PortfolioSummaryWidget: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        Text("Portfolio Value")
          .typography(.nano)
          .foregroundStyle(.secondary)

        Text("$124,830.42")
          .typography(.hero, weight: .bold)

        HStack(spacing: 8) {
          Label("+$2,814.11", systemImage: "arrow.up.right")
            .typography(.small, weight: .semibold)
            .foregroundStyle(AppTheme.Colors.success)

          Text("(+2.31%) today")
            .typography(.small)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    //    .sheet(isPresented: .constant(true)) {
    //        ConcentricRectangle()
    //            .fill(AppTheme.Colors.tertiaryFill(for: colorScheme))
    //            .frame(height: 120)
    //            .cornerRadius(16)
    //            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    //            .padding(40)
    //            .ignoresSafeArea()
    //            .presentationDetents([.medium])
    //    }
    //    .overlay {
    //      ConcentricRectangles(count: 1, spacing: 6, cornerRadius: 16)
    //        .stroke(AppTheme.Colors.tertiaryFill(for: colorScheme), lineWidth: 1)
    //        .allowsHitTesting(false)
    //    }
  }
}

private struct DailyPerformanceWidget: View {
  @Environment(\.colorScheme) private var colorScheme
  private let points: [Double] = [112, 118, 121, 119, 124, 127, 125, 129, 132]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        Text("Daily Performance")
          .typography(.label, weight: .semibold)

        Chart {
          ForEach(Array(points.enumerated()), id: \.offset) { index, value in
            LineMark(
              x: .value("Time", index),
              y: .value("Value", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(AppTheme.Colors.tint(for: colorScheme))

            AreaMark(
              x: .value("Time", index),
              y: .value("Value", value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
              LinearGradient(
                colors: [
                  AppTheme.Colors.tint(for: colorScheme).opacity(0.3),
                  .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 120)

        Text("Intraday trend (mock)")
          .typography(.nano)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    //    .overlay {
    //      ConcentricRectangles(count: 1, spacing: 6, cornerRadius: 16)
    //        .stroke(AppTheme.Colors.tertiaryFill(for: colorScheme), lineWidth: 1)
    //        .allowsHitTesting(false)
    //    }
  }
}

private struct TopMoversWidget: View {
  @Environment(\.colorScheme) private var colorScheme

  private let movers: [Mover] = [
    .init(symbol: "NVDA", changePercent: 4.12),
    .init(symbol: "TSLA", changePercent: 2.84),
    .init(symbol: "META", changePercent: -1.21),
    .init(symbol: "AMD", changePercent: 3.17),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Top Movers")
        .typography(.label, weight: .semibold)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(movers) { mover in
            GlassCard(cornerRadius: 16) {
              VStack(alignment: .leading, spacing: 6) {
                Text(mover.symbol)
                  .typography(.small, weight: .bold)
                Text(mover.changeString)
                  .typography(.label, weight: .semibold)
                  .foregroundStyle(
                    mover.changePercent >= 0 ? AppTheme.Colors.success : AppTheme.Colors.danger)
              }
              .frame(width: 100, alignment: .leading)
            }
            //            .overlay {
            //              ConcentricRectangles(count: 1, spacing: 6, cornerRadius: 16)
            //                .stroke(AppTheme.Colors.tertiaryFill(for: colorScheme), lineWidth: 1)
            //                .allowsHitTesting(false)
            //            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct AllocationWidget: View {
  @Environment(\.colorScheme) private var colorScheme

  private var buckets: [AllocationBucket] {
    [
      .init(name: "Tech", percent: 52, color: AppTheme.Colors.tint(for: colorScheme)),
      .init(name: "Index ETFs", percent: 23, color: .indigo),
      .init(name: "Finance", percent: 15, color: .teal),
      .init(name: "Cash", percent: 10, color: .orange),
    ]
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        Text("Allocation")
          .typography(.label, weight: .semibold)

        ForEach(buckets) { bucket in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(bucket.name)
                .typography(.nano, weight: .semibold)
              Spacer()
              Text("\(bucket.percent)%")
                .typography(.nano)
                .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
              RoundedRectangle(cornerRadius: 4)
                .fill(AppTheme.Colors.tertiaryFill(for: colorScheme))
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
    }
    //    .overlay {
    //      ConcentricRectangles(count: 1, spacing: 6, cornerRadius: 16)
    //        .stroke(AppTheme.Colors.tertiaryFill(for: colorScheme), lineWidth: 1)
    //        .allowsHitTesting(false)
    //    }
  }
}

private struct PortfolioPosition: Identifiable {
  let symbol: String
  let quantity: Double
  let averageCost: Double
  let marketPrice: Double

  var id: String { symbol }
  var marketValue: Double { quantity * marketPrice }
  var unrealizedPnL: Double { (marketPrice - averageCost) * quantity }
  var unrealizedPnLString: String {
    let sign = unrealizedPnL >= 0 ? "+" : "-"
    return "\(sign)\(abs(unrealizedPnL).currency)"
  }
}

private struct WatchlistItem: Identifiable {
  let symbol: String
  let price: Double
  let changePercent: Double

  var id: String { symbol }
  var changePercentString: String {
    let sign = changePercent >= 0 ? "+" : "-"
    return "\(sign)\(String(format: "%.2f%%", abs(changePercent)))"
  }
}

private struct Mover: Identifiable {
  let symbol: String
  let changePercent: Double

  var id: String { symbol }
  var changeString: String {
    let sign = changePercent >= 0 ? "+" : "-"
    return "\(sign)\(String(format: "%.2f%%", abs(changePercent)))"
  }
}

private struct AllocationBucket: Identifiable {
  let name: String
  let percent: Int
  let color: Color

  var id: String { name }
}

//private struct ConcentricRectangles: Shape {
//  var count: Int
//  var spacing: CGFloat
//  var cornerRadius: CGFloat
//
//  func path(in rect: CGRect) -> Path {
//    var path = Path()
//    let maxInsetAllowed = min(rect.width, rect.height) / 2
//    for i in 0..<count {
//      let inset = CGFloat(i) * spacing
//      if inset > maxInsetAllowed { break }
//      let r = rect.insetBy(dx: inset, dy: inset)
//      path.addRoundedRect(in: r, cornerSize: .init(width: cornerRadius, height: cornerRadius))
//    }
//    return path
//  }
//}

extension Double {
  var currency: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
  }
}

@MainActor
private final class PortfolioViewModel: ObservableObject {
  @Published var stocks: [StockResponse] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  // edit
  @Published var editingStock: StockResponse? = nil
  @Published var isSaving = false

  func load() async {
    guard !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      let service = Container.shared.stockService()
      stocks = try await service.fetchPortfolio()
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load portfolio."
    }
  }

  func delete(id: String) async {
    let old = stocks

    stocks.removeAll(where: { $0.id == id })

    do {
      let service = Container.shared.stockService()
      try await service.delete(id: id)
    } catch {
      stocks = old
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to delete stock."
    }
  }

  func beginEdit(_ stock: StockResponse) {
    editingStock = stock
  }

  func saveEdit(_ updated: StockResponse) async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }

    do {
      let service = Container.shared.stockService()
      let saved = try await service.updateStock(updated)

      if let idx = stocks.firstIndex(where: { $0.id == saved.id }) {
        stocks[idx] = saved
      } else {
        stocks.insert(saved, at: 0)
      }
      editingStock = nil
    } catch {
      errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to update stock."
    }
  }
}

// Removed the Binding extension helper for String? as it is no longer used.

private struct EditStockSheet: View {
  let stock: StockResponse
  let isSaving: Bool
  let onCancel: () -> Void
  let onSave: (StockResponse) -> Void

  @State private var shares: Double
  @State private var buyPrice: Double
  @State private var notes: String

  init(
    stock: StockResponse, isSaving: Bool, onCancel: @escaping () -> Void,
    onSave: @escaping (StockResponse) -> Void
  ) {
    self.stock = stock
    self.isSaving = isSaving
    self.onCancel = onCancel
    self.onSave = onSave
    _shares = State(initialValue: stock.shares)
    _buyPrice = State(initialValue: stock.buyPrice)
    _notes = State(initialValue: stock.notes ?? "")
  }

  var body: some View {
    NavigationStack {
      Form {
        // Symbol is displayed but not editable here to keep API unchanged
        HStack {
          Text("Symbol")
          Spacer()
          Text(stock.symbol)
            .foregroundStyle(.secondary)
        }
        TextField("Shares", value: $shares, format: .number)
        TextField("Buy price", value: $buyPrice, format: .number)
        TextField("Notes", text: $notes)
      }
      .navigationTitle("Edit Stock")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isSaving ? "Saving..." : "Save") {
            // Build a new StockResponse with edited fields, preserving immutable properties
            var updated = stock
            // If StockResponse is a struct with let properties, rebuild via a memberwise init
            // Attempt to use a convenience pattern: create a new instance preserving id/symbol/buyDate
            updated = StockResponse(
              id: stock.id,
              symbol: stock.symbol,
              shares: shares,
              buyPrice: buyPrice,
              buyDate: stock.buyDate,
              notes: notes.isEmpty ? nil : notes
            )
            onSave(updated)
          }
          .disabled(isSaving)
        }
      }
    }
  }
}
