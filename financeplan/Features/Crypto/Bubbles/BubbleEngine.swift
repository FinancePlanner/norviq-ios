import CoreGraphics
import Foundation
import StockPlanShared

/// Which quote metric drives bubble size.
enum BubbleSizeMetric: String, CaseIterable, Identifiable {
    case marketCap
    case changeMagnitude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marketCap: return "Market cap"
        case .changeMagnitude: return "% move"
        }
    }
}

/// A single floating bubble in the simulation.
struct CryptoBubble: Identifiable {
    let id: String          // symbol
    let symbol: String
    let name: String
    let changePercent: Double
    let marketCap: Double
    let price: Double

    var position: CGPoint
    var velocity: CGVector
    var radius: CGFloat

    /// Raw value behind the current size metric (pre-normalisation).
    func metricValue(_ metric: BubbleSizeMetric) -> Double {
        switch metric {
        case .marketCap: return max(marketCap, 0)
        case .changeMagnitude: return abs(changePercent)
        }
    }
}

/// Lightweight 2D physics: gentle pull to centre + soft collision separation,
/// bounded to the view. Reference type so the SwiftUI Canvas can step it per frame
/// without invalidating view state.
final class BubbleEngine {
    private(set) var bubbles: [CryptoBubble] = []
    private var bounds: CGSize = .zero
    private var metric: BubbleSizeMetric = .marketCap
    private var lastTick: TimeInterval?

    // Tuning
    private let minRadius: CGFloat = 24
    private let maxRadius: CGFloat = 64
    private let centerPull: CGFloat = 0.6
    private let damping: CGFloat = 0.86

    func configure(quotes: [CryptoQuoteResponse], bounds: CGSize, metric: BubbleSizeMetric) {
        self.bounds = bounds
        self.metric = metric
        guard !quotes.isEmpty, bounds.width > 0, bounds.height > 0 else {
            bubbles = []
            return
        }

        // Preserve positions for bubbles that already exist (smooth metric toggles).
        let existing = Dictionary(uniqueKeysWithValues: bubbles.map { ($0.id, $0) })

        let raw = quotes.map { quoteMetric($0) }
        let maxRaw = max(raw.max() ?? 1, 1)

        bubbles = quotes.map { quote in
            let value = quoteMetric(quote)
            let radius = radiusFor(value: value, maxValue: maxRaw)
            if var prior = existing[quote.symbol] {
                prior.radius = radius
                return prior
            }
            return CryptoBubble(
                id: quote.symbol,
                symbol: quote.symbol,
                name: quote.name,
                changePercent: quote.changePercentage,
                marketCap: quote.marketCap ?? 0,
                price: quote.price,
                position: randomPoint(),
                velocity: CGVector(dx: CGFloat.random(in: -20...20), dy: CGFloat.random(in: -20...20)),
                radius: radius
            )
        }
    }

    func updateBounds(_ size: CGSize) {
        bounds = size
    }

    func setMetric(_ metric: BubbleSizeMetric, quotes: [CryptoQuoteResponse]) {
        configure(quotes: quotes, bounds: bounds, metric: metric)
    }

    /// Advances the simulation to the given timestamp.
    func step(to time: TimeInterval) {
        defer { lastTick = time }
        guard let last = lastTick else { return }
        let dt = CGFloat(min(max(time - last, 0), 1.0 / 30.0))  // clamp for stability
        guard dt > 0, bounds.width > 0, !bubbles.isEmpty else { return }

        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)

        // Centre attraction + integrate.
        for i in bubbles.indices {
            let dx = center.x - bubbles[i].position.x
            let dy = center.y - bubbles[i].position.y
            bubbles[i].velocity.dx += dx * centerPull * dt
            bubbles[i].velocity.dy += dy * centerPull * dt
            bubbles[i].velocity.dx *= damping
            bubbles[i].velocity.dy *= damping
            bubbles[i].position.x += bubbles[i].velocity.dx * dt
            bubbles[i].position.y += bubbles[i].velocity.dy * dt
        }

        resolveCollisions()
        clampToBounds()
    }

    /// Returns the symbol of the bubble containing `point`, if any (topmost first).
    func hitTest(_ point: CGPoint) -> CryptoBubble? {
        for bubble in bubbles.reversed() {
            let dx = bubble.position.x - point.x
            let dy = bubble.position.y - point.y
            if (dx * dx + dy * dy) <= bubble.radius * bubble.radius {
                return bubble
            }
        }
        return nil
    }

    // MARK: - Private

    private func quoteMetric(_ quote: CryptoQuoteResponse) -> Double {
        switch metric {
        case .marketCap: return max(quote.marketCap ?? 0, 0)
        case .changeMagnitude: return abs(quote.changePercentage)
        }
    }

    private func radiusFor(value: Double, maxValue: Double) -> CGFloat {
        // sqrt scaling so area ~ value, with a floor for visibility.
        let normalized = maxValue > 0 ? sqrt(value / maxValue) : 0
        return minRadius + (maxRadius - minRadius) * CGFloat(normalized)
    }

    private func randomPoint() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: maxRadius...(max(bounds.width - maxRadius, maxRadius + 1))),
            y: CGFloat.random(in: maxRadius...(max(bounds.height - maxRadius, maxRadius + 1)))
        )
    }

    private func resolveCollisions() {
        guard bubbles.count > 1 else { return }
        for i in 0..<(bubbles.count - 1) {
            for j in (i + 1)..<bubbles.count {
                let a = bubbles[i]
                let b = bubbles[j]
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let minDist = a.radius + b.radius + 2
                let distSq = dx * dx + dy * dy
                if distSq < minDist * minDist, distSq > 0.0001 {
                    let dist = sqrt(distSq)
                    let overlap = (minDist - dist) / 2
                    let nx = dx / dist
                    let ny = dy / dist
                    bubbles[i].position.x -= nx * overlap
                    bubbles[i].position.y -= ny * overlap
                    bubbles[j].position.x += nx * overlap
                    bubbles[j].position.y += ny * overlap
                }
            }
        }
    }

    private func clampToBounds() {
        for i in bubbles.indices {
            let r = bubbles[i].radius
            if bubbles[i].position.x < r {
                bubbles[i].position.x = r
                bubbles[i].velocity.dx = abs(bubbles[i].velocity.dx) * 0.5
            } else if bubbles[i].position.x > bounds.width - r {
                bubbles[i].position.x = bounds.width - r
                bubbles[i].velocity.dx = -abs(bubbles[i].velocity.dx) * 0.5
            }
            if bubbles[i].position.y < r {
                bubbles[i].position.y = r
                bubbles[i].velocity.dy = abs(bubbles[i].velocity.dy) * 0.5
            } else if bubbles[i].position.y > bounds.height - r {
                bubbles[i].position.y = bounds.height - r
                bubbles[i].velocity.dy = -abs(bubbles[i].velocity.dy) * 0.5
            }
        }
    }
}
