import CoreGraphics
import Testing
@testable import financeplan

@Suite("Guided spotlight geometry")
struct GuidedSpotlightGeometryTests {
  private let container = CGSize(width: 400, height: 800)

  @Test("No hole means no scrim and nothing blocking touches")
  func noHoleMeansNoScrim() {
    #expect(GuidedSpotlightGeometry.showsScrim(hole: nil) == false)
    #expect(GuidedSpotlightGeometry.blockerRects(container: container, hole: nil).isEmpty)
  }

  @Test("A hole leaves exactly its own rect touchable")
  func blockersSurroundHole() {
    let hole = CGRect(x: 100, y: 300, width: 200, height: 60)
    let blockers = GuidedSpotlightGeometry.blockerRects(container: container, hole: hole)
    #expect(blockers.count == 4)
    #expect(blockers.allSatisfy { !$0.intersects(hole.insetBy(dx: 1, dy: 1)) })
    #expect(GuidedSpotlightGeometry.showsScrim(hole: hole))
  }
}
