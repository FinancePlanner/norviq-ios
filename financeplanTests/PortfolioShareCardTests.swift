import StockPlanShared
import SwiftUI
import XCTest
@testable import financeplan

@MainActor
final class PortfolioShareCardTests: XCTestCase {
  func testRendersAtShareSizeWithManyHoldings() throws {
    let pnl = (0..<20).map { index in
      PnlBySymbol(
        symbol: "SYM\(index)", currency: "USD", realizedPnl: 0, unrealizedPnl: 1_234,
        marketValue: Double(50_000 - index * 1_000), unrealizedPnlPercent: Double(index) - 5,
        dayChangePercent: 0.4, weightPercent: nil
      )
    }
    let card = PortfolioShareCard(
      model: PortfolioOnePageModel(pnl: pnl),
      totalReturnPercent: 12.34,
      dayChangePercent: -0.56
    )
    let image = try XCTUnwrap(ChartExporter.exportToImage(card, size: CGSize(width: 1080, height: 1350), scale: 1))
    XCTAssertEqual(image.size.width, 1080, accuracy: 1)
    XCTAssertEqual(image.size.height, 1350, accuracy: 1)
    // Optional artifact for eyeballing; the simulator shares the host filesystem.
    if let path = ProcessInfo.processInfo.environment["SHARE_CARD_PREVIEW_OUT"] {
      try image.pngData()?.write(to: URL(fileURLWithPath: path))
    }
  }

  func testSignedFormatting() {
    XCTAssertEqual(PortfolioShareCard.signed(12.345), "+12.35%")
    XCTAssertEqual(PortfolioShareCard.signed(-0.5), "-0.50%")
    XCTAssertEqual(PortfolioShareCard.signed(nil), "—")
  }
}

@MainActor
final class PortfolioShareCardPieTests: XCTestCase {
  func testPieStyleRendersAtShareSize() throws {
    let pnl = (0..<20).map { index in
      PnlBySymbol(
        symbol: "SYM\(index)", currency: "USD", realizedPnl: 0, unrealizedPnl: 0,
        marketValue: Double(50_000 - index * 1_000), unrealizedPnlPercent: 1, dayChangePercent: 0.4
      )
    }
    let card = PortfolioShareCard(
      model: PortfolioOnePageModel(pnl: pnl),
      totalReturnPercent: 12.34,
      dayChangePercent: -0.56,
      style: .pie
    )
    let image = try XCTUnwrap(ChartExporter.exportToImage(card, size: CGSize(width: 1080, height: 1350), scale: 1))
    XCTAssertEqual(image.size.width, 1080, accuracy: 1)
    XCTAssertEqual(image.size.height, 1350, accuracy: 1)
    if let path = ProcessInfo.processInfo.environment["SHARE_CARD_PIE_PREVIEW_OUT"] {
      try image.pngData()?.write(to: URL(fileURLWithPath: path))
    }
  }

  func testPieSlicesAreRowsPlusOther() {
    let pnl = (0..<15).map { PnlBySymbol(symbol: "S\($0)", currency: "USD", realizedPnl: 0, unrealizedPnl: 0, weightPercent: Double($0 + 1)) }
    let slices = PortfolioShareCard.pieSlices(for: PortfolioOnePageModel(pnl: pnl))
    XCTAssertEqual(slices.count, 13)
    XCTAssertEqual(slices.last?.label, "Other")
    XCTAssertEqual(slices.reduce(0) { $0 + $1.weight }, 120, accuracy: 0.001)
  }
}

@MainActor
final class PortfolioShareCardBrandingTests: XCTestCase {
  /// Samples the top-left corner, which is plain card background in every style.
  private func cornerBrightness(_ image: UIImage) throws -> CGFloat {
    let cg = try XCTUnwrap(image.cgImage)
    let context = try XCTUnwrap(CGContext(
      data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(cg, in: CGRect(x: -2, y: -(CGFloat(cg.height) - 3), width: CGFloat(cg.width), height: CGFloat(cg.height)))
    let pixel = try XCTUnwrap(context.data?.assumingMemoryBound(to: UInt8.self))
    return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
  }

  func testCardIsLightEvenWhenThePhoneIsInDarkMode() throws {
    for style in PortfolioShareCard.Style.allCases {
      let card = PortfolioShareCard(
        model: PortfolioOnePageModel(pnl: [PnlBySymbol(symbol: "AAPL", currency: "USD", realizedPnl: 0, unrealizedPnl: 0, weightPercent: 100)]),
        totalReturnPercent: 1, dayChangePercent: 1, style: style
      )
      .environment(\.colorScheme, .dark)
      let image = try XCTUnwrap(ChartExporter.exportToImage(card, size: CGSize(width: 1080, height: 1350), scale: 1))
      XCTAssertGreaterThan(try cornerBrightness(image), 0.9, "\(style) rendered dark")
      if let dir = ProcessInfo.processInfo.environment["SHARE_CARD_BRAND_PREVIEW_DIR"] {
        try image.pngData()?.write(to: URL(fileURLWithPath: "\(dir)/share-\(style.rawValue)-dark-phone.png"))
      }
    }
  }
}
