import StockPlanShared
import SwiftUI

/// Every holding that matters on one screen, plus sharing: a percent-only image
/// or a live public link the owner can revoke.
struct PortfolioOnePageScreen: View {
  let viewModel: PortfolioViewModel
  @State private var share = PortfolioShareViewModel()
  @State private var shareImage: Image?

  private var model: PortfolioOnePageModel { viewModel.onePageModel }
  private var currencyCode: String { viewModel.summary?.baseCurrency ?? "USD" }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      hero
      if model.rows.isEmpty {
        ContentUnavailableView("No holdings yet", systemImage: "chart.pie")
      } else {
        header
        ForEach(model.rows) { row in rowView(row) }
        if let other = model.otherWeightPercent {
          HStack {
            Text("Other")
            Spacer()
            Text(String(format: "%.1f%%", other))
          }
          .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
    }
    .font(.subheadline.monospacedDigit())
    .minimumScaleFactor(0.7)
    .lineLimit(1)
    .padding()
    .navigationTitle("One-page view")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { ToolbarItem(placement: .topBarTrailing) { shareMenu } }
    .task { await share.load(scope: viewModel.shareScope) }
    .task(id: model) { renderImage() }
    .alert(
      "Sharing failed",
      isPresented: Binding(get: { share.errorMessage != nil }, set: { if !$0 { share.errorMessage = nil } })
    ) {} message: {
      Text(share.errorMessage ?? "")
    }
  }

  @ViewBuilder
  private var hero: some View {
    if let summary = viewModel.summary {
      VStack(alignment: .leading, spacing: 2) {
        Text(summary.totalValue, format: .currency(code: summary.baseCurrency))
          .font(.largeTitle.bold().monospacedDigit())
        HStack(spacing: 12) {
          Text("Return \(PortfolioShareCard.signed(summary.unrealizedPnlPercent))")
          Text("Today \(PortfolioShareCard.signed(summary.dayChangePercent))")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
      }
    }
  }

  private var header: some View {
    HStack {
      Text("Symbol")
      Spacer()
      Text("Weight").frame(width: 64, alignment: .trailing)
      Text("Value").frame(width: 96, alignment: .trailing)
      Text("Return").frame(width: 72, alignment: .trailing)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  private func rowView(_ row: PortfolioOnePageRow) -> some View {
    HStack {
      Text(row.symbol).fontWeight(.semibold)
      Spacer()
      Text(String(format: "%.1f%%", row.weightPercent))
        .frame(width: 64, alignment: .trailing)
      Text(row.marketValue.map { $0.formatted(.currency(code: currencyCode).precision(.fractionLength(0))) } ?? "—")
        .frame(width: 96, alignment: .trailing)
      Text(row.unrealizedPnlPercent.map { String(format: "%+.1f%%", $0) } ?? "—")
        .foregroundStyle(PortfolioShareCard.color(row.unrealizedPnlPercent))
        .frame(width: 72, alignment: .trailing)
    }
  }

  private var shareMenu: some View {
    Menu {
      if let shareImage {
        ShareLink(item: shareImage, preview: SharePreview("My portfolio", image: shareImage)) {
          Label("Share image", systemImage: "photo")
        }
      }
      if let url = share.link.flatMap({ URL(string: $0.url) }) {
        ShareLink(item: url) {
          Label("Share link", systemImage: "link")
        }
        Button(role: .destructive) {
          Task { await share.revoke(scope: viewModel.shareScope) }
        } label: {
          Label("Stop sharing link", systemImage: "link.badge.minus")
        }
      } else {
        Button {
          Task { await share.create(scope: viewModel.shareScope) }
        } label: {
          Label("Create public link", systemImage: "link.badge.plus")
        }
      }
      Text("Shared views show percentages only.")
    } label: {
      Image(systemName: "square.and.arrow.up")
    }
    .disabled(share.isBusy)
    .accessibilityLabel("Share portfolio")
  }

  private func renderImage() {
    let card = PortfolioShareCard(
      model: model,
      totalReturnPercent: viewModel.summary?.unrealizedPnlPercent,
      dayChangePercent: viewModel.summary?.dayChangePercent
    )
    shareImage = ChartExporter.exportToImage(card, size: CGSize(width: 1080, height: 1350), scale: 1)
      .map { Image(uiImage: $0) }
  }
}
