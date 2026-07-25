import CoreGraphics
import Foundation

/// Bruls squarified-treemap frame computation, kept as a pure function so it
/// is unit-testable independently of SwiftUI. Weights must be positive;
/// output frames are in the same order as the input weights, tile the given
/// rect without overlap, and have areas proportional to the weights.
nonisolated enum SquarifiedTreemap {
  static func frames(weights: [Double], in rect: CGRect) -> [CGRect] {
    let positive = weights.map { max($0, .leastNonzeroMagnitude) }
    let total = positive.reduce(0, +)
    guard total > 0, rect.width > 0, rect.height > 0, !positive.isEmpty else {
      return Array(repeating: .zero, count: weights.count)
    }
    let scale = Double(rect.width * rect.height) / total
    let areas = positive.map { $0 * scale }

    var frames: [CGRect] = []
    frames.reserveCapacity(areas.count)
    var remaining = rect
    var row: [Double] = []
    var index = 0

    func worstAspect(_ row: [Double], side: Double) -> Double {
      guard side > 0, let minArea = row.min(), let maxArea = row.max(), minArea > 0 else {
        return .infinity
      }
      let sum = row.reduce(0, +)
      let sideSquared = side * side
      let sumSquared = sum * sum
      return max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    func layoutRow(_ row: [Double]) {
      let sum = row.reduce(0, +)
      let horizontal = remaining.width >= remaining.height
      if horizontal {
        // Row is a vertical strip on the left edge.
        let stripWidth = CGFloat(sum) / remaining.height
        var y = remaining.minY
        for area in row {
          let height = CGFloat(area) / stripWidth
          frames.append(CGRect(x: remaining.minX, y: y, width: stripWidth, height: height))
          y += height
        }
        remaining = CGRect(
          x: remaining.minX + stripWidth,
          y: remaining.minY,
          width: remaining.width - stripWidth,
          height: remaining.height
        )
      } else {
        // Row is a horizontal strip on the top edge.
        let stripHeight = CGFloat(sum) / remaining.width
        var x = remaining.minX
        for area in row {
          let width = CGFloat(area) / stripHeight
          frames.append(CGRect(x: x, y: remaining.minY, width: width, height: stripHeight))
          x += width
        }
        remaining = CGRect(
          x: remaining.minX,
          y: remaining.minY + stripHeight,
          width: remaining.width,
          height: remaining.height - stripHeight
        )
      }
    }

    while index < areas.count {
      let side = Double(min(remaining.width, remaining.height))
      let candidate = areas[index]
      if row.isEmpty || worstAspect(row + [candidate], side: side) <= worstAspect(row, side: side) {
        row.append(candidate)
        index += 1
      } else {
        layoutRow(row)
        row = []
      }
    }
    if !row.isEmpty {
      layoutRow(row)
    }
    return frames
  }
}
