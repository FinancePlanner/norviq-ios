import SwiftUI

struct SparklineShape: Shape {
    let values: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard values.count >= 2 else { return Path() }
        var path = Path()
        let stepX = rect.width / CGFloat(values.count - 1)

        for (i, value) in values.enumerated() {
            let x = CGFloat(i) * stepX
            let y = rect.height * (1 - value)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let prevX = CGFloat(i - 1) * stepX
                let prevY = rect.height * (1 - values[i - 1])
                let midX = (prevX + x) / 2
                path.addCurve(
                    to: CGPoint(x: x, y: y),
                    control1: CGPoint(x: midX, y: prevY),
                    control2: CGPoint(x: midX, y: y)
                )
            }
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
