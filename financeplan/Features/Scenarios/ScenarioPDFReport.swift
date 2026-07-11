import UIKit

enum ScenarioPDFReport {
  static func render(run: ScenarioRunSummary, result: ScenarioResultPayload) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("norviq-scenario-\(run.id).pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    try renderer.writePDF(to: url) { context in context.beginPage(); var y: CGFloat = 52; draw("Scenario stress-test report", .boldSystemFont(ofSize: 24), &y); draw("Private report · Engine \(run.engineVersion)", .systemFont(ofSize: 10), &y); y += 18; if let probability = result.goalProbability { draw("Goal probability: \(probability.formatted(.percent.precision(.fractionLength(0))))", .boldSystemFont(ofSize: 16), &y) }; if let drawdown = result.maximumDrawdown { draw("Maximum drawdown: \(drawdown.formatted(.percent.precision(.fractionLength(1))))", .systemFont(ofSize: 13), &y) }; y = 710; draw("Educational analysis only. Not investment, tax, or financial advice. Actual outcomes may differ materially.", .italicSystemFont(ofSize: 9), &y) }
    return url
  }
  private static func draw(_ text: String, _ font: UIFont, _ y: inout CGFloat) { let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.label]; text.draw(in: CGRect(x: 52, y: y, width: 508, height: 60), withAttributes: attributes); y += font.lineHeight + 10 }
}
