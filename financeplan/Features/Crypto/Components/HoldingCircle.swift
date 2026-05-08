import SwiftUI

struct HoldingCircle: View {
    let symbol: String

    var body: some View {
        Text(String(symbol.prefix(1)))
            .font(.caption2.bold())
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(Circle().stroke(.orange.opacity(0.5), lineWidth: 1))
    }
}
