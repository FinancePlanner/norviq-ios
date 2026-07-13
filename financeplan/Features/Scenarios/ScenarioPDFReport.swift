import UIKit

enum ScenarioPDFReport {
  static func render(run: ScenarioRunSummary, result: ScenarioResultPayload) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("norviq-scenario-\(run.id).pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    try renderer.writePDF(to: url) { context in
      context.beginPage(); var y: CGFloat = 52
      draw("Scenario stress-test report", .boldSystemFont(ofSize: 24), &y)
      draw("Private report · Engine \(run.engineVersion) · \(Date().formatted(.iso8601))", .systemFont(ofSize: 10), &y)
      y += 18
      if let probability = result.goalProbability { draw("Goal probability: \(probability.formatted(.percent.precision(.fractionLength(0))))", .boldSystemFont(ofSize: 16), &y) }
      if let drawdown = result.maximumDrawdown { draw("Maximum drawdown: \(drawdown.formatted(.percent.precision(.fractionLength(1))))", .systemFont(ofSize: 13), &y) }
      if let shortfall = result.expectedShortfall { draw("Expected shortfall: \(shortfall.formatted(.number.precision(.fractionLength(0))))", .systemFont(ofSize: 13), &y) }
      let values = result.timeline?.map(\.value) ?? result.percentileBands?.map(\.p50) ?? []
      if values.count > 1 { y += 8; drawChart(values, context: context.cgContext, y: y); y += 150 }
      if let assumptions = result.assumptions { draw("Assumptions", .boldSystemFont(ofSize: 14), &y); draw(assumptions.description, .systemFont(ofSize: 8), &y, height: 90) }
      if let warnings = result.warnings { draw("Data-quality and proxy warnings", .boldSystemFont(ofSize: 14), &y); draw(warnings.description, .systemFont(ofSize: 8), &y, height: 90) }
      y = 710
      draw("Educational analysis only. Not investment, tax, or financial advice. Actual outcomes may differ materially.", .italicSystemFont(ofSize: 9), &y)
    }
    return url
  }
  private static func draw(_ text: String, _ font: UIFont, _ y: inout CGFloat, height: CGFloat = 60) { let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]; text.draw(in: CGRect(x: 52, y: y, width: 508, height: height), withAttributes: attributes); y += height == 60 ? font.lineHeight + 10 : height }
  private static func drawChart(_ values: [Double], context: CGContext, y: CGFloat) {
    let rect = CGRect(x: 52, y: y, width: 508, height: 130); context.setStrokeColor(UIColor.tertiaryLabel.cgColor); context.stroke(rect)
    guard let minimum = values.min(), let maximum = values.max() else { return }; let span = max(1, maximum - minimum)
    let path = CGMutablePath()
    for (index, value) in values.enumerated() {
      let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
      let pointY = rect.maxY - rect.height * CGFloat((value - minimum) / span)
      if index == 0 { path.move(to: CGPoint(x: x, y: pointY)) } else { path.addLine(to: CGPoint(x: x, y: pointY)) }
    }
    context.setStrokeColor(UIColor.systemBlue.cgColor); context.setLineWidth(2); context.addPath(path); context.strokePath()
  }
}
