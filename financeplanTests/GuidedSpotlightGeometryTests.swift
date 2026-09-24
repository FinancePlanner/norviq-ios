import CoreGraphics
import Testing
@testable import financeplan

@Suite("Guided spotlight geometry")
struct GuidedSpotlightGeometryTests {
  @Test("No hole means no scrim")
  func noHoleMeansNoScrim() {
    #expect(GuidedSpotlightGeometry.showsScrim(hole: nil) == false)
  }

  @Test("A hole shows the scrim")
  func holeShowsScrim() {
    #expect(GuidedSpotlightGeometry.showsScrim(hole: CGRect(x: 100, y: 300, width: 200, height: 60)))
  }
}
