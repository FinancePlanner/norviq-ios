import Kingfisher
import SwiftUI
import StockPlanShared

struct CryptoNewsRow: View {
    let news: StockNews
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GlassCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(news.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(news.source ?? "News") • \(formatRelativeDate(news.date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let imageURL = news.imageURL, let url = URL(string: imageURL) {
                    // Kingfisher: disk/memory cached and downsampled to the
                    // 60pt frame instead of decoding the full-size thumbnail.
                    KFImage(url)
                        .downsampling(size: CGSize(width: 60, height: 60))
                        .scaleFactor(displayScale)
                        .cacheOriginalImage()
                        .placeholder { Color.gray.opacity(0.2) }
                        .onFailureView { Color.gray.opacity(0.2) }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
            }
        }
    }

    // Built once per process rather than per row (audit I8).
    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func formatRelativeDate(_ dateString: String) -> String {
        guard let date = Self.isoParser.date(from: dateString) else { return dateString }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }
}
