import SwiftUI
import UIKit
import XCTest
@testable import financeplan

/// Brygada 1918 is the display face for page titles and the Home greeting
/// (DS 2.0 § 9.0 Q2), and nowhere else. These pin that it is bundled, that the
/// role scales with Dynamic Type, that a missing font degrades to the system
/// serif rather than to nothing, and that no figure ever renders in it.
@MainActor
final class DisplayFontTests: XCTestCase {

  func testBrygadaIsRegisteredInTheApp() {
    // UIAppFonts in Info.plist; the test host is the app.
    XCTAssertNotNil(UIFont(name: "Brygada1918-SemiBold", size: 17), "Brygada1918-SemiBold.ttf is not registered")
    XCTAssertNotNil(UIFont(name: "Brygada1918-Regular", size: 17), "Brygada1918-Regular.ttf is not registered")
  }

  func testDisplayTitleIsTwentyEightPointSemiboldRelativeToTitle() {
    let style = TypographyStyle(.displayTitle)
    XCTAssertEqual(style.size, 28)
    XCTAssertEqual(style.weight, .semibold)
    XCTAssertEqual(style.relativeTextStyle, .title)
    XCTAssertFalse(style.usesTabularNumbers, "the display face never sets figures")
  }

  func testDisplayTitleResolvesToBrygadaSemiBold() {
    let font = TypographyStyle(.displayTitle).uiFont(compatibleWith: Self.traits(.large))
    XCTAssertEqual(font.fontName, "Brygada1918-SemiBold")
    XCTAssertEqual(font.pointSize, 28, accuracy: 0.01, "28pt at the default text size")
  }

  func testDisplayTitleScalesWithDynamicType() {
    let style = TypographyStyle(.displayTitle)
    let large = style.uiFont(compatibleWith: Self.traits(.large))
    let ax3 = style.uiFont(compatibleWith: Self.traits(.accessibilityExtraLarge))
    XCTAssertGreaterThan(ax3.pointSize, large.pointSize, "the serif title must grow at accessibility sizes")
    XCTAssertEqual(
      ax3.pointSize,
      UIFontMetrics(forTextStyle: .title1).scaledValue(for: 28, compatibleWith: Self.traits(.accessibilityExtraLarge)),
      accuracy: 0.5,
      "scales as .title1, the same curve the plan's role names"
    )
    XCTAssertEqual(ax3.fontName, "Brygada1918-SemiBold", "scaling must keep the face")
  }

  func testMissingDisplayFontFallsBackToTheSystemSerif() {
    let font = TypographyStyle(.displayTitle)
      .uiFont(compatibleWith: Self.traits(.large), displayFontName: "NoSuchFont-Regular")
    XCTAssertFalse(font.familyName.contains("Brygada"))
    XCTAssertEqual(font.pointSize, 28, accuracy: 0.01)
    // The system serif (New York), not SF: the title still reads as a title.
    let serif = UIFont.systemFont(ofSize: 28, weight: .semibold).fontDescriptor.withDesign(.serif)
    XCTAssertNotNil(serif)
    XCTAssertEqual(font.familyName, serif.map { UIFont(descriptor: $0, size: 28).familyName })
  }

  func testNumericRolesNeverUseTheDisplayFace() {
    for type in [Typography.displayNumber, .metricNumber, .numeric, .numericSmall, .code] {
      let style = TypographyStyle(type)
      XCTAssertNotEqual(style.fontDesign, .serif, "\(type) must stay SF")
      XCTAssertEqual(style.fontDesign, type == .code ? .monospaced : .default, "\(type)")
      let font = style.uiFont(compatibleWith: Self.traits(.large))
      XCTAssertFalse(font.familyName.contains("Brygada"), "\(type) resolved to \(font.fontName)")
    }
  }

  /// The two approved uses. Home keeps `navigationTitle(greetingText)` (see
  /// VigilDesignSystemTests.testHomeDropsCommandCenterTheater) and sets the
  /// display face in the iOS 26 large-title slot.
  func testPageHeaderAndHomeGreetingUseTheDisplayFace() throws {
    let header = try Self.source("financeplan/Components/VigilPageHeader.swift")
    XCTAssertTrue(header.contains("titleStyle: Typography = .displayTitle"), "page titles default to the display face")
    XCTAssertTrue(header.contains(".typography(titleStyle)"), "VigilPageHeader's title uses its title style")

    let item = try Self.greetingItem()
    XCTAssertTrue(item.contains("Text(greetingText)"), "the large-title slot holds the greeting")
    XCTAssertTrue(item.contains(".typography(.displayTitle)"), "the greeting is the display face")
  }

  /// A ticker is a symbol, not a title: it stays SF, like every other figure.
  func testTickerTitlesStaySans() throws {
    for path in [
      "financeplan/Features/Stocks/StockDetailsScreen.swift",
      "financeplan/Features/Crypto/Detail/CryptoDetailScreen.swift"
    ] {
      let src = try Self.source(path)
      let start = try XCTUnwrap(src.range(of: "VigilPageHeader("), "\(path) has no VigilPageHeader")
      let call = src[start.upperBound...].prefix(400)
      XCTAssertTrue(call.contains("titleStyle: .title"), "\(path): the ticker header must pass the SF title role")
      XCTAssertFalse(call.contains(".displayTitle"), "\(path): a ticker never uses the display face")
    }
  }

  /// 28pt serif at AX3 outgrows the large-title slot; two lines, then a little
  /// shrink, never an ellipsis.
  func testHomeGreetingWrapsBeforeItTruncates() throws {
    let item = try Self.greetingItem()
    XCTAssertTrue(item.contains(".lineLimit(2)"), "the greeting may take two lines")
    XCTAssertTrue(item.contains(".minimumScaleFactor(0.8)"), "then shrink slightly rather than truncate")
  }

  private static func source(_ path: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(path)
    return try String(contentsOf: url, encoding: .utf8)
  }

  /// The large-title toolbar item in Home, matched in pieces so a re-indent
  /// does not break the guards.
  private static func greetingItem() throws -> Substring {
    let home = try source("financeplan/Features/Home/DashboardRoot.swift")
    let slot = try XCTUnwrap(home.range(of: "ToolbarItem(placement: .largeTitle)"), "the greeting sits in the large-title slot")
    return home[slot.upperBound...].prefix(300)
  }

  private static func traits(_ category: UIContentSizeCategory) -> UITraitCollection {
    UITraitCollection(preferredContentSizeCategory: category)
  }
}
