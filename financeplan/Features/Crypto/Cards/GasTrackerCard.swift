import SwiftUI

struct GasTrackerCard: View {
    let gwei: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    private var statusColor: Color {
        gwei < 20 ? .green : gwei < 40 ? .yellow : .orange
    }

    private var statusText: String {
        gwei < 20 ? "Low · Cheap" : gwei < 40 ? "Normal" : "Congested"
    }

    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("ETH Gas")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.4 : 0.8)
                        .opacity(isPulsing ? 0.5 : 1.0)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                }

                HStack(alignment: .bottom, spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .padding(.bottom, 4)
                    Text("\(gwei)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Gwei")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }

                Text(statusText)
                    .font(.caption2.bold())
                    .foregroundStyle(statusColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusColor.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            guard !reduceMotion else { return }
            isPulsing = true
        }
    }
}
