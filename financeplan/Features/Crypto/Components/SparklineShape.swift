import Algorithms
import SwiftUI

struct SparklineShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        let stepX = rect.width / CGFloat(values.count - 1)
        let points = values.enumerated().map { i, value in
            CGPoint(x: CGFloat(i) * stepX, y: rect.height * (1 - value))
        }

        var path = Path()
        path.move(to: points[0])
        for (previous, point) in points.adjacentPairs() {
            let midX = (previous.x + point.x) / 2
            path.addCurve(
                to: point,
                control1: CGPoint(x: midX, y: previous.y),
                control2: CGPoint(x: midX, y: point.y)
            )
        }
        return path
    }
}

struct SparklineAreaShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        var path = SparklineShape(values: values).path(in: rect)
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}
