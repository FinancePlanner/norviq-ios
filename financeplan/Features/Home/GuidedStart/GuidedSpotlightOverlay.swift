import SwiftUI

nonisolated enum GuidedSpotlightGeometry {
  /// No anchor, no dim: a scrim with nothing to tap is a dead end.
  static func showsScrim(hole: CGRect?) -> Bool { hole != nil }

  /// Four rects around the hole that swallow touches, leaving only the hole
  /// live. Empty without a hole, so a missing anchor blocks nothing.
  static func blockerRects(container: CGSize, hole: CGRect?) -> [CGRect] {
    let full = CGRect(origin: .zero, size: container)
    guard let hole = hole?.intersection(full), !hole.isNull, !hole.isEmpty else { return [] }
    return [
      CGRect(x: 0, y: 0, width: container.width, height: hole.minY),
      CGRect(x: 0, y: hole.maxY, width: container.width, height: container.height - hole.maxY),
      CGRect(x: 0, y: hole.minY, width: hole.minX, height: hole.height),
      CGRect(x: hole.maxX, y: hole.minY, width: container.width - hole.maxX, height: hole.height),
    ].filter { $0.width > 0.5 && $0.height > 0.5 }
  }
}
